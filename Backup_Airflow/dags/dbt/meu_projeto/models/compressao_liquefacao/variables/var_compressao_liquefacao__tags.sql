{{ config(materialized='view') }}

select distinct
    regexp_replace(tag_name, ' - Sabroe (01|02)$', '', 'g') as tags
from {{ ref('stg_compressao_liquefacao_data') }}
where tag_name ~* '^(Pressão|Temperatura|Superaquecimento).*Sabroe (01|02)$'
order by 1
