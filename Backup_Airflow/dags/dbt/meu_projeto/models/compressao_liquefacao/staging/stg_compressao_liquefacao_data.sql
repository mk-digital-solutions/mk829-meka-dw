{{ config(materialized='view') }}

with limites as (
    select start_time, end_time from {{ ref('stg_time_window') }}
),

tags_alvo as (
    select id, description
    from {{ source('variables', 'params') }}
    where description in (
        -- Sabroe 01
        'Corrente - Sabroe 01',
        'Capacidade - Sabroe 01',
        'Pressão de Descarga - Sabroe 01',
        'Temperatura de Descarga - Sabroe 01',
        'Pressão de Óleo - Sabroe 01',
        'Temperatura do Óleo - Sabroe 01',
        'Superaquecimento de Aspiração - Sabroe 01',
        'Pressão de Aspiração - Sabroe 01',
        'Temperatura de Processo - Sabroe 01',
        'Temperatura de Aspiração - Sabroe 01',
        -- Sabroe 02
        'Corrente - Sabroe 02',
        'Capacidade - Sabroe 02',
        'Pressão de Descarga - Sabroe 02',
        'Temperatura de Descarga - Sabroe 02',
        'Pressão de Óleo - Sabroe 02',
        'Temperatura do Óleo - Sabroe 02',
        'Superaquecimento de Aspiração - Sabroe 02',
        'Pressão de Aspiração - Sabroe 02',
        'Temperatura de Processo - Sabroe 02',
        'Temperatura de Aspiração - Sabroe 02'
    )
)

select
    i.dt as data_hora,
    t.description as tag_name,
    i.value as tag_value

from {{ source('variables', 'inspections') }} i
cross join limites l
inner join tags_alvo t on i.id_param_fk = t.id

where i.dt >= l.start_time
  and i.dt <= l.end_time
