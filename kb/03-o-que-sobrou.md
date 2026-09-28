# 03 · O que sobrou de reaproveitável

Projeto encerrado tem uma pergunta que vale mais que todas as outras: **o que
dessas ~800 horas ainda serve para alguma coisa?** Esta é a resposta, ordenada
do mais para o menos aproveitável.

## 🟢 Vale muito — já provou valor fora do MK829

### 1. O padrão de nomenclatura (`padrao_nomenclaturas.md`)
11,5 KB de convenção fechada de DW: schemas por camada, prefixos de tabela,
sufixos de coluna, colunas de auditoria obrigatórias, nomenclatura de arquivo
SQL. **É genérico — não tem nada de específico do Meka DW.** Serve para qualquer
projeto de dados da casa.

**Já foi reaproveitado**, e por isso está catalogado no acervo do site:
`~/site-industrial-devops/03-arquitetura-e-stack/padroes-uns/padrao_nomenclaturas.md`.
⚠️ Lá ele está **na pasta errada** — foi arquivado junto com os padrões de UNS,
e a KB do site já registra isso como pendência
(`site-industrial-devops/kb/09-pendencias.md`, item **8f**:
*"padrao_nomenclaturas.md está na pasta errada — é o padrão do DW interno MK829,
não um padrão de UNS"*). Se for mexer nele, mexa **aqui**, na origem.

### 2. O manual de Airbyte (`airbyte.md`)
10,5 KB de passo a passo real de Google Sheets ↔ PostgreSQL: source, destination,
sync mode, agendamento, boas práticas e **uma tabela de troubleshooting de 6
sintomas** com causa e ação. É conhecimento operacional que não depende do
MK829 — vale para qualquer projeto que use Airbyte, inclusive de cliente.

### 3. O playbook interativo (`playbook.html`)
28,8 KB, HTML autocontido (CSS embutido, zero JavaScript, zero dependência
externa), publicado no GitHub Pages via Actions. Além do conteúdo, **é um
template de documentação técnica navegável que se publica sozinho**. O
`.github/workflows/deploy.yml` que faz isso tem 30 linhas e é copiável para
qualquer repositório.

**Já foi reaproveitado como case**: `readme.md` e `playbook.html` foram copiados
para `~/site-industrial-devops/06-cases/mekatronik-dw/` (11/08/2026, cópias
byte a byte). O MK829 está listado entre os repositórios varridos para montar a
área de dados do site (`SITE-MEKA-AREA-DADOS.md`).

## 🟡 Vale, com ressalva

### 4. `queries/dataset_apontamentos_diario.sql`
A lógica de **horas úteis por dia** (feriado integral, meio-expediente, carga por
dia da semana) e a de **normalizar centro de custo `MKxxx`** são reaproveitáveis
e não triviais. **Mas** carregam as duas limitações documentadas no próprio
cabeçalho — join por nome que falha para ~40 pessoas, e `'N/D'` para quem não
está no `BANCO_COLABORADORES`. Ver [02-modelo-de-dados.md](02-modelo-de-dados.md).

Hoje, o caminho vivo e confiável para esse mesmo número é a **skill `flowup`**,
que lê o MySQL de origem. Este SQL vale como **referência de regra de negócio**,
não como fonte de dado.

## 🔴 Não reaproveite como está

| artefato | por quê |
|---|---|
| `docker-compose.yaml` | contém marcadores de conflito de merge — **não é YAML válido**, `docker compose up` falha; e tem senha em texto plano no lado `HEAD` |
| `abctl` | 9 bytes com o texto `Not Found`; é um download 404 salvo em arquivo. Nunca funcionou |
| `readme.md` | descreve o projeto no presente ("está sendo executado") e lista "próximos passos" que nunca aconteceram. **Lido hoje, engana** |

## ⚠️ E o que provavelmente NÃO está aqui

**O repositório remoto está à frente deste clone local.** Ver
[04-indice-fontes §Git](04-indice-fontes.md):

- `main` local parou em **16/04/2026**; `origin/main` foi buscado depois e
  aponta para outro commit (`edc73a27`, fetch de **23/07/2026**).
- Existe uma branch remota **`chlorum-novos-modelos-dbt`** (fetch de 29/05/2026)
  que **nunca foi trazida para cá**. O nome diz "novos modelos dbt" — exatamente
  a camada de transformação que falta nesta pasta.

- **O Portal Meka-DW** (ingestão de e-mail, 24/09/2026). Lançado em
  **23/07/2026** por Wollace, "baseado nas entregas até o momento", com
  documentações, treinamentos dos serviços utilizados, status em tempo real das
  plataformas que mantêm o DW e a visualização explicada do fluxo dos dados;
  acessível ao time de gestão pela rede "Eng-meka" (e-mail, thread
  1871536062366461551, 23/07/2026). Na apresentação da véspera, o portal foi
  descrito como o lugar que centraliza documentação e fluxos de dados,
  eliminando a dependência de planilhas e permitindo substituir aos poucos as
  tabelas de consumo do Power BI (e-mail, thread 1871447900068149394,
  22/07/2026, ata gerada automaticamente). **Nada do portal está nesta pasta**, e
  o endereço não é registrado aqui. Se ainda estiver de pé, é provavelmente a
  documentação mais completa do projeto. Ver [05 §10](05-pendencias.md).

🔴 **Antes de concluir que as horas do MK829 não produziram modelagem, olhe o
GitHub.** O repo é `github.com/mk-digital-solutions/mk829-meka-dw`, e há pelo
menos três meses de commits que este clone nunca viu.
