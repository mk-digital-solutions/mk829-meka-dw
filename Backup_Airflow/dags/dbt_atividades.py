import os
from datetime import datetime
from airflow import DAG
# Importação atualizada conforme o aviso de depreciação do Airflow
from airflow.sdk import Param 
from cosmos import DbtTaskGroup, ProjectConfig, ProfileConfig, ExecutionConfig
from cosmos.profiles import PostgresUserPasswordProfileMapping

# --- CONFIGURAÇÕES BÁSICAS ---
BASE_DIR = "/opt/airflow"
DBT_PROJECT_PATH = os.path.join(BASE_DIR, "dags/dbt/cronogramas")
DBT_EXECUTABLE = "/home/airflow/.local/bin/dbt"

# --- CONFIGURAÇÃO DO PERFIL (Conexão Segura) ---
profile_config = ProfileConfig(
    profile_name="meka_dw_postgres",
    target_name="dev",
    profile_mapping=PostgresUserPasswordProfileMapping(
        conn_id="mekadw_airflow",
        profile_args={"schema": "raw_cronogramas", "dbname": "postgres"}
    ),
)

# --- EXECUÇÃO ---
execution_config = ExecutionConfig(dbt_executable_path=DBT_EXECUTABLE)

with DAG(
    dag_id="dbt_atividades",
    start_date=datetime(2024, 1, 1),
    schedule="0 3 * * *",  # Diariamente às 3h da manhã
    catchup=False,
    tags=["dbt", "cronogramas", "atividades"],
    
    # 1. Parâmetros visíveis na UI do Airflow ("Trigger w/ config")
    params={
        "dt_inicio": Param("", type=["string", "null"], description="Data início (YYYY-MM-DD). Deixe vazio para D-3."),
        "dt_fim": Param("", type=["string", "null"], description="Data fim (YYYY-MM-DD). Deixe vazio para Hoje."),
        # Parâmetros adicionados aqui para tipagem nativa no Airflow, eliminando a necessidade de filtros Jinja:
        "modo_debug": Param(False, type="boolean", description="Ativar modo debug? (Limita registros)"),
        "full_refresh": Param(False, type="boolean", description="Forçar full refresh das tabelas?"),
        "num_threads": Param(4, type="integer", description="Número de threads para a execução do dbt."),
    }
) as dag:

    # 2. Configuração do Projeto (Livre de variáveis para não quebrar o Parse do Airflow)
    project_config = ProjectConfig(
        dbt_project_path=DBT_PROJECT_PATH,
    )

    # 3. O Grupo de Tasks do Cosmos
    transformacao = DbtTaskGroup(
        group_id="dbt_run_atividades",
        project_config=project_config,
        profile_config=profile_config,
        execution_config=execution_config,
        
        # Injeta as variáveis dinâmicas APENAS na hora da execução
        operator_args={
            "vars": {
                "raw_schema": "raw_cronogramas",
                "analystic_schema": "analytic_cronogramas",
                "cronogramas": ["mk213_00___ATIVIDADES", "mk385_00___ATIVIDADES","mk389_00___ATIVIDADES"],
                "table_types": ["atividades"],
                "dt_inicio": "{{ params.dt_inicio }}",
                "dt_fim": "{{ params.dt_fim }}",
                # O Jinja só injeta a variável, o Airflow já garantiu que é booleano
                "modo_debug": "{{ params.modo_debug }}" 
            },

            # Rodar apenas os modelos finais (marts)
            "select": "path:models/marts",
            
            # Número de threads repassado direto do Airflow
            "threads": "{{ params.num_threads }}",
            
            # Full refresh condicional repassado direto do Airflow
            "full_refresh": "{{ params.full_refresh }}",
            
            # Fail fast em erro
            "args": "--fail-fast",
        }
    )

    # Define a ordem de execução
    transformacao