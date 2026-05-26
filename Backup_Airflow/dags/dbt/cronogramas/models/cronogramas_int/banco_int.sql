-- dbt/models/cronogramas_int/banco_int.sql

{{ config(
    materialized='table',
    schema='_int_cronogramas',
    alias='fct_banco'
) }}

{% set stg_schema = var('stg_schema', 'stg_cronogramas') %}
{% set debug = var('modo_debug', False) %}

SELECT *
FROM {{ stg_schema }}."fct_banco"
