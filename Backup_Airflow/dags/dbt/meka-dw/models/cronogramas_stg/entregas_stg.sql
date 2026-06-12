-- dbt/models/cronogramas_stg/entregas_stg.sql

{{ config(
    materialized='table',
    schema='_stg_cronogramas',
    alias='fct_entregas'
) }}

{% set raw_schema = var('raw_schema', 'raw_cronogramas') %}
{% set lista_entrada = var('cronogramas', ['MK213', 'MK385', 'MK389']) %}
{% set debug = var('modo_debug', False) %}

{# 1. ESSENCIAL: O dbt_utils precisa de uma lista de objetos Relation, não strings. #}
{% set relacoes_encontradas = [] %}
{% for item in lista_entrada %}
    {% set base_id = item.split('_')[0] | lower %}
    {% set table_name = base_id ~ '_00___ENTREGAS' %}
    
    {# Busca a referência real da tabela no banco #}
    {% set rel = adapter.get_relation(
        database=target.database,
        schema=raw_schema,
        identifier=table_name
    ) %}
    
    {% if rel %}
        {% do relacoes_encontradas.append(rel) %}
    {% endif %}
{% endfor %}

{# 2. ESSENCIAL: SQL de união inteligente das tabelas raw (gerado uma única vez
   e reaproveitado tanto na CTE quanto na detecção de tipos). #}
{% set union_sql %}
    {% if relacoes_encontradas | length > 0 %}
        {{ dbt_utils.union_relations(
            relations=relacoes_encontradas,
            source_column_name='tabela_origem'
        ) }}
    {% else %}
        SELECT 'NENHUMA_TABELA' AS tabela_origem LIMIT 0
    {% endif %}
{% endset %}

{# 3. Descobre as colunas da união, separando as colunas geradas pelo Airbyte
   (_airbyte_*) — que são repassadas intactas — das colunas de negócio,
   que terão o tipo convertido (varchar -> numeric/date) conforme os dados. #}
{% set colunas_airbyte = [] %}
{% set colunas_negocio = [] %}
{% if execute and relacoes_encontradas | length > 0 %}
    {% set nomes = [] %}
    {% for r in relacoes_encontradas %}
        {% do nomes.append(r.identifier) %}
    {% endfor %}
    {% set col_query %}
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = '{{ raw_schema }}'
          AND table_name IN ('{{ nomes | join("','") }}')
        GROUP BY column_name
        ORDER BY MIN(ordinal_position), column_name
    {% endset %}
    {% for c in run_query(col_query).columns[0].values() %}
        {% if c.startswith('_airbyte') %}
            {% do colunas_airbyte.append(c) %}
        {% else %}
            {% do colunas_negocio.append(c) %}
        {% endif %}
    {% endfor %}
{% endif %}

{# 4. Expressões já tipadas (numeric/date/varchar) para as colunas de negócio.
   FAT__PRODUTO e FAT__PESSOAL_PRD_ são colunas monetárias que hoje só contêm o
   placeholder "R$ -"; forçamos numeric (valores não numéricos viram NULL). #}
{% set exprs_tipadas = conv__lista_select(
    '(' ~ union_sql ~ ') AS _u',
    colunas_negocio,
    forcar_numericas=['FAT__PRODUTO', 'FAT__PESSOAL_PRD_']
) %}

WITH source_data AS (
    {{ union_sql }}
)

SELECT
    {# 5. ESSENCIAL: Recria a coluna codigo_cronograma extraindo o código 'mkXXX' do nome da tabela de origem #}
    LOWER(SUBSTRING(tabela_origem FROM '(?i)mk[0-9]+')) as codigo_cronograma,
    tabela_origem
    {%- for c in colunas_airbyte %},
    "{{ c }}"
    {%- endfor %}
    {%- for e in exprs_tipadas %},
    {{ e }}
    {%- endfor %}
FROM source_data
