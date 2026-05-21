{{ config(materialized='view') }}

with fonte_cloro as (
    select data_hora, max(tag_value) as venda_cloro
    from {{ ref('stg_producao_data') }}
    where tag_name = 'FI01507\U'
    group by data_hora
),

fonte_vapor as (
    select data_hora, max(tag_value) as venda_vapor
    from {{ ref('stg_producao_data') }}
    where tag_name = 'FIC076012\PV_IN'
    group by data_hora
),

fonte_soda as (
    select data_hora, max(tag_value) as venda_soda
    from {{ ref('stg_producao_data') }}
    where tag_name = 'Soda_solenis'
    group by data_hora
),

timestamps as (
    select data_hora from fonte_cloro
    union
    select data_hora from fonte_vapor
    union
    select data_hora from fonte_soda
)

select
    ts.data_hora                            as dt,
    coalesce(fc.venda_cloro, 0)             as venda_cloro,
    coalesce(fv.venda_vapor, 0)             as venda_vapor,
    coalesce(fs.venda_soda,  0)             as venda_soda
from timestamps ts
left join fonte_cloro fc on ts.data_hora = fc.data_hora
left join fonte_vapor fv on ts.data_hora = fv.data_hora
left join fonte_soda  fs on ts.data_hora = fs.data_hora
