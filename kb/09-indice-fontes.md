# 09 · Índice de fontes: qual arquivo contém o quê

Este índice existe para auditar a KB: cada afirmação dos outros capítulos deve poder ser rastreada até
uma linha daqui. Estado: **L** = lido, **P** = parseado (estrutura/trechos), **I** = inventariado.

## Raiz do repositório

| arquivo | estado | git | contém | usado em |
|---|---|---|---|---|
| `readme.md` | L | sim | descrição, ambiente (Hyper-V, Debian, .157), componentes, fluxo; diz "Airbyte via K3S" (desatualizado) | 00, 01 |
| `documentacao_airflow_dbt_om.md` | L | sim | DNS dos containers, dbt offline, pipeline de planilhas, DAGs `om_docs_*`, o que é documentado no OM, limitação das colunas com ponto | 03, 04, 05 |
| `padrao_nomenclaturas.md` | L | sim | padrão snake_case, prefixos de schema/tabela, sufixos de coluna | 04 |
| `airbyte.md` | L | sim | passo a passo da UI do Airbyte (Fluxos 1 e 2), boas práticas, troubleshooting | 02 |
| `handover (1).md` | L | **não** | PoC de sincronização com o Sheets (Hugo): fatos da API, desenho, plano de teste | 06 |
| `playbook.html` | I (31 KB) | sim | guia interativo; publicado no GitHub Pages por `.github/workflows/deploy.yml` (push em `main`) | — |
| `docker-compose.yaml` | L | sim | `postgres_db` (pg14, :5432, `POSTGRES_DB mkdw_db`, user admin, senha via `PG_PASSWORD`, rede `meka-dw-net`) | 01 |
| `.env` | I (48 B) | não | `PG_PASSWORD`; **valor não lido** | — |
| `sheetsproject-490617-*.json` | I | não (`.gitignore`) | chave da service account; **não lida** | — |
| `abctl` | I (9 B) | sim | stub | — |
| `.gitignore` | L | sim | exclusões (inclui `DBT_filtro.py`, `ingesting.py`, `Run_Timestamp.py`, `Teste_Gera_Doc.py`, `sheetsproject-*.json`) | 10 |
| `CLAUDE.md`, `kb/` | — | esta branch | o roteador e esta KB | — |

## `Backup_Airflow/`

| caminho | estado | git | contém |
|---|---|---|---|
| `Dockerfile` | L | sim (modificado) | airflow 3.1.5 + cosmos + dbt-postgres sem versão |
| `docker-compose-airflow.yaml` | P | sim | serviços, `dns`, portas 8086/5555 |
| `config/airflow.cfg` | I | sim (modificado) | `min_file_process_interval = 600` (memória) |
| `dags/*.py` | P | parcial | `dag_id` e `schedule` de todas (ver [03](03-airflow-e-orquestracao.md)). **Não versionados:** `pipeline_transformacao.py`, `sheets_planilha_gestao.py`, `dbt_atividades.py`; **no `.gitignore`:** `DBT_filtro.py` e rascunhos |
| `dags/pipeline_transformacao.py` | P | **não** | bloco `CADEIAS` e operadores |
| `dags/dbt_atividades.py` | P | **não** | cabeçalho: Cosmos, `select: atividades`, conn `mekadw_airflow` |
| `dags/dbt/meka-dw/models/**` | I (lista) | sim, exceto `fct_banco_bi_colaboradores.sql` | 22 modelos + `schema.yml` |
| `dags/dbt/meka-dw/macros/` | I (lista) | **não** | `conversao_tipos`, `generate_schema_name`, `filtroData`, `filtro_hora`, `TimescaleUtils` |
| `dags/dbt/meka-dw/dbt_project.yml` | L (sem copiar o token) | **não** | nome `cronogramas`, profile, vars do OM **com JWT** |
| `dags/dbt/meka-dw/profiles/`, `profiles.yml` | I | não | credenciais (desatualizadas) |
| `dags/dbt/meka-dw/dbt_packages/`, `target/`, `logs/`, `IGNORE/` | I | não | pacotes vendados, manifest, artefatos |
| `dags/dbt/meu_projeto/` | I | não (`.gitignore`) | projeto legado com IP `.89`; nenhuma DAG usa |
| `logs/` | I | não | logs do Airflow (retenção 30 d) |

