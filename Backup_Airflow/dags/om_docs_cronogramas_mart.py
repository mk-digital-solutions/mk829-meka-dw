"""
Documentação/enriquecimento do mart_cronogramas -> OpenMetadata (via REST API).

Mesma abordagem da om_docs_flowup_mart: as tabelas são geradas pelo dbt mas aqui
escrevemos metadados (descrição de tabela e colunas, owner, tier e rowCount dinâmico)
direto na API do OpenMetadata. Idempotente; roda semanalmente ou sob demanda.

Tier: todas as tabelas de cronogramas = Tier2.
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
OM_SCHEMA = "mart_cronogramas"
PG_CONN_ID = "mekadw_airflow"

OWNER_NAME = "mkadmin"
OWNER_EMAIL = "mkadmin@mekatronik.com.br"
OWNER_DISPLAY = "MKADMIN"

DOMAIN_NAME = "Meka DW"
DOMAIN_DISPLAY = "Meka DW"

TIER_DEFAULT = "Tier.Tier2"
TIER_OVERRIDES = {}  # cronogramas: todas Tier2

DESCRICOES = {
    "fct_banco":
        "Gold: 'banco' final dos cronogramas (unificação das tabelas mkXXX_00___BANCO de "
        "todos os cronogramas, com nulos numéricos -> 0 e texto -> '').",
    "fct_atividades":
        "Gold: atividades finais dos cronogramas (unificação das tabelas mkXXX_00___"
        "ATIVIDADES, com nulos numéricos -> 0 e texto -> '').",
    "fct_entregas":
        "Gold: entregas finais dos cronogramas (unificação das tabelas mkXXX_00___"
        "ENTREGAS, com nulos numéricos -> 0 e texto -> '').",
}

COLUNAS = {
    "fct_banco": {
        "codigo_cronograma": "Código do cronograma (mkXXX) extraído do nome da tabela de origem.",
        "tabela_origem": "Nome da tabela raw de origem (gerado na unificação dos cronogramas).",
        "_": "Coluna auxiliar/índice herdada da planilha de origem.",
        "MK": "Código MK do item/cronograma.",
        "Imped_": "Impedimento registrado.",
        "Esforco": "Esforço estimado.",
        "Estoque": "Estoque.",
        "Status_Data": "Data do status.",
        "Status_Comentario": "Comentário do status.",
        "Data_de_Conclusao": "Data de conclusão.",
        "Licoes_Aprendidas": "Lições aprendidas.",
        "Responsavel_Pendencia": "Responsável pela pendência.",
        "Fora_de_Orcamento": "Indica se está fora do orçamento.",
        "Valor_entregue__Cliente_": "Valor entregue ao cliente (numérico).",
    },
    "fct_atividades": {
        "codigo_cronograma": "Código do cronograma (mkXXX) extraído do nome da tabela de origem.",
        "tabela_origem": "Nome da tabela raw de origem (gerado na unificação dos cronogramas).",
        "CC": "Centro de custo.",
        "No_EAP": "Número da EAP (Estrutura Analítica do Projeto) da atividade.",
        "RESUMO": "Resumo da atividade.",
        "ERFORCO": "Esforço estimado da atividade.",
        "__CONCLUIDA": "Indica se a atividade está concluída.",
        "RESPONSAVEL": "Responsável pela atividade.",
        "DATA_DE_INICIO": "Data de início da atividade.",
        "E_A_P__ENTREGA": "EAP da entrega associada.",
        "TITULO_DA_TAA": "Título da tarefa (campo de origem alternativo).",
        "TITULO_DA_TAREFA": "Título da tarefa.",
        "DATA_DE_CONCLUSAO": "Data de conclusão da atividade.",
        "No_EAP___ENTREGAS": "Número da EAP de entregas.",
        "VALOR_DA_ATIVIDADE": "Valor da atividade.",
        "DATA_DE_INICIO__LINHA_DE_BASE_": "Data de início conforme linha de base (baseline).",
        "DATA_DE_CONCLUSAO__LINHA_DE_BASE_": "Data de conclusão conforme linha de base (baseline).",
    },
    "fct_entregas": {
        "codigo_cronograma": "Código do cronograma (mkXXX) extraído do nome da tabela de origem.",
        "tabela_origem": "Nome da tabela raw de origem (gerado na unificação dos cronogramas).",
        "_": "Coluna auxiliar/índice herdada da planilha de origem.",
        "ENTREGA": "Nome/descrição da entrega.",
        "SEGMENTO": "Segmento.",
        "_CLIENTE_": "Cliente.",
        "RESPONSAVEL": "Responsável pela entrega.",
        "E_A_P__ENTREGA": "EAP da entrega.",
        "CENTRO_DE_CUSTO": "Centro de custo.",
        "DATA_DE_INICIO": "Data de início.",
        "COMISSAO_GESTAO": "Comissão de gestão.",
        "DATA_DE_CONCLUSAO": "Data de conclusão.",
        "No_EAP_ATIVIDADE": "Número da EAP da atividade.",
        "FAT__PESSOAL_GESTAO": "Faturamento pessoal de gestão.",
        "DATA_DE_INICIO__LINHA_DE_BASE_": "Data de início conforme linha de base (baseline).",
        "DATA_DE_CONCLUSAO__LINHA_DE_BASE_": "Data de conclusão conforme linha de base (baseline).",
        "RESPONSAVEL_GESTAO": "Responsável de gestão.",
        "COMISSAO": "Comissão.",
        "FAT. PRODUTO": "Faturamento de produto.",
        "FAT. SERVICO": "Faturamento de serviço.",
        "FAT. PESSOAL PRD.": "Faturamento pessoal de produção.",
        "FAT. PESSOAL SERV.": "Faturamento pessoal de serviço.",
    },
}


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
    """Retorna (ops_tabela, ops_colunas). ops_colunas é lista de (nome_coluna, op)."""
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
    (com aviso) as que o OM rejeitar — ex.: nomes terminando em '.' geram 500 no OM.
    Retorna o número de colunas que não puderam ser documentadas."""
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
            logger.warning("Coluna '%s' NAO documentada no OM (%s) — ignorada.", col, rr.status_code)
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
        col_descs = COLUNAS.get(tabela, {})
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
    dag_id="om_docs_cronogramas_mart",
    start_date=datetime(2024, 1, 1),
    schedule="10 4 * * 1",  # semanal: segunda 04:10
    catchup=False,
    tags=["openmetadata", "docs", "cronogramas"],
    params={
        "om_database": Param("postgres", type="string",
                             description="Nome do database no OM (FQN: <service>.<DATABASE>.<schema>.<tabela>)."),
        "dry_run": Param(False, type="boolean",
                         description="Se True, apenas loga o que seria aplicado sem gravar no OM."),
    },
) as dag:
    PythonOperator(task_id="documentar_tabelas_om", python_callable=documentar_tabelas)
