/*
ALTER TABLE sf_avia.bronze_layer.airline_dataset_table 
SET DATA_RETENTION_TIME_IN_DAYS = 30; -- for enterprise version of snowflake is possible
*/

-- DDL
-- 1. Clones the entire gold schema into a separate testing environment from 30 minutes ago
CREATE OR REPLACE SCHEMA sf_avia.gold_layer_test
CLONE sf_avia.gold_layer
AT(OFFSET => -60*30);

-- 2. undrop table 
drop table sf_avia.gold_layer_test.dim_date;
undrop table sf_avia.gold_layer_test.dim_date;
select top 100 * from sf_avia.gold_layer_test.dim_date;

-- 3. restore stream
CREATE OR REPLACE STREAM sf_avia.silver_layer.passenger_silver_stream
ON TABLE sf_avia.silver_layer.passenger
AT(OFFSET => -60 * 30);
select top 100 * from sf_avia.silver_layer.passenger_silver_stream;

-- DML
-- 1. If commit on table was run, it's possible to overwrite data 
select * from sf_avia.gold_layer_test.dim_date; 
update sf_avia.gold_layer_test.dim_date
set calendar_year = 5;
INSERT OVERWRITE INTO sf_avia.gold_layer_test.dim_date
SELECT * FROM sf_avia.gold_layer_test.dim_date AT(OFFSET => -60*2);

-- 2. assume, having the last pipeline with an error. It's possible to delete data 
DELETE FROM sf_avia.gold_layer_test.fact_flights
WHERE flight_key NOT IN (
    SELECT flight_key 
    FROM sf_avia.gold_layer_test.fact_flights AT(OFFSET => -60*60) 
);