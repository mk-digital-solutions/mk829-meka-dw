import os
import shutil
from datetime import datetime
from airflow import DAG
from cosmos import ProjectConfig, ProfileConfig, ExecutionConfig
from cosmos.profiles import PostgresUserPasswordProfileMapping
from cosmos.operators.local import DbtDocsLocalOperator

# --- CONFIGURAÇÕES ---
BASE_DIR = "/opt/airflow"
DBT_PROJECT_PATH = os.path.join(BASE_DIR, "dags/dbt/meka-dw")
TARGET_FINAL = os.path.join(DBT_PROJECT_PATH, "target") 
DBT_EXECUTABLE = "dbt"

# --- FUNÇÃO DE RESGATE ---
def salvar_artefatos_no_disco(project_dir: str, **kwargs):
    """
    Copia manifest.json e catalog.json da pasta temp para a pasta real.
    Aceita **kwargs para ignorar o argumento 'context' enviado pelo Airflow.
    """
    import logging
    logger = logging.getLogger("airflow.task")
    
    temp_target = os.path.join(project_dir, "target")
    
    logger.info(f"--- INICIANDO RESGATE DE ARTEFATOS ---")
    logger.info(f"Origem (Temp): {temp_target}")
    logger.info(f"Destino (Final): {TARGET_FINAL}")

    # Garante que a pasta destino existe
    if not os.path.exists(TARGET_FINAL):
        os.makedirs(TARGET_FINAL)
        logger.info(f"Pasta destino criada: {TARGET_FINAL}")

    arquivos = ["manifest.json", "catalog.json", "index.html"]
    
    sucesso = True
    for arquivo in arquivos:
        origem = os.path.join(temp_target, arquivo)
        destino = os.path.join(TARGET_FINAL, arquivo)
        
        if os.path.exists(origem):
            try:
                shutil.copy2(origem, destino)
                logger.info(f"SUCESSO: {arquivo} copiado.")
            except Exception as e:
                logger.error(f"ERRO ao copiar {arquivo}: {str(e)}")
                sucesso = False
        else:
            logger.warning(f"AVISO: {arquivo} não encontrado na origem.")
            
    logger.info("--- FIM DO RESGATE ---")

# --- CONFIGURAÇÃO DO PERFIL ---
profile_config = ProfileConfig(
    profile_name="meka_dw_postgres",
    target_name="dev",
    profile_mapping=PostgresUserPasswordProfileMapping(
        conn_id="mekadw_airflow",
        profile_args={"schema": "raw_cronogramas", "dbname": "postgres"}
    ),
)

execution_config = ExecutionConfig(dbt_executable_path=DBT_EXECUTABLE)

with DAG(
    dag_id="gera_docs_dbt",
    start_date=datetime(2024, 1, 1),
    schedule="0 2 * * *",
    catchup=False,
    tags=["dbt", "cosmos", "docs"],
) as dag:

    # Geração da Documentação com Callback Corrigido
    gerar_docs = DbtDocsLocalOperator(
        task_id="dbt_generate_docs",
        project_dir=DBT_PROJECT_PATH,
        profile_config=profile_config,
        execution_config=execution_config,
        
        should_copy_project=True, # Deixa o Cosmos usar a pasta temp
        install_deps=False,
        
        # Chama a função para salvar os arquivos no diretório final
        callback=salvar_artefatos_no_disco
    )