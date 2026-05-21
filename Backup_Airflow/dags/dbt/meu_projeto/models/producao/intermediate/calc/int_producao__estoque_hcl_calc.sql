{{ config(materialized='view') }}

with base as (
    select dt,
           sum(case when nivel_bruto between -900 and 130000 then nivel_bruto else 0 end) as nivel_total_bruto
    from {{ ref('int_producao__estoque_hcl_pivot') }}
    group by dt
)

select
    dt,
    nivel_total_bruto * 0.95                              as nivel_total,
    case when nivel_total_bruto * 0.95 > 0 then 1 else 0 end as status
from base
