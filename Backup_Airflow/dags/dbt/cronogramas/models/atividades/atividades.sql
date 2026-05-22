-- dbt/models/atividades.sql

{{ config(
    materialized='table',
    schema='cronogramas',
    alias='fct_atividades'
) }}

{% set raw_schema = var('raw_schema', 'raw_cronogramas') %}
{% set lista_entrada = var('cronogramas', ['MK213', 'MK385', 'MK389']) %}
{% set debug = var('modo_debug', False) %}

{# 1. ESSENCIAL: O dbt_utils precisa de uma lista de objetos Relation, não strings. #}
{% set relacoes_encontradas = [] %}
{% for item in lista_entrada %}
    {% set base_id = item.split('_')[0] | lower %}
    {% set table_name = base_id ~ '_00___ATIVIDADES' %}
    
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

WITH source_data AS (
    {# 2. ESSENCIAL: Substituição do loop UNION ALL pela macro de união inteligente #}
    {% if relacoes_encontradas | length > 0 %}
        {{ dbt_utils.union_relations(
            relations=relacoes_encontradas,
            source_column_name='tabela_origem'
        ) }}
    {% else %}
        SELECT 'NENHUMA_TABELA' AS tabela_origem LIMIT 0
    {% endif %}
)

SELECT 
    {# 3. ESSENCIAL: Recria a sua coluna codigo_cronograma extraindo o código 'mkXXX' do nome da tabela de origem #}
    LOWER(SUBSTRING(tabela_origem FROM '(?i)mk[0-9]+')) as codigo_cronograma,
    *
FROM source_data
{% if debug %} LIMIT 100 {% endif %}