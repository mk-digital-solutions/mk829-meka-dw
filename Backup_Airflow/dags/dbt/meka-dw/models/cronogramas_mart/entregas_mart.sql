-- dbt/models/cronogramas_mart/entregas_mart.sql

{{ config(
    materialized='table',
    schema='_mart_cronogramas',
    alias='fct_entregas'
) }}

{% set debug = var('modo_debug', False) %}

{% set source_rel = ref('entregas_int') %}

{% if source_rel %}
    {% set columns = adapter.get_columns_in_relation(source_rel) %}
{% else %}
    {% set columns = [] %}
{% endif %}

SELECT
{% if columns | length > 0 %}
{% for col in columns %}
    {%- if col.is_string() -%}
    COALESCE("{{ col.name }}", '') AS "{{ col.name }}"
    {%- elif col.is_number() -%}
    COALESCE("{{ col.name }}", 0) AS "{{ col.name }}"
    {%- else -%}
    "{{ col.name }}"
    {%- endif %}{% if not loop.last %},{% endif %}
{% endfor %}
{% else %}
    NULL AS placeholder
{% endif %}
FROM {{ ref('entregas_int') }}
{% if columns | length == 0 %}LIMIT 0{% endif %}
