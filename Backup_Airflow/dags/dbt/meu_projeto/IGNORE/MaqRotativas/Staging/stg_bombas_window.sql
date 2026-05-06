{{ config(
    materialized='ephemeral' 
) }}

WITH last_exec AS (
    select MAX(last_timestamp) AS last_timestamp
    from {{ ref('stg_maqRotativas_raw') }}
)
SELECT  
    i.*
    from {{ ref('stg_bombas_raw') }} i
    CROSS JOIN last_exec m
    WHERE i.dt > m.last_timestamp