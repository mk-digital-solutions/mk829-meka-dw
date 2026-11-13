# 05 · OpenMetadata

## Onde

- OpenMetadata **1.11.5**, `http://192.168.0.157:8585` (API em `/api`). Sobe por
  `openmetadata-1.11.5/docker-compose-postgres.yml` (containers `openmetadata_server`,
  `openmetadata_elasticsearch`, `openmetadata_postgresql`; `openmetadata_ingestion` parado desde jul/2026).
- Service do banco no OM: **`mekadw_openmetadata`**. FQN: `mekadw_openmetadata.postgres.<schema>.<tabela>`.
- Owner padrão: usuário **MKADMIN**. Domínio global **Meka DW**.
- O Elasticsearch precisa estar de pé: lineage e busca dependem dele (atualizado em 24/08/2026).

## Como as tabelas chegam e são documentadas

| etapa | DAG | o que faz |
|---|---|---|
| 1. Catalogar | `ingest_postgres_metadata` (02:30) | escaneia `raw_/stg_/int_/mart_` e cria as entidades. Cria um venv e faz `pip install openmetadata-ingestion[postgres]` a cada run, **depende de DNS externo** ([01](01-infraestrutura-e-rede.md)) |
| 2. Documentar | `om_docs_*_mart` (segunda, 04:00–04:30) | descrições de tabela e coluna, owner, tier, domínio, rowCount, tamanho, data |
| 3. Lineage | `om_lineage_flowup_mmgp` (03:30), `om_lineage_planilhas` (03:45) | arestas via `PUT /v1/lineage` |

Tabela não catalogada no passo 1 é só "skipada" com aviso no passo 2.

### `om_docs_*`

As tabelas `mart_*` são geradas dinamicamente e não são nós dbt, por isso a documentação é escrita
direto na API (não pelo `schema.yml`). As DAGs são idempotentes e têm os params `dry_run` e `om_database`.

| DAG | schema | tabelas |
|---|---|---|
| `om_docs_flowup_mart` | `mart_flowup` | 13 consumidas no Power BI |
| `om_docs_cronogramas_mart` | `mart_cronogramas` | `fct_banco`, `fct_atividades`, `fct_entregas` |
| `om_docs_agilizatronik_mart` | `mart_agilizatronik` | `fct_agilizatronik` |
| `om_docs_planilhas_mart` | `mart_planilhas` | `BANCO_BI`, `BANCO_COLABORADORES`, `CADASTRO_CC`, `COMPOSICAO_PROJETOS`, `HH_COMPOSICOES`, e `fct_banco_bi` (Tier1, desde set/2026) |

- **Tier1**: `fct_reportagem`, `fct_agilizatronik`, `COMPOSICAO_PROJETOS`, `HH_COMPOSICOES`, `fct_banco_bi`; demais Tier2.
- Mecânica: `PATCH` (JSON Patch) para descrição/owner/tier/domínio; `PUT /tables/{id}/tableProfile` para
  rowCount (`count(*)`), tamanho (`pg_total_relation_size`) e data. O patch de colunas tenta em lote e
  cai para coluna a coluna se falhar.
- `COMPOSICAO_PROJETOS` (~180 colunas): descrições geradas por padrão do nome (HH/Comissão/Valor/cargo).
- Para ler o profile: `GET /v1/tables/{fqn}/tableProfile?startTs&endTs` (o campo `profile` da entidade
  volta vazio nesta versão).

**Limitação:** `FAT. PESSOAL PRD.` e `FAT. PESSOAL SERV.` (`mart_cronogramas.fct_entregas`) não aceitam
descrição: o nome termina com ponto e o OM dá erro 500 ao montar o FQN. Resolver exige renomear na origem.

Fonte: `documentacao_airflow_dbt_om.md` §3–5; memória `banco-bi-airbyte-overwrite`.

## Lineage: como foi feito de verdade

O `ingest-dbt` (DAG `ingestion_final_v6_clean`) roda, mas **não cria as arestas** (motivo não
diagnosticado). O lineage existente foi criado **por API** (`PUT /v1/lineage`), 1:1 por nome de coluna,
lendo o `manifest.json` do dbt:

- flowup/mmgp (raw → mart): DAG `om_lineage_flowup_mmgp`.
- planilhas, incluindo as 82 `<pessoa>_BANCO_BI` + `fct_entregas` → stg → mart: DAG `om_lineage_planilhas`.
- agilizatronik e cronogramas (raw → stg → int → mart): **script one-off de 27/05/2026, sem DAG**. Se os
  modelos mudarem, o lineage fica velho ([10](10-pendencias.md)).

Pré-requisitos que travaram no caminho: ES no ar, token do bot atualizado, `sink: metadata-rest` no
config de ingestão. Fonte: memória `lineage-om-via-api`.

## A porta 8585 depois de reboot

**Sintoma:** depois de reiniciar o host, todas as DAGs do OM (`om_docs_*`, `om_lineage_*`,
`ingest_postgres_metadata`, `ingestion_final_v6_clean`) falham com ConnectTimeout em
`192.168.0.157:8585`. Do host e da rede do OM funciona; de outra bridge (o worker, em `meka-dw-net`), não.

**Causa:** o DNAT de 8585 existe, mas falta a regra ACCEPT de 8585 na chain DOCKER (a de 8586 existe).
Provável corrida no boot com as regras do k3s/kube-router.

**Diagnóstico:** `docker exec backup_airflow-airflow-worker-1 curl http://192.168.0.157:8585/api/v1/system/version`.
**Correção:** `docker restart openmetadata_server` (o Docker reprograma as regras).

Ficou quebrado de 14 a 23/10/2026 sem ninguém perceber. Correção definitiva sugerida e não feita: ligar o
Airflow à rede `openmetadata-1115_meka-dw-net` e usar `http://openmetadata_server:8585` nas DAGs ([10](10-pendencias.md)).

Fonte: memória `om-porta-8585-iptables-reboot`.
