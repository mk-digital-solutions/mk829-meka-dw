import os
from datetime import datetime
from airflow import DAG
from airflow.models.param import Param
from cosmos import DbtTaskGroup, ProjectConfig, ProfileConfig, ExecutionConfig
from cosmos.profiles import PostgresUserPasswordProfileMapping

# --- CONFIGURAÇÕES BÁSICAS ---
BASE_DIR = "/opt/airflow"
DBT_PROJECT_PATH = os.path.join(BASE_DIR, "dags/dbt/meu_projeto")
DBT_EXECUTABLE = "/home/airflow/.local/bin/dbt"

# --- CONFIGURAÇÃO DO PERFIL (Conexão Segura) ---
profile_config = ProfileConfig(
    profile_name="meu_perfil_postgres",
    target_name="dev",
    profile_mapping=PostgresUserPasswordProfileMapping(
        conn_id="clorum",
        profile_args={"schema": "public", "dbname": "postgres"}
    ),
)

# --- EXECUÇÃO ---
execution_config = ExecutionConfig(dbt_executable_path=DBT_EXECUTABLE)

with DAG(
    dag_id="dbt_run_parametrizado",
    start_date=datetime(2024, 1, 1),
    schedule=None,
    catchup=False,
    tags=["dbt", "cosmos", "parametros"],
    # 1. Parâmetros visíveis na UI do Airflow ("Trigger w/ config")
    params={
        "dt_inicio": Param("", type=["string", "null"], description="Data início (YYYY-MM-DD). Deixe vazio para D-3."),
        "dt_fim": Param("", type=["string", "null"], description="Data fim (YYYY-MM-DD). Deixe vazio para Hoje."),
    }
) as dag:

    # 2. Configuração do Projeto (Livre de variáveis para não quebrar o Parse do Airflow)
    project_config = ProjectConfig(
        dbt_project_path=DBT_PROJECT_PATH,
    )

    # 3. O Grupo de Tasks do Cosmos
    transformacao = DbtTaskGroup(
        group_id="dbt_run_models",
        project_config=project_config,
        profile_config=profile_config,
        execution_config=execution_config,
        
        # AQUI ESTÁ A MÁGICA: Injeta as variáveis dinâmicas APENAS na hora da execução!
        operator_args={
            "vars": {
                "dt_inicio": "{{ params.dt_inicio }}",
                "dt_fim": "{{ params.dt_fim }}"
            }
        }
    )

    # Define a ordem de execução (como só tem o grupo, ele já se resolve sozinho)
    transformacao