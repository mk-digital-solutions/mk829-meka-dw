-- dbt/models/mmgp_mart/mmgp_mart.sql

{{ config(
    materialized='table',
    schema='mmgp',
    alias='mmgp_log_execucao'
) }}

{% set raw_schema = var('raw_schema', 'raw_mmgp') %}
{% set target_schema_full = target.schema ~ '_mmgp' %}
{% set debug = var('modo_debug', False) %}

{# Palavras-chave no nome da coluna que disparam a marcação de moeda (R$) #}
{% set currency_keywords = ['cost', 'comission', 'value'] %}

{# ------------------------------------------------------------------
   1. Garante a existência do schema de destino (mart_mmgp)
------------------------------------------------------------------- #}
{% if execute %}
    {% do run_query("CREATE SCHEMA IF NOT EXISTS " ~ target_schema_full) %}

    {# 2. Lista todas as tabelas presentes no schema raw_mmgp #}
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
            {% set col_name_lower = col_name | lower %}

            {# Verifica se o nome da coluna contém alguma palavra-chave de moeda #}
            {% set is_currency = false %}
            {% for kw in currency_keywords %}
                {% if kw in col_name_lower %}
                    {% set is_currency = true %}
                {% endif %}
            {% endfor %}

            {% if col_type in ['character varying', 'varchar', 'text', 'character', 'char', 'bpchar', 'name', 'citext'] %}
                {% if is_currency %}
                    {% do select_parts.append("('R$ ' || COALESCE(\"" ~ col_name ~ "\", '')) AS \"" ~ col_name ~ "\"") %}
                {% else %}
                    {% do select_parts.append('COALESCE("' ~ col_name ~ '", ' ~ "''" ~ ') AS "' ~ col_name ~ '"') %}
                {% endif %}

            {% elif col_type in ['integer', 'bigint', 'smallint', 'numeric', 'decimal', 'real', 'double precision', 'money'] %}
                {% if is_currency %}
                    {% do select_parts.append("('R$ ' || COALESCE(\"" ~ col_name ~ "\", 0)::text) AS \"" ~ col_name ~ "\"") %}
                {% else %}
                    {% do select_parts.append('COALESCE("' ~ col_name ~ '", 0) AS "' ~ col_name ~ '"') %}
                {% endif %}

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
        {% do log('[mmgp] Tabela transformada: ' ~ target_schema_full ~ '.' ~ tabela, info=True) %}

    {% endfor %}
{% endif %}

-- Tabela de log: registra a execução do modelo mmgp
SELECT
    '{{ run_started_at }}'::timestamp AS execucao_at,
    '{{ raw_schema }}'                AS schema_origem,
    '{{ target_schema_full }}'        AS schema_destino
