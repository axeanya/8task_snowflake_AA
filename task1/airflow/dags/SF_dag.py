from datetime import datetime
from airflow.decorators import dag, task_group, task
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator

@dag(
    dag_id="SF_medallion_pipeline",
    schedule=None,
    start_date=datetime(2026, 1, 1),
    catchup=False,
    tags=["Traineeship", "Snowflake"],
    description="DAG for medallion pipeline in snowflake",
)

def SF_medallion_pipeline():
    @task_group(group_id="medallion_processing_group")
    def medallion_processing_group():

        bronze = SQLExecuteQueryOperator(
            task_id="bronze",
            conn_id="snowflake_aa",
            sql="CALL sf_avia.bronze_layer.sp_load_stage_to_bronze();",
            trigger_rule="all_success",
        )

        silver = SQLExecuteQueryOperator(
            task_id="silver",
            conn_id="snowflake_aa",
            sql="CALL SF_AVIA.SILVER_LAYER.SP_TRANSFORM_BRONZE_TO_SILVER();",
            trigger_rule="all_success",
        )

        gold = SQLExecuteQueryOperator(
            task_id="gold",
            conn_id="snowflake_aa",
            sql="CALL SF_AVIA.GOLD_LAYER.SP_TRANSFORM_SILVER_TO_GOLD();",
            trigger_rule="all_success",
        )

        bronze >>silver >> gold 
    
    medallion_processing_group()

SF_medallion_pipeline()