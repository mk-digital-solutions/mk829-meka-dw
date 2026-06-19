"""
Documentação/enriquecimento do mart_flowup -> OpenMetadata (via REST API).

As tabelas de mart_flowup são geradas dinamicamente pelo modelo dbt 'flowup_mart'
(DROP/CREATE via run_query), portanto NÃO são nós dbt e não podem ser documentadas
pelo schema.yml. Esta DAG escreve metadados diretamente na API do OpenMetadata,
reaproveitando host/token do openmetadata.yaml.

O que aplica em cada uma das 13 tabelas consumidas no Power BI:
  - Descrição da tabela
  - Descrição das colunas (exceto as colunas técnicas do Airbyte _airbyte_*)
  - Owner: contato@mekatronik.com.br (usuário criado no OM se não existir)
  - Tier: fct_reportagem = Tier1; demais = Tier2
  - rowCount (profile) calculado dinamicamente no Postgres a cada execução

Idempotente: reexecutar reaplica tudo. Pré-requisito: as tabelas já catalogadas no
OM (DAG 'ingest_postgres_metadata'). Tabelas não encontradas são "skipadas".
"""
import os
import json
import time
import logging
import urllib.parse
from datetime import datetime, timezone

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
OM_SCHEMA = "mart_flowup"
PG_CONN_ID = "mekadw_airflow"

# Owner a atribuir (criado como usuário no OM se ainda não existir)
OWNER_NAME = "mkadmin"
OWNER_EMAIL = "mkadmin@mekatronik.com.br"
OWNER_DISPLAY = "MKADMIN"

DOMAIN_NAME = "Meka DW"
DOMAIN_DISPLAY = "Meka DW"

# Tier por tabela (default Tier2; override abaixo)
TIER_DEFAULT = "Tier.Tier2"
TIER_OVERRIDES = {"fct_reportagem": "Tier.Tier1"}

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

