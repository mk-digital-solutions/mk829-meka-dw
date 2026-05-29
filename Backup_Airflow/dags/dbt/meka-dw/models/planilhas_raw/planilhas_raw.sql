-- dbt/models/planilhas_raw/planilhas_raw.sql

{{ config(
    materialized='table',
    schema='_raw_planilhas',
    alias='planilhas_log_execucao'
) }}

{% set raw_schema = var('raw_schema', 'public') %}
{% set target_schema_full = var('target_schema', 'raw_planilhas') %}
{% set debug = var('modo_debug', False) %}

{# ------------------------------------------------------------------
   1. Garante a existência do schema de destino (raw_planilhas)
------------------------------------------------------------------- #}
{% if execute %}
    {% do run_query("CREATE SCHEMA IF NOT EXISTS " ~ target_schema_full) %}

    {# 2. Lista todas as tabelas presentes no schema de origem (public) #}
    {% set tabelas_query %}
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = '{{ raw_schema }}'
          AND table_type = 'BASE TABLE'
        ORDER BY table_name
    {% endset %}

    {% set tabelas_result = run_query(tabelas_query) %}
    {% set tabelas = tabelas_result.columns[0].values() %}

    {# 3. Cópia 1:1: recria cada tabela no schema de destino sem transformar nada #}
    {% for tabela in tabelas %}

        {% set ddl_drop = 'DROP TABLE IF EXISTS ' ~ target_schema_full ~ '."' ~ tabela ~ '" CASCADE' %}
        {% set ddl_create = 'CREATE TABLE ' ~ target_schema_full ~ '."' ~ tabela ~ '" AS SELECT * FROM ' ~ raw_schema ~ '."' ~ tabela ~ '"' %}

        {% do run_query(ddl_drop) %}
        {% do run_query(ddl_create) %}
        {% do log('[planilhas] Tabela copiada: ' ~ target_schema_full ~ '.' ~ tabela, info=True) %}

    {% endfor %}
{% endif %}

-- Tabela de log: registra a execução do modelo planilhas_raw
SELECT
    '{{ run_started_at }}'::timestamp AS execucao_at,
    '{{ raw_schema }}'                AS schema_origem,
    '{{ target_schema_full }}'        AS schema_destino
