-- dbt/models/planilhas_stg/planilhas_stg.sql

{{ config(
    materialized='table',
    schema='_stg_planilhas',
    alias='planilhas_log_execucao'
) }}

{% set raw_schema = var('raw_schema', 'raw_planilhas') %}
{% set target_schema_full = var('target_schema', 'stg_planilhas') %}
{% set debug = var('modo_debug', False) %}

{# ------------------------------------------------------------------
   1. Garante a existência do schema de destino (stg_planilhas)
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

    {# 3. Recria cada tabela no schema de destino, convertendo o tipo de cada
          coluna de negócio conforme os dados reais (varchar -> numeric/date;
          texto permanece varchar). As colunas geradas pelo Airbyte (_airbyte_*)
          são repassadas intactas. A detecção de tipo é feita amostrando os
          valores (ver macros/conversao_tipos.sql). #}
    {% for tabela in tabelas %}

        {% set cols_query %}
            SELECT column_name
            FROM information_schema.columns
            WHERE table_schema = '{{ raw_schema }}'
              AND table_name = '{{ tabela }}'
            ORDER BY ordinal_position
        {% endset %}

        {% set colunas_airbyte = [] %}
        {% set colunas_negocio = [] %}
        {% for row in run_query(cols_query).rows %}
            {% if row[0].startswith('_airbyte') %}
                {% do colunas_airbyte.append(row[0]) %}
            {% else %}
                {% do colunas_negocio.append(row[0]) %}
            {% endif %}
        {% endfor %}

        {% set src = raw_schema ~ '."' ~ tabela ~ '"' %}
        {% set select_parts = [] %}
        {% for col in colunas_airbyte %}
            {% do select_parts.append('"' ~ col ~ '"') %}
        {% endfor %}
        {% for expr in conv__lista_select(src, colunas_negocio) %}
            {% do select_parts.append(expr) %}
        {% endfor %}

        {% set ddl_select = 'SELECT ' ~ (select_parts | join(', ')) ~ ' FROM ' ~ src %}

        {% set ddl_drop = 'DROP TABLE IF EXISTS ' ~ target_schema_full ~ '."' ~ tabela ~ '" CASCADE' %}
        {% set ddl_create = 'CREATE TABLE ' ~ target_schema_full ~ '."' ~ tabela ~ '" AS ' ~ ddl_select %}

        {% do run_query(ddl_drop) %}
        {% do run_query(ddl_create) %}
        {% do log('[planilhas] Tabela em stg: ' ~ target_schema_full ~ '.' ~ tabela, info=True) %}

    {% endfor %}
{% endif %}

-- Tabela de log: registra a execução do modelo planilhas_stg
SELECT
    '{{ run_started_at }}'::timestamp AS execucao_at,
    '{{ raw_schema }}'                AS schema_origem,
    '{{ target_schema_full }}'        AS schema_destino
