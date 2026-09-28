# 04 · Índice de fontes e inventário completo

## Inventário — nenhum arquivo ficou de fora

A pasta tem **10 arquivos versionáveis, 58,4 KB** (fora `.git/` e fora desta
`kb/`). Todos os 10 foram abertos. Nada é binário, nada é opaco, nada foi
pulado.

| # | arquivo | tam. | mtime | estado | o que é |
|---|---|---:|---|---|---|
| 1 | `readme.md` | 1,8 KB | 16/04/2026 | **lido** | descrição do projeto, ambiente, fluxo e "próximos passos". ⚠️ escrito no presente |
| 2 | `airbyte.md` | 10,5 KB | 09/04/2026 | **lido** | manual passo a passo dos 2 fluxos Airbyte + troubleshooting |
| 3 | `padrao_nomenclaturas.md` | 11,5 KB | 16/04/2026 | **lido** | padrão de nomenclatura do DW + catálogo de 7 fontes / 24 tabelas raw |
| 4 | `playbook.html` | 28,8 KB | 16/04/2026 | **parseado** (HTML → texto, 445 linhas úteis) | playbook interativo. HTML autocontido: 1 bloco `<style>` de 2,9 KB, **zero `<script>`**, zero asset externo. Conteúdo ≈ união de `readme.md` + `airbyte.md` + `padrao_nomenclaturas.md` |
| 5 | `docker-compose.yaml` | 454 B | 15/04/2026 | **lido** | PostgreSQL 14. 🔴 **com conflito de merge não resolvido e senha em claro** |
| 6 | `abctl` | 9 B | 09/04/2026 | **lido** | contém só o texto `Not Found`. Download 404 commitado por engano |
| 7 | `.env` | 44 B | 09/04/2026 | **lido, valor não copiado** | uma chave: `PG_PASSWORD=…`. Está no `.gitignore` |
| 8 | `.gitignore` | 64 B | 09/04/2026 | **lido** | ignora `.airbyte/`, `.kube/`, `.vscode-server/`, `*.log`, `*.swp`, `.env`, `data/`, `pgdata/` |
| 9 | `.github/workflows/deploy.yml` | 891 B | 09/04/2026 | **lido** | publica `playbook.html` como `index.html` no GitHub Pages a cada push em `main` |
| 10 | `queries/dataset_apontamentos_diario.sql` | 5,6 KB | 30/04/2026 | **lido** | dataset de apontamentos diários. **Não está no índice do git** |

### Contagem por extensão (fecha em 10)

| extensão | qtd |
|---|---:|
| `.md` | 3 |
| `.html` | 1 |
| `.sql` | 1 |
| `.yaml` | 1 |
| `.yml` | 1 |
| `.env` | 1 |
| `.gitignore` | 1 |
| sem extensão (`abctl`) | 1 |
| **total** | **10** |

### Diretório declarado e não percorrido

| dir | arquivos | tam. | por quê |
|---|---:|---:|---|
| `.git/` | 145 | 2,0 MB | metadados de versionamento. **Não foi percorrido objeto a objeto** — foram lidos apenas os arquivos de texto de metadado (`logs/HEAD`, `refs/*`, `config`, `FETCH_HEAD`, `ORIG_HEAD`, `COMMIT_EDITMSG`, e `index` via `strings`), que são a fonte da seção Git abaixo. Nenhum comando `git` foi executado |

Não há `node_modules/`, `.venv/`, `__pycache__/`, `dist/`, `data/` nem
`pgdata/` — os quatro últimos estão no `.gitignore` mas nunca existiram aqui.
**Não há `.claude/` nesta pasta e não há histórico de sessão em
`~/.claude/projects/-home-hugof-mk829-meka-dw/`: esta é a primeira vez que um
agente trabalha aqui.**

---

## Qual arquivo tem o quê

