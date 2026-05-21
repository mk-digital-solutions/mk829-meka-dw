{{ config(materialized='view') }}

-- Soma o peso de todos os tanques válidos por timestamp e converte g → ton (÷1000).
with base as (
    select dt,
           sum(case when peso_bruto between -900 and 130000 then peso_bruto else 0 end) as peso_total_g
    from {{ ref('int_producao__estoque_cloro_pivot') }}
    group by dt
)

select
    dt,
    peso_total_g / 1000.0                              as peso_total_ton,
    case when peso_total_g / 1000.0 > 0 then 1 else 0 end as status
from base
