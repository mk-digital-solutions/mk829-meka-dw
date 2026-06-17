"""
Documentação (descrições de tabela) do mart_flowup -> OpenMetadata (via REST API).

As tabelas de mart_flowup são geradas dinamicamente pelo modelo dbt 'flowup_mart'
(DROP/CREATE via run_query), portanto NÃO são nós dbt e não podem ser documentadas
pelo schema.yml. Esta DAG escreve a descrição de cada tabela diretamente na API do
OpenMetadata (PATCH json-patch), reaproveitando host/token do openmetadata.yaml.

Escopo atual: apenas as 12 tabelas consumidas no Power BI, somente a nível de TABELA
(colunas ficam para uma etapa futura). Idempotente: reexecutar reaplica as descrições.

Pré-requisito: as tabelas mart_flowup já devem estar catalogadas no OM (DAG
'ingest_postgres_metadata'). Tabelas não encontradas são apenas "skipadas" com aviso.
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

logger = logging.getLogger("airflow.task")

# --- CONFIGURAÇÕES ---
BASE_DIR = "/opt/airflow"
OM_CONFIG_PATH = os.path.join(BASE_DIR, "dags/dbt/meka-dw/openmetadata.yaml")

OM_SERVICE = "mekadw_openmetadata"   # Database Service já criado no OM
OM_SCHEMA = "mart_flowup"

# --- DESCRIÇÕES (nível de tabela) ---
# Camada gold (mart) do Flowup: dados ingeridos do Flowup via Airbyte e recriados
# pelo modelo flowup_mart com tratamento de nulos. Consumidas no Power BI.
DESCRICOES = {
    "fct_reportagem":
        "Apontamentos de horas (reportagem) dos membros no Flowup — a maior e principal "
        "tabela de horas trabalhadas. Cada linha registra as horas de um membro em uma "
        "tarefa/quadro/projeto num dia, com horário de início e fim, detalhes, status do "
        "apontamento, crédito de horas, marcações de sábado e domingo/feriado e adicional "
        "noturno (valor e percentual).",
    "fct_cashflowitems":
        "Lançamentos do fluxo de caixa do Flowup (contas a pagar e a receber). Cada "
        "linha é um item financeiro com valor, data, vencimento (DueDate), tipo "
        "(entrada/saída), categoria, centro de custo, fornecedor, cliente, conta "
        "bancária e situação de execução/pagamento. Tabela financeira central.",
    "fct_costcenters":
        "Centros de custo cadastrados no Flowup (nome, cor, situação e regra de rateio). "
        "Usados para classificar lançamentos financeiros, projetos e vendas.",
    "fct_suppliers":
        "Cadastro de fornecedores do Flowup (nome fantasia/razão social, contato, e-mail, "
        "telefones, endereço, dados bancários e PIX). Referenciado nos lançamentos "
        "financeiros (Supplier_Id).",
    "fct_abono":
        "Abonos de horas dos membros em projetos (data do abono, membro, projeto, "
        "quantidade de horas abonadas e descrição/justificativa).",
    "fct_tagtasks":
        "Tabela associativa N:N entre tags e tarefas (Tag_Id, Task_Id). Liga as etiquetas "
        "de fct_tags às tarefas dos quadros.",
    "fct_boards":
        "Quadros/projetos do Flowup (nome, datas de início e fim, dono, visibilidade, "
        "se é Gantt/template, status template, centro de custo e venda de serviço "
        "associada). Representa os projetos.",
    "fct_status":
        "Status (etapas/colunas) dos quadros e tarefas (nome, tipo, ordem, quadro e "
        "template). Define os estados do fluxo de trabalho.",
    "fct_tags":
        "Cadastro de tags/etiquetas (nome, cor e situação) usadas para classificar "
        "tarefas. A associação com tarefas está em fct_tagtasks.",
    "fct_productsales":
        "Cabeçalho das vendas de produtos (data, número da venda, total, cliente, "
        "situação - fechada/cancelada/entregue -, conta bancária e centro de custo). "
        "Os itens vendidos estão em fct_productsaleitems.",
    "fct_productsaleitems":
        "Itens das vendas de produtos (uma linha por produto vendido): venda de origem, "
        "produto, quantidade, valor, desconto e custos adicionais. Detalha fct_productsales.",
    "fct_products":
        "Cadastro de produtos (nome, código, EAN, NCM, CFOP, preço de venda, categoria, "
        "controle de estoque e situação).",
    "fct_servicesales":
        "Cabeçalho das vendas de serviços (data, número, total, cliente, tipo de serviço, "
        "recorrência, aprovação, versão, impostos - ISS/retenções -, conta bancária e "
        "centro de custo).",
}


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
    s.headers.update({"Authorization": f"Bearer {token}"})
    return s


def _get_table(session, host, fqn):
    """Busca a tabela no OM pelo FQN. Retorna o JSON (com id + description) ou None."""
    url = f"{host}/v1/tables/name/{urllib.parse.quote(fqn, safe='')}"
    r = session.get(url, timeout=30)
    if r.status_code == 404:
        return None
    r.raise_for_status()
    return r.json()


def _patch_description(session, host, table, description):
    """Aplica a descrição via JSON Patch (add se vazia, replace se já existir)."""
    op = "replace" if (table.get("description") or "").strip() else "add"
    body = [{"op": op, "path": "/description", "value": description}]
    url = f"{host}/v1/tables/{table['id']}"
    r = session.patch(
        url, json=body,
        headers={"Content-Type": "application/json-patch+json"},
        timeout=30,
    )
    r.raise_for_status()


def documentar_tabelas(**context):
    params = context["params"]
    om_database = params.get("om_database") or "postgres"
    dry_run = bool(params.get("dry_run", False))

    host, token = _load_om_config(OM_CONFIG_PATH)
    session = _session(token)

    total_ok, total_skip = 0, 0
    for tabela, descricao in DESCRICOES.items():
        fqn = f"{OM_SERVICE}.{om_database}.{OM_SCHEMA}.{tabela}"
        tbl = _get_table(session, host, fqn)
        if not tbl:
            logger.warning(
                "SKIP '%s': nao encontrada no OM (fqn=%s). A ingestao de metadados "
                "Postgres ja rodou?", tabela, fqn,
            )
            total_skip += 1
            continue

        if dry_run:
            logger.info("DRY-RUN %s: %s", tabela, descricao[:70] + "...")
        else:
            _patch_description(session, host, tbl, descricao)
            logger.info("OK: descricao aplicada em %s", fqn)
        total_ok += 1

    logger.info("FIM. documentadas=%d, skip=%d", total_ok, total_skip)
    if total_ok == 0:
        raise ValueError(
            "Nenhuma tabela documentada. Verifique OM_SERVICE='%s', om_database='%s', "
            "schema='%s' e se as tabelas ja foram ingeridas no OpenMetadata."
            % (OM_SERVICE, om_database, OM_SCHEMA)
        )


with DAG(
    dag_id="om_docs_flowup_mart",
    start_date=datetime(2024, 1, 1),
    schedule=None,  # documentação: roda sob demanda (trigger manual)
    catchup=False,
    tags=["openmetadata", "docs", "flowup"],
    params={
        "om_database": Param(
            "postgres", type="string",
            description="Nome do database no OM. FQN usado: <service>.<DATABASE>.<schema>.<tabela>.",
        ),
        "dry_run": Param(
            False, type="boolean",
            description="Se True, apenas loga o que seria documentado sem gravar no OM.",
        ),
    },
) as dag:

    PythonOperator(
        task_id="documentar_tabelas_om",
        python_callable=documentar_tabelas,
    )
