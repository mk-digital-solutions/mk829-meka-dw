# 02 · Ingestão: Airbyte

## Onde o Airbyte roda

Via **abctl**: um cluster **kind** dentro do container Docker `airbyte-abctl-control-plane`, UI em
`http://192.168.0.157:8000`. **Não** está no k3s do host. (O `readme.md` diz "instalação via
Kubernetes (K3S)"; está desatualizado, ver [10](10-pendencias.md).)

```bash
kubectl --kubeconfig ~/.airbyte/abctl/abctl.kubeconfig get pods -n airbyte-abctl
```

- Pods de sync: `replication-job-<jobid>-attempt-0`, 3 containers (source/dest/orchestrator), cerca de
  4 Gi reservados por job (orchestrator 2 Gi + source 1 Gi + dest 1 Gi).
- `MAX_SYNC_WORKERS=5`. Uma leva de ~248 syncs leva 35–75 min.
- Dados: pgdata do Airbyte (PG17) ~31 GB; `~/.airbyte/abctl/data/airbyte-local-pv` ~17 GB
  (`job-logging` com ~1,09 M arquivos). Capacidade e memória em [07](07-operacao-e-manutencao.md).

## Destinos e frequências (desde 15/10/2026)

| destino | conexões | frequência |
|---|---|---|
| `Postgres_cronogramas` | 163: **84 desativadas** (projeto 100% concluído), 61 em andamento + 18 sem atividade em "Every 1 HOURS" | 1 h |
| `Postgres_Alocacao` | 85, todas "Every 1 HOURS" (antes 82 em 6 h e 3 em 12 h) | 1 h |
| `Postgres_flowup` | cron `0 0 0/2 * * ?` Brazil/East | 2 h |
| `Postgres_agilizatronik` | cron `0 0 0/6 * * ?` Brazil/East | 6 h |
| `Postgres_voe` | `OData VOE → Postgres_voe` **inativa**; último job falhou em 21/07/2026 | — |

- Critério de "concluído": todas as linhas de `mart_cronogramas.fct_atividades` do MK com
  `__CONCLUIDA = 100`, ignorando títulos `#N/A`.
- Backups do estado anterior, para reverter: `/home/mkadmin/airbyte_cronogramas_backup_20261015.json`
  e `/home/mkadmin/airbyte_alocacao_backup_20261015.json`. Lista das ativas em 13/11:
  `/home/mkadmin/airbyte_cronogramas_ativas_20261113.tsv`.
- **Projeto reaberto ou que chegou a 100%** → reativar/desativar a conexão correspondente.
- 612 de 632 streams são full_refresh/overwrite (08/10/2026): retenção por DELETE no DW é desfeita no sync.

Fonte: memórias `airbyte-frequencias-conexoes`, `disco-servidor-crescimento`.

## Cronogramas: o padrão de conexão

| campo | valor |
|---|---|
| Source | Google Sheets, service account, planilha do projeto |
| Destination | `Postgres_cronogramas`, namespace = destination (`raw_cronogramas`) |
| **Prefixo** | **`mkXXX_` minúsculo**, com o `_` |
| Streams | `00 - ATIVIDADES`, `00 - BANCO`, `00 - ENTREGAS`, full_refresh/overwrite |
| Agendamento | basic, Every 1 HOURS |
| nonBreakingChanges | `propagate_columns` (as criadas em out/2026 vieram com `ignore`) |

Tabelas resultantes: `raw_cronogramas.mkXXX_00___ATIVIDADES` / `_BANCO` / `_ENTREGAS`.

**Por que o prefixo é inviolável:** os modelos `atividades_stg`/`banco_stg`/`entregas_stg` montam o
nome em minúsculo. Em 26/10/2026, as conexões MK921 e MK926 vieram com `MK921_`/`MK926_` (e o stream
extra `00 - A GASTAR`); o dbt abortou com "found an approximate match…" e **o stg de todos os cronogramas
falhou** até 28/10 13:30, deixando o mart congelado. Correção: prefixo minúsculo na conexão, DROP das
tabelas `MKxxx_*` em `raw_cronogramas` (e das sobras sem `_`, como `MK92100___*`), resync. Dos 34
códigos novos, 30 chegaram ao mart (mk315/mk878 sem dados; mk437/mk462 com ENTREGAS vazia).

- Tabelas `raw_cronogramasmkXXX_…<hash>` vazias são sobras de syncs interrompidos (inofensivas).
- **Um MK só pode estar numa planilha**: ver [06](06-consumo-power-bi-e-sheets.md).

Fonte: memória `cronogramas-prefixo-maiusculo-quebra-stg`.

## Alocação: BANCO_BI por pessoa

Até 15/09/2026, 82 conexões `google_sheets_<pessoa> → Postgres_mkdw` gravavam o stream BANCO_BI na
**mesma** `public.BANCO_BI` em overwrite: cada sync apagava as outras (só 31/82 pessoas presentes no
momento da análise). Em 19/09/2026 cada conexão ganhou **prefixo por pessoa** → `public.<pessoa>_BANCO_BI`
(68 tabelas). O dbt une essas tabelas em `fct_banco_bi` ([04](04-dbt-modelos-e-nomenclatura.md)). A
`public.BANCO_BI` antiga parou em 16/09 18:05; o modelo `fct_banco_bi_colaboradores` (vínculo por
`_airbyte_meta->>'sync_id'`) ficou **obsoleto** e não é usado.

Fonte: memória `banco-bi-airbyte-overwrite`.

## Outras conexões citadas

- `google_sheets_pa` (id `a88c9ef9-a33d-4b00-898c-3ea5890e09c1`), stream `COMPOSIÇÃO PROJETOS` →
  `raw_planilhas.COMPOSICAO_PROJETOS`.
- Conexão Airbyte `63b7eba3` (`postgres_PG → Google Sheets_PG`, destination-google-sheets 0.3.5):
  **deve ficar desligada**. Foi substituída pela DAG `sheets_planilha_gestao` ([06](06-consumo-power-bi-e-sheets.md)).

## API

- Pública: `POST /api/public/v1/jobs` `{"connectionId": "...", "jobType": "sync"}`; status em
  `/api/public/v1/jobs/{id}`.
- Token: conexão Airflow `airbyte_api` (host/port, login = client_id, password = client_secret) →
  `POST /api/v1/applications/token`. Fora de task context, buscar a connection pela ORM
  (`airflow.models.Connection` + Session), não por `airflow.sdk.BaseHook`.
- Editar agendamento: API **interna** `/api/v1/connections/update` (a pública rejeita timezone no cron).
- Cancelar job: `POST /api/v1/jobs/cancel` ou botão Cancel na UI.

## Falhas típicas

| sintoma | causa | ação |
|---|---|---|
| Job **succeeded com 0 linhas**, duração ~PT30M | pod ficou Pending ("Insufficient memory") e o Airbyte desistiu | `get pods`: procure `replication-job` com idade de dias (prendem ~4 Gi cada) e cancele |
| Sync manual demora 15+ min para começar | pico horário, backlog no nó | esperar ou escalonar |
| UI/API 503 após queda | `airbyte-abctl-server` em CrashLoopBackOff (OOM) | depois que o load baixar, `kubectl delete pod` do server |
| Conexão não sincroniza nem manualmente | está **inactive** | ativar antes |
| Teste falha no Google Sheets | planilha não compartilhada com a service account | compartilhar (Leitor/Editor) |

Exemplos reais: 26/10/2026, FlowUp sem dados desde 25/10 por 3 jobs travados havia dias (212927, 217747,
233778); 06/11/2026, server com 473 restarts após a queda do host. Fonte: memória `airbyte-abctl-capacidade`.

## O guia de configuração

O passo a passo de criar source/destination/connection na UI (Fluxo 1 Sheets → Postgres; Fluxo 2
Postgres → Sheets) está em [`airbyte.md`](../airbyte.md), também usado no treinamento do portal. O
Fluxo 2 foi aposentado (ver acima), e o padrão "a cada 6 horas" do Fluxo 1 hoje é 1 h.
