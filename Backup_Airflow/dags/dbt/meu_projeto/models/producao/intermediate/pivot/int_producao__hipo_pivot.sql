{{ config(materialized='view') }}

with fonte_naclo as (
    select data_hora, max(tag_value) as naclo_raw
    from {{ ref('stg_producao_data') }}
    where tag_name = 'FI_NaCl0\U'
    group by data_hora
),

fonte_naoh as (
    select data_hora, max(tag_value) as naoh_raw
    from {{ ref('stg_producao_data') }}
    where tag_name = 'FIC12702\PV_IN'
    group by data_hora
),

fonte_agua as (
    select data_hora, max(tag_value) as agua_raw
    from {{ ref('stg_producao_data') }}
    where tag_name = 'FIC12703\PV_IN'
    group by data_hora
),

fonte_cl2 as (
    select data_hora, max(tag_value) as cl2_raw
    from {{ ref('stg_producao_data') }}
    where tag_name = 'FIC12718\MV'
    group by data_hora
),

timestamps as (
    select data_hora from fonte_naclo
    union
    select data_hora from fonte_naoh
    union
    select data_hora from fonte_agua
    union
    select data_hora from fonte_cl2
)

select
    ts.data_hora                        as dt,
    coalesce(fn.naclo_raw,  0)          as naclo_raw,
    coalesce(fn2.naoh_raw,  0)          as naoh_raw,
    coalesce(fa.agua_raw,   0)          as agua_raw,
    coalesce(fc.cl2_raw,    0)          as cl2_raw
from timestamps ts
left join fonte_naclo fn  on ts.data_hora = fn.data_hora
left join fonte_naoh  fn2 on ts.data_hora = fn2.data_hora
left join fonte_agua  fa  on ts.data_hora = fa.data_hora
left join fonte_cl2   fc  on ts.data_hora = fc.data_hora
