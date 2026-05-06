{{ config(
    materialized='incremental',
    post_hook="SELECT create_hypertable('{{ this }}', 'data_hora', if_not_exists => TRUE, migrate_data => TRUE);"
) }}


with limites as (
    select start_time, end_time from {{ ref('stg_iba_time_window') }}
),

tags_alvo as (
    -- Usamos o dbt para injetar a lista de tags de forma limpa.
    -- O 'default' entra em ação se você não configurar a variável no seu dbt_project.yml
    select id, description
    from {{ source('variables', 'params') }}
    where description in (
        'FI01507\\U',
        'FIC076012\\PV_IN',
        'Soda_solenis',
        'Cl2_solenis',
        'Vapor_solenis',
        'Producao_Hcl',
        'Concentracao_HCL',
        'FIC051025C\PV_IN',
        'Peso%Tanque%0%'
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

-- Lógica para evitar duplicatas nas próximas execuções (opcional, mas recomendado)
{% if is_incremental() %}
  and i.dt > (select coalesce(max(data_hora), '1900-01-01') from {{ this }})
{% endif %}