# Base de conhecimento: `mk829-meka-dw`

> **Última consolidação: 13/11/2026**, criação da KB (branch `dev-wollace`). Consolida os documentos
> soltos da raiz do repositório, o código em `Backup_Airflow/`, `manutencao/` e as 15 memórias do Claude
> deste servidor (sessões de jun a nov/2026), mais o estado observado dos containers em 13/11/2026.

O que uma pessoa (ou um agente) precisa saber para operar e evoluir o Meka-DW sem reabrir os
documentos antigos, o histórico das sessões e as memórias. A ordem vai do **o que é** ao **o que ainda
não fecha**: identidade → infraestrutura → ingestão → orquestração → transformação → catálogo →
consumo → operação → portal → proveniência → o aberto.

| # | arquivo | responde |
|---|---|---|
| 00 | [visao-geral.md](00-visao-geral.md) | O que é o Meka-DW, as fontes, o fluxo ponta a ponta, as camadas, a linha do tempo |
| 01 | [infraestrutura-e-rede.md](01-infraestrutura-e-rede.md) | VM, IPs (atuais e obsoletos), containers e portas, Docker, Tailscale, DNS |
| 02 | [ingestao-airbyte.md](02-ingestao-airbyte.md) | abctl/kind, conexões e frequências, padrão de cronograma, BANCO_BI, API, falhas típicas |
| 03 | [airflow-e-orquestracao.md](03-airflow-e-orquestracao.md) | As DAGs, o `pipeline_transformacao`, Cosmos sem internet, uid 50000 |
| 04 | [dbt-modelos-e-nomenclatura.md](04-dbt-modelos-e-nomenclatura.md) | Projeto dbt, modelos por origem, macros (conversão de tipos), `fct_banco_bi`, nomenclatura |
| 05 | [openmetadata.md](05-openmetadata.md) | Catálogo, DAGs `om_docs_*`, lineage por API, limitações, a porta 8585 |
| 06 | [consumo-power-bi-e-sheets.md](06-consumo-power-bi-e-sheets.md) | Horários do Power BI, Planilha de Gestão, os erros de refresh conhecidos e como diagnosticar |
| 07 | [operacao-e-manutencao.md](07-operacao-e-manutencao.md) | Disco, retenção de logs, limpeza de pods, memória do kind, roteiro pós-queda |
| 08 | [portal-meka-dw.md](08-portal-meka-dw.md) | O portal Flask, Caddy/HTTPS, login, SSO pendente de DNS |
| 09 | [indice-fontes.md](09-indice-fontes.md) | Qual arquivo/memória contém o quê; inventário da pasta |
| 10 | [pendencias.md](10-pendencias.md) | O que está aberto, o que diverge entre fontes, o que precisa de decisão |

## Como esta KB foi montada

Lendo, nominalmente:

- **Documentos da raiz** — `readme.md`, `documentacao_airflow_dbt_om.md`, `padrao_nomenclaturas.md`,
  `airbyte.md`, `handover (1).md`; `playbook.html` só inventariado (é o mesmo conteúdo, publicado no
  GitHub Pages pelo `.github/workflows/deploy.yml`).
- **Código** — lista de DAGs e `dag_id`/`schedule` de todas (`grep`), `pipeline_transformacao.py`
  (bloco `CADEIAS`), cabeçalho de `dbt_atividades.py`, `dbt_project.yml` (sem copiar o token),
  `Dockerfile`, `docker-compose.yaml` e trechos de `docker-compose-airflow.yaml`, lista de modelos e
  macros dbt; `git status`/`git ls-files` para saber o que está versionado.
- **Ambiente** — `docker ps -a`, `crontab -l`, `df`, `free`, `manutencao/uso_disco.csv` e logs da
  manutenção, em 13/11/2026.
- **Memórias do Claude** — os 15 arquivos de `~/.claude/projects/-home-mkadmin/memory/` (lista em [09](09-indice-fontes.md)).

**Pulado:** `Backup_Airflow/logs/`, `dbt_packages/`, `target/`, `openmetadata-1.11.5/docker-volume/`
(dados), `openmetadata.tar.gz`, `dbt/meu_projeto/` (legado) — inventariados em [09](09-indice-fontes.md).

## O que esta KB **não** carrega

| fora daqui | por quê | onde está |
|---|---|---|
| Senha do Postgres do DW (`PG_PASSWORD`) | credencial de produção | `.env` da raiz (fora do git) |
| Chave da service account Google (`sheets-teste@sheetsproject-490617`) | credencial | `sheetsproject-*.json` na raiz (no `.gitignore`); conexão Airflow `google_sheets_gestao` |
| JWT do bot de ingestão do OpenMetadata | credencial, sem expiração | `Backup_Airflow/dags/dbt/meka-dw/dbt_project.yml` (vars) — **arquivo hoje não versionado; ver [10](10-pendencias.md)** |
| client_id/secret da API do Airbyte | credencial | conexão Airflow `airbyte_api` |
| Senha compartilhada e credenciais Google do portal | credencial | `.env` do portal (`/home/mkadmin/meka-dw-portal/portal`) |
| Senha em texto puro do compose antigo | credencial | `/home/mkadmin/docker-compose.yaml` (volume antigo `mkadmin_db_data`) |

**Estão** aqui, de propósito: nomes de quem opera, ids de conexões Airbyte e de planilhas, códigos MK.
É dado interno da Mekatronik num repositório privado.
