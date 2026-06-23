CREATE OR REPLACE PROCEDURE sf_avia.silver_layer.sp_transform_bronze_to_silver()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_job_name       VARCHAR := 'SP_TRANSFORM_BRONZE_TO_SILVER';
    v_stream_name    VARCHAR := 'SF_AVIA.BRONZE_LAYER.AIRLINE_DATASET_STREAM';
    v_source         VARCHAR := 'SF_AVIA.BRONZE_LAYER.AIRLINE_DATASET_STREAM';
    v_target         VARCHAR := 'SF_AVIA.SILVER_LAYER.*';
    v_log_id         VARCHAR;
    v_start_time     TIMESTAMP_NTZ; 
    v_end_time       TIMESTAMP_NTZ;
    v_rows_passenger INTEGER := 0;
    v_rows_airport   INTEGER := 0;
    v_rows_flight    INTEGER := 0;
    v_rows_quarantine INTEGER := 0;
    v_error_msg      VARCHAR;
BEGIN
    ALTER SESSION SET TIMEZONE = 'UTC';

    v_start_time := CURRENT_TIMESTAMP();
    v_log_id := MD5(:v_job_name || TO_VARCHAR(:v_start_time, 'YYYYMMDDHH24MISS'));

    -- Check if data is available inside the stream
    IF (NOT SYSTEM$STREAM_HAS_DATA(:v_stream_name)) THEN
        INSERT INTO sf_avia.bronze_layer.pipeline_logs 
            (log_id, job_name, source_object, target_table, status, start_time, end_time, rows_processed, execution_time_sec)
        VALUES 
            (:v_log_id, :v_job_name, :v_source, :v_target, 'SUCCESS_NO_DATA', :v_start_time, :v_start_time, 0, 0);
        RETURN 'Success: No new delta changes detected in stream.';
    END IF;

    -- log the start of processing
    INSERT INTO sf_avia.bronze_layer.pipeline_logs 
        (log_id, job_name, source_object, target_table, status, start_time)
    VALUES 
        (:v_log_id, :v_job_name, :v_source, :v_target, 'STARTED', :v_start_time);

    -- Open transaction for several DML
    BEGIN TRANSACTION;

    ----------------------------------------------------------------------------
    -- CENTRALIZED CLEANING & CONDITIONAL JSON QUARANTINE ROUTING
    ----------------------------------------------------------------------------
    CREATE OR REPLACE TEMPORARY TABLE sf_avia.silver_layer.tmp_scrubbed_stream_delta AS
    SELECT 
        -- Cleaned Dimension Fields
        REGEXP_REPLACE(TRIM("Passenger ID"), '[^a-zA-Z0-9\\s\\-]', '') AS clean_passenger_id,
        REGEXP_REPLACE(TRIM("First Name"), '[^a-zA-Z\\s\\-]', '') AS clean_first_name,
        REGEXP_REPLACE(TRIM("Last Name"), '[^a-zA-Z\\s\\-]', '') AS clean_last_name,
        REGEXP_REPLACE(TRIM(Gender), '[^a-zA-Z\\s]', '') AS clean_gender,
        REGEXP_REPLACE(TRIM(Nationality), '[^a-zA-Z\\s\\-]', '') AS clean_nationality,
        REGEXP_REPLACE(TRIM("Arrival Airport"), '[^a-zA-Z]', '') AS clean_iata_code,
        REGEXP_REPLACE(TRIM("Airport Name"), '[^a-zA-Z0-9\\s\\-\\.\\,]', '') AS clean_airport_name,
        REGEXP_REPLACE(TRIM("Airport Country Code"), '[^a-zA-Z]', '') AS clean_country_code,
        REGEXP_REPLACE(TRIM("Country Name"), '[^a-zA-Z\\s\\-]', '') AS clean_country_name,
        REGEXP_REPLACE(TRIM("Airport Continent"), '[^a-zA-Z]', '') AS clean_continent_code,
        REGEXP_REPLACE(TRIM(Continents), '[^a-zA-Z\\s\\-]', '') AS clean_continent_name,
        
        -- Enforced Typing & String Scrubbing for Fact Ingestion
        TRY_TO_DATE(TRIM("Departure Date"), 'MM/DD/YYYY') AS clean_departure_date,
        TRY_TO_NUMBER(TRIM(Age))                          AS clean_passenger_age,
        REGEXP_REPLACE(TRIM("Pilot Name"), '[^a-zA-Z\\s\\-\\.]', '') AS clean_pilot_name,
        REGEXP_REPLACE(TRIM("Flight Status"), '[^a-zA-Z\\s]', '') AS clean_flight_status,
        REGEXP_REPLACE(TRIM("Ticket Type"), '[^a-zA-Z\\s]', '') AS clean_ticket_type,
        REGEXP_REPLACE(TRIM("Passenger Status"), '[^a-zA-Z\\s]', '') AS clean_passenger_status,

        -- Validation Rules (Filters "-", "0", and bad lengths out of IATA strings)
        CASE 
            WHEN "Passenger ID" IS NULL OR TRIM("Passenger ID") = '' THEN 'Missing Passenger ID'
            
            WHEN "Arrival Airport" IS NULL 
                 OR REGEXP_REPLACE(TRIM("Arrival Airport"), '[^a-zA-Z]', '') = '' 
                 OR LENGTH(REGEXP_REPLACE(TRIM("Arrival Airport"), '[^a-zA-Z]', '')) != 3 
                 THEN 'Missing or Invalid Arrival Airport'
                 
            WHEN TRY_TO_DATE(TRIM("Departure Date"), 'MM/DD/YYYY') IS NULL THEN 'Missing Departure Date'
            ELSE NULL 
        END AS quarantine_reason,

        -- JSON ONLY for damaged records
        CASE 
            WHEN "Passenger ID" IS NULL OR TRIM("Passenger ID") = '' OR
                 "Arrival Airport" IS NULL OR 
                 REGEXP_REPLACE(TRIM("Arrival Airport"), '[^a-zA-Z]', '') = '' OR 
                 LENGTH(REGEXP_REPLACE(TRIM("Arrival Airport"), '[^a-zA-Z]', '')) != 3 OR
                 TRY_TO_DATE(TRIM("Departure Date"), 'MM/DD/YYYY') IS NULL 
            THEN OBJECT_CONSTRUCT(*)
            ELSE NULL 
        END AS inline_quarantine_json
    FROM sf_avia.bronze_layer.airline_dataset_stream
    WHERE METADATA$ACTION = 'INSERT';


    ----------------------------------------------------------------------------
    -- PASSENGER (insert new passengers, don't change their data, new MD5 id is created)
    ----------------------------------------------------------------------------
    MERGE INTO sf_avia.silver_layer.passenger AS target
    USING (
        SELECT DISTINCT
            MD5(COALESCE(clean_passenger_id, '') || COALESCE(clean_first_name, '') || COALESCE(clean_last_name, '') || COALESCE(clean_nationality, '') || COALESCE(clean_gender, '')) AS passenger_id,
            clean_passenger_id AS raw_passenger_id,
            clean_first_name   AS first_name,
            clean_last_name    AS last_name,
            clean_gender       AS gender,
            clean_nationality  AS nationality
        FROM sf_avia.silver_layer.tmp_scrubbed_stream_delta
        WHERE quarantine_reason IS NULL 
    ) AS source
    ON target.passenger_id = source.passenger_id
    WHEN NOT MATCHED THEN
        INSERT (passenger_id, raw_passenger_id, first_name, last_name, gender, nationality)
        VALUES (source.passenger_id, source.raw_passenger_id, source.first_name, source.last_name, source.gender, source.nationality);

    v_rows_passenger := SQLROWCOUNT;


    ----------------------------------------------------------------------------
    -- AIRPORT (SCD Type 1 update existing airports, as I assume "Arrival Airport" as inernational IATA_CODE)
    ----------------------------------------------------------------------------
    MERGE INTO sf_avia.silver_layer.airport AS target
    USING (
        SELECT DISTINCT
            MD5(COALESCE(clean_iata_code, '')) AS airport_id,
            clean_iata_code                    AS iata_code,
            clean_airport_name                 AS airport_name,
            clean_country_code                 AS country_code,
            clean_country_name                 AS country_name,
            clean_continent_code               AS continent_code,
            clean_continent_name               AS continent_name
        FROM sf_avia.silver_layer.tmp_scrubbed_stream_delta
        WHERE quarantine_reason IS NULL 
    ) AS source
    ON target.airport_id = source.airport_id
    WHEN MATCHED AND (
        target.airport_name   != source.airport_name OR 
        target.country_code   != source.country_code OR
        target.country_name   != source.country_name OR
        target.continent_code != source.continent_code OR
        target.continent_name != source.continent_name
    ) THEN
        UPDATE SET 
            target.airport_name   = source.airport_name,
            target.country_code   = source.country_code,
            target.country_name   = source.country_name,
            target.continent_code = source.continent_code,
            target.continent_name = source.continent_name
    WHEN NOT MATCHED THEN
        INSERT (airport_id, iata_code, airport_name, country_code, country_name, continent_code, continent_name)
        VALUES (source.airport_id, source.iata_code, source.airport_name, source.country_code, source.country_name, source.continent_code, source.continent_name);

    v_rows_airport := SQLROWCOUNT;


    ----------------------------------------------------------------------------
    -- FLIGHT (Deterministic Multi-Key Surrogates)
    ----------------------------------------------------------------------------
    MERGE INTO sf_avia.silver_layer.flight AS target
    USING (
        SELECT 
            MD5(COALESCE(clean_passenger_id, '') || COALESCE(clean_first_name, '') || COALESCE(clean_last_name, '') || COALESCE(clean_nationality, '') || COALESCE(clean_gender, '')) AS calculated_passenger_id,
            MD5(COALESCE(clean_iata_code, '')) AS calculated_airport_id,
            
            clean_departure_date,   
            clean_passenger_age,    
            clean_pilot_name,
            clean_flight_status,
            clean_ticket_type,
            clean_passenger_status,
            
            MD5(
                COALESCE(calculated_passenger_id, '') || 
                COALESCE(calculated_airport_id, '') || 
                COALESCE(TO_VARCHAR(clean_departure_date, 'YYYY-MM-DD'), '') ||
                COALESCE(clean_flight_status, '') ||
                COALESCE(clean_passenger_status, '')
            ) AS flight_id
        FROM sf_avia.silver_layer.tmp_scrubbed_stream_delta
        WHERE quarantine_reason IS NULL 
    ) AS source
    ON target.flight_id = source.flight_id
    WHEN NOT MATCHED THEN
        INSERT (flight_id, passenger_id, airport_id, departure_date, passenger_age, pilot_name, flight_status, ticket_type, passenger_status)
        VALUES (source.flight_id, source.calculated_passenger_id, source.calculated_airport_id, source.clean_departure_date, source.clean_passenger_age, source.clean_pilot_name, source.clean_flight_status, source.clean_ticket_type, source.clean_passenger_status);

    v_rows_flight := SQLROWCOUNT;


    ----------------------------------------------------------------------------
    -- QUARANTINE 
    ----------------------------------------------------------------------------
    INSERT INTO sf_avia.silver_layer.ingestion_quarantine (reason, raw_record_json)
    SELECT 
        quarantine_reason,
        inline_quarantine_json
    FROM sf_avia.silver_layer.tmp_scrubbed_stream_delta
    WHERE quarantine_reason IS NOT NULL;

    v_rows_quarantine := SQLROWCOUNT;

    -- Commit and clean stream
    COMMIT;

    -- log Success parameters
    v_end_time := CURRENT_TIMESTAMP();
    UPDATE sf_avia.bronze_layer.pipeline_logs
    SET status = 'SUCCESS',
        rows_processed = :v_rows_passenger + :v_rows_airport + :v_rows_flight + :v_rows_quarantine,
        end_time = :v_end_time,
        execution_time_sec = TIMESTAMPDIFF(second, :v_start_time, :v_end_time)
    WHERE log_id = :v_log_id;

    DROP TABLE IF EXISTS sf_avia.silver_layer.tmp_scrubbed_stream_delta;

    RETURN 'Success: Silver layer transformed and updated cleanly. Log ID: ' || :v_log_id;

EXCEPTION
    WHEN OTHER THEN
        -- rollback prior changes, safe data in the stream
        ROLLBACK; 

        v_end_time := CURRENT_TIMESTAMP();
        v_error_msg := SQLERRM; 

        -- log FAILED parameters
        UPDATE sf_avia.bronze_layer.pipeline_logs
        SET status = 'FAILED',
            error_message = :v_error_msg,
            end_time = :v_end_time,
            execution_time_sec = TIMESTAMPDIFF(second, :v_start_time, :v_end_time)
        WHERE log_id = :v_log_id;
        
        DROP TABLE IF EXISTS sf_avia.silver_layer.tmp_scrubbed_stream_delta;
        
        -- return error to Airflow worker process listener
        RAISE;
END;
$$;