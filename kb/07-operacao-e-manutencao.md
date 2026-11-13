# 07 · Operação e manutenção

## Rotinas automáticas (crontab do `mkadmin`)

| quando | script | o que faz | log |
|---|---|---|---|
| 03:30 diário | `manutencao/retencao_logs.sh` | logs do Airflow > 30 dias (via `docker exec`, uid 50000); `job-logging` do Airbyte > 60 dias; grava uma linha em `manutencao/uso_disco.csv` | `manutencao/retencao_logs.log` |
| a cada 15 min | `manutencao/limpeza_pods_airbyte.sh` | só pods sem ownerReferences: apaga Succeeded/Failed > 30 min e check/discover/spec > 1 h; `replication-job` > 12 h só gera **ALERTA** no log | `manutencao/limpeza_pods_airbyte.log` |

Também em `manutencao/`: `vigia_memoria_airbyte.sh` (não está no cron em 13/11/2026; conteúdo não
detalhado nesta consolidação).

`uso_disco.csv` (colunas: `data, disco_usado_mb, disco_livre_mb, dw_mb, airbyte_db_mb, logs_airflow_mb,
logs_airbyte_mb`) é a régua do crescimento real. Em 13/11/2026: 80 GB livres, DW 7,2 GB, banco do Airbyte
30,7 GB (subiu de 24,5 para 30,7 GB entre 08 e 13/11), logs do Airbyte 13,2 GB.

## Disco

Diagnóstico de 08/10/2026 (232 GB, 47 GB livres, crescimento ~7,8 GB/mês → cheio em ~abr/2027):

| consumidor | tamanho/taxa | situação |
|---|---|---|
| logs do dag-processor do Airflow | 29 GB, ~4,1 GB/mês | retenção 30 d + `min_file_process_interval` 600 |
| `job-logging` do Airbyte | 19 GB, ~2,3 GB/mês | retenção 60 d |
| banco interno do Airbyte | temporal ~14 GB (retenção 30 d, estável); db-airbyte cresce ~0,45 GB/mês (jobs nunca expurgados) | aberto |
| `raw_voe` | 5,6 GB dos 7,1 GB do DW, congelado; 29 tabelas `raw_voe.raw_voefct_*` (1,6 GB) sobras de 22/06 | aberto |
| volume `mkadmin_db_data` | DW antigo | remover só após `pg_dump` |
| cache de build | — | não limpar antes de fixar versões no Dockerfile |

Feito: removida a cópia `mk829-meka-dw/.airbyte` (11 GB) e imagens do Airbyte no host (o kind tem cópia).
Crescimento estimado após as ações: ~0,9 GB/mês (+0,7 se o VOE voltar). O kubelet do kind tem eviction
desligado: o limite real é 100% do disco. **Nunca remover a imagem `f226345927d7`** (kindest/node).

Fonte: memória `disco-servidor-crescimento`.

## Memória e o Airbyte

O kind não tinha teto e derrubou a VM duas vezes:

- **06/11/2026**: host caiu (sem shutdown limpo, como em 14/10) e voltou às 07:31; load ~124, tempestade de
  syncs atrasados, `airbyte-abctl-server` em CrashLoopBackOff (473 restarts). Fix: com o load já baixo,
  `kubectl delete pod` do server.
- **13/11/2026**: rede e ssh caíram por OOM do kind. Aplicado `docker update --memory 10g --memory-swap 10g`
  (persiste no container). Ao religar, os syncs atrasados encheram os 10 GB em ~2 min → **livelock dentro
  do cgroup** (sem OOM kill, kubectl pendurado, PSI full 86%, load 700) → `docker stop`.

**Lição:** o teto do container não basta, porque o kubelet do kind enxerga a memória toda do host e agenda
pods além do teto. **Teto em vigor em 13/11/2026 ~15h: 12 GiB** (`docker inspect`: Memory = MemorySwap =
12884901888). A memória registrava 10g e depois 14g; ver [10 A7](10-pendencias.md).

Sem o Airbyte, a VM usa ~7 GB (Airflow, OM, ES, VS Code, k3s ocioso ~0,5 GB).

### Religar o Airbyte com segurança (roteiro inferido do incidente de 13/11; validar na próxima vez)

1. Confirmar o teto: `docker inspect airbyte-abctl-control-plane --format '{{.HostConfig.Memory}}'`.
2. `docker start airbyte-abctl-control-plane`.
3. Assim que o API server responder (~15 s), **escalar o workload-launcher para 0**:
   `kubectl --kubeconfig ~/.airbyte/abctl/abctl.kubeconfig -n airbyte-abctl scale deploy/<workload-launcher> --replicas=0`
   (confira o nome com `get deploy`).
4. Limpar pods Completed/Unknown acumulados (havia ~1.400 em 13/11).
5. Limitar o paralelismo (`MAX_SYNC_WORKERS`, hoje 5) e só então devolver o launcher a 1, observando `free`.

## Depois de uma queda ou reboot: checklist

1. Rede: `ip a show eth0` → `192.168.0.157`? ([01](01-infraestrutura-e-rede.md))
2. `docker ps -a`: o que está `Exited`? OM, portal e Caddy não voltam sozinhos se foram parados à mão.
3. Airbyte: siga o roteiro acima; procure `replication-job` em `Unknown`/com idade de dias.
4. OM: `docker exec backup_airflow-airflow-worker-1 curl http://192.168.0.157:8585/api/v1/system/version`;
   timeout → `docker restart openmetadata_server` ([05](05-openmetadata.md)).
5. Airflow: o `pipeline_transformacao` voltou a dar success?
6. Portal: abrir `http://192.168.0.157` **de fora** do servidor.

## Permissões do Claude neste servidor

O auto mode do Claude bloqueia: cancelar jobs do Airbyte, alterar conexões/tabelas do Airbyte, `docker
restart` do OM. Nesses casos o Claude prepara o comando e **o usuário executa** (memórias
`airbyte-abctl-capacidade`, `om-porta-8585-iptables-reboot`, `cronogramas-prefixo-maiusculo-quebra-stg`).
