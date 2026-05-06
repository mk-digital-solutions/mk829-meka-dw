{{ config(materialized='table') }}

with sensor_measurement as (
    -- Delta real de produção sem o multiplicador exagerado
    select 
        (max(wqi) - min(wqi)) as sensor_value
    from {{ ref('int_iba_pivot_minute') }}
),

componentes as (
    select
        c.media_filtrada as corrente_filtrada,
        n.total_weighted_duration,
        m.segundos_on / 3600.0 as hours_on
        
    from {{ ref('avg_corrente') }} c 
    cross join {{ ref('Acumulado_n_cell_dia') }} n
    cross join {{ ref('sum_on') }} m
)

select
    s.sensor_value,
    comp.corrente_filtrada,
    comp.total_weighted_duration,
    comp.hours_on,
    
    -- A mágica matemática: 
    -- total_weighted_duration já é (Segundos * 91 Células). 
    -- Dividindo por 3600, vira (Horas * 91 Células).
    (s.sensor_value / 
        nullif(comp.corrente_filtrada * 1.4923 * (comp.total_weighted_duration / 3600.0), 0)
    )::numeric as efic_prod

from sensor_measurement s
cross join componentes comp