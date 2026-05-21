{{ config(materialized='view') }}

select
    data_hora as dt,
    tag_name   as tanque,
    tag_value  as peso_bruto
from {{ ref('stg_producao_data') }}
where tag_name like 'Peso%Tanque%0%'