# --- DESCRIÇÕES (nível de coluna) — colunas _airbyte_* propositalmente omitidas ---
COLUNAS = {
    "fct_reportagem": {
        "Id": "Identificador único do apontamento de horas.",
        "Dia": "Data do apontamento (dia trabalhado).",
        "Sabado": "Indica se o dia é sábado.",
        "Task_Id": "Identificador da tarefa apontada.",
        "Board_Id": "Identificador do quadro/board da tarefa.",
        "Detalhes": "Descrição do que foi feito no apontamento.",
        "Membro_Id": "Identificador do membro (colaborador) que apontou as horas.",
        "HorarioFim": "Horário de término do trabalho.",
        "Projeto_Id": "Identificador do projeto.",
        "CreditoHoras": "Crédito de horas (banco de horas) gerado pelo apontamento.",
        "ReportStatus": "Status do apontamento (ex.: aprovado/pendente).",
        "HorarioInicio": "Horário de início do trabalho.",
        "DomingoFeriado": "Indica se o dia é domingo ou feriado.",
        "AdicionalNoturno": "Valor do adicional noturno do apontamento.",
        "HorasTrabalhadas": "Quantidade de horas trabalhadas no dia.",
        "PercentualNoturno": "Percentual de adicional noturno aplicado.",
    },
    "fct_cashflowitems": {
        "Id": "Identificador único do lançamento financeiro.",
        "Date": "Data do lançamento.",
        "Type": "Tipo do lançamento (entrada/saída).",
        "Value": "Valor do lançamento.",
        "Rebate": "Desconto/abatimento aplicado.",
        "DueDate": "Data de vencimento.",
        "CheckNum": "Número do cheque (quando aplicável).",
        "Executed": "Indica se o lançamento foi executado/baixado.",
        "Client_Id": "Identificador do cliente.",
        "Generated": "Indica se foi gerado automaticamente (ex.: recorrência).",
        "Parent_Id": "Identificador do lançamento pai (parcelamento/recorrência).",
        "Person_Id": "Identificador da pessoa associada.",
        "Scheduled": "Indica se o lançamento está agendado.",
        "Timestamp": "Data/hora de registro/atualização (controle do Flowup).",
        "Company_Id": "Identificador da empresa.",
        "BilledValue": "Valor faturado.",
        "Category_Id": "Identificador da categoria de fluxo de caixa.",
        "Description": "Descrição do lançamento.",
        "InvoiceDate": "Data da nota fiscal.",
        "Supplier_Id": "Identificador do fornecedor.",
        "Transfer_Id": "Identificador da transferência entre contas.",
        "CostCenter_Id": "Identificador do centro de custo.",
        "ImportInfo_Id": "Identificador da informação de importação (origem do lançamento).",
        "InvoiceNumber": "Número da nota fiscal.",
        "PrevisionEmit": "Data prevista de emissão.",
        "RefundedValue": "Valor reembolsado.",
        "TransactionId": "Identificador da transação (conciliação bancária).",
        "BankAccount_Id": "Identificador da conta bancária.",
        "CompetenceDate": "Data de competência.",
        "ApprovedPayment": "Indica se o pagamento foi aprovado.",
        "ExpectedTaxName": "Nome do imposto previsto.",
        "ApprovedPaymentDate": "Data de aprovação do pagamento.",
        "ServiceSaleInvoice_Id": "Identificador da nota de venda de serviço relacionada.",
        "AlternativeDescription": "Descrição alternativa do lançamento.",
        "ApprovedPaymentUser_Id": "Identificador do usuário que aprovou o pagamento.",
        "RecurrentAsGenerated_Id": "Identificador do lançamento recorrente que o gerou.",
    },
    "fct_costcenters": {
        "Id": "Identificador único do centro de custo.",
        "Name": "Nome do centro de custo.",
        "Color": "Cor associada (hex), usada na interface.",
        "Active": "Indica se o centro de custo está ativo.",
        "Client_Id": "Identificador do cliente.",
        "Timestamp": "Data/hora de registro/atualização (controle do Flowup).",
        "ApportionRule": "Regra de rateio do centro de custo.",
    },
    "fct_suppliers": {
        "Id": "Identificador único do fornecedor.",
        "Name": "Nome fantasia do fornecedor.",
        "Email": "E-mail do fornecedor.",
        "Active": "Indica se o fornecedor está ativo.",
        "Agency": "Agência bancária.",
        "Phone1": "Telefone principal.",
        "Phone2": "Telefone secundário.",
        "Account": "Conta bancária.",
        "Bank_Id": "Identificador do banco.",
        "Contact": "Nome do contato no fornecedor.",
        "PixType": "Tipo da chave PIX.",
        "IdNumber": "Documento do fornecedor (CNPJ/CPF).",
        "PixValue": "Chave PIX.",
        "Timestamp": "Data/hora de registro/atualização (controle do Flowup).",
        "Address_Id": "Identificador do endereço.",
        "Observations": "Observações.",
        "SupplierType": "Tipo de fornecedor.",
        "CorporateName": "Razão social.",
        "BankAccountType": "Tipo de conta bancária.",
    },
    "fct_abono": {
        "Id": "Identificador único do abono.",
        "DataAbono": "Data do abono.",
        "Descricao": "Descrição/justificativa do abono.",
        "Membro_Id": "Identificador do membro abonado.",
        "Projeto_Id": "Identificador do projeto.",
        "ValorHoras": "Quantidade de horas abonadas.",
    },
    "fct_tagtasks": {
        "Tag_Id": "Identificador da tag (ver fct_tags).",
        "Task_Id": "Identificador da tarefa.",
    },
    "fct_boards": {
        "Id": "Identificador único do quadro/projeto.",
        "Name": "Nome do quadro.",
        "Active": "Indica se o quadro está ativo.",
        "EndDate": "Data de término planejada.",
        "IsGantt": "Indica se o quadro usa visão de Gantt.",
        "OwnerId": "Identificador do dono do quadro.",
        "Archived": "Indica se o quadro está arquivado.",
        "IsPrivate": "Indica se o quadro é privado.",
        "SortOrder": "Ordem de exibição.",
        "StartDate": "Data de início planejada.",
        "IsTemplate": "Indica se é um modelo (template).",
        "Description": "Descrição do quadro.",
        "RealEndDate": "Data de término real.",
        "CostCenterId": "Identificador do centro de custo.",
        "ServiceSaleId": "Identificador da venda de serviço associada.",
        "StatusTemplateId": "Identificador do template de status usado.",
    },
    "fct_status": {
        "Id": "Identificador único do status.",
        "Name": "Nome do status.",
        "Type": "Tipo do status.",
        "Order": "Ordem do status no fluxo.",
        "Active": "Indica se o status está ativo.",
        "BoardId": "Identificador do quadro ao qual pertence.",
        "TemplateId": "Identificador do template de status.",
    },
    "fct_tags": {
        "Id": "Identificador único da tag.",
        "Name": "Nome da tag/etiqueta.",
        "Color": "Cor da tag (hex).",
        "Active": "Indica se a tag está ativa.",
    },
    "fct_productsales": {
        "Id": "Identificador único da venda de produto.",
        "Date": "Data da venda.",
        "Guid": "Identificador global (GUID) da venda.",
        "Notes": "Observações.",
        "Serie": "Série da nota/venda.",
        "Total": "Valor total da venda.",
        "Closed": "Indica se a venda está fechada.",
        "User_Id": "Identificador do usuário que registrou a venda.",
        "Canceled": "Indica se a venda foi cancelada.",
        "Client_Id": "Identificador do cliente.",
        "Delivered": "Indica se a venda foi entregue.",
        "Timestamp": "Data/hora de registro/atualização (controle do Flowup).",
        "Company_Id": "Identificador da empresa.",
        "SaleNumber": "Número da venda.",
        "CostCenterId": "Identificador do centro de custo.",
        "BankAccountId": "Identificador da conta bancária.",
        "BankAgreement_Id": "Identificador do convênio bancário.",
        "StockLocation_Id": "Identificador do local de estoque.",
    },
    "fct_productsaleitems": {
        "Id": "Identificador único do item de venda.",
        "Guid": "Identificador global (GUID) do item.",
        "Value": "Valor do item.",
        "Sale_Id": "Identificador da venda (fct_productsales).",
        "Discount": "Desconto aplicado ao item.",
        "Quantity": "Quantidade vendida.",
        "Timestamp": "Data/hora de registro/atualização (controle do Flowup).",
        "Product_Id": "Identificador do produto.",
        "Description": "Descrição do item.",
        "AdditionalCosts": "Custos adicionais do item.",
    },
    "fct_products": {
        "Id": "Identificador único do produto.",
        "EAN": "Código de barras EAN.",
        "NCM": "Código NCM (classificação fiscal da mercadoria).",
        "CFOP": "Código CFOP (natureza da operação).",
        "Code": "Código interno do produto.",
        "Guid": "Identificador global (GUID) do produto.",
        "Name": "Nome do produto.",
        "Sells": "Indica se o produto é vendável.",
        "Active": "Indica se o produto está ativo.",
        "NoStock": "Indica se o produto não controla estoque.",
        "Timestamp": "Data/hora de registro/atualização (controle do Flowup).",
        "Category_Id": "Identificador da categoria do produto.",
        "Description": "Descrição do produto.",
        "SellingPrice": "Preço de venda.",
        "CashFlowCategory_Id": "Identificador da categoria de fluxo de caixa associada.",
    },
    "fct_servicesales": {
        "Id": "Identificador único da venda de serviço.",
        "Date": "Data da venda.",
        "Notes": "Observações.",
        "Serie": "Série da nota/venda.",
        "Total": "Valor total da venda.",
        "Closed": "Indica se a venda está fechada.",
        "User_Id": "Identificador do usuário que registrou a venda.",
        "Canceled": "Indica se a venda foi cancelada.",
        "IsActual": "Indica se é a versão vigente/atual.",
        "Client_Id": "Identificador do cliente.",
        "Delivered": "Indica se a venda foi entregue.",
        "Timestamp": "Data/hora de registro/atualização (controle do Flowup).",
        "Company_Id": "Identificador da empresa.",
        "IsApproved": "Indica se a venda foi aprovada.",
        "SaleNumber": "Número da venda.",
        "isRecurring": "Indica se a venda é recorrente.",
        "CostCenterId": "Identificador do centro de custo.",
        "BankAccountId": "Identificador da conta bancária.",
        "VersionNumber": "Número da versão da venda.",
        "ServiceType_Id": "Identificador do tipo de serviço.",
        "BankAgreement_Id": "Identificador do convênio bancário.",
        "IsWithHoldingISS": "Indica se há retenção de ISS.",
        "ParentVersion_Id": "Identificador da versão pai.",
        "RecurringSale_Id": "Identificador da venda recorrente de origem.",
        "WithholdingTaxes": "Impostos retidos.",
        "ServiceSubType_Id": "Identificador do subtipo de serviço.",
        "ShippingDetails_Id": "Identificador dos detalhes de envio.",
        "ParentRecurringSale_Id": "Identificador da venda recorrente pai.",
    },
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


def _ensure_owner(session, host, dry_run):
    """Resolve o usuário owner; cria no OM se não existir. Retorna EntityReference."""
    r = session.get(f"{host}/v1/users/name/{OWNER_NAME}", timeout=30)
    if r.status_code == 200:
        return {"id": r.json()["id"], "type": "user"}
    if dry_run:
        logger.info("DRY-RUN: usuario owner '%s' nao existe -> seria criado", OWNER_EMAIL)
        return None
    body = {"name": OWNER_NAME, "email": OWNER_EMAIL, "displayName": OWNER_DISPLAY}
    rp = session.put(f"{host}/v1/users", json=body, timeout=30)
    rp.raise_for_status()
    logger.info("Owner '%s' criado/garantido no OM", OWNER_EMAIL)
    return {"id": rp.json()["id"], "type": "user"}


def _ensure_domain(session, host, dry_run):
    """Resolve o domínio global; cria no OM se não existir. Retorna EntityReference."""
    r = session.get(f"{host}/v1/domains/name/{urllib.parse.quote(DOMAIN_NAME, safe='')}", timeout=30)
    if r.status_code == 200:
        return {"id": r.json()["id"], "type": "domain"}
    if dry_run:
        logger.info("DRY-RUN: dominio '%s' nao existe -> seria criado", DOMAIN_DISPLAY)
        return None
    rp = session.put(f"{host}/v1/domains", json={
        "name": DOMAIN_NAME, "displayName": DOMAIN_DISPLAY,
        "description": "Dominio global do Data Warehouse Mekatronik (marts consumidos no Power BI).",
        "domainType": "Aggregate"}, timeout=30)
    rp.raise_for_status()
    logger.info("Dominio '%s' criado/garantido no OM", DOMAIN_DISPLAY)
    return {"id": rp.json()["id"], "type": "domain"}


def _iso(epoch_ms):
    if not epoch_ms:
        return None
    return datetime.fromtimestamp(epoch_ms / 1000, tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"


def _om_created_at(session, host, table_id):
    """Data de catalogacao no OM = updatedAt da 1a versao da entidade (epoch ms)."""
    r = session.get(f"{host}/v1/tables/{table_id}/versions", timeout=30)
    if r.status_code != 200:
        return None
    versions = r.json().get("versions", [])
    if not versions:
        return None
    oldest = versions[-1]
    if isinstance(oldest, str):
        oldest = json.loads(oldest)
    return oldest.get("updatedAt")


def _get_table(session, host, fqn):
    url = f"{host}/v1/tables/name/{urllib.parse.quote(fqn, safe='')}"
    r = session.get(url, params={"fields": "owners,tags,columns,domains"}, timeout=30)
    if r.status_code == 404:
        return None
    r.raise_for_status()
    return r.json()


def _build_patch(table, description, owner_ref, domain_ref, tier_fqn, col_descs):
    """Monta a lista JSON Patch (descrição, owner, domínio, tier e descrições de coluna)."""
    patch = []

    # descrição da tabela
    patch.append({
        "op": "replace" if (table.get("description") or "").strip() else "add",
        "path": "/description", "value": description,
    })

    # owner (lista 'owners')
    if owner_ref:
        op = "replace" if table.get("owners") else "add"
        patch.append({"op": op, "path": "/owners", "value": [owner_ref]})

    # domínio (lista 'domains')
    if domain_ref:
        op = "replace" if table.get("domains") else "add"
        patch.append({"op": op, "path": "/domains", "value": [domain_ref]})

    # tier: preserva tags não-Tier e (re)define a Tier desejada
    existing = [t for t in (table.get("tags") or []) if not t.get("tagFQN", "").startswith("Tier.")]
    new_tags = existing + [{
        "tagFQN": tier_fqn, "source": "Classification",
        "labelType": "Manual", "state": "Confirmed",
    }]
    op_tags = "replace" if table.get("tags") is not None else "add"
    patch.append({"op": op_tags, "path": "/tags", "value": new_tags})

    # descrições de coluna (por índice, casando pelo nome)
    name_to_idx = {c["name"]: i for i, c in enumerate(table.get("columns") or [])}
    faltando = []
    for col, desc in col_descs.items():
        i = name_to_idx.get(col)
        if i is None:
            faltando.append(col)
            continue
        cur = (table["columns"][i].get("description") or "").strip()
        patch.append({
            "op": "replace" if cur else "add",
            "path": f"/columns/{i}/description", "value": desc,
        })
    if faltando:
        logger.warning("Colunas no dict mas ausentes na tabela: %s", faltando)
    return patch


def _patch_table(session, host, table_id, patch):
    r = session.patch(
        f"{host}/v1/tables/{table_id}", json=patch,
        headers={"Content-Type": "application/json-patch+json"}, timeout=30,
    )
    r.raise_for_status()


def _put_profile(session, host, table_id, row_count, column_count, size_bytes, create_dt):
    profile = {
        "timestamp": int(time.time() * 1000),
        "rowCount": row_count,
        "columnCount": column_count,
    }
    if size_bytes is not None:
        profile["sizeInByte"] = size_bytes
    if create_dt:
        profile["createDateTime"] = create_dt
    r = session.put(f"{host}/v1/tables/{table_id}/tableProfile",
                    json={"tableProfile": profile}, timeout=30)
    r.raise_for_status()


def documentar_tabelas(**context):
    params = context["params"]
    om_database = params.get("om_database") or "postgres"
    dry_run = bool(params.get("dry_run", False))

    host, token = _load_om_config(OM_CONFIG_PATH)
    session = _session(token)
    owner_ref = _ensure_owner(session, host, dry_run)
    domain_ref = _ensure_domain(session, host, dry_run)
    hook = PostgresHook(postgres_conn_id=PG_CONN_ID)

    total_ok, total_skip = 0, 0
    for tabela, descricao in DESCRICOES.items():
        fqn = f"{OM_SERVICE}.{om_database}.{OM_SCHEMA}.{tabela}"
        tbl = _get_table(session, host, fqn)
        if not tbl:
            logger.warning("SKIP '%s': nao encontrada no OM (fqn=%s).", tabela, fqn)
            total_skip += 1
            continue

        tier = TIER_OVERRIDES.get(tabela, TIER_DEFAULT)
        col_descs = COLUNAS.get(tabela, {})
        # rowCount dinâmico (muda conforme o Airbyte atualiza o Postgres)
        row_count = hook.get_first(f'SELECT count(*) FROM {OM_SCHEMA}."{tabela}"')[0]
        column_count = len(tbl.get("columns") or [])
        size_bytes = hook.get_first("SELECT pg_total_relation_size('%s.\"%s\"')" % (OM_SCHEMA, tabela))[0]
        create_dt = _iso(_om_created_at(session, host, tbl["id"]))

        if dry_run:
            logger.info(
                "DRY-RUN %s | tier=%s | owner=%s | dominio=%s | cols_doc=%d | rowCount=%s | size=%s",
                tabela, tier, OWNER_EMAIL, DOMAIN_DISPLAY, len(col_descs), row_count, size_bytes,
            )
        else:
            patch = _build_patch(tbl, descricao, owner_ref, domain_ref, tier, col_descs)
            _patch_table(session, host, tbl["id"], patch)
            _put_profile(session, host, tbl["id"], row_count, column_count, size_bytes, create_dt)
            logger.info(
                "OK %s | tier=%s | dominio=%s | cols_doc=%d | rowCount=%s | size=%s",
                tabela, tier, DOMAIN_DISPLAY, len(col_descs), row_count, size_bytes,
            )
        total_ok += 1

    logger.info("FIM. processadas=%d, skip=%d", total_ok, total_skip)
    if total_ok == 0:
        raise ValueError(
            "Nenhuma tabela processada. Verifique OM_SERVICE='%s', om_database='%s', "
            "schema='%s' e se as tabelas ja foram ingeridas no OpenMetadata."
            % (OM_SERVICE, om_database, OM_SCHEMA)
        )


with DAG(
    dag_id="om_docs_flowup_mart",
    start_date=datetime(2024, 1, 1),
    schedule="0 4 * * 1",  # semanal: toda segunda-feira às 04:00 (apos as cargas diarias)
    catchup=False,
    tags=["openmetadata", "docs", "flowup"],
    params={
        "om_database": Param(
            "postgres", type="string",
            description="Nome do database no OM. FQN usado: <service>.<DATABASE>.<schema>.<tabela>.",
        ),
        "dry_run": Param(
            False, type="boolean",
            description="Se True, apenas loga o que seria aplicado sem gravar no OM.",
        ),
    },
) as dag:

    PythonOperator(
        task_id="documentar_tabelas_om",
        python_callable=documentar_tabelas,
    )
