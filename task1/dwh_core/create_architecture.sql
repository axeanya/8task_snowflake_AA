CREATE OR REPLACE DATABASE sf_avia;
-- create layers
CREATE OR REPLACE SCHEMA sf_avia.bronze_layer;
CREATE OR REPLACE SCHEMA sf_avia.silver_layer;
CREATE OR REPLACE SCHEMA sf_avia.gold_layer;
-- choose database, and virtual dwh for work
USE WAREHOUSE COMPUTE_WH;
USE DATABASE sf_avia;
-- 
CREATE OR REPLACE STAGE sf_avia.bronze_layer.avia_internal_stage;

CREATE OR REPLACE TABLE sf_avia.bronze_layer.airline_dataset (
id string,
passenger_id STRING,
first_name STRING,
last_name STRING,
gender STRING,
age STRING,
nationality STRING,
airport_name STRING,
airport_country_code STRING,
country_name STRING, 
airport_continent STRING, 
continents STRING, 
departure_date STRING,
arrival_airport STRING, 
pilot_name STRING, 
flight_status STRING, 
ticket_type STRING,
passenger_status STRING
);

CREATE OR REPLACE STREAM sf_avia.bronze_layer.airline_dataset_stream 
ON TABLE sf_avia.bronze_layer.airline_dataset;
