{{ config(materialized='view') }}

with source_data as (
    select data_hora, tag_name, tag_value
    from {{ ref('stg_iba_data_prod') }} 
    where tag_name in (
        'FI01507\\U', 
        'FIC076012\\PV_IN', 
        'Soda_solenis', 
        'Cl2_solenis', 
        'Vapor_solenis'
    )
)

select
    data_hora,
    -- O COALESCE garante que se o MAX for NULL, o resultado será 0
    coalesce(max(case when tag_name = 'FI01507\\U' then tag_value end), 0) as fi01507,
    coalesce(max(case when tag_name = 'FIC076012\\PV_IN' then tag_value end), 0) as fic076012,
    coalesce(max(case when tag_name = 'Soda_solenis' then tag_value end), 0) as soda_solenis,
    coalesce(max(case when tag_name = 'Cl2_solenis' then tag_value end), 0) as cl2_solenis,
    coalesce(max(case when tag_name = 'Vapor_solenis' then tag_value end), 0) as vapor_solenis
from source_data
group by data_hora