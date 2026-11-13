# 00 · Visão geral

## O que é

O **MK829 · Meka-DW** é o Data Warehouse interno da Mekatronik: reestrutura os dados de gestão
(cronogramas de projeto, alocação de pessoas, horas e faturamento, chamados, CRM) num PostgreSQL
organizado em camadas, para análise no **Power BI** e para alimentar a **Planilha de Gestão** no
Google Sheets (fonte: `readme.md`).

## As fontes

| fonte | o que é | como entra | schema raw |
|---|---|---|---|
| **Planilhas de cronograma** (`mkXXX`) | um Google Sheets por projeto, abas `00 - ATIVIDADES`, `00 - BANCO`, `00 - ENTREGAS` | Airbyte, destino `Postgres_cronogramas`, ~163 conexões | `raw_cronogramas` |
| **Planilhas de alocação** (`<pessoa>_BANCO_BI`) | planilha de alocação de cada colaborador | Airbyte, destino `Postgres_Alocacao`, ~85 conexões | `public` → `raw_planilhas` |
| **Outras planilhas** | `COMPOSICAO_PROJETOS` (PA - Composição Projetos), `BANCO_COLABORADORES`, `CADASTRO_CC`, `HH_COMPOSICOES` | Airbyte (ex.: `google_sheets_pa`) | `public` → `raw_planilhas` |
| **FlowUp** | sistema de apontamento de horas/faturamento (MySQL/MariaDB) | Airbyte, `Postgres_flowup` | `raw_flowup` (inferido do padrão; modelo lê e grava `mart_flowup`) |
| **Agilizatronik** | chamados, via OData | Airbyte (Connector Builder), `Postgres_agilizatronik` | `raw_agilizatronik` (inferido) |
| **MMGP** | CRM/gestão de projetos | Airbyte | `raw_mmgp` (inferido) |
| **VOE** | OData | conexão `OData VOE → Postgres_voe` **inativa** desde 21/06/2026; nenhum modelo dbt lê `raw_voe` | `raw_voe` (5,6 GB congelados) |

## O fluxo ponta a ponta

```
Google Sheets / FlowUp / OData
        │  Airbyte (abctl, kind) — full refresh/overwrite, maioria de hora em hora
        ▼
PostgreSQL 14 (postgres_db, :5432, database postgres)   raw_*
        │  Airflow 3.1 + Cosmos → dbt   (pipeline_transformacao, toda hora :30)
        ▼
stg_* → int_* → mart_*
        │                     │                         │
        ▼                     ▼                         ▼
   Power BI (refresh     Planilha de Gestão        OpenMetadata (:8585)
   07/10/13/16/19h)      (DAG sheets_planilha_     catálogo, descrições,
                          gestao)                   lineage
```

## As camadas

| camada | papel | exemplo |
|---|---|---|
| `raw_*` | cópia como chega da fonte; **sobrescrita a cada sync** | `raw_cronogramas.mk829_00___ENTREGAS` |
| `stg_*` | limpeza e tipagem (macro `conversao_tipos`) | `stg_planilhas` |
| `int_*` | união das planilhas de cronograma, colunas duplicadas unificadas | `int_cronogramas` |
| `mart_*` | pronta para BI: nulos tratados (texto → `''`, número → `0`) | `mart_cronogramas.fct_banco`, `fct_atividades`, `fct_entregas` |
| `audit_*` | controle | `audit_airbyte.sincronizacoes_conexoes` |

Os modelos dbt são **dinâmicos**: descobrem as tabelas da origem e recriam o schema inteiro via
`run_query` (DROP/CREATE), materializando só uma tabela de log (fonte: `documentacao_airflow_dbt_om.md`
§2). Por isso as tabelas `mart_*` não são nós dbt, e a documentação no OM é feita por API ([05](05-openmetadata.md)).

## Linha do tempo

| quando | o quê | fonte |
|---|---|---|
| mar–abr/2026 | VM, Postgres, Airbyte via abctl; padrões de nomenclatura e doc do Airbyte | `readme.md`, `padrao_nomenclaturas.md`, `airbyte.md` |
| 14/05–29/05/2026 | DAGs e modelos dbt de cronogramas (stg/int/mart), agilizatronik, mmgp, flowup, planilhas | `git log` |
| 27/05/2026 | lineage agilizatronik + cronogramas criado por script one-off via API | memória `lineage-om-via-api` |
| 16/06/2026 | servidor fixado em `192.168.0.157`; DNS dos containers do Airflow corrigido | memórias `infra-openmetadata-postgres`, `airflow-ambiente-offline` |
| 17–19/06/2026 | DAGs `om_docs_*`; `documentacao_airflow_dbt_om.md` | `git log` |
| 16/07/2026 | portal Meka-DW no ar na :80 (Traefik do k3s desligado) | memória `portal-meka-dw` |
| 24/08/2026 | Elasticsearch do OM atualizado | `git log` |
| 15–19/09/2026 | BANCO_BI: overwrite entre 82 conexões descoberto e resolvido com prefixo por pessoa | memória `banco-bi-airbyte-overwrite` |
| 08/10/2026 | diagnóstico de disco; retenção de logs no cron | memória `disco-servidor-crescimento` |
| 14/10/2026 | DAG `sheets_planilha_gestao` substitui a conexão Airbyte → Sheets | memória `airbyte-sheets-planilha-gestao` |
| 15/10/2026 | `pipeline_transformacao` (toda hora); frequências do Airbyte revistas | memórias `agendamento-dags-powerbi`, `airbyte-frequencias-conexoes` |
| 19/10/2026 | blindagem de data serial na `conversao_tipos`; `DBT_filtro.py` por manifest | memória `sheets-serial-date-quebra-powerbi` |
| 22/10/2026 | `fct_banco_bi` reatribui `colaborador_planilha`; 2 abas novas na Planilha de Gestão | memórias `banco-bi-airbyte-overwrite`, `airbyte-sheets-planilha-gestao` |
| 28–29/10/2026 | incidentes de prefixo maiúsculo e MK duplicado | memórias `cronogramas-*` |
| 06/11 e 13/11/2026 | quedas da VM por memória do Airbyte; teto no kind; limpeza de pods no cron | memória `airbyte-abctl-capacidade` |
| 13/11/2026 | rede: VM volta à 192.168.0.157 fixa; criação desta KB | memória `infra-openmetadata-postgres` |

## Quem é quem

- **Wollace Dantas**: autor de todos os commits, opera o DW.
- **Albert**: cria conexões de cronograma no Airbyte e mantém planilhas de cronograma (memórias `cronogramas-*`).
- **Hugo**: Head de Industrial DevOps; autor do handover da PoC de sincronização com o Sheets (`handover (1).md`).
- Gestores com planilha de alocação própria: geraldo_vinicius, vanessa_barbalho (memória `banco-bi-airbyte-overwrite`).
