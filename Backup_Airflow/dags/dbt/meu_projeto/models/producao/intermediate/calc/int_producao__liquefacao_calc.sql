{{ config(materialized='view') }}

with base as (
    select *
    from {{ ref('int_producao__liquefacao_pivot') }}
    where peso_bruto between -900 and 130000
),

com_slope as (
    select
        dt,
        tanque,
        status_cpc_a,
        status_cpc_b,
        status_cpc_c,
        status_cpc_3,
        cap_sabroe_01,
        cap_sabroe_02,
        regr_slope(
            peso_bruto,
            extract(epoch from dt)
        ) over (
            partition by tanque
            order by dt
            rows between 9 preceding and current row
        ) * 3600 as taxa_compressao
    from base
),

filtrado as (
    select *
    from com_slope
    where taxa_compressao is not null
      and taxa_compressao < 4500
)

select
    dt,
    max(case when tanque = 'Peso Tanque de Cloro 01' then taxa_compressao end) as cpc_tanque_01,
    max(case when tanque = 'Peso Tanque de Cloro 02' then taxa_compressao end) as cpc_tanque_02,
    max(case when tanque = 'Peso Tanque de Cloro 03' then taxa_compressao end) as cpc_tanque_03,
    max(case when tanque = 'Peso Tanque de Cloro 04' then taxa_compressao end) as cpc_tanque_04,
    max(case when tanque = 'Peso Tanque de Cloro 05' then taxa_compressao end) as cpc_tanque_05,
    max(case when tanque = 'Peso Tanque de Cloro 06' then taxa_compressao end) as cpc_tanque_06,
    max(status_cpc_a)  as status_cpc_a,
    max(status_cpc_b)  as status_cpc_b,
    max(status_cpc_c)  as status_cpc_c,
    max(status_cpc_3)  as status_cpc_3,
    max(cap_sabroe_01) as cap_sabroe_01,
    max(cap_sabroe_02) as cap_sabroe_02,
    case when
        coalesce(max(status_cpc_a),  0) + coalesce(max(status_cpc_b),  0)
      + coalesce(max(status_cpc_c),  0) + coalesce(max(status_cpc_3),  0)
      + coalesce(max(cap_sabroe_01), 0) + coalesce(max(cap_sabroe_02), 0) > 0
    then 1 else 0 end  as status
from filtrado
group by dt
order by dt
