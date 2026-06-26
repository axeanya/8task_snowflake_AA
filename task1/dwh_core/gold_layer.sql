-- 1. DIM_PASSENGERS
CREATE OR REPLACE TABLE sf_avia.gold_layer.dim_passengers (
    passenger_key VARCHAR PRIMARY KEY, -- Maps directly to Silver passenger_id (the composite hash)
    passenger_id  VARCHAR,             -- The original raw business ID for analyst reference
    first_name    VARCHAR,
    last_name     VARCHAR,
    gender        VARCHAR,
    nationality   VARCHAR
);

-- 2. DIM_AIRPORTS
CREATE OR REPLACE TABLE sf_avia.gold_layer.dim_airports (
    airport_key          VARCHAR PRIMARY KEY, -- Maps directly to Silver airport_id (MD5 of iata_code)
    iata_code            VARCHAR,
    airport_name         VARCHAR,
    country_code         VARCHAR,
    country_name         VARCHAR,
    continent_code       VARCHAR,
    continent_name       VARCHAR
);

-- 3. DIM_DATE (Standard Analytical Calendar)
CREATE OR REPLACE TABLE sf_avia.gold_layer.dim_date (
    date_id           DATE PRIMARY KEY,
    calendar_year     INTEGER,
    calendar_quarter  INTEGER,
    calendar_month    INTEGER,
    day_of_week       INTEGER,
    day_name          VARCHAR
);

-- 4. FACT_FLIGHTS
CREATE OR REPLACE TABLE sf_avia.gold_layer.fact_flights (
    flight_key         VARCHAR PRIMARY KEY, -- Maps to Silver flight_id (the composite transaction hash)
    passenger_key      VARCHAR FOREIGN KEY REFERENCES sf_avia.gold_layer.dim_passengers(passenger_key),
    airport_key        VARCHAR FOREIGN KEY REFERENCES sf_avia.gold_layer.dim_airports(airport_key),
    departure_date     DATE FOREIGN KEY REFERENCES sf_avia.gold_layer.dim_date(date_id),
    passenger_age      INTEGER,             
    pilot_name         VARCHAR,
    flight_status      VARCHAR,
    ticket_type        VARCHAR,
    passenger_status   VARCHAR
);