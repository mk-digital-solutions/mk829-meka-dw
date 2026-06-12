-- dbt/models/cronogramas_int/entregas_int.sql

{{ config(
    materialized='table',
    schema='_int_cronogramas',
    alias='fct_entregas'
) }}

{% set debug = var('modo_debug', False) %}

{# Pares (col_a, col_b) que se alternam (uma com valor, outra null) e o alias final #}
{% set merges = [
    {'a': '_COMISSAO_',           'b': 'COMISSAO',              'alias': 'COMISSAO'},
    {'a': '_FAT__PRODUTO_',        'b': 'FAT__PRODUTO',           'alias': 'FAT. PRODUTO'},
    {'a': '_FAT__SERVICO_',        'b': 'FAT__SERVICO',           'alias': 'FAT. SERVICO'},
    {'a': 'FAT__PESSOAL_PRD_',    'b': '_FAT__PESSOAL_PRD__',   'alias': 'FAT. PESSOAL PRD.'},
    {'a': 'FAT__PESSOAL_SERV_',   'b': '_FAT__PESSOAL_SERV__',  'alias': 'FAT. PESSOAL SERV.'}
] %}

{% set excluded = [] %}
{% for m in merges %}
    {% do excluded.append(m['a']) %}
    {% do excluded.append(m['b']) %}
{% endfor %}

{% set source_rel = ref('entregas_stg') %}

{% if source_rel %}
    {% set columns = adapter.get_columns_in_relation(source_rel) %}
{% else %}
    {% set columns = [] %}
{% endif %}

{% set passthrough = [] %}
{% for col in columns %}
    {% if col.name not in excluded %}
        {% do passthrough.append(col) %}
    {% endif %}
{% endfor %}

SELECT
{% if columns | length > 0 %}
{% for col in passthrough %}
    "{{ col.name }}",
{% endfor %}
{% for m in merges %}
    COALESCE("{{ m['a'] }}", "{{ m['b'] }}") AS "{{ m['alias'] }}"{% if not loop.last %},{% endif %}
{% endfor %}
{% else %}
    NULL AS placeholder
{% endif %}
FROM {{ ref('entregas_stg') }}
{% if columns | length == 0 %}LIMIT 0{% endif %}
