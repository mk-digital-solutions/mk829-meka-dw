"""
Lineage planilhas -> OpenMetadata (via REST API).

Os modelos planilhas_raw / planilhas_stg / planilhas_mart criam as tabelas de
destino dinamicamente (run_query), então o dbt NÃO registra o lineage delas no
manifest. Como o mapeamento é 1:1 pelo nome da tabela e da coluna, esta DAG cria
as setas diretamente na API do OpenMetadata, cobrindo a cadeia completa:

    raw_planilhas -> stg_planilhas -> mart_planilhas

A tabela de log (planilhas_log_execucao) existe nos três schemas, mas é metadado
operacional do próprio modelo — não é dado de origem — então é excluída.

Pré-requisito: as tabelas raw_*/stg_*/mart_* já devem estar catalogadas no OM
(workflow de metadados do Database Service Postgres). Caso contrário, os pares
são apenas "skipados" com aviso no log.
"""
import os
import logging
import urllib.parse
from datetime import datetime

import yaml
import requests
from airflow import DAG
from airflow.sdk import Param
from airflow.providers.standard.operators.python import PythonOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook

logger = logging.getLogger("airflow.task")

# --- CONFIGURAÇÕES ---
BASE_DIR = "/opt/airflow"
OM_CONFIG_PATH = os.path.join(BASE_DIR, "dags/dbt/meka-dw/openmetadata.yaml")

OM_SERVICE = "mekadw_openmetadata"   # Database Service já criado no OM
PG_CONN_ID = "mekadw_airflow"

# Tabela de log dos modelos planilhas — não é dado de origem, não gera lineage.
LOG_TABLE = "planilhas_log_execucao"

# Pares (schema_origem, schema_destino) — cadeia raw -> stg -> mart
SCHEMA_PAIRS = [
    ("raw_planilhas", "stg_planilhas"),
    ("stg_planilhas", "mart_planilhas"),
]


def _load_om_config(path):
    """Lê hostPort e jwtToken do openmetadata.yaml."""
    with open(path) as f:
        cfg = yaml.safe_load(f)
    server = cfg["workflowConfig"]["openMetadataServerConfig"]
    host = server["hostPort"].rstrip("/")  # ex.: http://192.168.0.157:8585/api
    token = server["securityConfig"]["jwtToken"]
    return host, token


def _session(token):
    s = requests.Session()
    s.headers.update({
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    })
    return s


def _get_table(session, host, fqn):
    """Busca a tabela no OM pelo FQN. Retorna o JSON (com id + columns) ou None."""
    url = f"{host}/v1/tables/name/{urllib.parse.quote(fqn, safe='')}?fields=columns"
    r = session.get(url, timeout=30)
    if r.status_code == 404:
        return None
    r.raise_for_status()
    return r.json()


def _put_lineage(session, host, from_tbl, to_tbl):
    """Cria a aresta de lineage (tabela + colunas 1:1 por nome)."""
    to_cols = {c["name"]: c["fullyQualifiedName"] for c in (to_tbl.get("columns") or [])}
    cols_lineage = [
        {"fromColumns": [c["fullyQualifiedName"]], "toColumn": to_cols[c["name"]]}
        for c in (from_tbl.get("columns") or [])
        if c["name"] in to_cols
    ]

    body = {
        "edge": {
            "fromEntity": {"id": from_tbl["id"], "type": "table"},
            "toEntity": {"id": to_tbl["id"], "type": "table"},
            "lineageDetails": {
                "source": "Manual",
                "columnsLineage": cols_lineage,
            },
        }
    }
    r = session.put(f"{host}/v1/lineage", json=body, timeout=30)
    r.raise_for_status()


def criar_lineage(**context):
    params = context["params"]
    om_database = params.get("om_database") or "postgres"
    dry_run = bool(params.get("dry_run", False))

    host, token = _load_om_config(OM_CONFIG_PATH)
    session = _session(token)
    hook = PostgresHook(postgres_conn_id=PG_CONN_ID)

    total_ok, total_skip = 0, 0
    for origem_schema, destino_schema in SCHEMA_PAIRS:
        # Só tabelas que existem em AMBOS os schemas (exceto a tabela de log)
        rows = hook.get_records(
            """
            SELECT r.table_name
            FROM information_schema.tables r
            JOIN information_schema.tables m
              ON m.table_name = r.table_name AND m.table_schema = %s
            WHERE r.table_schema = %s
              AND r.table_name <> %s
            ORDER BY r.table_name
            """,
            parameters=(destino_schema, origem_schema, LOG_TABLE),
        )
        tabelas = [row[0] for row in rows]
        logger.info("[%s -> %s] %d tabela(s) candidata(s)", origem_schema, destino_schema, len(tabelas))

        for t in tabelas:
            from_fqn = f"{OM_SERVICE}.{om_database}.{origem_schema}.{t}"
            to_fqn = f"{OM_SERVICE}.{om_database}.{destino_schema}.{t}"

            from_tbl = _get_table(session, host, from_fqn)
            to_tbl = _get_table(session, host, to_fqn)
            if not from_tbl or not to_tbl:
                logger.warning(
                    "SKIP '%s': nao encontrada no OM (origem=%s, destino=%s). "
                    "A ingestao de metadados Postgres ja rodou?",
                    t, bool(from_tbl), bool(to_tbl),
                )
                total_skip += 1
                continue

            if dry_run:
                logger.info("DRY-RUN: %s -> %s", from_fqn, to_fqn)
            else:
                _put_lineage(session, host, from_tbl, to_tbl)
                logger.info("OK: %s -> %s", from_fqn, to_fqn)
            total_ok += 1

    logger.info("FIM. processadas=%d, skip=%d", total_ok, total_skip)
    if total_ok == 0:
        raise ValueError(
            "Nenhuma lineage criada. Verifique OM_SERVICE='%s', om_database='%s' e "
            "se as tabelas raw_*/stg_*/mart_* ja foram ingeridas no OpenMetadata."
            % (OM_SERVICE, om_database)
        )


with DAG(
    dag_id="om_lineage_planilhas",
    start_date=datetime(2024, 1, 1),
    schedule="45 3 * * *",
    catchup=False,
    tags=["openmetadata", "lineage", "planilhas"],
    params={
        "om_database": Param(
            "postgres", type="string",
            description="Nome do database no OM. FQN usado: <service>.<DATABASE>.<schema>.<tabela>.",
        ),
        "dry_run": Param(
            False, type="boolean",
            description="Se True, apenas loga os pares encontrados sem criar lineage.",
        ),
    },
) as dag:

    PythonOperator(
        task_id="criar_lineage_om",
        python_callable=criar_lineage,
    )
