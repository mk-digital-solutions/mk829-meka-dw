import os
from datetime import datetime
from airflow import DAG
from airflow.sdk import Param
from cosmos import DbtTaskGroup, ProjectConfig, ProfileConfig, ExecutionConfig, RenderConfig
from cosmos.profiles import PostgresUserPasswordProfileMapping

# --- CONFIGURAÇÕES BÁSICAS ---
BASE_DIR = "/opt/airflow"
DBT_PROJECT_PATH = os.path.join(BASE_DIR, "dags/dbt/meka-dw")
DBT_EXECUTABLE = "/home/airflow/.local/bin/dbt"

# --- CONFIGURAÇÃO DO PERFIL (Conexão Segura) ---
profile_config = ProfileConfig(
    profile_name="meka_dw_postgres",
    target_name="dev",
    profile_mapping=PostgresUserPasswordProfileMapping(
        conn_id="mekadw_airflow",
        profile_args={"schema": "mart", "dbname": "postgres"}
    ),
)

# --- EXECUÇÃO ---
execution_config = ExecutionConfig(dbt_executable_path=DBT_EXECUTABLE)


with DAG(
    dag_id="dbt_cronogramas_mart",
    start_date=datetime(2024, 1, 1),
    schedule="0 3 * * *",
    catchup=False,
    tags=["dbt", "cronogramas", "mart"],
    params={
        "modo_debug": Param(False, type="boolean", description="Ativar modo debug? (Limita registros)"),
        "full_refresh": Param(False, type="boolean", description="Forçar full refresh das tabelas?"),
        "num_threads": Param(4, type="integer", description="Número de threads para a execução do dbt."),
    }
) as dag:

    project_config = ProjectConfig(
        dbt_project_path=DBT_PROJECT_PATH,
    )

    render_config = RenderConfig(select=["atividades_mart", "banco_mart", "entregas_mart"])

    transformacao = DbtTaskGroup(
        group_id="dbt_run_cronogramas_mart",
        project_config=project_config,
        profile_config=profile_config,
        execution_config=execution_config,
        render_config=render_config,
        operator_args={
            "vars": {
                "int_schema": "int_cronogramas",
                "modo_debug": "{{ params.modo_debug }}",
            },
            "select": "atividades_mart banco_mart entregas_mart",
            "threads": "{{ params.num_threads }}",
            "full_refresh": "{{ params.full_refresh }}",
            "args": "--fail-fast",
        }
    )
