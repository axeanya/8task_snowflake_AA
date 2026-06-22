-- 1. PASSENGER TABLE
CREATE OR REPLACE TABLE sf_avia.silver_layer.passenger (
    passenger_id     VARCHAR PRIMARY KEY, -- MD5(raw_id || first_name || last_name || nationality)
    raw_passenger_id VARCHAR, -- Natural key from CSV
    first_name       VARCHAR,
    last_name        VARCHAR,
    gender           VARCHAR,
    nationality      VARCHAR
);

-- 2. AIRPORT TABLE
CREATE OR REPLACE TABLE sf_avia.silver_layer.airport (
    airport_id           VARCHAR PRIMARY KEY, -- MD5(iata_code)
    iata_code            VARCHAR,
    airport_name         VARCHAR,
    country_code         VARCHAR,
    country_name         VARCHAR,
    continent_code       VARCHAR,
    continent_name       VARCHAR
);

-- 3. FLIGHT TABLE
CREATE OR REPLACE TABLE sf_avia.silver_layer.flight (
    flight_id        VARCHAR PRIMARY KEY, -- Generated using MD5 (passenger_id, airport_id, departure_date)
    passenger_id     VARCHAR FOREIGN KEY REFERENCES sf_avia.silver_layer.passenger(passenger_id), 
    airport_id       VARCHAR FOREIGN KEY REFERENCES sf_avia.silver_layer.airport(airport_id),
    departure_date   DATE, -- Converted from text to DATE
    passenger_age    INTEGER, -- depended on passenger and departure_date
    pilot_name       VARCHAR,
    flight_status    VARCHAR,
    ticket_type      VARCHAR,
    passenger_status VARCHAR
);