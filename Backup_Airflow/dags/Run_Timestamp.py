import os
from datetime import datetime
from airflow import DAG
from airflow.models.param import Param
from cosmos import DbtTaskGroup, ProjectConfig, ProfileConfig, ExecutionConfig
from cosmos.profiles import PostgresUserPasswordProfileMapping

# --- PATHS ---
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
    dag_id="dbt_run",
    start_date=datetime(2024, 1, 1),
    schedule=None,
    catchup=False,
    tags=["dbt", "cosmos", "parametros", "sensores"],
    
    # 1. PARÂMETROS ATUALIZADOS PARA RECEBER DATA E HORA
    params={
        "ts_inicio": Param("", type=["string", "null"], description="Início (YYYY-MM-DD HH:MM:SS). Deixe vazio para usar as horas padrão do modelo."),
        "ts_fim": Param("", type=["string", "null"], description="Fim (YYYY-MM-DD HH:MM:SS). Deixe vazio para usar a hora atual."),
    }
) as dag:

    # 2. Configuração do Projeto (Vazia para não quebrar o Parse do Airflow)
    project_config = ProjectConfig(
        dbt_project_path=DBT_PROJECT_PATH,
    )

    # 3. O Grupo de Tasks do Cosmos
    transformacao = DbtTaskGroup(
        group_id="dbt_run_models",
        project_config=project_config,
        profile_config=profile_config,
        execution_config=execution_config,
        
        # 4. INJETANDO AS NOVAS VARIÁVEIS DE TIMESTAMP NA EXECUÇÃO
        operator_args={
            "vars": {
                "ts_inicio": "{{ params.ts_inicio }}",
                "ts_fim": "{{ params.ts_fim }}"
            }
        }
    )

    transformacao