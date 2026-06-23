# 8task_Spark_AA
## task1:
### Task Description
Creation of small DWH (5-10 tables) 5 with several layer, which will be based on input data and creatine ETL pipeline of processing data into target layer using AIrflow

### Acceptance Criteria
1. Data is processed into DWH through several stages of storage:
- SOLUTION: medallion architecture (raw data -> cleaned data in the 2NF -> Dimensional modelling)
2. Data should be loaded in several ways using Airflow:
- SOLUTION: snowflake internal stage (internal stage was created on the bronze layer)
3. Additional required tasks from the Task Steps section are done
- SOLUTION:
    1. logging process: 
        - pipeline_logs(bronze): 1 row for each task of DAG (SP)
        - ingestion_quarantine(silver): broken data stored here in OBJECT type as JSON.
        For example, I assume the "Arrival Airport" as IATA_CODE, and all airports without international code are in this table. 


## task2:
### Task Description
Determine if it is possible to replace following code with a kind of cycle in SQL procedure. (i.e how to do it in Postgres and Snowflake)? 
Result would be a separate SQL file with a Postgres solution, and second file with a Snowflake solution.
### Solution
- task for both, Snowflake and Postgres was completed using cursor

## task3:
