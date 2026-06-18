CREATE OR REPLACE PROCEDURE sf_avia.gold_layer.sp_transform_silver_to_gold()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    -- delete+Insert+Merge
    RETURN 'SUCCESS: GOLD';
END;
$$;