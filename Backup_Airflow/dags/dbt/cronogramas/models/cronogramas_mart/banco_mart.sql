-- dbt/models/cronogramas_mart/banco_mart.sql

{{ config(
    materialized='table',
    schema='_mart_cronogramas',
    alias='fct_banco'
) }}

{% set int_schema = var('int_schema', 'int_cronogramas') %}
{% set source_table = 'fct_banco' %}
{% set debug = var('modo_debug', False) %}

{% set source_rel = adapter.get_relation(
    database=target.database,
    schema=int_schema,
    identifier=source_table
) %}

{% if source_rel %}
    {% set columns = adapter.get_columns_in_relation(source_rel) %}
{% else %}
    {% set columns = [] %}
{% endif %}

SELECT
{% if columns | length > 0 %}
{% for col in columns %}
    {%- if col.is_string() -%}
    COALESCE("{{ col.name }}", 'vazio') AS "{{ col.name }}"
    {%- elif col.is_number() -%}
    COALESCE("{{ col.name }}", 0) AS "{{ col.name }}"
    {%- else -%}
    "{{ col.name }}"
    {%- endif %}{% if not loop.last %},{% endif %}
{% endfor %}
{% else %}
    NULL AS placeholder
{% endif %}
FROM {{ int_schema }}."{{ source_table }}"
{% if columns | length == 0 %}LIMIT 0{% endif %}
