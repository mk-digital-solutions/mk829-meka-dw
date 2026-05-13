-- dbt/models/marts/entregas.sql

{{ config(
    materialized='table',
    schema='marts',
    alias='fct_banco'
) }}

{% set raw_schema = var('raw_schema', 'raw_cronogramas') %}
{% set lista_entrada = var('cronogramas', ['MK213', 'MK385', 'MK389']) %}
{% set debug = var('modo_debug', False) %}

WITH source_data AS (
    {% for item in lista_entrada %}
        
        {# 1. Corta a string no primeiro '_' e pega só o prefixo (Ex: 'mk213') #}
        {% set base_id = item.split('_')[0] | lower %}
        
        {# 2. Monta o nome exato da tabela de entregas (com os 3 underlines) #}
        {% set table_name = base_id ~ '_00___BANCO' %}

        SELECT 
            '{{ base_id | lower }}' as codigo_cronograma,
            *
        {# Usamos aspas duplas no nome da tabela para garantir que o Postgres respeite o maiúsculo/minúsculo do seu banco #}
        FROM {{ raw_schema }}."{{ table_name }}"
        
        {% if not loop.last %} UNION ALL {% endif %}
    {% endfor %}
)

SELECT * FROM source_data
{% if debug %} LIMIT 100 {% endif %}