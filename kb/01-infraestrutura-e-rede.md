# 01 · Infraestrutura e rede

## A máquina

| item | valor | fonte |
|---|---|---|
| Host físico | Windows Server 2025, Hyper-V | `readme.md` |
| VM | Debian (kernel 6.12), hostname `meka-dw`, usuário `mkadmin` | ambiente |
| Memória | **20 GB** desde 13/11/2026 (antes 16 GB) | memória `airbyte-abctl-capacidade` |
| Disco | `/dev/sda2` 232 GB; 79 GB livres em 13/11/2026 | `df` |
| IP LAN | **192.168.0.157 fixo** no `eth0` (MAC 00:15:5d:e6:91:01), gateway 192.168.0.1 | memória `infra-openmetadata-postgres` |
| IP Tailscale | **100.87.152.38** (MagicDNS `meka-dw`) | memória `tailscale-rota-pve-quebrada` |

**IPs obsoletos:** `192.168.0.89` → `192.168.0.156` → `192.168.0.157` (atual desde ~16/06/2026). Toda
migração de IP já fez a ingestão no OM falhar em silêncio porque algum arquivo ficou com o IP antigo.
Ao migrar, procurar o IP em `dbt_project.yml`, `openmetadata.yaml`, `profiles/profiles.yaml`,
`ingest_postgres_metadata.py` e `om_lineage_*.py`. O legado `dbt/meu_projeto/` ainda tem `.89`, mas
nenhuma DAG usa.

### Configuração de rede (13/11/2026)

A VM chegou a ir para a `10.10.0.x` (DHCP atrás do roteador Proxmox 10.10.0.1 = 192.168.0.48) e saiu do
alcance do Wi-Fi. A equipe devolveu o `eth0` ao switch da 192.168.0.x e o IP fixo foi reconfigurado:

- `/etc/network/interfaces` (backup `.bak_20261113_1238`): `.157` estático no `eth0`.
- DNS no drop-in `/etc/systemd/resolved.conf.d/meka-dw.conf` (192.168.0.1, 8.8.8.8; mDNS+LLMNR). O
  `resolved.conf` principal tinha `DNS=` fora da seção `[Resolve]` e era ignorado.
- `/etc/hosts`: `192.168.0.157 meka-dw`. Na LAN, o nome resolve só por LLMNR/mDNS (`meka-dw.local`);
  nenhum DNS do roteador tem o registro.
- `eth1` (…91:06) fica DOWN, na 10.10.0.x. O DHCP da 192.168.0.x tinha dado o `.170`.

## Containers e portas

| serviço | container | porta no host | sobe por | restart |
|---|---|---|---|---|
| Postgres do DW | `postgres_db` (postgres:14) | **5432** | `docker-compose.yaml` da raiz | always |
| Airflow API/UI | `backup_airflow-airflow-apiserver-1` (Airflow 3.1.5) | **8086** | `Backup_Airflow/docker-compose-airflow.yaml` | — |
| Airflow worker/scheduler/triggerer/dag-processor | `backup_airflow-airflow-*` | — | idem | — |
| Banco do Airflow / broker | `postgres_airflow` (pg16), `backup_airflow-redis-1` | — | idem | — |
| Flower | (perfil do compose) | 5555 | idem | — |
| Airbyte | `airbyte-abctl-control-plane` (kindest/node v1.32.2) | **8000** | `abctl` | — |
| OpenMetadata | `openmetadata_server`, `openmetadata_elasticsearch`, `openmetadata_postgresql` | **8585** (API/UI), 8586 | `openmetadata-1.11.5/docker-compose-postgres.yml` | always |
| Portal | `meka-dw-portal`, `meka-dw-caddy` | **80**, 8090, **443**, 8443 | `/home/mkadmin/meka-dw-portal/portal/docker-compose.yml` | unless-stopped |

Redes Docker: `meka-dw-net` (externa: DW e Airflow) e `openmetadata-1115_meka-dw-net` (OM). O Airflow
fala com o OM pelo IP da LAN `192.168.0.157:8585`, atravessando bridges. É isso que quebra após
reboot ([05](05-openmetadata.md)).

**Estado em 13/11/2026 ~15h:** OM, Elasticsearch, Postgres do OM, portal e Caddy estavam **parados**
(Exited ~3 h antes, na contenção da queda do Airbyte daquele dia). Ver [10](10-pendencias.md).

### O que não confundir

- **k3s no host**: resíduo sem apps (coredns, metrics-server, local-path). O Traefik dele foi desligado
  em 16/07/2026 (`/etc/rancher/k3s/config.yaml` com `disable: [traefik]`) porque sequestrava 80/443.
  **O Airbyte não roda nele**, roda no kind ([02](02-ingestao-airbyte.md)).
- **Imagem `f226345927d7` sem tag** = `kindest/node` do Airbyte. **Nunca remover.**
- **Volume `mkadmin_db_data`** = banco DW antigo (snapshot de 06/05/2026), apontado pelo
  `/home/mkadmin/docker-compose.yaml`. Não é o DW atual (o atual é o volume `db_data` do compose do repo).

## Postgres do DW

- Usuário do container `admin`; **database de dados é `postgres`**, não `mkdw_db` (que é o `POSTGRES_DB`
  do compose). Senha em `PG_PASSWORD` no `.env`.
- `pg_hba.conf`: `host all all all scram-sha-256` → aceita qualquer origem com senha. **Timeout de
  conexão nunca é permissão, é rota.**
- Conexão do Airflow: `mekadw_airflow`. O `profiles/profiles.yaml` com `dbt_user/dbt_pass` está
  desatualizado e não autentica; as DAGs usam o profile mapping do Cosmos.

## DNS dentro dos containers do Airflow

O host usa o resolver do Tailscale (`100.100.100.100`), inalcançável de dentro da bridge. Por isso os
containers do Airflow têm `dns: [8.8.8.8, 1.1.1.1]` no bloco `x-airflow-common` do compose (desde
16/06/2026). Após mudar o compose é preciso **recriar** os containers (`up -d --no-deps <svc>`).
Validar: `docker exec backup_airflow-airflow-worker-1 getent hosts pypi.org`.

## Tailscale: a rota 192.168.0.0/24 quebrada

Um nó da tailnet anuncia `192.168.0.0/24` como subnet route sem conseguir entregar (o `pve` em
13/08/2026; o `ServerDevops` em 31/08/2026; confira com `tailscale status --json`, campo `PrimaryRoutes`).
Cliente com `--accept-routes=true` (padrão do Tailscale para Windows) manda todo tráfego para 192.168.0.x
para o túnel, onde morre. O sintoma é **timeout**, e o servidor não registra tentativa nenhuma.

- **Recorre em toda máquina Windows nova** que aponta o Power BI para `192.168.0.157`.
- Diagnóstico: `tracert -d 192.168.0.157`; salto 1 em `100.x` = rota sequestrada.
- Correção: na LAN, `tailscale set --accept-routes=false`; ou (preferido em arquivo de dashboard) usar
  o IP Tailscale `100.87.152.38`, que funciona dentro e fora da LAN.
- O `meka-dw` tem `--accept-routes=false`; o aviso "Some peers are advertising routes…" é esperado.

Fonte: memória `tailscale-rota-pve-quebrada`.
