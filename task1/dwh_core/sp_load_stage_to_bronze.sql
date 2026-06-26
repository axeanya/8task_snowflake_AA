CREATE OR REPLACE PROCEDURE sf_avia.bronze_layer.sp_load_stage_to_bronze()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_job_name       VARCHAR := 'SP_LOAD_STAGE_TO_BRONZE';
    v_source         VARCHAR := '@sf_avia.bronze_layer.avia_internal_stage';
    v_target         VARCHAR := 'SF_AVIA.BRONZE_LAYER.AIRLINE_DATASET';
    v_log_id         VARCHAR;
    v_start_time     TIMESTAMP_NTZ; 
    v_end_time       TIMESTAMP_NTZ;
    v_rows_loaded    INTEGER;
    v_error_msg      VARCHAR;
BEGIN
    -- Synchronize session timezone to prevent server execution drift
    ALTER SESSION SET TIMEZONE = 'UTC';

    v_start_time := CURRENT_TIMESTAMP();
    v_log_id := MD5(:v_job_name || TO_VARCHAR(:v_start_time, 'YYYYMMDDHH24MISS'));

    -- Log the initiation of the job
    INSERT INTO sf_avia.bronze_layer.pipeline_logs 
        (log_id, job_name, source_object, target_table, status, start_time)
    VALUES 
        (:v_log_id, :v_job_name, :v_source, :v_target, 'STARTED', :v_start_time);

    -- Structured Ingestion
    /*  no need to create a transaction, as long as we have autocommit and 
    there is only 1 DML in this potential transaction*/
    COPY INTO sf_avia.bronze_layer.airline_dataset
    FROM (
        SELECT 
            t.$1, t.$2, t.$3, t.$4, t.$5, t.$6, t.$7, t.$8, t.$9, t.$10, 
            t.$11, t.$12, t.$13, t.$14, t.$15, t.$16, t.$17, t.$18,
            CURRENT_TIMESTAMP() -- Dynamically injects the time as the 19th column!
        FROM @sf_avia.bronze_layer.avia_internal_stage t
    )
    FILE_FORMAT = (
        TYPE = 'CSV'
        FIELD_OPTIONALLY_ENCLOSED_BY = '"'
        SKIP_HEADER = 1
    );

    v_rows_loaded := SQLROWCOUNT;
    v_end_time := CURRENT_TIMESTAMP();

    -- Update log entry with SUCCESS metrics
    UPDATE sf_avia.bronze_layer.pipeline_logs
    SET status = 'SUCCESS',
        rows_processed = :v_rows_loaded,
        end_time = :v_end_time,
        execution_time_sec = TIMESTAMPDIFF(second, :v_start_time, :v_end_time)
    WHERE log_id = :v_log_id;

    RETURN 'Success: Ingested ' || :v_rows_loaded || ' rows. Log ID: ' || :v_log_id;

EXCEPTION
    WHEN OTHER THEN
        v_end_time := CURRENT_TIMESTAMP();
        v_error_msg := SQLERRM; 

        -- Update log entry with FAILURE metrics
        UPDATE sf_avia.bronze_layer.pipeline_logs
        SET status = 'FAILED',
            error_message = :v_error_msg,
            end_time = :v_end_time,
            execution_time_sec = TIMESTAMPDIFF(second, :v_start_time, :v_end_time)
        WHERE log_id = :v_log_id;
        
        RAISE; -- Signals failure back to Airflow
END;
$$;