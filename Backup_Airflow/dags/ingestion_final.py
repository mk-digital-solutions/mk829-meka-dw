import os
import shutil
from datetime import datetime
from airflow import DAG
from airflow.operators.bash import BashOperator
from cosmos import DbtTaskGroup, ProjectConfig, ProfileConfig, ExecutionConfig
from cosmos.profiles import PostgresUserPasswordProfileMapping
from cosmos.operators.local import DbtDocsLocalOperator

# --- CONFIGURAÇÕES DO AMBIENTE DOCKER ---
BASE_DIR = "/opt/airflow"
DBT_PROJECT_PATH = os.path.join(BASE_DIR, "dags/dbt/meu_projeto")
DBT_EXECUTABLE = "dbt" # ou "/home/airflow/.local/bin/dbt"

# --- VALIDAÇÃO DE SEGURANÇA ---
if not os.path.exists(DBT_PROJECT_PATH):
    raise ValueError(f"ERRO: Pasta do projeto não encontrada: {DBT_PROJECT_PATH}")

# Configuração do Perfil (Cosmos injeta as env vars do Airflow Connection no dbt)
profile_config = ProfileConfig(
    profile_name="meu_perfil_postgres",
    target_name="dev",
    profile_mapping=PostgresUserPasswordProfileMapping(
        conn_id="db_conn",
        profile_args={
            "schema": "public",
            "dbname": "postgres"}
    ),
)

execution_config = ExecutionConfig(dbt_executable_path=DBT_EXECUTABLE)

with DAG(
    dag_id="ingestion_final_v6_clean",  # Atualizado para v6
    start_date=datetime(2024, 1, 1),
    schedule=None,
    catchup=False,
    tags=["dbt", "cosmos", "openmetadata", "prod"],
) as dag:

    ingest_metadata = BashOperator(
        task_id="enviar_metadados_om",
        cwd=DBT_PROJECT_PATH, # Importante: Define a raiz para o comando achar o dbt_project.yml
        bash_command="""
        set -e
        
        echo "--- 1. Preparando Ambiente de Ingestão ---"
        python3 -m venv /tmp/venv_ingestion
        source /tmp/venv_ingestion/bin/activate
        
        echo "--- 2. Instalando OpenMetadata ---"
        pip install --upgrade pip
        # Instalação fixada na versão 1.11.5.0 para parear com o Servidor
        pip install -q cachetools "openmetadata-ingestion[dbt]==1.11.5.0"
        
        echo "--- 3. Enviando Metadados ---"
        # O comando 'ingest-dbt' vai ler automaticamente:
        #  - dbt_project.yml (na pasta atual)
        #  - target/manifest.json (gerado pela task anterior)
        #  - target/catalog.json (gerado pela task anterior)
        metadata --debug ingest-dbt 
        
        echo "--- 4. Limpeza ---"
        deactivate
        rm -rf /tmp/venv_ingestion
        """
    )