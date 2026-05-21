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

select
    p.dt,
    p.corrente,
    p.capacidade,
    p.pressao_descarga,
    p.temp_descarga,
    p.pressao_oleo,
    p.temp_oleo,
    p.superaquecimento_aspiracao,
    p.pressao_aspiracao,
    p.temp_processo,
    p.temp_aspiracao
from {{ ref('int_compressao_liquefacao__comp_sabroe_1_pivot') }} p

{% if is_incremental() %}
  where p.dt > (select coalesce(max(dt), '1900-01-01'::timestamptz) from {{ this }})
{% endif %}
