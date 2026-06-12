-- dbt/models/cronogramas_int/atividades_int.sql

{{ config(
    materialized='table',
    schema='_int_cronogramas',
    alias='fct_atividades'
) }}

{% set debug = var('modo_debug', False) %}

SELECT *
FROM {{ ref('atividades_stg') }}
