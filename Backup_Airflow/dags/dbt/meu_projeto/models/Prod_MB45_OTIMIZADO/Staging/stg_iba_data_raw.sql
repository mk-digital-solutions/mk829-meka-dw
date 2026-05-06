{{ config(
    materialized='table' 
) }}
-- ephemeral: Não cria tabela no banco. Injeta o SQL direto nos próximos modelos.
with limites as (
    select start_time, end_time from {{ ref('stg_iba_time_window') }}
),

tags_alvo as (
    -- Usamos o dbt para injetar a lista de tags de forma limpa.
    -- O 'default' entra em ação se você não configurar a variável no seu dbt_project.yml
    select id, description
    from {{ source('variables', 'params') }}
    where description in (
        '{{ var("tag_corrente", "II113RC001\\U") }}',
        '{{ var("tag_wqi", "WQI13107_100\\V") }}',
        '{{ var("tag_sum_cell", "EI113RC001\\U") }}'
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