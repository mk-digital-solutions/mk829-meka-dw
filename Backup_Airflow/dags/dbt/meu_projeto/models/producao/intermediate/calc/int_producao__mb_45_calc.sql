{{ config(materialized='view') }}

-- Dados básicos da planta: tensão média, corrente e performance diária (disponibilidade e eficiência).
-- A tensão média é calculada dividindo a soma da tensão por 92 eletrodos (zerada quando a planta está desligada).
-- Disponibilidade e eficiência são unidas por date_trunc(day) pois têm granularidade diária.

with base as (
    select
        dt,
        soma_tensao,
        planta_membrana_ligada,
        corrente
    from {{ ref('int_producao__mb_45_pivot') }}
),

_membrana as (
    select dt, horas_on, segundos_on
    from {{ ref('util_producao__mb_45_membrana_on') }}
),

_efic as (
    select dt, eficiencia
    from {{ ref('util_producao__producao_cl2_base') }}
)

select
    b.dt,
    case
        when b.planta_membrana_ligada = 1 then b.soma_tensao / 92.0 -- tensão média por eletrodo
        else 0
    end                                              as tensao_media,
    b.corrente,
    case when b.corrente > 3 then 1 else 0 end       as status,
    m.horas_on,
    least(m.horas_on / 24.0 * 100.0, 100.0)         as disponibilidade,
    coalesce(e.eficiencia * 100.0, 0)                as eficiencia
from base b
left join _membrana m on date_trunc('day', b.dt) = m.dt
left join _efic     e on date_trunc('day', b.dt) = e.dt
