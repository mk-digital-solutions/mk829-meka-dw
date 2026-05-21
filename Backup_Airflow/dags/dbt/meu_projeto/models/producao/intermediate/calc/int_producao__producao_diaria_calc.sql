{{ config(materialized='view') }}

with base as (
    select * from {{ ref('int_producao__producao_diaria_pivot') }}
),

com_deltas as (
    select
        dt,
        naoh_raw,
        agua_raw,
        cl2_raw,
        cl2_liquido_raw,
        demanda_raw,
        tensao_ff,
        fator_potencia,
        greatest(
            producao_soda_raw - lag(producao_soda_raw) over (order by dt),
            0
        ) as producao_soda,
        greatest(
            producao_hcl_raw - lag(producao_hcl_raw) over (order by dt),
            0
        ) as producao_hcl
    from base
)

select
    dt,
    producao_soda,
    producao_hcl,
    naoh_raw                                                        as vazao_naoh,
    case when agua_raw < 0 then 0 else agua_raw end                 as vazao_agua,
    case when cl2_raw < 1 then 0 else 1 end                         as cl2_on,
    demanda_raw / 1000.0                                            as demanda,
    tensao_ff,
    fator_potencia,
    case when cl2_liquido_raw < 0 then 0 else cl2_liquido_raw end   as cl2_liquido
from com_deltas
