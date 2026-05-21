{{ config(materialized='ephemeral') }}

{% set var_inicio = var("ts_inicio", "") %}
{% set var_fim = var("ts_fim", "") %}

select
{% if var_inicio != "" and var_fim != "" %}
    -- Se o Airflow mandar os parâmetros, usamos eles
    '{{ var_fim }}'::timestamptz as end_time,
    '{{ var_inicio }}'::timestamptz as start_time
{% else %}
    -- Plano B: Lemos da FONTE FÍSICA para quebrar a dependência circular
    -- Usamos 'dt' porque é o nome original na tabela 'inspections'
    max(dt) as end_time,
    max(dt) - interval '12 hours' as start_time
from {{ source('variables', 'inspections') }}
{% endif %}