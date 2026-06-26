CREATE OR REPLACE PROCEDURE sf_avia.gold_layer.sp_populate_dim_date(p_start_year INT, p_end_year INT)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    ALTER SESSION SET TIMEZONE = 'UTC';

    -- DML overwrite operation
    INSERT OVERWRITE INTO sf_avia.gold_layer.dim_date (
        date_id, 
        calendar_year, 
        calendar_quarter, 
        calendar_month, 
        day_of_week, 
        day_name
    )
    WITH row_generator AS (
        SELECT 
            ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS row_num
        -- Generates a safe buffer of rows 
        FROM TABLE(GENERATOR(ROWCOUNT => 25000))
    ),
    calculated_dates AS (
        SELECT 
            DATEADD(day, row_num, (:p_start_year || '-01-01')::DATE) AS current_date_val
        FROM row_generator
        -- Restrict generation precisely to the date boundaries of the input years
        WHERE row_num <= DATEDIFF(day, (:p_start_year || '-01-01')::DATE, (:p_end_year || '-12-31')::DATE)
    )
    SELECT 
        current_date_val AS date_id,
        EXTRACT(year FROM current_date_val) AS calendar_year,
        EXTRACT(quarter FROM current_date_val) AS calendar_quarter,
        EXTRACT(month FROM current_date_val) AS calendar_month,
        EXTRACT(dayofweekiso FROM current_date_val) AS day_of_week,
        TO_VARCHAR(current_date_val, 'DY') AS day_name
    FROM calculated_dates
    ORDER BY date_id ASC;

    RETURN 'Success: dim_date initialized from ' || :p_start_year || ' to ' || :p_end_year;

END;
$$;