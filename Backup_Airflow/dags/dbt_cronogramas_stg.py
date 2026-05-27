import os
from datetime import datetime
from airflow import DAG
from airflow.sdk import Param
from airflow.providers.standard.operators.python import PythonOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook
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


# --- FUNÇÃO QUE BUSCA OS CRONOGRAMAS NO BANCO ---
def buscar_cronogramas_stg(**context):
    """Unifica os códigos de cronograma (mkXXX) das tabelas raw de
    BANCO, ATIVIDADES e ENTREGAS num único conjunto. Cada modelo staging
    reanexa o sufixo correto e ignora tabelas inexistentes."""
    hook = PostgresHook(postgres_conn_id="mekadw_airflow")
    resultado = hook.get_records("""
        SELECT DISTINCT LOWER(SUBSTRING(tablename FROM '(?i)mk[0-9]+')) AS codigo
        FROM pg_tables
        WHERE schemaname = 'raw_cronogramas'
          AND (tablename ILIKE 'mk%_00___BANCO'
               OR tablename ILIKE 'mk%_00___ATIVIDADES'
               OR tablename ILIKE 'mk%_00___ENTREGAS')
        ORDER BY codigo
    """)
    cronogramas = [row[0] for row in resultado]
    context["ti"].xcom_push(key="cronogramas", value=cronogramas)


with DAG(
    dag_id="dbt_cronogramas_stg",
    start_date=datetime(2024, 1, 1),
    schedule="0 3 * * *",
    catchup=False,
    tags=["dbt", "cronogramas", "stg"],
    # ✅ CORREÇÃO: faz o Jinja devolver o tipo nativo (lista) em vez de string
    render_template_as_native_obj=True,
    params={
        "modo_debug": Param(False, type="boolean", description="Ativar modo debug? (Limita registros)"),
        "full_refresh": Param(False, type="boolean", description="Forçar full refresh das tabelas?"),
        "num_threads": Param(4, type="integer", description="Número de threads para a execução do dbt."),
    }
) as dag:

    buscar_cronogramas = PythonOperator(
        task_id="buscar_cronogramas",
        python_callable=buscar_cronogramas_stg,
    )

    project_config = ProjectConfig(
        dbt_project_path=DBT_PROJECT_PATH,
    )

    # ✅ Renderiza APENAS os 3 modelos staging como tasks (não o projeto inteiro)
    render_config = RenderConfig(select=["atividades_stg", "banco_stg", "entregas_stg"])

    transformacao = DbtTaskGroup(
        group_id="dbt_run_cronogramas_stg",
        project_config=project_config,
        profile_config=profile_config,
        execution_config=execution_config,
        render_config=render_config,
        operator_args={
            "vars": {
                "raw_schema": "raw_cronogramas",
                # ✅ Com render_template_as_native_obj=True, isso volta como lista real
                "cronogramas": "{{ ti.xcom_pull(task_ids='buscar_cronogramas', key='cronogramas') }}",
                "modo_debug": "{{ params.modo_debug }}",
            },
            "select": "atividades_stg banco_stg entregas_stg",
            "threads": "{{ params.num_threads }}",
            "full_refresh": "{{ params.full_refresh }}",
            "args": "--fail-fast",
        }
    )

    buscar_cronogramas >> transformacao
