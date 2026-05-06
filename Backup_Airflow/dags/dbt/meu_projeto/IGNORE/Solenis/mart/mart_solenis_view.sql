{{ config(materialized='view') }}

with dados_calculados as (
    select * from {{ ref('int_solenis_calc') }}
),

totais_dia as (
    select
        *,
        -- Acumulados de Tempo (Minutos)
        sum(tempo_sem_cloro) over (partition by date(data_hora) order by data_hora) as sum_tempo_sem_cloro,
        sum(tempo_sem_vapor) over (partition by date(data_hora) order by data_hora) as sum_tempo_sem_vapor,
        sum(tempo_sem_soda) over (partition by date(data_hora) order by data_hora) as sum_tempo_sem_soda,

        -- Acumulados de Consumo/Venda (Unidades)
        sum(acumulado_cl2_minuto) over (partition by date(data_hora) order by data_hora) as sum_venda_cloro_dia,
        sum(acumulado_soda_minuto) over (partition by date(data_hora) order by data_hora) as sum_venda_soda_dia,
        sum(acumulado_vapor_minuto) over (partition by date(data_hora) order by data_hora) as sum_venda_vapor_dia
    from dados_calculados
)

select 
    data_hora,
    venda_cloro,
    venda_vapor,
    venda_soda,
    -- Totais de tempo sem venda
    sum_tempo_sem_cloro,
    sum_tempo_sem_vapor,
    sum_tempo_sem_soda,
    -- Totais de consumo acumulado
    sum_venda_cloro_dia,
    sum_venda_soda_dia,
    sum_venda_vapor_dia
from totais_dia
order by data_hora desc
limit 1