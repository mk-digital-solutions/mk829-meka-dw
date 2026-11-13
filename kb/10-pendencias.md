# 10 · Pendências, divergências e decisões em aberto

Contradição entre fontes fica aqui com **as duas versões**, não é resolvida no chute. Pendência resolvida
sai daqui e vira frase afirmativa no capítulo do assunto.

---

## 0 · Urgente (13/11/2026)

### 0.1 OpenMetadata e portal parados

Em 13/11/2026 ~15h, `openmetadata_server`, `openmetadata_elasticsearch`, `openmetadata_postgresql`,
`meka-dw-portal` e `meka-dw-caddy` estavam `Exited` havia ~3 h (contenção da queda do Airbyte). Enquanto
estiverem parados, as DAGs do OM falham e o portal fica fora do ar. Subir primeiro o Postgres do OM e o ES,
depois o server; o portal pelo `docker compose up -d`. Observar a memória (VM com 20 GB, ~7 GB livres na
hora).

### 0.2 Código de produção fora do git

Rodam em produção sem estar versionados: `pipeline_transformacao.py`, `sheets_planilha_gestao.py`,
`dbt_atividades.py`, `macros/` inteira (incluindo `conversao_tipos.sql`), `dbt_project.yml`, `packages.yml`,
`fct_banco_bi_colaboradores.sql`, `manutencao/`, `handover (1).md`. E `DBT_filtro.py` (a DAG oficial
`dbt_entregas`) está **no `.gitignore`**. Além disso, 43 arquivos versionados estão modificados sem commit
na `main` (DAGs, modelos, Dockerfile, airflow.cfg, deploy.yml). Um disco perdido leva junto o pipeline.
Pelo Padrão da Casa ("uma branch encalhada produz conclusões erradas sobre o estado do projeto"), isso é a
pendência mais cara do repositório.

**Antes de versionar `dbt_project.yml`:** tirar o JWT do bot do OM das `vars` (passar para variável de
ambiente, `env_var()`) e **rotacionar** o token, que não expira.

## A · Divergências entre fontes

| # | assunto | versão 1 | versão 2 | valendo |
|---|---|---|---|---|
| A1 | Onde roda o Airbyte | `readme.md`: "instalação via Kubernetes (K3S)" | memórias: abctl/kind no container `airbyte-abctl-control-plane`; k3s do host sem apps | kind |
| A2 | Agendamento das DAGs de planilhas | `documentacao_airflow_dbt_om.md` §3.1: `0 1`, `15 1`, `30 1 * * *` | código: `schedule=None`, disparadas pelo `pipeline_transformacao` (15/10) | pipeline |
| A3 | Frequência padrão do Airbyte | `airbyte.md`: "a cada 6 horas" (Fluxo 1), 12 h (Fluxo 2) | memória de 15/10: 1 h para cronogramas e alocação; Fluxo 2 aposentado | memória |
| A4 | Schema raw | `padrao_nomenclaturas.md`: `raw_airbyte`, tabelas `fonte_entidade` | realidade: `raw_cronogramas`, `raw_planilhas`… com nome de stream | realidade; decidir se o padrão muda |
| A5 | Horário da `sheets_planilha_gestao` | memória de 14/10: 01:30 e 13:30 UTC | código: `schedule=None`, última etapa da cadeia de cronogramas (hora em hora) | código |
| A6 | Ritmo da Planilha de Gestão | `handover (1).md`: PoC a cada 5 min | DAG em produção: a cada 1 h | produção; o handover é a PoC |
| A7 | Teto de memória do kind | memória, 13/11: `docker update --memory 10g`; trecho final: "teto atual: 14g" | `docker inspect` às ~15h de 13/11: **12 GiB** | 12 GiB (medido); confirmar se foi intencional |
| A8 | Database do DW | compose: `POSTGRES_DB: mkdw_db` | dados reais em `postgres`; DAGs usam `dbname: postgres` | `postgres` |
| A9 | Treinamento do portal | ensina o Fluxo 2 (Airbyte → Sheets) | Fluxo 2 aposentado em 14/10 | atualizar o treinamento |

## B · Pendências técnicas

1. **Correção definitiva da 8585**: ligar o Airflow à rede `openmetadata-1115_meka-dw-net` e usar
   `http://openmetadata_server:8585` nas DAGs ([05](05-openmetadata.md)).
2. **Lineage de agilizatronik e cronogramas sem DAG** (script one-off de 27/05/2026); criar `om_lineage_dbt`.
3. **`ingest-dbt` não cria lineage**: motivo não diagnosticado (olhar o log do `ingestion_final_v6_clean`).
4. **Capacidade do Airbyte**: escalonar horários, reduzir frequência das não críticas, limitar paralelismo;
   expurgar jobs antigos do db-airbyte (~0,45 GB/mês; 24,5 → 30,7 GB entre 08 e 13/11/2026, o que pede
   remedição). Validar o roteiro de religar ([07](07-operacao-e-manutencao.md)).
5. **Fixar versões** no `Dockerfile` (cosmos 1.14.1, dbt-core 1.11.8, dbt-postgres 1.10.0) e só depois
   limpar o cache de build.
6. **Volume `mkadmin_db_data`**: `pg_dump` e remover; o `/home/mkadmin/docker-compose.yaml` tem senha em
   texto puro.
7. **VOE**: decidir se volta. Se não, arquivar e dropar `raw_voe` (5,6 GB) e as sobras `raw_voe.raw_voefct_*` (1,6 GB).
8. **`dbt_entregas` pausada** e **`dbt_atividades`** rodando às 03h fora do pipeline: decidir o papel
   das duas (despausar, incorporar ao pipeline ou aposentar).
9. **Colunas `FAT. PESSOAL PRD.` / `SERV.`**: renomear na origem para documentar no OM.
10. **`profiles/profiles.yaml` desatualizado** (dbt_user/dbt_pass não autentica): corrigir ou remover.
11. **`vigia_memoria_airbyte.sh`** existe mas não está no cron: documentar ou remover.
12. **Rascunhos no diretório de DAGs** (`ingesting.py`, `Run_Timestamp.py`, `Teste_Gera_Doc.py`) são
    parseados pelo Airflow: mover para fora de `dags/`.

## C · Decisões de terceiros

1. **Registro DNS `meka-dw.mekatronik.com.br → 192.168.0.157`** (DreamHost ou DNS interno): destrava o
   acesso por nome e o SSO Google do portal ([08](08-portal-meka-dw.md)).
2. **Rota 192.168.0.0/24 na tailnet**: quem administra a tailnet precisa parar de anunciar a rota a
   partir de um nó que não entrega (hoje `ServerDevops`), ou corrigir o encaminhamento ([01](01-infraestrutura-e-rede.md)).
3. **Uso de `kb-index.md` global** (Padrão da Casa, roteamento entre projetos): este servidor não tem
   `~/.claude/kb-index.md`, `kb-status.sh` nem `kb-init.sh`; decidir se o MK829 entra no índice da casa.
