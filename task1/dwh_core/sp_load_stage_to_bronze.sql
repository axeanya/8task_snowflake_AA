CREATE OR REPLACE PROCEDURE sf_avia.bronze_layer.sp_load_stage_to_bronze()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    -- delete+Insert+Merge
    RETURN 'SUCCESS: Bronze';
END;
$$;