CREATE OR REPLACE STAGE sf_avia.bronze_layer.avia_internal_stage;

-- schema evolution?
-- CREATE OR REPLACE TABLE sf_avia.bronze_layer.airline_dataset (
-- NONAME_0 VARCHAR,
-- "Passenger ID" VARCHAR,
-- "First Name" VARCHAR,
-- "Last Name" VARCHAR,
-- Gender VARCHAR, 
-- Age VARCHAR,
-- Nationality VARCHAR,
-- "Airport Name" VARCHAR,
-- "Airport Country Code" VARCHAR,
-- "Country Name" VARCHAR,
-- "Airport Continent" VARCHAR,
-- Continents VARCHAR,
-- "Departure Date" VARCHAR,
-- "Arrival Airport" VARCHAR,
-- "Pilot Name" VARCHAR,
-- "Flight Status" VARCHAR,
-- "Ticket Type" VARCHAR,
-- "Passenger Status" VARCHAR,
-- _loaded_at       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
-- );
CREATE OR REPLACE TABLE sf_avia.bronze_layer.airline_dataset (
    raw_record  VARIANT,
    _loaded_at  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
CREATE OR REPLACE TABLE sf_avia.bronze_layer.pipeline_logs (
    log_id            VARCHAR PRIMARY KEY, -- MD5(job_name || start_time)
    job_name          VARCHAR,             -- e.g., 'SP_LOAD_STAGE_TO_BRONZE'
    source_object     VARCHAR,             -- e.g., '@AVIA_INTERNAL_STAGE'
    target_table      VARCHAR,             -- e.g., 'SF_AVIA.BRONZE_LAYER.AIRLINE_DATASET'
    status            VARCHAR,             -- 'STARTED', 'SUCCESS', 'FAILED'
    rows_processed    INTEGER DEFAULT 0,   -- Total rows handled
    error_message     VARCHAR,             -- Captures SQL exceptions if they happen
    start_time        TIMESTAMP_NTZ,
    end_time          TIMESTAMP_NTZ,
    execution_time_sec NUMBER(10, 2)       -- Calculated duration
);
CREATE OR REPLACE STREAM sf_avia.bronze_layer.airline_dataset_stream 
ON TABLE sf_avia.bronze_layer.airline_dataset;