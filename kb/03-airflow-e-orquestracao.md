# 03 · Airflow e orquestração

## Ambiente

- Airflow **3.1.5** em Docker Compose (`Backup_Airflow/docker-compose-airflow.yaml`), CeleryExecutor
  com Redis, UI em `http://192.168.0.157:8086`.
- Imagem própria (`Backup_Airflow/Dockerfile`): `apache/airflow:3.1.5` + git + `astronomer-cosmos` e
  `dbt-postgres` **sem versão fixada** (instalados em out/2026: cosmos 1.14.1, dbt-core 1.11.8,
  dbt-postgres 1.10.0). Ver [10](10-pendencias.md).
- `min_file_process_interval` foi de 30 para 600 no `airflow.cfg` em 08/10/2026 (reduz log do
  dag-processor). O arquivo está modificado e sem commit.
- Projeto dbt montado em `/opt/airflow/dags/dbt/meka-dw`; executável `/home/airflow/.local/bin/dbt`.
- Conexões Airflow usadas: `mekadw_airflow` (Postgres do DW), `airbyte_api`, `google_sheets_gestao`.

## As DAGs

### Orquestração

| DAG (`dag_id`) | arquivo | schedule | o que faz |
|---|---|---|---|
| `pipeline_transformacao` | `pipeline_transformacao.py` | `30 * * * *` | dispara as DAGs dbt em sequência por origem; `max_active_runs=1` |

`CADEIAS` (ordem real, de `pipeline_transformacao.py`):

1. `dbt_cronogramas_stg` → `dbt_cronogramas_int` → `dbt_cronogramas_mart` → `sheets_planilha_gestao`
2. `dbt_planilhas_raw` → `dbt_planilhas_stg` → `dbt_planilhas_mart`
3. `dbt_agilizatronik_stg` → `dbt_agilizatronik_mart`
4. `dbt_flowup_mart`
5. `dbt_mmgp_mart`

Ao final, `verificar_falhas`. Cada disparo é `TriggerDagRunOperator(wait_for_completion=True,
deferrable=True, execution_timeout=30 min)`. A primeira DAG de cada cadeia tem `trigger_rule=ALL_DONE`,
então uma falha interrompe só a própria cadeia. Ciclo completo ~4 min no teste de 15/10/2026.

**Por que de hora em hora:** o Power BI atualiza às 07, 10, 13, 16 e 19h BRT, e o Airbyte das fontes
roda a cada 1 h; qualquer carga precisa chegar ao mart antes do refresh seguinte. Rodar em sequência
também evita o timeout de parse do Cosmos quando várias DAGs sobem juntas. `schedule` em UTC, mas o
minuto `:30` é o mesmo em BRT.

### Transformação (dbt via Cosmos), todas com `schedule=None` (disparadas pelo pipeline)

`dbt_cronogramas_stg`, `dbt_cronogramas_int`, `dbt_cronogramas_mart`, `dbt_planilhas_raw`,
`dbt_planilhas_stg`, `dbt_planilhas_mart`, `dbt_agilizatronik_stg`, `dbt_agilizatronik_mart`,
`dbt_flowup_mart`, `dbt_mmgp_mart`, e `sheets_planilha_gestao` (Python, não dbt; ver [06](06-consumo-power-bi-e-sheets.md)).

- `dbt_planilhas_raw` roda `path:models/planilhas_raw/planilhas_raw.sql` (o seletor `planilhas_raw`
  casaria a pasta inteira) e depois a task `mapear_sincronizacoes_banco_bi`, que grava
  `audit_airbyte.sincronizacoes_conexoes` via API do Airbyte.
- `dbt_planilhas_stg` roda `planilhas_stg` + `fct_banco_bi`.

### Fora do pipeline

