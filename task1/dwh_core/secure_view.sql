-- VIEW 
CREATE OR REPLACE VIEW sf_avia.gold_layer.vw_AGE_AVG AS
select 
d.calendar_year, 
d.calendar_month,
avg(f.passenger_age)  age_avg
from SF_AVIA.GOLD_LAYER.FACT_FLIGHTS f 
join dim_date d on d.date_id = f.departure_date
group by d.calendar_year, d.calendar_month
order by d.calendar_year, d.calendar_month;

-- SECURE VIEW
CREATE OR REPLACE SECURE VIEW sf_avia.gold_layer.vw_SECURE_AGE_AVG AS
select 
d.calendar_year, 
d.calendar_month, 
avg(f.passenger_age)  age_avg
from SF_AVIA.GOLD_LAYER.FACT_FLIGHTS f 
join dim_date d on d.date_id = f.departure_date
group by d.calendar_year, d.calendar_month
order by d.calendar_year, d.calendar_month;

-- CREATE A NEW ROLE
USE ROLE ACCOUNTADMIN;
CREATE OR REPLACE ROLE data_analyst_role;
GRANT USAGE ON DATABASE sf_avia TO ROLE data_analyst_role;
GRANT USAGE ON SCHEMA sf_avia.gold_layer TO ROLE data_analyst_role;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE data_analyst_role;

-- ROW ACCESS POLICY
CREATE OR REPLACE ROW ACCESS POLICY sf_avia.gold_layer.age_avg_security_policy
AS (calendar_month INTEGER) RETURNS BOOLEAN ->
       CURRENT_ROLE() = 'ACCOUNTADMIN'       -- Admin sees EVERYTHING
    OR (
       CURRENT_ROLE() = 'DATA_ANALYST_ROLE'  -- Analyst is restricted to 'On Time' only
       AND calendar_month >5
    );
ALTER VIEW sf_avia.gold_layer.vw_SECURE_AGE_AVG 
ADD ROW ACCESS POLICY sf_avia.gold_layer.age_avg_security_policy ON (calendar_month);

-- GRANT privileges on VIEW
GRANT SELECT ON VIEW sf_avia.gold_layer.vw_secure_age_avg TO ROLE data_analyst_role;
GRANT SELECT ON VIEW sf_avia.gold_layer.vw_age_avg TO ROLE data_analyst_role;

GRANT ROLE data_analyst_role TO USER AXEANYA;

-- This command doesn't work in VS Code. I changed my role in vs code snowflake extension 
-- and switch "Use secondary roles" off  
USE ROLE data_analyst_role; 

-- TESTING
-- 1. VIEW
SELECT * FROM SF_AVIA.GOLD_LAYER.VW_AGE_AVG;
SELECT GET_DDL('VIEW', 'SF_AVIA.GOLD_LAYER.VW_AGE_AVG');
-- 2. SECTURE VIEW
SELECT * FROM SF_AVIA.GOLD_LAYER.VW_SECURE_AGE_AVG;
SELECT GET_DDL('VIEW', 'SF_AVIA.GOLD_LAYER.VW_SECURE_AGE_AVG');

/* 
SHOW GRANTS ON VIEW sf_avia.gold_layer.vw_secure_age_avg;
SHOW GRANTS TO ROLE data_analyst_role;
*/
