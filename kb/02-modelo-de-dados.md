# 02 · Modelo de dados, nomenclatura e a única query real

## A arquitetura em camadas (desenhada, não construída)

Modelo clássico de DW por medalhão, definido em
[`padrao_nomenclaturas.md`](../padrao_nomenclaturas.md):

| schema | papel |
|---|---|
| `raw_airbyte` | bruto, exatamente como chega da fonte |
| `stg_*` | limpo e padronizado |
| `int_*` | cruzamentos intermediários |
| `mart_*` | pronto para análise/BI |
| `audit_*` | controle e rastreabilidade |

**Só o `raw_airbyte` tem evidência de ter existido.** Não há um único arquivo
`.sql` de modelo `stg_`, `int_`, `mart_` ou `dim_`/`fct_` nesta pasta — e o
padrão prescreve exatamente que cada tabela tenha o seu. Ver
[05-pendencias §3](05-pendencias.md).

## Convenções de nomenclatura — o ativo mais reaproveitável desta pasta

Base: **snake_case**, minúsculo, sem acento, sem espaço, sem hífen.

**Tabelas** — prefixo por tipo, nome no plural, descreve conteúdo (não a
planilha de origem): `fct_` (fatos), `dim_` (dimensões), `stg_`, `int_`.
Raw segue `[fonte]_[entidade_plural]`, e o nome é configurado como *stream name*
dentro do Airbyte — não renomeado depois.

**Colunas** — sufixo declara o tipo:

| sufixo | significado | | sufixo | significado |
|---|---|---|---|---|
| `_id` | chave primária | | `_qtd` | quantidade |
| `_fk` | chave estrangeira | | `_vlr` | valor monetário |
| `_at` | timestamp | | `_flag` | booleano |
| `_dt` | só data | | `_cd` | código/categoria |
| | | | `_nm` | nome/texto |

**Duas colunas obrigatórias em toda tabela:** `airbyte_created_at` (quando o
Airbyte carregou) e `fonte_nm` (origem, ex. `'flowup'`, `'google_sheets'`).

**Arquivos SQL:** `stg_[fonte]_[entidade].sql`, `fct_[entidade].sql`,
`dim_[entidade].sql` — o nome do arquivo é o nome da tabela que ele cria.

Proibido explicitamente: maiúscula, camelCase, hífen, nome sem prefixo, nome sem
significado (`planilha1`), e palavra reservada do PostgreSQL como nome de coluna
(`user`, `date`, `table`, `order`).

## As fontes que alimentariam o DW

`padrao_nomenclaturas.md` cataloga **7 fontes e 24 tabelas raw**. Isto é o
*catálogo pretendido*, não o implantado:

| fonte | tipo | tabelas raw previstas | chegou a existir? |
|---|---|---|---|
| Google Sheets — cronogramas | Sheets | `cronograma_atividades`, `cronograma_marcos`, `cronograma_fases` | ✅ o Fluxo 1 do Airbyte existia |
| Google Sheets — alocação/colaboradores | Sheets | `alocacao_equipe`, `colaboradores`, `alocacao_projetos` | ✅ mesma via |
| Google Sheets — acompanhamento | Sheets | `acompanhamento_projetos`, `acompanhamento_tarefas` | ✅ mesma via |
| **Flowup** | MySQL | `flowup_projetos`, `flowup_apontamentos`, `flowup_centros_custo`, `flowup_colaboradores`, `flowup_despesas` | ❌ listado como "próximo passo" nos dois documentos |
| **Agilizatronik** (chamados) | API REST | `agilizatronik_chamados`, `_categorias`, `_responsaveis`, `_status` | ❌ nunca configurado |
| **MMGP** (CRM/projetos) | API REST | `mmgp_projetos`, `mmgp_oportunidades`, `mmgp_clientes`, `mmgp_contratos`, `mmgp_tarefas` | ❌ nunca configurado |
| **VOE** (CRM/ágil) | API REST | `voe_projetos`, `voe_sprints`, `voe_tarefas`, `voe_clientes` | ❌ nunca configurado |

> **Meka Strategy não aparece em nenhuma fonte desta pasta.** O sistema
> financeiro do grupo não era fonte prevista do Meka DW. Se a pergunta for "o
> DW ia puxar do Meka Strategy?", a resposta honesta é **não, segundo o que está
> documentado aqui** — o financeiro entrava pelo Flowup (`flowup_despesas`).

## A única query real: `queries/dataset_apontamentos_diario.sql`

**É o artefato de modelagem mais avançado da pasta** — e o mais revelador. 5,6 KB,
criado em **30/04/2026**, **nunca commitado** (não está no índice do git; é
arquivo local solto).

Produz o dataset **apontamentos diários por colaborador × centro de custo**:

`dia · colaborador · setor · segmento · horas_uteis · centro_custo · horas_apontadas`

### O que ela ensina sobre o modelo

- **Fonte declarada no cabeçalho: `postgres @ 192.168.0.156`, schema `public`** —
  IP diferente do `.168` do readme. Ver [05-pendencias §5](05-pendencias.md).
- **As tabelas consultadas são o schema nativo do Flowup**, com nomes de coluna
  em PascalCase entre aspas: `membro`, `reportagem`, `projeto`, `cargo`,
  `carga_horaria`, `feriado`. Ou seja: **os dados do Flowup já estavam
  replicados num PostgreSQL** — mas em `public`, cru, **não** em `raw_airbyte` e
  **não** com os nomes `flowup_*` que o próprio padrão da casa prescreve.
- Cruza com `public."BANCO_COLABORADORES"` (colunas `NOME_FLOWUP`, `EMPRESA`,
  `EQUIPE`) — uma planilha do Google Sheets carregada no banco, que traz
  **setor** (Mekatronik / Mk Digital / Mk Engenharia) e **segmento**
  (AUTOMAÇÃO, INSTALACAO, INDUSTRIAL DEVOPS, ADM…).
- Calcula `horas_uteis` do dia: 0 se feriado integral, metade se meio-expediente,
  senão a `Carga` do cargo para aquele dia da semana. **É a mesma mecânica dos
  indicadores de disponibilidade da casa** — este SQL é uma reimplementação, em
  Postgres, do que a skill `flowup` faz em MySQL.
- Normaliza o centro de custo: `MKxxx` para projetos MK, nome completo para o
  resto (`CASE WHEN p."Nome" ~ '^MK\d+'`).

### As duas limitações que o próprio autor documentou no cabeçalho

1. **~40 colaboradores não têm entrada em `carga_horaria`** → `horas_uteis = 0`
   para eles. O join membro→cargo é feito por **string do nome** (primeiro nome +
   último sobrenome, com fallback que remove acentos via `translate()`), e falha.
2. **Quem não está em `BANCO_COLABORADORES` aparece com setor/segmento `'N/D'`.**

🔴 **Não use esta query como fonte de número de gestão sem tratar essas duas
limitações.** Um `horas_uteis = 0` silencioso destrói qualquer cálculo de
disponibilidade. Para número confiável de horas, a fonte é a skill `flowup`, que
lê o MySQL de origem.
