{{ config(materialized='view') }}

with fonte_producao as (
    select data_hora, min(tag_value) as producao_raw
    from {{ ref('stg_producao_data') }}
    where tag_name = 'Producao_HCL'
      and tag_value >= 0
    group by data_hora
),

fonte_concentracao as (
    select data_hora, avg(tag_value) as concentracao
    from {{ ref('stg_producao_data') }}
    where tag_name = 'Concentracao_HCL'
    group by data_hora
),

fonte_capacidade as (
    select data_hora, max(tag_value) as fluxo_raw
    from {{ ref('stg_producao_data') }}
    where tag_name = 'FIC051025C\PV_IN'
    group by data_hora
),

timestamps as (
    select data_hora from fonte_producao
    union
    select data_hora from fonte_concentracao
    union
    select data_hora from fonte_capacidade
)

select
    ts.data_hora                        as dt,
    coalesce(fp.producao_raw, 0)        as producao_raw,
    coalesce(fc.concentracao, 0)        as concentracao,
    coalesce(fk.fluxo_raw, 0)           as fluxo_raw
from timestamps ts
left join fonte_producao   fp on ts.data_hora = fp.data_hora
left join fonte_concentracao fc on ts.data_hora = fc.data_hora
left join fonte_capacidade fk on ts.data_hora = fk.data_hora
