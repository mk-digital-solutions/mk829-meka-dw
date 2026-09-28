# 01 · Arquitetura e ambiente

> Tudo aqui está no **passado**. Não há garantia de que a VM, o container ou o
> Airbyte ainda existam — nenhuma fonte desta pasta registra desmobilização, e
> nenhuma registra que continua de pé. **Confirme antes de assumir qualquer
> coisa como viva.**

## A infraestrutura, como documentada

| camada | o que era | fonte |
|---|---|---|
| Servidor físico | "Mekatronik" (servidor da casa) | `readme.md` |
| SO do host | Windows Server 2025 | `readme.md` |
| Virtualização | Hyper-V | `readme.md` |
| VM | Linux Debian | `readme.md` |
| IP da VM | **192.168.0.168** | `readme.md`, `playbook.html` |
| Hostname do Postgres no Airbyte | `Meka-dw` | `airbyte.md`, `playbook.html` |
| Banco | PostgreSQL 14 em Docker, container `postgres_db`, porta 5432 exposta no host | `docker-compose.yaml` |
| Ingestão | Airbyte OSS, instalado via `abctl` sobre **K3S** | `readme.md`, `playbook.html` |

**Rede interna 192.168.0.x — não há VPN, túnel ou acesso externo documentado.**
Se o ambiente for reativado, presuma que só se chega nele de dentro da rede da
Mekatronik.

## O `docker-compose.yaml` — leia antes de rodar

O arquivo provisiona um único serviço: `postgres:14`, banco `mkdw_db`, usuário
`admin`, volume nomeado `db_data`, `restart: always`, porta **5432 publicada no
host** (sem bind em 127.0.0.1 — qualquer máquina da LAN alcançava o banco).

**Dois problemas conhecidos, ambos ainda presentes no arquivo:**

1. 🔴 **O arquivo contém marcadores de conflito de merge não resolvidos**
   (`<<<<<<< HEAD` / `=======` / `>>>>>>> 848108c1…`) no bloco
   `POSTGRES_PASSWORD`. **Ele não é um YAML válido — `docker compose up` falha.**
   Está assim desde 15/04/2026 e nunca foi corrigido. Se você for reaproveitar
   este compose, resolver o conflito é o passo zero.
2. 🔴 **Senha do Postgres em texto plano** no lado `HEAD` do conflito, e
   portanto **no histórico do repositório publicado no GitHub**. A senha em si
   não está reproduzida nesta KB de propósito — ela está no arquivo e no
   histórico git. Ver [05-pendencias §4](05-pendencias.md).

O lado correto do conflito é `POSTGRES_PASSWORD: ${PG_PASSWORD}`, lido do
`.env` (que está no `.gitignore` e contém uma única chave, `PG_PASSWORD`).

## O `abctl` — armadilha silenciosa

`abctl` é o instalador oficial do Airbyte. **O arquivo `abctl` desta pasta tem
9 bytes e contém literalmente o texto `Not Found`.** É um download de release
que falhou (404 salvo em arquivo) e foi commitado assim, sem `chmod +x` e sem
ninguém perceber. Ele nunca funcionou.

Consequência prática: **`readme.md` e `playbook.html` descrevem o `abctl` como
um componente do projeto, e ele nunca esteve aqui.** Quem for reinstalar o
Airbyte precisa baixar o binário do repositório oficial do Airbyte, não usar
este arquivo.

## Os dois fluxos Airbyte que existiram

Documentados passo a passo em [`airbyte.md`](../airbyte.md) (o manual completo,
com telas e troubleshooting) e replicados em [`playbook.html`](../playbook.html).

### Fluxo 1 — Google Sheets → PostgreSQL

- Source `google_sheets_MKXXX`, autenticação por **Service Account Key (JSON)**
- Row Batch Size 200
- Destination `postgres_mkdw`, schema `raw_airbyte`, SSL Mode `require`
- Sync **Full Refresh — Overwrite**, a cada 12 h

