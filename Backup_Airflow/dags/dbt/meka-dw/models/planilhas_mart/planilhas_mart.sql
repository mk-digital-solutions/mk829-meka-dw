-- dbt/models/planilhas_mart/planilhas_mart.sql

{{ config(
    materialized='table',
    schema='planilhas',
    alias='planilhas_log_execucao'
) }}

{% set raw_schema = var('raw_schema', 'raw_planilhas') %}
{% set target_schema_full = target.schema ~ '_planilhas' %}
{% set debug = var('modo_debug', False) %}

{# ------------------------------------------------------------------
   1. Garante a existência do schema de destino (mart_planilhas)
------------------------------------------------------------------- #}
{% if execute %}
    {% do run_query("CREATE SCHEMA IF NOT EXISTS " ~ target_schema_full) %}

    {# 2. Lista as tabelas de raw_planilhas, EXCETO a tabela de log de execução
          (que é gerada pelos próprios modelos planilhas e não é dado de origem). #}
    {% set tabelas_query %}
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = '{{ raw_schema }}'
          AND table_type = 'BASE TABLE'
          AND table_name <> 'planilhas_log_execucao'
        ORDER BY table_name
    {% endset %}

    {% set tabelas_result = run_query(tabelas_query) %}
    {% set tabelas = tabelas_result.columns[0].values() %}

    {# 3. Para cada tabela, preenche os null: texto -> '', numérico/int -> 0.
          Mantém os tipos originais; demais tipos passam adiante sem alteração. #}
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
                {% do select_parts.append('COALESCE("' ~ col_name ~ '", ' ~ "''" ~ ') AS "' ~ col_name ~ '"') %}

            {% elif col_type in ['integer', 'bigint', 'smallint', 'numeric', 'decimal', 'real', 'double precision', 'money'] %}
                {% do select_parts.append('COALESCE("' ~ col_name ~ '", 0) AS "' ~ col_name ~ '"') %}

            {% else %}
                {% do select_parts.append('"' ~ col_name ~ '"') %}
            {% endif %}
        {% endfor %}

        {% set ddl_drop = 'DROP TABLE IF EXISTS ' ~ target_schema_full ~ '."' ~ tabela ~ '" CASCADE' %}
        {% set ddl_create = 'CREATE TABLE ' ~ target_schema_full ~ '."' ~ tabela ~ '" AS SELECT ' ~ (select_parts | join(', ')) ~ ' FROM ' ~ raw_schema ~ '."' ~ tabela ~ '"' %}

        {% do run_query(ddl_drop) %}
        {% do run_query(ddl_create) %}
        {% do log('[planilhas] Tabela tratada (texto -> ' ~ "''" ~ ', num -> 0): ' ~ target_schema_full ~ '.' ~ tabela, info=True) %}

    {% endfor %}
{% endif %}

-- Tabela de log: registra a execução do modelo planilhas_mart
SELECT
    '{{ run_started_at }}'::timestamp AS execucao_at,
    '{{ raw_schema }}'                AS schema_origem,
    '{{ target_schema_full }}'        AS schema_destino
