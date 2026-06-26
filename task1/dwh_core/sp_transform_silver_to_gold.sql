CREATE OR REPLACE PROCEDURE sf_avia.gold_layer.sp_transform_silver_to_gold()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_job_name        VARCHAR := 'SP_TRANSFORM_SILVER_TO_GOLD';
    v_source          VARCHAR := 'SF_AVIA.SILVER_LAYER.*_SILVER_STREAM';
    v_target          VARCHAR := 'SF_AVIA.GOLD_LAYER.*';
    v_log_id          VARCHAR;
    v_start_time      TIMESTAMP_NTZ; 
    v_end_time        TIMESTAMP_NTZ;
    v_rows_passengers INTEGER := 0;
    v_rows_airports   INTEGER := 0;
    v_rows_flights    INTEGER := 0;
    v_error_msg       VARCHAR;
BEGIN
    ALTER SESSION SET TIMEZONE = 'UTC';

    v_start_time := CURRENT_TIMESTAMP();
    v_log_id := MD5(:v_job_name || TO_VARCHAR(:v_start_time, 'YYYYMMDDHH24MISS'));

    -- Skip execution if there is no data across all silver streams
    IF (NOT SYSTEM$STREAM_HAS_DATA('sf_avia.silver_layer.passenger_silver_stream') AND
        NOT SYSTEM$STREAM_HAS_DATA('sf_avia.silver_layer.airport_silver_stream') AND
        NOT SYSTEM$STREAM_HAS_DATA('sf_avia.silver_layer.flight_silver_stream')) THEN
        
        INSERT INTO sf_avia.bronze_layer.pipeline_logs 
            (log_id, job_name, source_object, target_table, status, start_time, end_time, rows_processed, execution_time_sec)
        VALUES 
            (:v_log_id, :v_job_name, :v_source, :v_target, 'SUCCESS_NO_DATA', :v_start_time, :v_start_time, 0, 0);
        RETURN 'Success: No new delta changes detected across Silver streams.';
    END IF;

    -- Log pipeline 
    INSERT INTO sf_avia.bronze_layer.pipeline_logs 
        (log_id, job_name, source_object, target_table, status, start_time)
    VALUES 
        (:v_log_id, :v_job_name, :v_source, :v_target, 'STARTED', :v_start_time);

    -- Open transactional 
    BEGIN TRANSACTION;

    ----------------------------------------------------------------------------
    -- DIM_PASSENGERS (Append-Only Inserts)
    ----------------------------------------------------------------------------
    MERGE INTO sf_avia.gold_layer.dim_passengers AS target
    USING (
        SELECT passenger_id, raw_passenger_id, first_name, last_name, gender, nationality
        FROM sf_avia.silver_layer.passenger_silver_stream 
        WHERE METADATA$ACTION = 'INSERT'
    ) AS source
    ON target.passenger_key = source.passenger_id
    WHEN NOT MATCHED THEN
        INSERT (passenger_key, passenger_id, first_name, last_name, gender, nationality)
        VALUES (source.passenger_id, source.raw_passenger_id, source.first_name, source.last_name, source.gender, source.nationality);

    v_rows_passengers := SQLROWCOUNT;

    ----------------------------------------------------------------------------
    -- DIM_AIRPORTS (SCD Type 1 Updates & Inserts)
    ----------------------------------------------------------------------------
    MERGE INTO sf_avia.gold_layer.dim_airports AS target
    USING (
        SELECT airport_id, iata_code, airport_name, country_code, country_name, continent_code, continent_name
        FROM sf_avia.silver_layer.airport_silver_stream
        WHERE METADATA$ACTION = 'INSERT'
    ) AS source
    ON target.airport_key = source.airport_id
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
        INSERT (airport_key, iata_code, airport_name, country_code, country_name, continent_code, continent_name)
        VALUES (source.airport_id, source.iata_code, source.airport_name, source.country_code, source.country_name, source.continent_code, source.continent_name);

    v_rows_airports := SQLROWCOUNT;


    ----------------------------------------------------------------------------
    -- FACT_FLIGHTS (Append-Only Inserts)
    ----------------------------------------------------------------------------
    MERGE INTO sf_avia.gold_layer.fact_flights AS target
    USING (
        SELECT flight_id, passenger_id, airport_id, departure_date, passenger_age, pilot_name, flight_status, ticket_type, passenger_status
        FROM sf_avia.silver_layer.flight_silver_stream
        WHERE METADATA$ACTION = 'INSERT'
    ) AS source
    ON target.flight_key = source.flight_id
    WHEN NOT MATCHED THEN
        INSERT (flight_key, passenger_key, airport_key, departure_date, passenger_age, pilot_name, flight_status, ticket_type, passenger_status)
        VALUES (source.flight_id, source.passenger_id, source.airport_id, source.departure_date, source.passenger_age, source.pilot_name, source.flight_status, source.ticket_type, source.passenger_status);

    v_rows_flights := SQLROWCOUNT;

    COMMIT;

    -- Log success execution data
    v_end_time := CURRENT_TIMESTAMP();
    UPDATE sf_avia.bronze_layer.pipeline_logs
    SET status = 'SUCCESS',
        rows_processed = :v_rows_passengers + :v_rows_airports + :v_rows_flights,
        end_time = :v_end_time,
        execution_time_sec = TIMESTAMPDIFF(second, :v_start_time, :v_end_time)
    WHERE log_id = :v_log_id;

    RETURN 'Success: Gold tables loaded via incremental silver streams. Log ID: ' || :v_log_id;

EXCEPTION
    WHEN OTHER THEN
        ROLLBACK; 

        v_end_time := CURRENT_TIMESTAMP();
        v_error_msg := SQLERRM; 

        UPDATE sf_avia.bronze_layer.pipeline_logs
        SET status = 'FAILED',
            error_message = :v_error_msg,
            end_time = :v_end_time,
            execution_time_sec = TIMESTAMPDIFF(second, :v_start_time, :v_end_time)
        WHERE log_id = :v_log_id;
        
        RAISE;
END;
$$;