| se você precisa de… | o arquivo original é |
|---|---|
| Topologia do servidor, VM, IP | `readme.md` §Ambiente · `playbook.html` |
| Passo a passo de configurar o Airbyte (telas, campos) | `airbyte.md` — é o mais detalhado |
| Troubleshooting de sync | `airbyte.md` §Troubleshooting Rápido |
| Padrão de schema, tabela, coluna, arquivo SQL | `padrao_nomenclaturas.md` |
| Catálogo das 7 fontes e 24 tabelas raw previstas | `padrao_nomenclaturas.md` §3 |
| Regra de horas úteis, feriado, meio-expediente | `queries/dataset_apontamentos_diario.sql` |
| Schema do Flowup replicado (`membro`, `reportagem`, `projeto`, `cargo`, `carga_horaria`, `feriado`) | idem |
| Como o playbook vai ao ar | `.github/workflows/deploy.yml` |

## Fontes fora desta pasta que a KB usou

| fonte | o que trouxe |
|---|---|
| `~/flowup/feedback-mensal/frentes.json`, bloco `MK829` | receita R$ 0, janela até set/2026, encerramento no prazo, realocação do Wollace em 01/09 |
| `~/flowup/feedback-mensal/frentes.json`, bloco `despesas.wollace_ate_agosto` | a pendência contábil: R$ 30.000 estimados, R$ 8.262,55 identificáveis, o bloqueio dos R$ 143.996 de folha sem colaborador |
| `~/flowup/feedback-mensal/frentes.json`, bloco `wollace_meka_dw` | 784,7 h do Wollace no MK829 (13,3% do segmento); reclassificação conservadora R$ 30.507,76 / cheia R$ 39.877,42 |
| `~/flowup/resultados-mes/resultado-devops-mes-2026-*.json` | horas mês a mês por pessoa (a tabela do [00](00-visao-geral.md)) |
| `~/flowup/feedback-mensal/coleta.py:51` | `MK_INTERNOS = {"MK829"}` — o MK829 é o único |
| `~/flowup/feedback-mensal/README.md` · `~/flowup/kb/03-indicadores-e-ciclos.md` | efeito do MK829 na D.proj faturável |
| `~/flowup/flowup-skill/projetos_locais.json` · `~/flowup/kb/07-sugerir-apontamento.md` | apelido `"meka dw"` → MK829 no sugeridor de apontamento |
| `~/site-industrial-devops/07-decks-e-apresentacoes/segmento/DADOS-FLOWUP.md` | 812 h / 2 pessoas (consulta de 03/09/2026) |
| `~/site-industrial-devops/kb/09-pendencias.md` item 8f · `kb/08-indice-fontes.md` | o `padrao_nomenclaturas.md` arquivado na pasta errada do site |
| `~/site-industrial-devops/06-cases/mekatronik-dw/` | `readme.md` + `playbook.html` reaproveitados como case |

## O que a KB apurou no git (lendo metadado, sem rodar git)

**Remoto:** `https://github.com/mk-digital-solutions/mk829-meka-dw.git`

| quando | o quê |
|---|---|
| 09/04/2026 17:04 | commit inicial — playbook + Actions |
| 09/04/2026 17:06 | "Added .env interaction with docker compose" — **é o commit que tirou a senha do compose**; ela continua no histórico |
| 09/04/2026 17:11 | fix do playbook (remoção de JS conflitante com `<details>`) |
| 15/04/2026 09:07 | `pull: Fast-forward` — e é a data do `docker-compose.yaml` com conflito |
| 16/04/2026 09:56 | "Ajustes no playbook e padrão de nomenclaturas" — **último commit local. `main` local para aqui** |
| 29/05/2026 13:56 | `fetch` — traz `origin/main` adiante **e a branch `chlorum-novos-modelos-dbt`** |
| 29/05/2026 14:28 | novo `fetch`, `origin/main` avança de novo |
| 23/07/2026 10:42 | último `fetch` — `origin/main` = `edc73a27…`. **Nunca integrado ao working tree** |

**Índice do git (`.git/index`) lista 8 caminhos.** `queries/` não está entre
eles: `queries/dataset_apontamentos_diario.sql` **nunca foi versionado**.

Autor de **todos** os commits: Hugo Fonseca `<haf@poli.br>`. Nenhum commit do
Wollace neste repositório — mais um indício de que a execução dele foi
registrada em outro lugar.
