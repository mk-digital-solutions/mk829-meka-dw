{{ config(
    materialized='ephemeral' 
) }}

SELECT DISTINCT ON (tag)
    last_timestamp, 
    tag, 
    area, 
    status, 
    tempo_atual, 
    tempo_ok, 
    tempo_falha,
    n_falhas,
    mtbf, 
    mttr
FROM {{ source('variables', 'maquinas_rotativas') }}
order by tag, last_timestamp desc