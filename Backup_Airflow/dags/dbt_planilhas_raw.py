import os
import logging
from datetime import datetime

import requests
from airflow import DAG
from airflow.sdk import Param, BaseHook
from airflow.providers.standard.operators.python import PythonOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook
from cosmos import DbtTaskGroup, ProjectConfig, ProfileConfig, ExecutionConfig, RenderConfig
from cosmos.profiles import PostgresUserPasswordProfileMapping

logger = logging.getLogger(__name__)

# --- CONFIGURAÇÕES BÁSICAS ---
BASE_DIR = "/opt/airflow"
DBT_PROJECT_PATH = os.path.join(BASE_DIR, "dags/dbt/meka-dw")
DBT_EXECUTABLE = "/home/airflow/.local/bin/dbt"

PG_CONN_ID = "mekadw_airflow"
AIRBYTE_CONN_ID = "airbyte_api"  # HTTP: host/port da API do Airbyte, login=client_id, password=client_secret
MAPA_TABELA = "audit_airbyte.sincronizacoes_conexoes"

# --- CONFIGURAÇÃO DO PERFIL (Conexão Segura) ---
profile_config = ProfileConfig(
    profile_name="meka_dw_postgres",
    target_name="dev",
    profile_mapping=PostgresUserPasswordProfileMapping(
        conn_id=PG_CONN_ID,
        profile_args={"schema": "mart", "dbname": "postgres"}
    ),
)

# --- EXECUÇÃO ---
execution_config = ExecutionConfig(dbt_executable_path=DBT_EXECUTABLE)


def mapear_sincronizacoes_banco_bi(**context):
    """
    BANCO_BI é gravada por várias conexões do Airbyte (uma por colaborador) e a
    linha só traz o sync_id em _airbyte_meta. Esta task consulta a API do Airbyte
    e grava sync_id -> conexão em audit_airbyte.sincronizacoes_conexoes, usada
    pelo modelo fct_banco_bi_colaboradores para achar o NOME_B1 de cada linha.
    """
    conn = BaseHook.get_connection(AIRBYTE_CONN_ID)
    base_url = f"http://{conn.host}:{conn.port}"
    token = requests.post(
        f"{base_url}/api/v1/applications/token",
        json={"client_id": conn.login, "client_secret": conn.password},
        timeout=30,
    )
    token.raise_for_status()
    session = requests.Session()
    session.headers["Authorization"] = f"Bearer {token.json()['access_token']}"

    # Nome de cada conexão ("google_sheets_hugo_leite → Postgres_mkdw" -> "google_sheets_hugo_leite")
    nomes, offset = {}, 0
    while True:
        resp = session.get(f"{base_url}/api/public/v1/connections", params={"limit": 100, "offset": offset}, timeout=60)
        resp.raise_for_status()
        pagina = resp.json()["data"]
        nomes.update({c["connectionId"]: c["name"].split("→")[0].strip() for c in pagina})
        if len(pagina) < 100:
            break
        offset += 100

    hook = PostgresHook(postgres_conn_id=PG_CONN_ID)
    hook.run(f"""
        CREATE SCHEMA IF NOT EXISTS audit_airbyte;
        CREATE TABLE IF NOT EXISTS {MAPA_TABELA} (
            sync_id         bigint PRIMARY KEY,
            connection_id   text NOT NULL,
            conexao_airbyte text NOT NULL,
            atualizado_em   timestamptz NOT NULL DEFAULT now()
        );
    """)

    sync_ids = [r[0] for r in hook.get_records(
        """SELECT DISTINCT (_airbyte_meta ->> 'sync_id')::bigint
           FROM raw_planilhas."BANCO_BI"
           WHERE _airbyte_meta ? 'sync_id'"""
    )]
    conhecidos = dict(hook.get_records(f"SELECT sync_id, connection_id FROM {MAPA_TABELA}"))

    linhas = []
    for sync_id in sync_ids:
        connection_id = conhecidos.get(sync_id)
        if connection_id is None:
            resp = session.get(f"{base_url}/api/public/v1/jobs/{sync_id}", timeout=30)
            if resp.status_code == 404:
                logger.warning("sync_id %s não encontrado no Airbyte", sync_id)
                continue
            resp.raise_for_status()
            connection_id = resp.json()["connectionId"]
        linhas.append((sync_id, connection_id, nomes.get(connection_id, connection_id), datetime.now()))

    if linhas:
        hook.insert_rows(
            MAPA_TABELA,
            linhas,
            target_fields=["sync_id", "connection_id", "conexao_airbyte", "atualizado_em"],
            replace=True,
            replace_index="sync_id",
        )
    logger.info("%d sync_id(s) em BANCO_BI, %d novo(s) consultado(s) na API",
                len(sync_ids), len([s for s in sync_ids if s not in conhecidos]))


with DAG(
    dag_id="dbt_planilhas_raw",
    start_date=datetime(2024, 1, 1),
    schedule="0 1 * * *",
    catchup=False,
    tags=["dbt", "planilhas", "raw"],
    params={
        "modo_debug": Param(False, type="boolean", description="Ativar modo debug? (Limita registros)"),
        "full_refresh": Param(False, type="boolean", description="Forçar full refresh das tabelas?"),
        "num_threads": Param(4, type="integer", description="Número de threads para a execução do dbt."),
    }
) as dag:

    project_config = ProjectConfig(
        dbt_project_path=DBT_PROJECT_PATH,
    )

    # Seleção pelo arquivo: "planilhas_raw" sozinho casaria também com a pasta
    # models/planilhas_raw/ e levaria junto o fct_banco_bi_colaboradores.
    SELECT_PLANILHAS_RAW = "path:models/planilhas_raw/planilhas_raw.sql"

    render_config = RenderConfig(select=[SELECT_PLANILHAS_RAW], dbt_deps=False)

    transformacao = DbtTaskGroup(
        group_id="dbt_run_planilhas_raw",
        project_config=project_config,
        profile_config=profile_config,
        execution_config=execution_config,
        render_config=render_config,
        operator_args={
            "install_deps": False,  # casa com dbt_deps=False do RenderConfig (ambiente offline)
            "vars": {
                "raw_schema": "public",
                "target_schema": "raw_planilhas",
                "modo_debug": "{{ params.modo_debug }}",
            },
            "select": SELECT_PLANILHAS_RAW,
            "threads": "{{ params.num_threads }}",
            "full_refresh": "{{ params.full_refresh }}",
            "args": "--fail-fast",
        }
    )

    mapear_sincronizacoes = PythonOperator(
        task_id="mapear_sincronizacoes_banco_bi",
        python_callable=mapear_sincronizacoes_banco_bi,
    )

    banco_bi_colaboradores = DbtTaskGroup(
        group_id="dbt_run_banco_bi_colaboradores",
        project_config=project_config,
        profile_config=profile_config,
        execution_config=execution_config,
        render_config=RenderConfig(select=["fct_banco_bi_colaboradores"], dbt_deps=False),
        operator_args={
            "install_deps": False,
            "select": "fct_banco_bi_colaboradores",
            "threads": "{{ params.num_threads }}",
            "full_refresh": "{{ params.full_refresh }}",
            "args": "--fail-fast",
        }
    )

    transformacao >> mapear_sincronizacoes >> banco_bi_colaboradores