### Fluxo 2 — PostgreSQL → Google Sheets ("PLANILHA_GESTÃO")

- Volta para uma planilha de gestão, um stream por aba
- Também Full Refresh — Overwrite, a cada 12 h

⚠️ **Full Refresh — Overwrite nos dois sentidos.** Edição manual, tanto na
tabela do Postgres quanto na planilha de gestão, é apagada no próximo sync. Isso
está avisado em ambos os documentos e é a pegadinha número um do desenho.

⚠️ **O Fluxo 2 fecha um ciclo Sheets → Postgres → Sheets.** Se alguma planilha
de origem do Fluxo 1 for também destino do Fluxo 2, o desenho tem um laço. Nada
nas fontes diz se isso chegou a acontecer — mas é o primeiro lugar onde eu
olharia se alguém relatar "a planilha zerou sozinha".

## O que as atas de reunião acrescentam (ingestão de e-mail, 24/09/2026)

As atas abaixo foram geradas automaticamente (Gemini, Google Meet) e trazem o
aviso de que "podem conter erros". Nada daqui foi verificado no ambiente.

| o quê | detalhe | fonte |
|---|---|---|
| **Power BI Gateway** | Instalado no servidor da Mekatronik para o Power BI acessar o PostgreSQL. O fluxo de consumo validado era Google Sheets (conta de serviço) → Airbyte → PostgreSQL → Power BI via Gateway | e-mail, thread 1862559850459943952, 15/04/2026 (ata "MK829 - Validação Entrega 01") |
| **Valores nulos no PostgreSQL** | Atribuídos a possível limitação do Airbyte com cadeias complexas de fórmulas nas planilhas de origem. Sem solução registrada na data | idem |
| **Frequência do sync** | Ajustada de 12 h para **1 h**, para testes rápidos. Nenhuma fonte diz se voltou a 12 h; a tabela do Fluxo 1 acima reflete o `airbyte.md` de 09/04 | idem |
| **Cadastro de cronogramas** | Cada cronograma novo era cadastrado **manualmente** no Airbyte, "por enquanto". Levantou-se a necessidade de mapear os links dos cronogramas no PostgreSQL, com a API do Airbyte como possível futuro produto de dados | idem |
| **Credenciais e treinamento adiados** | Alteração de credenciais e treinamento da equipe adiados para julho/2026, por instabilidade do servidor e pendências de infraestrutura. Nenhuma fonte diz se a alteração aconteceu; a rotação do [05 §4](05-pendencias.md) continua aberta | idem |
| **Requisitos de segurança** | Arquitetura em medalhão com adesão à LGPD, Single Sign-On e autenticação multifator, declarados na apresentação do portal | e-mail, thread 1871447900068149394, 22/07/2026 |
| **Rede "Eng-meka"** | O hub do projeto era acessível ao time de gestão pela rede "Eng-meka". Coerente com a ausência de acesso externo documentado acima | e-mail, thread 1871536062366461551, 23/07/2026 |
| **Licença do Windows Server** | Em 18/09/2026, Wollace marcou a reunião "Tomada de decisão - Licença windows server Meka-DW" para **05/01/2027**, com Hugo e José Almeida. A decisão estava pendente nessa data. *Inferência (do convite):* o host Windows Server não tinha sido desmobilizado até 18/09, e a questão do licenciamento sobrevive ao encerramento do MK829 | e-mail, thread 1876667899637299617, 18/09/2026 |

## A publicação do playbook

`.github/workflows/deploy.yml` publica **`playbook.html` como `index.html` no
GitHub Pages** a cada push em `main`. Repositório:
`github.com/mk-digital-solutions/mk829-meka-dw`.

**Isso significa que o playbook é (ou foi) público na web.** Ele não contém
senha nem URL de planilha — verifiquei —, mas contém o IP interno
`192.168.0.168`, a topologia do servidor e os nomes dos sistemas internos da
casa (Flowup, Agilizatronik, MMGP, VOE). Se o Pages ainda estiver ligado, vale
decidir se isso deve continuar público.
