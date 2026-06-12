-- dbt/models/cronogramas_int/banco_int.sql

{{ config(
    materialized='table',
    schema='_int_cronogramas',
    alias='fct_banco'
) }}

{% set debug = var('modo_debug', False) %}

-- 'Valor_entregue__Cliente_' já vem como NUMERIC da camada staging (banco_stg),
-- portanto não é mais necessário limpar o formato BR aqui. Repasse direto.
SELECT *
FROM {{ ref('banco_stg') }}
