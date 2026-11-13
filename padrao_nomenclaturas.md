# Padrões de Nomenclatura — mk829-dw

> **Público-alvo:** Todos os envolvidos no projeto MK829 - Meka-DW  
> **Última atualização:** Abril de 2026  
> **Padrão base:** snake_case (palavras em minúsculo separadas por `_`)

---

## O que é snake_case e por que usamos?

`snake_case` é uma forma de escrever nomes usando apenas letras minúsculas e o underline (`_`) como separador de palavras. Exemplo: `nome_do_projeto`, `data_criacao`.

**Por que isso importa?** Bancos de dados e ferramentas como Airbyte e dbt são sensíveis a espaços, acentos e letras maiúsculas. Usando snake_case, evitamos erros e facilitamos a leitura por qualquer pessoa do time.

---

## Sumário

1. [Nomenclatura de Schemas (Pastas do Banco)](#1-nomenclatura-de-schemas)
2. [Nomenclatura de Tabelas](#2-nomenclatura-de-tabelas)
3. [Tabelas Raw por Fonte de Dados](#3-tabelas-raw-por-fonte-de-dados)
4. [Nomenclatura de Colunas](#4-nomenclatura-de-colunas)
5. [Nomenclatura de Arquivos e Pastas](#5-nomenclatura-de-arquivos-e-pastas)
6. [Resumo Rápido](#6-resumo-rápido)

---

## 1. Nomenclatura de Schemas

Pense nos **schemas** como as "pastas" do banco de dados. Cada pasta guarda tabelas de uma mesma etapa do pipeline de dados.

| Prefixo  | Exemplo          | O que guarda                                        |
|----------|------------------|-----------------------------------------------------|
| `raw_`   | `raw_airbyte`    | Dados brutos, exatamente como chegam das fontes     |
| `stg_`   | `stg_faturamento`| Dados limpos e padronizados (staging)               |
| `int_`   | `int_projetos`   | Dados já combinados entre tabelas (intermediário)   |
| `mart_`  | `mart_gestao`    | Dados prontos para análise e relatórios             |
| `audit_` | `audit_logs`     | Registros de controle e rastreabilidade             |

**Regras simples:**
- Tudo em minúsculo, sem acentos, sem espaços.
- Use `_` para separar palavras.
- O prefixo indica a etapa, não a ferramenta ou fonte.

```sql
-- ✅ Correto
raw_airbyte
stg_gestao
mart_cronogramas

-- ❌ Incorreto
RawAirbyte        -- maiúsculas não permitidas
dados-gestao      -- hífen não permitido
CRONOGRAMAS       -- tudo maiúsculo não permitido
```

---

## 2. Nomenclatura de Tabelas

Toda tabela começa com um **prefixo** que indica o seu tipo:

| Prefixo | Exemplo                    | Quando usar                                        |
|---------|----------------------------|----------------------------------------------------|
| `fct_`  | `fct_atividades`           | Tabelas de eventos e métricas (fatos)              |
| `dim_`  | `dim_colaboradores`        | Tabelas de entidades descritivas (dimensões)       |
| `stg_`  | `stg_apontamentos_flowup`  | Tabelas de dados brutos padronizados               |
| `int_`  | `int_entregas`             | Tabelas intermediárias com cruzamentos             |

**Regras simples:**
- Sempre minúsculo e snake_case.
- Nome no **plural** (ex: `fct_atividades`, não `fct_atividade`).
- Nome descreve o **conteúdo**, não a planilha ou arquivo de origem.

```sql
-- ✅ Correto
fct_atividades
dim_colaboradores
stg_apontamentos_flowup

-- ❌ Incorreto
atividades          -- falta o prefixo
fct-faturamento     -- hífen não permitido
planilha1           -- nome sem significado
```

---

## 3. Tabelas Raw por Fonte de Dados

As tabelas `raw_` recebem os dados **exatamente como chegam** das ferramentas (Airbyte, APIs). Cada fonte pode gerar várias tabelas — uma para cada contexto de dado.

**Padrão:** `[fonte]_[entidade_plural]`  
O nome é configurado como o **nome do stream** dentro do Airbyte ou da integração.

### Google Sheets — Planilhas de Cronograma

Schema de destino: `raw_airbyte`

| Nome da tabela            | Conteúdo esperado                              |
|---------------------------|------------------------------------------------|
| `cronograma_atividades`   | Atividades e tarefas dos cronogramas           |
| `cronograma_marcos`       | Marcos e entregas dos projetos                 |
| `cronograma_fases`        | Fases ou etapas dos projetos                   |

### Google Sheets — Banco de Alocação e Colaborador

Schema de destino: `raw_airbyte`

| Nome da tabela            | Conteúdo esperado                              |
|---------------------------|------------------------------------------------|
| `alocacao_equipe`         | Registros de alocação de colaboradores         |
| `colaboradores`           | Cadastro de colaboradores                      |
| `alocacao_projetos`       | Alocação por projeto                           |

### Google Sheets — Planilha de Acompanhamento

Schema de destino: `raw_airbyte`

| Nome da tabela              | Conteúdo esperado                            |
|-----------------------------|----------------------------------------------|
| `acompanhamento_projetos`   | Status e progresso dos projetos              |
| `acompanhamento_tarefas`    | Acompanhamento de tarefas específicas        |

### FlowUp (MySQL — Sistema de gestão financeira e horas)

Schema de destino: `raw_airbyte`

| Nome da tabela            | Conteúdo esperado                              |
|---------------------------|------------------------------------------------|
| `flowup_projetos`         | Projetos cadastrados no FlowUp                 |
| `flowup_apontamentos`     | Horas apontadas por colaborador/projeto        |
| `flowup_centros_custo`    | Centros de custo e suas configurações          |
| `flowup_colaboradores`    | Colaboradores cadastrados no FlowUp            |
| `flowup_despesas`         | Despesas financeiras registradas               |

### Agilizatronik (API Rest — Sistema de chamados/tickets)

Schema de destino: `raw_airbyte`

| Nome da tabela                | Conteúdo esperado                            |
|-------------------------------|----------------------------------------------|
| `agilizatronik_chamados`      | Chamados e tickets abertos                   |
| `agilizatronik_categorias`    | Categorias dos chamados                      |
| `agilizatronik_responsaveis`  | Responsáveis pelos chamados                  |
| `agilizatronik_status`        | Status possíveis dos chamados                |

### MMGP (API Rest — CRM e gestão de projetos)

Schema de destino: `raw_airbyte`

| Nome da tabela            | Conteúdo esperado                              |
|---------------------------|------------------------------------------------|
| `mmgp_projetos`           | Projetos cadastrados no MMGP                   |
| `mmgp_oportunidades`      | Oportunidades comerciais (CRM)                 |
| `mmgp_clientes`           | Cadastro de clientes                           |
| `mmgp_contratos`          | Contratos e propostas                          |
| `mmgp_tarefas`            | Tarefas vinculadas a projetos                  |

### VOE (API Rest — CRM/gestão ágil de projetos)

Schema de destino: `raw_airbyte`

| Nome da tabela        | Conteúdo esperado                              |
|-----------------------|------------------------------------------------|
| `voe_projetos`        | Projetos cadastrados no VOE                    |
| `voe_sprints`         | Sprints e ciclos de trabalho                   |
| `voe_tarefas`         | Tarefas e itens de backlog                     |
| `voe_clientes`        | Cadastro de clientes no VOE                    |

> **Dica:** Se uma fonte gerar uma tabela com contexto diferente dos exemplos acima, siga o padrão `[fonte]_[entidade_plural]` e documente aqui.

---

## 4. Nomenclatura de Colunas

Colunas também seguem sufixos que indicam o tipo do dado:

| Sufixo   | Exemplo              | Tipo de dado                          |
|----------|----------------------|---------------------------------------|
| `_id`    | `projeto_id`         | Identificador único (chave primária)  |
| `_fk`    | `projeto_fk`         | Referência a outra tabela             |
| `_at`    | `criado_at`          | Data e hora (timestamp)               |
| `_dt`    | `inicio_dt`          | Somente data                          |
| `_qtd`   | `horas_qtd`          | Quantidade numérica                   |
| `_vlr`   | `custo_vlr`          | Valor monetário                       |
| `_flag`  | `ativo_flag`         | Verdadeiro/Falso (sim/não)            |
| `_cd`    | `status_cd`          | Código de categoria ou status         |
| `_nm`    | `projeto_nm`         | Nome ou descrição textual             |

**Regras simples:**
- Sempre minúsculo e snake_case.
- Nunca use palavras reservadas como `user`, `date`, `table`, `order`.
- Toda tabela deve ter as colunas de auditoria abaixo:

```sql
-- Colunas obrigatórias em toda tabela
airbyte_created_at    TIMESTAMP   -- quando o registro foi carregado pelo Airbyte
fonte_nm              VARCHAR     -- identifica a origem (ex: 'flowup', 'google_sheets')
```

```sql
-- ✅ Correto
projeto_id      SERIAL PRIMARY KEY
colaborador_fk  INT
inicio_dt       DATE
custo_vlr       NUMERIC(10,2)
ativo_flag      BOOLEAN

-- ❌ Incorreto
ID              -- maiúsculo
DataInicio      -- camelCase não permitido
preco           -- sem sufixo de tipo
user            -- palavra reservada do PostgreSQL
```

---

## 5. Nomenclatura de Arquivos e Pastas

| Tipo de arquivo         | Padrão                             | Exemplo                             |
|-------------------------|------------------------------------|-------------------------------------|
| Documentação            | `snake_case.md`                    | `padrao_nomenclaturas.md`           |
| Scripts SQL — staging   | `stg_[fonte]_[entidade].sql`       | `stg_flowup_apontamentos.sql`       |
| Scripts SQL — marts     | `fct_[entidade].sql`               | `fct_atividades.sql`                |
| Scripts SQL — dimensões | `dim_[entidade].sql`               | `dim_colaboradores.sql`             |
| Configurações           | `snake_case.yaml` / `snake_case.env` | `docker_compose.yaml`             |

**Regras simples:**
- Sempre minúsculo, sem espaços — use `_` como separador.
- O nome do arquivo SQL deve corresponder ao nome da tabela que ele cria.
- Arquivos sensíveis (`.env`, chaves JSON) **nunca** devem ser enviados ao repositório — adicione ao `.gitignore`.

---

## 6. Resumo Rápido

| Elemento              | Padrão                  | Exemplo                             |
|-----------------------|-------------------------|-------------------------------------|
| Schema                | `prefixo_nome`          | `raw_airbyte`, `mart_gestao`        |
| Tabela                | `prefixo_nome_plural`   | `fct_atividades`, `dim_colaboradores` |
| Tabela raw (fonte)    | `fonte_entidade_plural` | `flowup_apontamentos`, `voe_sprints` |
| Coluna — ID           | `entidade_id`           | `projeto_id`, `colaborador_id`      |
| Coluna — Data/Hora    | `nome_at`               | `criado_at`, `atualizado_at`        |
| Coluna — Valor        | `nome_vlr`              | `custo_vlr`, `desconto_vlr`         |
| Coluna — Flag         | `nome_flag`             | `ativo_flag`, `deletado_flag`       |
| Arquivo SQL           | `prefixo_entidade.sql`  | `fct_atividades.sql`                |
| Arquivo doc           | `descricao.md`          | `padrao_nomenclaturas.md`           |
| Pasta                 | `snake_case/`           | `sql/`, `docs/`, `airbyte/`         |

---

*Dúvidas ou sugestões de ajuste? Abra uma PR ou consulte o time de Engenharia de Dados.*
