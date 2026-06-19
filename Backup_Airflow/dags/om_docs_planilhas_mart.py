"""
Documentação/enriquecimento do mart_planilhas -> OpenMetadata (via REST API).

Mesma abordagem da om_docs_flowup_mart (descrição de tabela e colunas, owner, tier e
rowCount dinâmico via API). Idempotente; roda semanalmente ou sob demanda.

Tier: COMPOSICAO_PROJETOS e HH_COMPOSICOES = Tier1; demais = Tier2.
A tabela de log 'planilhas_log_execucao' é ignorada (não é dado de BI).

COMPOSICAO_PROJETOS tem ~180 colunas (uma por cargo/HH/comissão/valor). Em vez de um
dicionário gigante, as descrições dessa tabela são geradas por padrão do nome da coluna
(_descreve_composicao). As demais tabelas usam dicionários explícitos.
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

BASE_DIR = "/opt/airflow"
OM_CONFIG_PATH = os.path.join(BASE_DIR, "dags/dbt/meka-dw/openmetadata.yaml")
OM_SERVICE = "mekadw_openmetadata"
OM_SCHEMA = "mart_planilhas"
PG_CONN_ID = "mekadw_airflow"

OWNER_NAME = "mkadmin"
OWNER_EMAIL = "mkadmin@mekatronik.com.br"
OWNER_DISPLAY = "MKADMIN"

DOMAIN_NAME = "Meka DW"
DOMAIN_DISPLAY = "Meka DW"

AIRBYTE_COLS = {"_airbyte_raw_id", "_airbyte_extracted_at", "_airbyte_meta", "_airbyte_generation_id"}

TIER_DEFAULT = "Tier.Tier2"
TIER_OVERRIDES = {"COMPOSICAO_PROJETOS": "Tier.Tier1", "HH_COMPOSICOES": "Tier.Tier1"}

DESCRICOES = {
    "BANCO_BI":
        "Planilha BANCO_BI: visão financeira/BI por data (entrega, proposta, comissões e "
        "faturamentos por tipo - produto, serviço, pessoal, assistência e centro de custo).",
    "BANCO_COLABORADORES":
        "Cadastro de colaboradores (equipe, custo, empresa, fornecedor e nomes - completo, "
        "Flowup e abreviado).",
    "CADASTRO_CC":
        "Cadastro de centros de custo / projetos (CC, cliente, empresa, segmento, receita, "
        "responsáveis, tipo de venda, cronograma e datas).",
    "COMPOSICAO_PROJETOS":
        "Composição de custos e horas-homem (HH) dos projetos, detalhada por cargo "
        "(alocação, HH previsto, comissões), além de valores previstos, lucro, impostos e "
        "dados comerciais do pedido. Tabela ampla (~180 colunas).",
    "HH_COMPOSICOES":
        "Composição de horas-homem (HH) por cargo: quantidade de HH, valor do HH, comissão "
        "e valor previsto, vinculados ao CC/composição.",
}

# Colunas explícitas para as tabelas "pequenas" (COMPOSICAO_PROJETOS usa gerador abaixo)
COLUNAS = {
    "BANCO_BI": {
        "DATA": "Data de referência.",
        "_Entrega_": "Valor de entrega.",
        "_Proposta_": "Valor de proposta.",
        "_Comissao_": "Comissão.",
        "___Faturado_": "Valor faturado.",
        "_Fat__Produto_": "Faturamento de produto.",
        "_Fat__Servico_": "Faturamento de serviço.",
        "_Valor_de_Venda_": "Valor de venda.",
        "_Comissao_Venda_": "Comissão de venda.",
        "_Comissao_Gestao_": "Comissão de gestão.",
        "_Fat__Pessoal_Prd__": "Faturamento pessoal de produção.",
        "_Fat__Pessoal_Serv__": "Faturamento pessoal de serviço.",
        "_Fat__Pessoal_Gestao_": "Faturamento pessoal de gestão.",
        "_Comissao_Assistencia_": "Comissão de assistência.",
        "_Faturamento_Assistencia_": "Faturamento de assistência.",
        "_Alocacao__Centro_de_Custo__": "Alocação por centro de custo.",
        "_Faturamento__Centro_de_Custo__": "Faturamento por centro de custo.",
    },
    "BANCO_COLABORADORES": {
        "EQUIPE": "Equipe do colaborador.",
        "No_A1": "Número/índice do colaborador (coluna A1 da planilha).",
        "__CUSTO": "Custo do colaborador.",
        "EMPRESA": "Empresa.",
        "NOME_B1": "Nome do colaborador (coluna B1 da planilha).",
        "STATUS_": "Status do colaborador.",
        "FORNECEDOR": "Fornecedor associado.",
        "NOME_FLOWUP": "Nome do colaborador no Flowup.",
        "NOME_ABREVIADO": "Nome abreviado.",
    },
    "CADASTRO_CC": {
        "_": "Coluna auxiliar/índice herdada da planilha.",
        "CC": "Centro de custo.",
        "HH": "Horas-homem (HH) do projeto.",
        "ID": "Identificador do projeto.",
        "Setor": "Setor.",
        "Pedido": "Número do pedido.",
        "Status": "Status do projeto.",
        "Cliente": "Cliente.",
        "Empresa": "Empresa.",
        "Receita": "Receita.",
        "Tipo_PR": "Tipo de PR.",
        "Segmento": "Segmento.",
        "Cronograma": "Cronograma associado (mkXXX).",
        "Tipo_de_Venda": "Tipo de venda.",
        "Data_de_Inicio": "Data de início.",
        "Responsavel_1": "Responsável 1.",
        "Responsavel_2": "Responsável 2.",
        "Descricao_Projeto": "Descrição do projeto.",
        "Planilha_de_Resultado": "Planilha de resultado associada.",
        "Data_de_Conclusao_Prevista": "Data de conclusão prevista.",
        "Data_de_Fechamento_Comercial": "Data de fechamento comercial.",
    },
    "HH_COMPOSICOES": {
        "CARGO": "Cargo/função.",
        "QUANT_HH": "Quantidade de horas-homem (HH).",
        "VALOR_HH": "Valor do HH (R$/hora).",
        "COMISSAO": "Comissão.",
        "Valor_HH_Prev_": "Valor de HH previsto.",
        "CONCAT_CC___Composicao": "Chave de concatenação CC + composição.",
    },
}

# Descrições explícitas (não-padrão) para colunas de COMPOSICAO_PROJETOS
COMPOSICAO_EXPLICITAS = {
    "CC": "Centro de custo.",
    "ID": "Identificador do projeto.",
    "Pedido": "Número do pedido.",
    "No_Pedido": "Número do pedido.",
    "Empresa": "Empresa.",
    "Tipo_PR": "Tipo de PR.",
    "Outros": "Outros custos.",
    "Deslocamento": "Custo de deslocamento.",
    "Alimentacao": "Custo de alimentação.",
    "Lucro_Previsto": "Lucro previsto.",
    "Valor_Entregue": "Valor entregue.",
    "Descricao_Projeto": "Descrição do projeto.",
    "Data_Atualizacao": "Data de atualização.",
    "Data_de_Emissao_do_Pedido": "Data de emissão do pedido.",
    "Data_de_Conclusao_Prevista": "Data de conclusão prevista.",
    "Data_de_Fechamento_Comercial": "Data de fechamento comercial.",
    "Condicao_de_Pagamento": "Condição de pagamento.",
    "Indicador_da_Oportunidade": "Indicador da oportunidade.",
    "Responsavel_Oportunidade": "Responsável pela oportunidade.",
    "Responsavel_Comercial": "Responsável comercial.",
    "Planilha_de_Resultado": "Planilha de resultado associada.",
    "CONCAT_CC___Composicao": "Chave de concatenação CC + composição.",
    "Valor_Pedido_Produto": "Valor do pedido de produto.",
    "Valor_Pedido_Servicos": "Valor do pedido de serviços.",
    "Valor_Materiais_Prev_": "Valor de materiais previsto.",
    "Valor_Outros_Prev_": "Valor de 'outros' previsto.",
    "Valor_Adm__Prev_": "Valor administrativo previsto.",
}


def _humaniza(s):
    return s.replace("_", " ").replace("  ", " ").strip().strip(".").strip()


def _descreve_composicao(col):
    """Descrição por padrão do nome da coluna em COMPOSICAO_PROJETOS."""
    if col in COMPOSICAO_EXPLICITAS:
        return COMPOSICAO_EXPLICITAS[col]
    if col.startswith("HH_"):
        return f"Horas-homem (HH) previstas para o cargo {_humaniza(col[3:])}."
    if col.startswith("Comissao_"):
        return f"Comissão prevista do cargo {_humaniza(col[9:])}."
    if col.startswith("Valor_"):
        return f"Valor (R$) previsto — {_humaniza(col[6:])}."
    if col.startswith("__"):
        return f"Rubrica de custo/financeira: {_humaniza(col)}."
    # demais: nomes de cargos/funções alocados ao projeto
    return f"Alocação/quantidade do cargo {_humaniza(col)} no projeto."


def _colunas_da_tabela(tabela, tbl):
    """Resolve o dict {coluna: descricao} para a tabela (gerado p/ COMPOSICAO_PROJETOS)."""
    if tabela == "COMPOSICAO_PROJETOS":
        nomes = [c["name"] for c in (tbl.get("columns") or []) if c["name"] not in AIRBYTE_COLS]
        return {c: _descreve_composicao(c) for c in nomes}
    return COLUNAS.get(tabela, {})


def _load_om_config(path):
    with open(path) as f:
        cfg = yaml.safe_load(f)
    server = cfg["workflowConfig"]["openMetadataServerConfig"]
    return server["hostPort"].rstrip("/"), server["securityConfig"]["jwtToken"]


def _session(token):
    s = requests.Session()
    s.headers.update({"Authorization": f"Bearer {token}"})
    return s


def _ensure_owner(session, host, dry_run):
    r = session.get(f"{host}/v1/users/name/{OWNER_NAME}", timeout=30)
    if r.status_code == 200:
        return {"id": r.json()["id"], "type": "user"}
    if dry_run:
        logger.info("DRY-RUN: usuario owner '%s' nao existe -> seria criado", OWNER_EMAIL)
        return None
    rp = session.put(f"{host}/v1/users",
                     json={"name": OWNER_NAME, "email": OWNER_EMAIL, "displayName": OWNER_DISPLAY},
                     timeout=30)
    rp.raise_for_status()
    logger.info("Owner '%s' criado/garantido no OM", OWNER_EMAIL)
    return {"id": rp.json()["id"], "type": "user"}


def _ensure_domain(session, host, dry_run):
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


def _build_ops(table, description, owner_ref, domain_ref, tier_fqn, col_descs):
    """Retorna (ops_tabela, ops_colunas). ops_colunas e lista de (nome_coluna, op)."""
    tbl_ops = [{
        "op": "replace" if (table.get("description") or "").strip() else "add",
        "path": "/description", "value": description,
    }]
    if owner_ref:
        tbl_ops.append({
            "op": "replace" if table.get("owners") else "add",
            "path": "/owners", "value": [owner_ref],
        })
    if domain_ref:
        tbl_ops.append({
            "op": "replace" if table.get("domains") else "add",
            "path": "/domains", "value": [domain_ref],
        })
    existing = [t for t in (table.get("tags") or []) if not t.get("tagFQN", "").startswith("Tier.")]
    new_tags = existing + [{"tagFQN": tier_fqn, "source": "Classification",
                            "labelType": "Manual", "state": "Confirmed"}]
    tbl_ops.append({"op": "replace" if table.get("tags") is not None else "add",
                    "path": "/tags", "value": new_tags})

    col_ops = []
    name_to_idx = {c["name"]: i for i, c in enumerate(table.get("columns") or [])}
    faltando = []
    for col, desc in col_descs.items():
        i = name_to_idx.get(col)
        if i is None:
            faltando.append(col)
            continue
        cur = (table["columns"][i].get("description") or "").strip()
        col_ops.append((col, {"op": "replace" if cur else "add",
                              "path": f"/columns/{i}/description", "value": desc}))
    if faltando:
        logger.warning("Colunas no dict mas ausentes na tabela: %s", faltando)
    return tbl_ops, col_ops


def _patch_table(session, host, table_id, ops):
    r = session.patch(f"{host}/v1/tables/{table_id}", json=ops,
                      headers={"Content-Type": "application/json-patch+json"}, timeout=30)
    r.raise_for_status()


def _patch_raw(session, host, table_id, ops):
    return session.patch(f"{host}/v1/tables/{table_id}", json=ops,
                         headers={"Content-Type": "application/json-patch+json"}, timeout=30)


def _aplicar_colunas(session, host, table_id, col_ops):
    """Tenta o patch combinado das colunas; se falhar, aplica uma a uma e ignora
    (com aviso) as que o OM rejeitar -- ex.: nomes terminando em '.' geram 500 no OM.
    Retorna o numero de colunas que nao puderam ser documentadas."""
    if not col_ops:
        return 0
    r = _patch_raw(session, host, table_id, [op for _, op in col_ops])
    if r.status_code < 300:
        return 0
    logger.warning("Patch combinado de colunas falhou (%s); aplicando individualmente.",
                   r.status_code)
    falhas = 0
    for col, op in col_ops:
        rr = _patch_raw(session, host, table_id, [op])
        if rr.status_code >= 300:
            falhas += 1
            logger.warning("Coluna '%s' NAO documentada no OM (%s) -- ignorada.", col, rr.status_code)
    return falhas


def _put_profile(session, host, table_id, row_count, column_count, size_bytes, create_dt):
    profile = {"timestamp": int(time.time() * 1000),
               "rowCount": row_count, "columnCount": column_count}
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
        col_descs = _colunas_da_tabela(tabela, tbl)
        row_count = hook.get_first(f'SELECT count(*) FROM {OM_SCHEMA}."{tabela}"')[0]
        column_count = len(tbl.get("columns") or [])
        size_bytes = hook.get_first("SELECT pg_total_relation_size('%s.\"%s\"')" % (OM_SCHEMA, tabela))[0]
        create_dt = _iso(_om_created_at(session, host, tbl["id"]))

        if dry_run:
            logger.info("DRY-RUN %s | tier=%s | owner=%s | dominio=%s | cols_doc=%d | rowCount=%s | size=%s",
                        tabela, tier, OWNER_EMAIL, DOMAIN_DISPLAY, len(col_descs), row_count, size_bytes)
        else:
            tbl_ops, col_ops = _build_ops(tbl, descricao, owner_ref, domain_ref, tier, col_descs)
            _patch_table(session, host, tbl["id"], tbl_ops)
            falhas = _aplicar_colunas(session, host, tbl["id"], col_ops)
            _put_profile(session, host, tbl["id"], row_count, column_count, size_bytes, create_dt)
            logger.info("OK %s | tier=%s | dominio=%s | cols_doc=%d (col_falhas=%d) | rowCount=%s | size=%s",
                        tabela, tier, DOMAIN_DISPLAY, len(col_ops), falhas, row_count, size_bytes)
        total_ok += 1

    logger.info("FIM. processadas=%d, skip=%d", total_ok, total_skip)
    if total_ok == 0:
        raise ValueError("Nenhuma tabela processada em %s. Ja foram ingeridas no OM?" % OM_SCHEMA)


with DAG(
    dag_id="om_docs_planilhas_mart",
    start_date=datetime(2024, 1, 1),
    schedule="30 4 * * 1",  # semanal: segunda 04:30
    catchup=False,
    tags=["openmetadata", "docs", "planilhas"],
    params={
        "om_database": Param("postgres", type="string",
                             description="Nome do database no OM (FQN: <service>.<DATABASE>.<schema>.<tabela>)."),
        "dry_run": Param(False, type="boolean",
                         description="Se True, apenas loga o que seria aplicado sem gravar no OM."),
    },
) as dag:
    PythonOperator(task_id="documentar_tabelas_om", python_callable=documentar_tabelas)
