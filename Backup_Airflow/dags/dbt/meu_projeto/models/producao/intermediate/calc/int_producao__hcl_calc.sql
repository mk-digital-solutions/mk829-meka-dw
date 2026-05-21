{{ config(materialized='view') }}

with base as (
    select * from {{ ref('int_producao__hcl_pivot') }}
),

with_delta as (
    select
        dt,
        concentracao,
        greatest(
            producao_raw - lag(producao_raw) over (order by dt),
            0
        )                                                           as producao_hcl,
        case when fluxo_raw > 0 then fluxo_raw / 495.0 else 0 end  as capacidade_atual
    from base
)

select
    dt,
    producao_hcl,
    concentracao,
    capacidade_atual,
    case when producao_hcl > 0 then 1 else 0 end as status
from with_delta
