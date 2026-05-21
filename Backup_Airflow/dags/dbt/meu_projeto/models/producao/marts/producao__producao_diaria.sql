{{ config(
    materialized='incremental',
    unique_key='dt',
    post_hook=[
      "SELECT create_hypertable('{{ this }}', 'dt', chunk_time_interval => interval '1 day', if_not_exists => TRUE, migrate_data => TRUE)",
      "ALTER TABLE {{ this }} SET (timescaledb.compress, timescaledb.compress_orderby = 'dt DESC')",
      "SELECT add_compression_policy('{{ this }}', INTERVAL '7 days', if_not_exists => TRUE)",
      "SELECT add_retention_policy('{{ this }}', INTERVAL '30 days', if_not_exists => TRUE)"
    ]
) }}

with tw as (
    select start_time, end_time from {{ ref('stg_time_window') }}
),

producao as (
    select dt, producao_cl2 / 1000.0 as producao_cl2, plan_diario
    from {{ ref('util_producao__producao_cl2_base') }}
),

kwh as (
    select dt, value as kwh_diario
    from dashboard.geral_hist
    where description = 'total_kwh_diario'
)

select
    c.dt,
    c.producao_soda,
    c.producao_hcl,
    c.vazao_naoh,
    c.vazao_agua,
    c.cl2_on,
    c.cl2_liquido,
    c.demanda,
    c.tensao_ff,
    c.fator_potencia,
    coalesce(pr.producao_cl2, 0)                                                          as producao_cl2,
    coalesce(pr.plan_diario,  0)                                                          as plan_diario,
    coalesce(k.kwh_diario,    0)                                                          as kwh_diario,
    ceil(coalesce(k.kwh_diario, 0) / nullif(coalesce(pr.producao_cl2, 0), 0))             as kwh_por_ton
from {{ ref('int_producao__producao_diaria_calc') }} c
cross join tw
left join producao pr on date_trunc('day', c.dt) = pr.dt
left join kwh      k  on date_trunc('day', c.dt) = date_trunc('day', k.dt)

{% if is_incremental() %}
  where c.dt > (select coalesce(max(dt), '1900-01-01'::timestamptz) from {{ this }})
{% endif %}
