# Padrões de Nomenclatura — mk829-dw

> **Público-alvo:** Envolvidos ao mk829-meka dw  
> **Última atualização:** Abril de 2026  
> **Padrão base:** snake_case

---

## Sumário

1. [Nomenclatura de Schemas](#nomenclatura-de-schemas)
2. [Nomenclatura de Tabelas](#nomenclatura-de-tabelas)
3. [Nomenclatura de Colunas](#nomenclatura-de-colunas)
4. [Nomenclatura de Arquivos e Pastas](#nomenclatura-de-arquivos-e-pastas)
5. [Resumo Rápido](#resumo-rápido)

---

## Nomenclatura de Schemas

Os schemas organizam as camadas do pipeline de dados. Utilize prefixos que indiquem a camada de processamento:

| Prefixo     | Schema exemplo       | Finalidade                                                  |
|-------------|----------------------|-------------------------------------------------------------|
| `raw_`      | `raw_airbyte`        | Dados brutos carregados diretamente pelas fontes (Airbyte)  |
| `stg_`      | `stg_faturamento`          | Dados limpos e padronizados (staging)                 |
| `int_`      | `int_cliente`       | Dados intermediários com joins e agregações                  |
| `mart_`     | `mart_gestao`    | Dados prontos para consumo analítico (data marts)               |
| `audit_`    | `audit_logs`         | Logs, controle de execução e rastreabilidade                |

**Regras:**
- Sempre em `snake_case` e letras minúsculas.
- Nunca usar espaços, acentos ou caracteres especiais.
- O prefixo deve refletir a camada, não a fonte de dados.

```sql
-- ✅ Correto
CREATE SCHEMA raw_airbyte;
CREATE SCHEMA stg_gestao;
CREATE SCHEMA mart_cronogramas;

-- ❌ Incorreto
CREATE SCHEMA RawAirbyte;
CREATE SCHEMA dados-gestao;
CREATE SCHEMA CRONOGRAMAS;
```

---

## Nomenclatura de Tabelas

### Prefixos por tipo de tabela

| Prefixo  | Exemplo                    | Uso                                                   |
|----------|----------------------------|-------------------------------------------------------|
| `fct_`   | `fct_atividades`           |      Tabelas fato — eventos e transações mensuráveis  |
| `dim_`   | `dim_bancos`              | Tabelas dimensão — entidades descritivas               |
| `stg_`   | `stg_apontamentos_flowup`  |     Tabelas de staging — dados brutos padronizados    |
| `int_`   | `int_entregas`     | Tabelas intermediárias — transformações internas              |


**Regras:**
- Sempre em `snake_case` e letras minúsculas.
- Use nomes no **plural** para tabelas (ex: `fct_atividades`, não `fct_atividade`).
- O nome deve descrever o **conteúdo**, não a fonte (ex: `stg_apontamentos_flowup`, não `stg_planilha`).
- Evite abreviações desnecessárias — clareza é preferível à brevidade.

```sql
-- ✅ Correto
CREATE TABLE mart_cronogramas.fct_atividades (...);
CREATE TABLE mart_cronogramas.dim_banco (...);
CREATE TABLE raw_airbyte.stg_faturamento (...);

-- ❌ Incorreto
CREATE TABLE mart_cronogramas.atividades (...);
CREATE TABLE mart_cronogramas.fct-faturamento (...);
CREATE TABLE raw_airbyte.planilha1 (...);
```

---

## Nomenclatura de Colunas

### Sufixos recomendados por tipo de dado

| Sufixo     | Exemplo              | Tipo de dado                          |
|------------|----------------------|---------------------------------------|
| `_id`      | `centro_de_custo_id` | Identificador único / chave primária  |
| `_fk`      | `centro_de_custo_fk` | Chave estrangeira                     |
| `_at`      | `airbyte_created_at` | Timestamp (data e hora)               |
| `_dt`      | `data_dt`            | Date (somente data)                   |
| `_qtd`     | `esforco_qtd`        | Quantidade                            |
| `_vlr`     | `comissao_vlr`       | Valor monetário                       |
| `_flag`    | `imped_flag`         | Booleano (true/false)                 |
| `_cd`      | `status_cd`          | Código de categoria ou status         |
| `_nm`      | `entrega_nm`         | Nome descritivo                       |

**Regras:**
- Sempre em `snake_case` e letras minúsculas.
- Nunca usar palavras reservadas do PostgreSQL como nome de coluna (ex: `user`, `date`, `table`).
- Colunas de auditoria padrão em todas as tabelas:

```sql
airbyte_created_at    TIMESTAMP DEFAULT NOW(),
entrega_nm            VARCHAR(100)   -- identifica a fonte do dado (ex: 'airbyte', 'manual')
```

```sql
-- ✅ Correto
cliente_id          SERIAL PRIMARY KEY,
pedido_fk           INT REFERENCES fct_pedidos(pedido_id),
airbyte_created_at  TIMESTAMP,
faturamento_vlr     NUMERIC(10,2),
impd_flag           BOOLEAN

-- ❌ Incorreto
ID              SERIAL,
DataPedido      TIMESTAMP,
preco           NUMERIC,
user            VARCHAR   -- palavra reservada
```

---

## Nomenclatura de Arquivos e Pastas

### Padrão para arquivos

| Tipo de arquivo         | Padrão                              | Exemplo                              |
|-------------------------|-------------------------------------|--------------------------------------|
| Documentação            | `snake_case.md`                     | `padrao_nomenclaturas.md`             |
| Scripts SQL — staging   | `stg_[fonte]_[entidade].sql`        | `stg_google_sheets_cronogramas.sql`  |
| Scripts SQL — marts     | `fct_[entidade].sql`                | `fct_cronogramas.sql`                |
| Scripts SQL — dimensões | `dim_[entidade].sql`                | `dim_colaboradores.sql`              |
| Configurações           | `snake_case.yaml` / `snake_case.env`| `docker_compose.yaml`                |

**Regras:**
- Sempre em `snake_case` e letras minúsculas.
- Nunca usar espaços no nome de arquivos — use `_` como separador.
- O nome do arquivo SQL deve corresponder ao nome da tabela que ele cria ou popula.
- Arquivos de configuração sensíveis (`.env`, chaves JSON) nunca devem ser commitados — adicione ao `.gitignore`.

---

## Resumo Rápido

| Elemento           | Padrão       | Exemplo                          |
|--------------------|--------------|----------------------------------|
| Schema             | `prefixo_nome` | `raw_airbyte`, `mart_financeiro` |
| Tabela             | `prefixo_nome_plural` | `fct_pedidos`, `dim_clientes` |
| Coluna — ID        | `entidade_id` | `cliente_id`, `pedido_id`       |
| Coluna — Data/Hora | `nome_at`    | `criado_at`, `atualizado_at`     |
| Coluna — Valor     | `nome_vlr`   | `preco_vlr`, `desconto_vlr`      |
| Coluna — Flag      | `nome_flag`  | `ativo_flag`, `deletado_flag`    |
| Arquivo SQL        | `prefixo_entidade.sql` | `fct_cronogramas.sql`  |
| Arquivo doc        | `descricao.md` | `convencoes_nomenclatura.md`   |
| Pasta              | `snake_case/` | `sql/`, `docs/`, `airbyte/`     |

---

*Documentação gerada para uso interno. Dúvidas ou sugestões de ajuste nos padrões? Abra uma PR ou consulte o time de Engenharia de Dados.*
