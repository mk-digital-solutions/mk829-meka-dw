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

with calc as (
    select dt, corrente, tensao_media, horas_on, disponibilidade, eficiencia, status
    from {{ ref('int_producao__mb_45_calc') }}
),

producao as (
    select dt, producao_cl2, plan_diario
    from {{ ref('util_producao__producao_cl2_base') }}
)

select
    c.dt,
    c.corrente,
    c.tensao_media,
    c.horas_on,
    c.disponibilidade,
    c.eficiencia,
    c.status,
    pr.producao_cl2,
    pr.plan_diario
from calc c
left join producao pr on date_trunc('day', c.dt) = pr.dt

{% if is_incremental() %}
  where c.dt > (select coalesce(max(dt), '1900-01-01'::timestamptz) from {{ this }})
{% endif %}