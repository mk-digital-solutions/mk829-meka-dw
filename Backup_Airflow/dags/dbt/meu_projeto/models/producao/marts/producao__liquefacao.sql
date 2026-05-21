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

{{ config(materialized='incremental', unique_key='dt') }}

with tw as (
    select start_time, end_time from {{ ref('stg_time_window') }}
)

select
    c.dt,
    c.cpc_tanque_01,
    c.cpc_tanque_02,
    c.cpc_tanque_03,
    c.cpc_tanque_04,
    c.cpc_tanque_05,
    c.cpc_tanque_06,
    c.status_cpc_a,
    c.status_cpc_b,
    c.status_cpc_c,
    c.status_cpc_3,
    c.cap_sabroe_01,
    c.cap_sabroe_02,
    c.status
from {{ ref('int_producao__liquefacao_calc') }} c
cross join tw

{% if is_incremental() %}
  where c.dt > (select coalesce(max(dt), '1900-01-01'::timestamptz) from {{ this }})
{% endif %}