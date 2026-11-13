# 08 · Portal Meka-DW

## O que é

Portal web (Flask) do MK829 em **`/home/mkadmin/meka-dw-portal/portal/`**, **fora deste repositório**.
Replicado do modelo `/home/mkadmin/Portal/portal`, com a identidade visual do kit `meka-brand-main`.

Conteúdo: a documentação deste repo (docs 00–04: readme, nomenclaturas, airbyte, airflow/dbt/om), o
**Treinamento Airbyte** (trilha Fundamentos = Fluxo 1 Sheets → Postgres; trilha Operação = Fluxo 2 + boas
práticas), Plataformas com status ao vivo (Airbyte 8000, PostgreSQL, Airflow 8086, OpenMetadata 8585), Mapa
do Sistema e export em PDF.

> O treinamento ensina o Fluxo 2 (Postgres → Sheets pelo Airbyte), que foi **aposentado em 14/10/2026**
> ([06](06-consumo-power-bi-e-sheets.md)). Ver [10](10-pendencias.md).

## Deploy

```bash
cd /home/mkadmin/meka-dw-portal/portal
docker compose up -d            # sobe
docker compose up -d --build    # depois de editar código/template (templates são embutidos na imagem)
```

| serviço | imagem | portas | papel |
|---|---|---|---|
| `meka-dw-portal` | `portal-portal` | 80, 8090 | app Flask |
| `meka-dw-caddy` | `caddy:2` | 443, 8443 | HTTPS com CA interna (`tls internal`), reverse proxy; `caddy/Caddyfile` atende `meka-dw`, `meka-dw.mekatronik.com.br`, `localhost` |

`restart: unless-stopped`: se alguém der `docker stop`, ele **não** volta no boot. Em 13/11/2026 os dois
estavam parados.

## Acesso e login

- Na LAN: **`http://192.168.0.157`** (sem porta). O nome `meka-dw` só resolve para quem está no Tailscale
  (MagicDNS → 100.87.152.38) ou por LLMNR/mDNS.
- Login por e-mail + senha: 6 e-mails em `auth.py` (`ALLOWED_USERS`), senha compartilhada em
  `PORTAL_ADMIN_PASSWORD` (`.env` do portal).
- `curl localhost:80` no próprio servidor pode dar 404 (loopback/OUTPUT): teste sempre pelo IP.

**Portas 80/443, resolvido em 16/07/2026:** o `svclb-traefik` do k3s do host sequestrava 80/443 no IP da
LAN e devolvia 404. Traefik desligado por `/etc/rancher/k3s/config.yaml` (`disable: [traefik]`) + `systemctl
restart k3s`. Rollback: apagar o config e reiniciar o k3s.

## SSO Google: pronto, esperando DNS

- `GOOGLE_CLIENT_ID`/`SECRET` no `.env` (comentar/descomentar liga e desliga).
- O botão "Entrar com Google" só aparece em HTTPS (`auth.py`: `request.is_secure`); `ProxyFix` no `app.py`
  garante o `redirect_uri` em https.
- O Google exige FQDN + https: só funciona em `https://meka-dw.mekatronik.com.br`.
- **Falta o registro A** `meka-dw.mekatronik.com.br → 192.168.0.157` (DNS da mekatronik.com.br na
  DreamHost, ou DNS interno). CA raiz do Caddy para distribuir por GPO: `caddy/root-ca.crt`.

Fonte: memória `portal-meka-dw`.
