# mk829-meka-dw: o Data Warehouse interno da Mekatronik

> Este arquivo é o **roteador**: diz *o que ler antes de agir*. O conteúdo está nos capítulos de
> [`kb/`](kb/README.md). Padrão: "O Padrão da Casa" (`industrial-dataops/norma/padrao-da-casa`).

## O projeto em cinco linhas

- **Cliente:** a própria Mekatronik (projeto interno MK829). **Objeto:** DW de gestão: cronogramas, alocação, FlowUp, Agilizatronik, MMGP e planilhas Google, servido ao Power BI.
- **Quem executa:** Wollace Dantas (engenharia de dados), com a gestão do segmento Industrial DevOps/DataOps.
- **Pilha:** Airbyte (abctl/kind) → PostgreSQL 14 → dbt via Airflow 3.1 + Cosmos → Power BI e Planilha de Gestão; catálogo no OpenMetadata 1.11.5.
- **Onde roda:** VM Debian no Hyper-V, `192.168.0.157` (`meka-dw`, Tailscale `100.87.152.38`), usuário `mkadmin`.
- **Fase:** produção e sustentação (desde mai/2026); KB iniciada em 13/11/2026.

## Roteador

| se a tarefa é… | leia primeiro | e provavelmente também |
|---|---|---|
| **Entender o projeto, a pilha e o fluxo de dados** | [kb/00](kb/00-visao-geral.md) | [kb/01](kb/01-infraestrutura-e-rede.md) |
| **IP, porta, container, rede, Tailscale, "não conecta"** | [kb/01](kb/01-infraestrutura-e-rede.md) | [kb/07](kb/07-operacao-e-manutencao.md) |
| **Conexão Airbyte nova, frequência, sync travado, Pending** | [kb/02](kb/02-ingestao-airbyte.md) | [kb/07](kb/07-operacao-e-manutencao.md) (capacidade do kind) |
| **Cronograma novo (planilha mkXXX)** | [kb/02 §Cronogramas](kb/02-ingestao-airbyte.md#cronogramas-o-padrão-de-conexão) | [kb/06](kb/06-consumo-power-bi-e-sheets.md) (MK duplicado) |
| **DAG nova, agendamento, pipeline_transformacao, Cosmos** | [kb/03](kb/03-airflow-e-orquestracao.md) | [kb/04](kb/04-dbt-modelos-e-nomenclatura.md) |
| **Modelo dbt, camada raw/stg/int/mart, conversão de tipos, nomes** | [kb/04](kb/04-dbt-modelos-e-nomenclatura.md) | [`padrao_nomenclaturas.md`](padrao_nomenclaturas.md) |
| **BANCO_BI / alocação / colaborador_planilha** | [kb/04 §fct_banco_bi](kb/04-dbt-modelos-e-nomenclatura.md#fct_banco_bi-alocação-por-colaborador) | [kb/02](kb/02-ingestao-airbyte.md) |
| **OpenMetadata: catálogo, descrições, lineage, :8585 fora** | [kb/05](kb/05-openmetadata.md) | [kb/07](kb/07-operacao-e-manutencao.md) |
| **Erro no refresh do Power BI, Planilha de Gestão** | [kb/06](kb/06-consumo-power-bi-e-sheets.md) | [kb/04](kb/04-dbt-modelos-e-nomenclatura.md) |
| **Servidor caiu, reboot, disco, memória, limpeza** | [kb/07](kb/07-operacao-e-manutencao.md) | [kb/01](kb/01-infraestrutura-e-rede.md) |
| **Backup completo, migrar para outro servidor/datacenter** | [kb/07 §Backup](kb/07-operacao-e-manutencao.md#backup-completo-base-para-migrar-de-servidor) | [kb/01](kb/01-infraestrutura-e-rede.md) (IP espalhado nos arquivos) |
| **Portal web Meka-DW (Flask, :80/:443)** | [kb/08](kb/08-portal-meka-dw.md) | nenhum |
| **De onde veio cada afirmação, o que há na pasta** | [kb/09](kb/09-indice-fontes.md) | nenhum |
| **O que está aberto, o que diverge** | [kb/10](kb/10-pendencias.md) | nenhum |

## Regras invioláveis

1. **Prefixo de conexão de cronograma é minúsculo (`mkXXX_`).** Um único `MK921_` derrubou o stg de *todos* os cronogramas de 26 a 28/10/2026 ([kb/02](kb/02-ingestao-airbyte.md)).
2. **Um código MK só pode existir em uma planilha de cronograma.** Duplicata derruba o refresh inteiro do Power BI ("CostCenters.Id contains a duplicate value") ([kb/06](kb/06-consumo-power-bi-e-sheets.md)).
3. **Corrigir dado de planilha na planilha, nunca no banco.** `raw_*` é full refresh/overwrite: o próximo sync desfaz qualquer UPDATE/DELETE.
4. **DAG dbt nova: `dbt_deps=False` + `install_deps=False`, juntos.** Os containers não têm DNS externo garantido e o Cosmos recusa valores diferentes ([kb/03](kb/03-airflow-e-orquestracao.md)).
5. **DAG de transformação nova entra em `CADEIAS` do `pipeline_transformacao` e fica com `schedule=None`.** Senão ela corre fora de ordem com o refresh do Power BI.
6. **Não religar o Airbyte sem conter o kind.** Sem pausar o `workload-launcher`, a fila de syncs atrasados enche a memória em ~2 min e trava a VM ([kb/07](kb/07-operacao-e-manutencao.md)).
7. **Segredo nunca entra no git nem nesta KB.** `.env`, `sheetsproject-*.json`, o JWT do bot do OM em `dbt_project.yml` e `profiles/` ficam fora; aqui só o formato e o lugar.
8. **Commit sem coautoria de IA** (regra do Padrão da Casa). Trabalho em `dev-<nome>`, volta para `main` em até uma semana.

## Como não perder tempo

- **Sync "succeeded" com 0 linhas em ~30 min** = o pod ficou Pending por falta de memória, não "planilha vazia". Procure `replication-job` com idade de dias ([kb/02](kb/02-ingestao-airbyte.md)).
- **DAGs do OM com timeout após reboot**: o OM está de pé, falta a regra ACCEPT do Docker para 8585. `docker restart openmetadata_server` ([kb/05](kb/05-openmetadata.md)).
- **"Dag not found during start up"** logo após editar uma DAG é bug intermitente do Airflow: rode de novo.
- **Arquivos de `Backup_Airflow/dags` são do uid 50000**: o host nega escrita. Edite uma cópia e `docker cp` (ou `docker exec -i ... sh -c "cat > ..."`).
- **`curl localhost:80` no servidor pode dar 404**: teste o portal pelo IP/de fora.
- **Timeout de cliente Windows para 192.168.0.x** é rota do Tailscale (accept-routes), nunca senha ([kb/01](kb/01-infraestrutura-e-rede.md)).
- **Usuário do Postgres do DW é `admin`, database `postgres`** (não `mkdw_db`); o `profiles.yaml` com `dbt_user` está desatualizado.
- **Uma coluna de data virou texto** = um valor fora do padrão DD/MM/AAAA na planilha ([kb/06](kb/06-consumo-power-bi-e-sheets.md)).

## Skills, comandos e convenções

```bash
# Airbyte (kind dentro do Docker)
kubectl --kubeconfig ~/.airbyte/abctl/abctl.kubeconfig get pods -n airbyte-abctl
# Airflow: http://192.168.0.157:8086 · containers backup_airflow-airflow-*
docker exec backup_airflow-airflow-worker-1 curl -s http://192.168.0.157:8585/api/v1/system/version
# Postgres do DW
docker exec -it postgres_db psql -U admin -d postgres
# Manutenção (cron do mkadmin)
tail manutencao/retencao_logs.log manutencao/limpeza_pods_airbyte.log; tail manutencao/uso_disco.csv
```

Convenções: nomes em snake_case e camadas `raw_/stg_/int_/mart_/audit_` ([`padrao_nomenclaturas.md`](padrao_nomenclaturas.md)). Datas da KB em DD/MM/AAAA. Memórias do Claude deste servidor em `~/.claude/projects/-home-mkadmin/memory/`: são a fonte de boa parte desta KB e continuam valendo como diário. Ao mudar algo relevante, atualize o capítulo e a nota de consolidação em [`kb/README.md`](kb/README.md).