| DAG | arquivo | schedule | situação |
|---|---|---|---|
| `dbt_entregas` | `DBT_filtro.py` | `0 3 * * *` | oficial desde 19/10/2026; **pausada**; arquivo **no `.gitignore`** (ver [10](10-pendencias.md)) |
| `dbt_atividades` | `dbt_atividades.py` | `0 3 * * *` | roda `select: atividades`; não versionado; papel atual não confirmado (provável legado anterior ao pipeline, inferência) |
| `ingest_postgres_metadata` | | `30 2 * * *` | cataloga tabelas no OM ([05](05-openmetadata.md)) |
| `ingestion_final_v6_clean` | `ingestion_final.py` | `0 3 * * *` | ingest-dbt no OM (não cria lineage) |
| `om_lineage_flowup_mmgp` | | `30 3 * * *` | lineage por API |
| `om_lineage_planilhas` | | `45 3 * * *` | lineage por API |
| `om_docs_flowup_mart` / `_cronogramas_` / `_agilizatronik_` / `_planilhas_` | | seg 04:00 / 04:10 / 04:20 / 04:30 | descrições, owner, tier, domínio |
| `gera_docs_dbt` | `GeraDocs.py` | `0 2 * * *` | gera docs do dbt |
| `ingestaDados`, `dbt_run`, `dbt_cosmos_apenas_docs` | `ingesting.py`, `Run_Timestamp.py`, `Teste_Gera_Doc.py` | None | rascunhos/testes, no `.gitignore` |

`documentacao_airflow_dbt_om.md` §3.1 ainda lista `dbt_planilhas_*` com crons às 01h. **Isso mudou em
15/10/2026**: hoje são `None` e disparadas pelo pipeline.

## Regras para DAG nova

1. **dbt sem internet:** `RenderConfig(..., dbt_deps=False)` **e** `operator_args={"install_deps": False}`.
   O Cosmos (LoadMode.DBT_LS + ExecutionMode.LOCAL) exige os dois iguais, senão a DAG nem importa. Os
   pacotes (dbt_utils, codegen) estão vendados em `dbt/meka-dw/dbt_packages/`. Mudou `packages.yml`?
   Rode `dbt deps` uma vez com internet e versione o `dbt_packages/`.
2. **Parse rápido:** preferir `RenderConfig(load_method=LoadMode.DBT_MANIFEST)` +
   `ProjectConfig(manifest_path=target/manifest.json)`. Em `LoadMode.AUTOMATIC` o `dbt ls` roda no
   parse e estoura o `DagBag import timeout 30s` (foi o que derrubou o pipeline em 19/10/2026: o
   `DBT_filtro.py` passou de >30 s para ~0,35 s). O manifest se renova a cada `dbt run`; se sumir,
   `dbt parse` com um `profiles.yml` num diretório temporário.
3. **Transformação entra em `CADEIAS`** e fica com `schedule=None`.
4. **`dag_id` único:** o `dbt_entregas` já existiu em dois arquivos; o timeout de parse mascarava o
   `AirflowDagDuplicatedIdException`.
5. Lista dinâmica de cronogramas: task `buscar_cronogramas` (PostgresHook em `raw_cronogramas` por
   `mk%_00___ENTREGAS`) → XCom → `vars` do DbtTaskGroup, com `render_template_as_native_obj=True`
   (padrão do `DBT_filtro.py`).
6. `fail_when_dag_is_paused` **não existe** no Airflow 3.1.

## Armadilhas

- **Arquivos de `Backup_Airflow/dags` são do uid 50000**; o host nega escrita. Edite no scratchpad e
  `docker cp`, ou `docker exec -i backup_airflow-airflow-scheduler-1 sh -c "cat > /opt/airflow/dags/<arq>"`.
- **"Dag not found during start up"** logo após editar = bug intermitente (relative_fileloc errado
  durante o reparse). Rode de novo.
- Filha pausada faz o pipeline esperar até o `execution_timeout` de 30 min.

Fontes: memórias `agendamento-dags-powerbi`, `airflow-ambiente-offline`, `sheets-serial-date-quebra-powerbi`,
`banco-bi-airbyte-overwrite`; `grep` das DAGs em 13/11/2026.
