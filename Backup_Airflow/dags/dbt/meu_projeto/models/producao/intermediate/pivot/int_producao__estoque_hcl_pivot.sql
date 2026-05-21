{{ config(materialized='view') }}

select
    data_hora as dt,
    tag_name   as sensor,
    tag_value  as nivel_bruto
from {{ ref('stg_producao_data') }}
where tag_name like 'READ_TRANSMITERS\LI0510%.PV'
