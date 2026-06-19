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
NONAME_0 VARCHAR,
"Passenger ID" VARCHAR,
"First Name" VARCHAR,
"Last Name" VARCHAR,
Gender VARCHAR, 
Age VARCHAR,
Nationality VARCHAR,
"Airport Name" VARCHAR,
"Airport Country Code" VARCHAR,
"Country Name" VARCHAR,
"Airport Continent" VARCHAR,
Continents VARCHAR,
"Departure Date" VARCHAR,
"Arrival Airport" VARCHAR,
"Pilot Name" VARCHAR,
"Flight Status" VARCHAR,
"Ticket Type" VARCHAR,
"Passenger Status" VARCHAR
);

CREATE OR REPLACE STREAM sf_avia.bronze_layer.airline_dataset_stream 
ON TABLE sf_avia.bronze_layer.airline_dataset;

CREATE OR REPLACE TABLE sf_avia.silver_layer.passenger (
passenger_id
first_name
last_name
gender
age
nationality
);

CREATE OR REPLACE TABLE sf_avia.silver_layer.airport(
airport_id
airport_name
airport_country_code
country_name
airport_continent
continents
arrival_airport
);

CREATE OR REPLACE TABLE sf_avia.silver_layer.flight(
flight_id
passenger_id
airport_id
departure_date
pilot_name
fligh_status
ticket_type
passenger_status
);