## Outras pastas

| caminho | estado | git | contém |
|---|---|---|---|
| `manutencao/*.sh` | I (nomes; comportamento pela memória) | **não** | `retencao_logs.sh`, `limpeza_pods_airbyte.sh`, `vigia_memoria_airbyte.sh` |
| `manutencao/uso_disco.csv` | P | não | série diária de disco (cabeçalho + últimas linhas lidas) |
| `manutencao/*.log` | P | não (`*.log`) | saídas do cron |
| `openmetadata-1.11.5/*.yml` | I | parcial | composes do OM (`docker-compose-postgres.yml` é o que roda) |
| `openmetadata-1.11.5/docker-volume/`, `openmetadata.tar.gz`, `openmetadata-1.11.5/` | I | não | dados e pacote do OM |
| `.github/workflows/deploy.yml` | L | sim (modificado) | deploy do `playbook.html` no Pages |

## Fora do repositório

| caminho | estado | contém |
|---|---|---|
| `/home/mkadmin/meka-dw-portal/portal/` | I (lista) | portal Flask ([08](08-portal-meka-dw.md)) |
| `/home/mkadmin/airbyte_*_backup_20261015.json` | I | estado das conexões antes de 15/10/2026 |
| `/home/mkadmin/airbyte_cronogramas_ativas_20261113.tsv` | I | conexões de cronograma ativas em 13/11 |
| `/home/mkadmin/drop_cronogramas_antigos_20261029.sql` | I | DROPs do incidente de 29/10 |
| `/home/mkadmin/mk829-meka-dw_backup_072026.tar.gz` | I (2 GB, root) | backup do repo de jul/2026 |
| `/home/mkadmin/docker-compose.yaml` | I | compose do DW antigo (`mkadmin_db_data`), **senha em texto puro** |
| `/home/mkadmin/mk829-meka-dw-apresentacao.html`, `meka-brand-main/mk829-meka-dw-treinamento.html` | I | apresentação e treinamento |
| `/etc/network/interfaces`, `/etc/systemd/resolved.conf.d/meka-dw.conf`, `/etc/rancher/k3s/config.yaml` | I (pela memória) | rede e k3s |

## Memórias do Claude (`~/.claude/projects/-home-mkadmin/memory/`)

Todas **lidas**. São o diário das sessões de jun a nov/2026.

| arquivo | assunto | usado em |
|---|---|---|
| `infra-openmetadata-postgres.md` | IPs atuais/obsoletos, rede de 13/11 | 01, 05 |
| `lineage-om-via-api.md` | lineage por API | 05 |
| `airflow-ambiente-offline.md` | DNS dos containers, dbt offline | 01, 03 |
| `portal-meka-dw.md` | portal, porta 80, SSO | 08 |
| `banco-bi-airbyte-overwrite.md` | BANCO_BI, `fct_banco_bi`, uid 50000 | 02, 04 |
| `tailscale-rota-pve-quebrada.md` | rota 192.168.0.0/24 | 01 |
| `disco-servidor-crescimento.md` | disco, retenção | 07 |
| `airbyte-sheets-planilha-gestao.md` | DAG da Planilha de Gestão | 06 |
| `agendamento-dags-powerbi.md` | `pipeline_transformacao` | 03 |
| `om-porta-8585-iptables-reboot.md` | 8585 após reboot | 05 |
| `airbyte-frequencias-conexoes.md` | frequências de 15/10 | 02 |
| `sheets-serial-date-quebra-powerbi.md` | data serial, `DBT_filtro.py` | 03, 04, 06 |
| `airbyte-abctl-capacidade.md` | kind, memória, API, limpeza de pods | 02, 07 |
| `cronogramas-prefixo-maiusculo-quebra-stg.md` | prefixo de conexão | 02 |
| `cronogramas-mk-duplicado-powerbi.md` | MK duplicado | 06 |

## Comandos de ambiente (13/11/2026)

`docker ps -a`, `crontab -l`, `df -h /`, `free -g`, `git status`, `git ls-files`, `git log`.
