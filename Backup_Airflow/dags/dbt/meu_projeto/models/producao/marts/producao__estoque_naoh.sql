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
)

select
    c.dt,
    c.nivel_total,
    c.status
from {{ ref('int_producao__estoque_naoh_calc') }} c
cross join tw

{% if is_incremental() %}
  where c.dt > (select coalesce(max(dt), '1900-01-01'::timestamptz) from {{ this }})
{% endif %}