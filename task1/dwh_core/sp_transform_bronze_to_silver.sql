CREATE OR REPLACE PROCEDURE sf_avia.silver_layer.sp_transform_bronze_to_silver()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    -- delete+Insert+Merge
    RETURN 'SUCCESS: Silver';
END;
$$;