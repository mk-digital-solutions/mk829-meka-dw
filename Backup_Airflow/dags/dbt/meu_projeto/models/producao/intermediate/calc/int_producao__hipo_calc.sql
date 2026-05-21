{{ config(materialized='view') }}

with base as (
    select * from {{ ref('int_producao__hipo_pivot') }}
),

calculado as (
    select
        dt,
        case when naclo_raw >= 0 then naclo_raw / 60000.0 else 0 end    as naclo,
        case when naoh_raw  < 0  then 0 else naoh_raw * 357.0           end as consumo_naoh,
        naoh_raw * (350.0 / 15)                                          as capacidade,
        case when agua_raw  <= 0 then 0 else agua_raw                    end as vazao_agua,
        case when naoh_raw  < 0  then 0 else naoh_raw                   end as naoh_valid,
        case when cl2_raw   >= 1 then 1 else 0                          end as cl2_on
    from base
)

select
    dt,
    naclo,
    consumo_naoh,
    capacidade,
    vazao_agua,
    cl2_on,
    (consumo_naoh * 1560 + vazao_agua * 1210) / 60000.0                 as consumo_cloro,
    (naoh_valid * 1560 + vazao_agua * 1210) * cl2_on / 60000.0          as producao_hipo_ton
from calculado
