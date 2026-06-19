# Documentação — Airflow, dbt e OpenMetadata (MK829 / Meka-DW)

Registro do que foi construído/ajustado na orquestração (Airflow + Cosmos/dbt) e na
catalogação/documentação no OpenMetadata (OM). Ambiente: Airflow em containers
(`backup_airflow-*`), Postgres do DW e OpenMetadata em `192.168.0.157`.

---

## 1. Ambiente Airflow

### 1.1. Correção de DNS dos containers (offline)
Os containers do Airflow têm rota de saída para a internet, mas **não resolviam nomes
externos** porque herdavam o resolver do Tailscale (`100.100.100.100`), inalcançável de
dentro da rede bridge. Isso quebrava qualquer tarefa que acessasse a internet por URL
(ex.: `pip install` do PyPI, `dbt deps` do `hub.getdbt.com`).

**Correção:** adicionado `dns: [8.8.8.8, 1.1.1.1]` no bloco `x-airflow-common` do
`Backup_Airflow/docker-compose-airflow.yaml` (cobre worker, scheduler, dag-processor e
containers futuros).

### 1.2. dbt/Cosmos em ambiente sem internet
Como o `dbt deps` baixa pacotes da internet, as DAGs dbt foram padronizadas para **não**
rodar `deps`, usando os pacotes já vendados em `dbt/meka-dw/dbt_packages/`:

- `RenderConfig(..., dbt_deps=False)`
- `operator_args={"install_deps": False, ...}` (o Cosmos exige que os dois valores sejam iguais)

> **Regra para novas DAGs dbt:** sempre criar com `dbt_deps=False` + `install_deps=False`.
> Ao alterar `packages.yml`, rodar `dbt deps` uma vez em ambiente com internet e versionar
> o `dbt_packages/`.

---

## 2. Pipeline dbt — Planilhas (Google Sheets → Postgres)

Pipeline em 3 camadas para os dados de planilhas, seguindo o padrão dos demais modelos
(`flowup`/`mmgp`): modelos dinâmicos que recriam o schema inteiro via `run_query`
(DROP/CREATE), materializando apenas uma tabela de log de execução.

| Camada | Modelo dbt | DAG | Origem → Destino | O que faz |
|---|---|---|---|---|
| RAW | `planilhas_raw.sql` | `dbt_planilhas_raw` | `public` → `raw_planilhas` | Cópia 1:1 de todas as tabelas, **sem transformação**. |
| STG | `planilhas_stg.sql` | `dbt_planilhas_stg` | `raw_planilhas` → `stg_planilhas` | Camada intermediária (staging). |
| MART | `planilhas_mart.sql` | `dbt_planilhas_mart` | `stg_planilhas` → `mart_planilhas` | Tratamento de nulos: texto → `''`, numérico/inteiro → `0` (mantém os tipos originais). |

Detalhes:
- O schema de destino `raw_planilhas` é literal (macro `generate_schema_name`: prefixo `_`
  no `config(schema=...)` evita a concatenação com `target.schema`).
- A tabela de log `planilhas_log_execucao` é ignorada nas camadas seguintes (não é dado de BI).

### Ajuste no modelo de Cronogramas
A coluna `Valor_entregue__Cliente_` (cronogramas) estava como `varchar` no formato BR
(`R$ 1.234,56`) e foi convertida para `numeric` (limpeza de `R$`, separador de milhar e
vírgula decimal) para uso no Power BI.

---

## 3. DAGs criadas — descrição breve

### 3.1. DAGs dbt (Cosmos)
| DAG | Schedule | Descrição |
|---|---|---|
| `dbt_planilhas_raw` | `0 1 * * *` | Copia o schema `public` para `raw_planilhas` (sem transformar). |
| `dbt_planilhas_stg` | `15 1 * * *` | Camada de staging das planilhas (`raw_planilhas` → `stg_planilhas`). |
| `dbt_planilhas_mart` | `30 1 * * *` | Camada final das planilhas com tratamento de nulos (`stg_planilhas` → `mart_planilhas`). |

### 3.2. DAGs de documentação no OpenMetadata
Quatro DAGs que escrevem metadados diretamente na **API REST do OpenMetadata** (as tabelas
`mart_*` são geradas dinamicamente pelo dbt e não são nós dbt, então não podem ser
documentadas via `schema.yml`). Todas são **idempotentes** e rodam semanalmente (segunda).

| DAG | Schedule | Schema documentado |
|---|---|---|
| `om_docs_flowup_mart` | `0 4 * * 1` | `mart_flowup` (13 tabelas consumidas no Power BI) |
| `om_docs_cronogramas_mart` | `10 4 * * 1` | `mart_cronogramas` (`fct_banco`, `fct_atividades`, `fct_entregas`) |
| `om_docs_agilizatronik_mart` | `20 4 * * 1` | `mart_agilizatronik` (`fct_agilizatronik`) |
| `om_docs_planilhas_mart` | `30 4 * * 1` | `mart_planilhas` (`BANCO_BI`, `BANCO_COLABORADORES`, `CADASTRO_CC`, `COMPOSICAO_PROJETOS`, `HH_COMPOSICOES`) |

Cada DAG tem os params `dry_run` (loga sem gravar) e `om_database`.

---

## 4. OpenMetadata — o que foi documentado

As DAGs `om_docs_*` aplicam, por tabela, o seguinte conjunto de metadados:

| Item | Como é obtido / valor |
|---|---|
| **Descrição da tabela** | Texto redigido por tabela. |
| **Descrição das colunas** | Por coluna, exceto as técnicas do Airbyte (`_airbyte_*`). Em `COMPOSICAO_PROJETOS` (~180 colunas) as descrições são geradas por padrão do nome (HH/Comissão/Valor/cargo). |
| **Owner** | Usuário **MKADMIN** (criado no OM se não existir). |
| **Tier** | `Tier1` para `fct_reportagem`, `fct_agilizatronik`, `COMPOSICAO_PROJETOS` e `HH_COMPOSICOES`; demais `Tier2`. |
| **Domínio** | Domínio global **Meka DW** (criado uma vez, atribuído a todas as tabelas). |
| **Nº de linhas** (rowCount) | `SELECT count(*)` no Postgres — dinâmico a cada execução. |
| **Tamanho** (sizeInByte) | `pg_total_relation_size` no Postgres — dinâmico. |
| **Data de criação** (createDateTime) | Data de catalogação no OM (`updatedAt` da 1ª versão da entidade). |

### Mecânica técnica
- Descrição/owner/tier/domínio: `PATCH` (JSON Patch) na entidade da tabela.
- rowCount/tamanho/data: `PUT /tables/{id}/tableProfile`.
- **Resiliência de colunas:** o patch de colunas é tentado em lote e, se falhar, é aplicado
  coluna a coluna, ignorando (com aviso) as que o OM rejeitar.

### Limitação conhecida
As colunas **`FAT. PESSOAL PRD.`** e **`FAT. PESSOAL SERV.`** (de `mart_cronogramas.fct_entregas`)
não podem ter descrição: o nome **termina com ponto** e o OpenMetadata retorna erro 500 ao
montar o FQN. Todo o restante da tabela é documentado normalmente. Para documentá-las, seria
necessário renomear as colunas na origem (remover o ponto final).

---

## 5. Pré-requisito de catalogação
As tabelas precisam estar catalogadas no OM (DAG `ingest_postgres_metadata`, que escaneia os
schemas `raw_/stg_/int_/mart_`) **antes** das DAGs `om_docs_*` rodarem; tabelas não encontradas
são apenas "skipadas" com aviso no log.
