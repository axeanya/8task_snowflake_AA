CREATE OR REPLACE DATABASE sf_avia;
-- create layers
CREATE OR REPLACE SCHEMA sf_avia.bronze_layer;
CREATE OR REPLACE SCHEMA sf_avia.silver_layer;
CREATE OR REPLACE SCHEMA sf_avia.gold_layer;
-- choose database, and virtual dwh for work
-- USE WAREHOUSE COMPUTE_WH;
-- USE DATABASE sf_avia;