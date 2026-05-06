{{ config(materialized='table') }}

with dados_brutos as (
    select * from {{ ref('int_solenis_pivot') }}
),

calculos_base as (
    select
        data_hora,
        -- Vendas instantâneas (tratando negativos)
        case when fi01507 < 0 then 0 else fi01507 end as venda_cloro,
        case when fic076012 < 0 then 0 else (fic076012/1000) end as venda_vapor,
        case when soda_solenis < 0 then 0 else (soda_solenis/1000) end as venda_soda,

        -- Tags originais para deltas
        soda_solenis,
        cl2_solenis,
        vapor_solenis
    from dados_brutos
),

calculo_deltas as (
    select
        *,
        greatest(cl2_solenis - lag(cl2_solenis) over (order by data_hora), 0) as delta_cl2_bruto,
        greatest(soda_solenis - lag(soda_solenis) over (order by data_hora), 0) as delta_soda_bruto,
        greatest(vapor_solenis - lag(vapor_solenis) over (order by data_hora), 0) as delta_vapor_bruto
    from calculos_base
),

flags_e_metricas as (
    select
        *,
        -- FLAGS DE TEMPO SEM VENDA
        case when venda_cloro <= 0.2 then 1 else 0 end as tempo_sem_cloro,
        case when venda_vapor <= 0 then 1 else 0 end as tempo_sem_vapor,
        case when venda_soda <= 0 then 1 else 0 end as tempo_sem_soda, -- Adicionado

        -- ACUMULADOS POR MINUTO (Com filtros de ruído/picos)
        case when delta_cl2_bruto <= 1 then delta_cl2_bruto else 0 end as acumulado_cl2_minuto,
        case when delta_soda_bruto < 1000 then delta_soda_bruto else 0 end as acumulado_soda_minuto,
        case when delta_vapor_bruto < 1000 then delta_vapor_bruto else 0 end as acumulado_vapor_minuto
    from calculo_deltas
)

select 
data_hora,
venda_cloro,
venda_vapor,
venda_soda,
tempo_sem_cloro,
tempo_sem_vapor,
tempo_sem_soda,
acumulado_cl2_minuto,
acumulado_vapor_minuto,
acumulado_soda_minuto
 from flags_e_metricas