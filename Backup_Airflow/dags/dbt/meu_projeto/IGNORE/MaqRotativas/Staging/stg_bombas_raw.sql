{{ config(
    materialized='ephemeral' 
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
    where description LIKE '%Feedback de %peracao'
)

select
    i.dt as dt,
    substring(t.description from '(\d{3}[PK]\d{3}[A-C]?)') as tag,
    (i.value::bigint & 32) >> 5 as fb_on,
    (i.value::bigint & 8) >> 3 as fb_falha

from {{ source('variables', 'inspections') }} i
cross join limites l
inner join tags_alvo t on i.id_param_fk = t.id

where i.dt >= l.start_time 
  and i.dt <= l.end_time
