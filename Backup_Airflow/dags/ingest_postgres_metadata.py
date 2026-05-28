"""
Ingestão de metadados do Postgres para o OpenMetadata.

Escaneia o banco Postgres e cataloga tabelas, schemas e colunas no serviço
'mekadw_openmetadata'. Este é o passo PRÉ-REQUISITO: sem as tabelas catalogadas,
o lineage do dbt (ingestion_final) e da API (om_lineage_flowup_mmgp) não tem
onde se conectar.

Arquitetura (importante):
- Task 1 (PythonOperator, ambiente do Airflow): lê a connection do Postgres e
  gera o /tmp/postgres_config.yaml já com as credenciais reais.
- Task 2 (BashOperator, venv isolado): cria venv, instala openmetadata-ingestion
  e roda 'metadata ingest'. O venv NÃO tem o Airflow — por isso o YAML precisa
  vir pronto do Task 1 (não dá para importar PostgresHook dentro do venv).
"""
import os
from datetime import datetime

import yaml
from airflow import DAG
from airflow.hooks.base import BaseHook
from airflow.operators.bash import BashOperator
from airflow.providers.standard.operators.python import PythonOperator

PG_CONN_ID = "mekadw_airflow"
OM_HOST = "http://192.168.0.156:8585/api"
OM_JWT_TOKEN = "eyJraWQiOiJHYjM4OWEtOWY3Ni1nZGpzLWE5MmotMDI0MmJrOTQzNTYiLCJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJvcGVuLW1ldGFkYXRhLm9yZyIsInN1YiI6ImluZ2VzdGlvbi1ib3QiLCJyb2xlcyI6WyJJbmdlc3Rpb25Cb3RSb2xlIl0sImVtYWlsIjoiaW5nZXN0aW9uLWJvdEBvcGVuLW1ldGFkYXRhLm9yZyIsImlzQm90Ijp0cnVlLCJ0b2tlblR5cGUiOiJCT1QiLCJ1c2VybmFtZSI6ImluZ2VzdGlvbi1ib3QiLCJwcmVmZXJyZWRfdXNlcm5hbWUiOiJpbmdlc3Rpb24tYm90IiwiaWF0IjoxNzczNDE2MjY1LCJleHAiOm51bGx9.rzt4KrFbDYr1-TVTR3ZdIi7dm5d44SyIb6k0C1c4agH0djFgQHgjZg6yXcDDiRTvIiA4ENHDuezWVn3wiJl0xGz5oi3wzSTZs-XtJGLK44M4tS-WqbITI-BWMfdZ5oCXX6R1Jz47iWVPCiDwlWCpvG8LIrB6LrpGjorI7gUe7hqyVRT5aKxYLLG_dDJLcj9307YRjv4jQMkl3i-xdXIN53yAhItOgLpl7C2iF5FjMT7Bh1U7lAUjr96qgrUwTJUDpd_pOpYiq6rxKsX0hV0MB3XRrF2GTXO95OevJbJWOhIxzvweH3J3le8Y8Vgqdmhu6t4FbnYBaCGr0Lc5-eHWPg"

CONFIG_PATH = "/tmp/postgres_om_config.yaml"

# Schemas a catalogar (mesmos usados no dbt: raw_/stg_/int_/mart_)
SCHEMA_INCLUDES = ["raw_.*", "stg_.*", "int_.*", "mart_.*"]


def gerar_config_yaml(**context):
    """Lê a connection do Airflow e escreve o YAML de ingestão já preenchido."""
    conn = BaseHook.get_connection(PG_CONN_ID)
    host = conn.host
    port = conn.port or 5432
    user = conn.login
    password = conn.password or ""
    database = conn.schema or "postgres"  # 'schema' na connection = nome do database

    # O dbt usa dbname=postgres; a connection pode ter outro 'schema'. Forçamos
    # 'postgres' como database para casar com os FQNs do dbt/lineage.
    database = "postgres"

    config = {
        "source": {
            "type": "postgres",
            "serviceName": "mekadw_openmetadata",
            "serviceConnection": {
                "config": {
                    "type": "Postgres",
                    "username": user,
                    "authType": {"password": password},
                    "hostPort": f"{host}:{port}",
                    "database": database,
                }
            },
            "sourceConfig": {
                "config": {
                    "type": "DatabaseMetadata",
                    "schemaFilterPattern": {"includes": SCHEMA_INCLUDES},
                }
            },
        },
        # 'sink' obrigatorio: define o destino dos metadados (a API do OM).
        # Sem ele o workflow quebra com "'NoneType' object has no attribute 'type'".
        "sink": {
            "type": "metadata-rest",
            "config": {},
        },
        "workflowConfig": {
            "openMetadataServerConfig": {
                "hostPort": OM_HOST,
                "authProvider": "openmetadata",
                "securityConfig": {"jwtToken": OM_JWT_TOKEN},
            }
        },
    }

    with open(CONFIG_PATH, "w") as f:
        yaml.safe_dump(config, f, sort_keys=False)

    print(f"Config gerado em {CONFIG_PATH}")
    print(f"Conectando a: {host}:{port}/{database} como '{user}'")
    print(f"Schemas: {SCHEMA_INCLUDES}")


with DAG(
    dag_id="ingest_postgres_metadata",
    start_date=datetime(2024, 1, 1),
    schedule=None,
    catchup=False,
    tags=["openmetadata", "postgres", "metadata-ingestion"],
) as dag:

    gerar_config = PythonOperator(
        task_id="gerar_config_yaml",
        python_callable=gerar_config_yaml,
    )

    ingest_postgres = BashOperator(
        task_id="ingest_postgres",
        bash_command=f"""
echo "########## INICIO ingest_postgres ##########"

echo "--- 1. Criando venv ---"
python3 -m venv /tmp/venv_postgres_ingest || {{ echo ">>> FALHA AO CRIAR VENV"; exit 1; }}
source /tmp/venv_postgres_ingest/bin/activate

echo "--- 2. Instalando openmetadata-ingestion[postgres]==1.11.5.0 ---"
pip install --upgrade pip -q
# cachetools instalado explicitamente: o openmetadata-ingestion usa mas nao puxa
# como dependencia transitiva (mesmo macete das DAGs ingesting/ingestion_final).
if ! pip install cachetools "openmetadata-ingestion[postgres]==1.11.5.0" 2>&1 | tail -n 40; then
    echo ""
    echo ">>>>>>>>>> ERRO NO PIP INSTALL (ver acima) <<<<<<<<<<"
    exit 1
fi

echo "--- 3. Conteudo do config (sem token/senha) ---"
grep -vi "jwttoken\\|password" {CONFIG_PATH} || true

echo "--- 4. Rodando Ingestao Postgres ---"
set -o pipefail
metadata --debug ingest -c {CONFIG_PATH} 2>&1 | tee /tmp/ingest_out.log
RC=${{PIPESTATUS[0]}}

if [ "$RC" -ne 0 ]; then
    echo ""
    echo ">>>>>>>>>> ERRO REAL DA INGESTAO (ultimas 60 linhas) <<<<<<<<<<"
    tail -n 60 /tmp/ingest_out.log
    echo ">>>>>>>>>> FIM DO ERRO (exit code: $RC) <<<<<<<<<<"
    deactivate
    exit 1
fi

echo "--- 5. OK! Limpeza ---"
deactivate
rm -rf /tmp/venv_postgres_ingest {CONFIG_PATH} /tmp/ingest_out.log
echo "########## FIM ingest_postgres ##########"
        """,
    )

    gerar_config >> ingest_postgres
