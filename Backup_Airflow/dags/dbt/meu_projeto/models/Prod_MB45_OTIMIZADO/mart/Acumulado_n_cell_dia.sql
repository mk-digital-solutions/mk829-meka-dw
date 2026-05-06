{{ config(materialized='table') }}

with limites as (
    -- Puxamos o ts_inicio e ts_fim da janela atual
    select 
        start_time as ts_inicio, 
        end_time as ts_fim 
    from {{ ref('stg_iba_time_window') }}
)

select
    sum(
        case 
            when p.tensao > 227 and p.corrente > 2.8 
            -- Substituído exatamente como você pediu:
            then extract(epoch from (l.ts_fim - l.ts_inicio)) 
            else 0 
        end
    ) * 91 as total_weighted_duration

from {{ ref('int_iba_pivot_minute') }} p
cross join limites l