# 04 · dbt: modelos, macros e nomenclatura

## O projeto

`Backup_Airflow/dags/dbt/meka-dw/`, projeto `cronogramas` (nome no `dbt_project.yml`), profile
`meka_dw_postgres`. O bloco `models:` do `dbt_project.yml` ainda se refere a `meu_projeto`, nome
herdado do legado. As `vars` guardam a configuração do OpenMetadata (service `mekadw_openmetadata`, host
`http://192.168.0.157:8585/api`) **e o JWT do bot de ingestão**: não versionar sem retirar o token
([10](10-pendencias.md)).

Pacotes vendados em `dbt_packages/`: dbt_utils, codegen.

## Modelos por origem

| pasta | modelos | origem → destino |
|---|---|---|
| `cronogramas_stg/` | `atividades_stg`, `banco_stg`, `entregas_stg` | `raw_cronogramas.mkXXX_00___*` → `stg_cronogramas` |
| `cronogramas_int/` | `atividades_int`, `banco_int`, `entregas_int` | une as planilhas e unifica colunas duplicadas → `int_cronogramas` |
| `cronogramas_mart/` | `atividades_mart`, `banco_mart`, `entregas_mart` | nulos tratados → `mart_cronogramas.fct_atividades` / `fct_banco` / `fct_entregas` |
| `planilhas_raw/` | `planilhas_raw`, `fct_banco_bi_colaboradores` (obsoleto) | `public` → `raw_planilhas`, cópia 1:1 |
| `planilhas_stg/` | `planilhas_stg`, `fct_banco_bi` | `raw_planilhas` → `stg_planilhas` |
| `planilhas_mart/` | `planilhas_mart` | `stg_planilhas` → `mart_planilhas` (texto → `''`, número → `0`) |
| `agilizatronik_stg/`, `agilizatronik_mart/` | um modelo cada | → `mart_agilizatronik.fct_agilizatronik` |
| `flowup_mart/` | `flowup_mart` | → `mart_flowup` (13 tabelas consumidas no Power BI) |
| `mmgp_mart/` | `mmgp_mart` | → `mart_mmgp` |
| `schema.yml` | catálogo dos modelos para o OM | |

Os modelos são **dinâmicos** (descobrem tabelas e recriam o schema via `run_query`), materializando só
uma tabela de log (ex.: `planilhas_log_execucao`, ignorada nas camadas seguintes).

- O schema de destino é literal graças à macro `generate_schema_name`: prefixo `_` no
  `config(schema=...)` evita a concatenação com `target.schema`.
- `planilhas_stg` ignora `%\_BANCO\_BI` (essas tabelas vão para `fct_banco_bi`).
- `Valor_entregue__Cliente_` (cronogramas) é convertida de `R$ 1.234,56` (varchar) para `numeric`.
- `agilizatronik`: prefixos das colunas Priority e Status retirados (commit de 26/05/2026).

Fontes: `documentacao_airflow_dbt_om.md` §2, `git log`, listagem de `models/`.

## Macros

| macro | papel |
|---|---|
| `conversao_tipos.sql` | detecta e converte tipos das colunas de planilha (usada por `planilhas_stg`) |
| `generate_schema_name.sql` | schema literal |
| `filtroData.sql`, `filtro_hora.sql` | filtros de período (não detalhados nas fontes lidas) |
| `TimescaleUtils.sql` | utilitários Timescale (não detalhado nas fontes lidas) |

**A pasta `macros/` inteira está fora do git** ([10](10-pendencias.md)).

### `conversao_tipos`: a regra das datas

A coluna só vira `date` se **todos** os valores preenchidos baterem com `DD/MM/AAAA` ou `DD/MM/AA`. Um
único valor fora do padrão rebaixa a coluna inteira para `varchar`, e isso quebra o Power BI ([06](06-consumo-power-bi-e-sheets.md)).

Blindagem de 19/10/2026: `conv__expr_is_serial` reconhece o **número de série** do Sheets (inteiro de 5
dígitos, base `1899-12-30`; ex.: `46310` = 15/10/2026), `conv__cast_data` converte por
`DATE '1899-12-30' + n::int`, e `conv__detectar_tipos` aceita `ndat == tot OR (ndat > 0 AND ndat+nser == tot)`.
Ou seja, só trata serial como data se houver ao menos uma data DD/MM real, para não confundir uma coluna
de inteiros. **Data mal digitada** (ex.: `11/09/20245`) continua rebaixando a coluna, de propósito: não dá
para adivinhar o valor certo, e a correção é na planilha.

## `fct_banco_bi`: alocação por colaborador

`stg_planilhas.fct_banco_bi` é o `union_relations` das `public.<pessoa>_BANCO_BI` ([02](02-ingestao-airbyte.md)).
Efeito em 19/09/2026: 1536 linhas e 218 MKs (antes 542/95).

| coluna | regra |
|---|---|
| `_Entrega_` | sem o prefixo "MKxxx " (mesmo formato de `fct_entregas.ENTREGA`) |
| `CENTRO_DE_CUSTO` | o prefixo (ex.: MK829). **É centro de custo, não `codigo_cronograma`**: o cronograma mk522 traz entregas do MK609 |
| `DATA_DE_CONCLUSAO` | de `mart_cronogramas.fct_entregas` pela chave (CENTRO_DE_CUSTO, ENTREGA); casa 93,5% (o join por cronograma casava 46%; só texto dá falso casamento) |
| `colaborador_planilha` | **quem realmente faturou** (22/10/2026): se o texto da entrega cita um colaborador que tem planilha própria, reatribui para ele; senão fica o dono da planilha |
| `colaborador_origem` | `'entrega'` ou `'dono_planilha'` |
| `dono_planilha_alocacao` | o dono original, preservado |

Implementação da reatribuição: CTE `donos` (slug + tokens) + `LEFT JOIN LATERAL` com `d.tokens <@` tokens
do texto normalizado. A ordem importa: translate acentos → ASCII **antes** de tirar pontuação. Vence o
nome com mais tokens. Só reatribui para quem tem planilha; nomes sem planilha (ex.: Leonardo Aquino,
Arthur Felipe na planilha da Vanessa) ficam com o dono, de propósito. Impacto: 106 linhas, todas da
Vanessa (gestora).

Regra de negócio de 15/09/2026: NOME_B1 = **quem está alocado na entrega, não o gestor**.

Fonte: memória `banco-bi-airbyte-overwrite`.

## Nomenclatura

O padrão completo está em [`padrao_nomenclaturas.md`](../padrao_nomenclaturas.md): snake_case; schemas
`raw_/stg_/int_/mart_/audit_`; tabelas `fct_/dim_/stg_/int_` no plural; sufixos de coluna `_id`,
`_fk`, `_at`, `_dt`, `_qtd`, `_vlr`, `_flag`, `_cd`, `_nm`.

**Onde a realidade diverge do padrão** (registrado, não corrigido):

- O padrão prevê raw em `raw_airbyte` com nomes `fonte_entidade`; na prática são `raw_cronogramas`,
  `raw_planilhas` etc. com nomes de stream (`mk829_00___ENTREGAS`, `COMPOSICAO_PROJETOS`).
- Colunas vêm com o nome da planilha (`Valor_entregue__Cliente_`, `FAT. PESSOAL PRD.`), não com sufixos.
- Tabelas em maiúsculo em `mart_planilhas` (`BANCO_COLABORADORES`, `CADASTRO_CC`).

Ver [10](10-pendencias.md).
