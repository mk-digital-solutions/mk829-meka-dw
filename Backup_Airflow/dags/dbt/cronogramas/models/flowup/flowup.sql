-- dbt/models/flowup/flowup.sql

{{ config(
    materialized='table',
    schema='flowup',
    alias='flowup_log_execucao'
) }}

{% set raw_schema = var('raw_schema', 'raw_flowup') %}
{% set target_schema_full = target.schema ~ '_flowup' %}
{% set debug = var('modo_debug', False) %}

{# ------------------------------------------------------------------
   1. Garante a existência do schema de destino (mart_flowup)
------------------------------------------------------------------- #}
{% if execute %}
    {% do run_query("CREATE SCHEMA IF NOT EXISTS " ~ target_schema_full) %}

    {# 2. Lista todas as tabelas presentes no schema raw_flowup #}
    {% set tabelas_query %}
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = '{{ raw_schema }}'
          AND table_type = 'BASE TABLE'
        ORDER BY table_name
    {% endset %}

    {% set tabelas_result = run_query(tabelas_query) %}
    {% set tabelas = tabelas_result.columns[0].values() %}

    {# 3. Para cada tabela, descobre as colunas/tipos e aplica os COALESCE #}
    {% for tabela in tabelas %}

        {% set cols_query %}
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_schema = '{{ raw_schema }}'
              AND table_name = '{{ tabela }}'
            ORDER BY ordinal_position
        {% endset %}

        {% set cols_result = run_query(cols_query) %}

        {% set select_parts = [] %}
        {% for row in cols_result.rows %}
            {% set col_name = row[0] %}
            {% set col_type = row[1] | lower %}

            {% if col_type in ['character varying', 'varchar', 'text', 'character', 'char', 'bpchar', 'name', 'citext'] %}
                {% do select_parts.append('COALESCE("' ~ col_name ~ '", ' ~ "'vazio'" ~ ') AS "' ~ col_name ~ '"') %}

            {% elif col_type in ['integer', 'bigint', 'smallint', 'numeric', 'decimal', 'real', 'double precision', 'money'] %}
                {% do select_parts.append('COALESCE("' ~ col_name ~ '", 0) AS "' ~ col_name ~ '"') %}

            {% elif 'timestamp' in col_type or col_type == 'date' %}
                {% do select_parts.append('COALESCE("' ~ col_name ~ '"::text, ' ~ "'0000-00-00 00:00:00.000'" ~ ') AS "' ~ col_name ~ '"') %}

            {% else %}
                {% do select_parts.append('"' ~ col_name ~ '"') %}
            {% endif %}
        {% endfor %}

        {% set limit_clause = '' %}

        {% set ddl_drop = 'DROP TABLE IF EXISTS ' ~ target_schema_full ~ '."' ~ tabela ~ '" CASCADE' %}
        {% set ddl_create = 'CREATE TABLE ' ~ target_schema_full ~ '."' ~ tabela ~ '" AS SELECT ' ~ (select_parts | join(', ')) ~ ' FROM ' ~ raw_schema ~ '."' ~ tabela ~ '"' ~ limit_clause %}

        {% do run_query(ddl_drop) %}
        {% do run_query(ddl_create) %}
        {% do log('[flowup] Tabela transformada: ' ~ target_schema_full ~ '.' ~ tabela, info=True) %}

    {% endfor %}
{% endif %}

-- Tabela de log: registra a execução do modelo flowup
SELECT
    '{{ run_started_at }}'::timestamp AS execucao_at,
    '{{ raw_schema }}'                AS schema_origem,
    '{{ target_schema_full }}'        AS schema_destino
