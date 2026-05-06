{{ config(
    materialized='incremental',
    unique_key='dt',
    on_schema_change='sync_all_columns'
) }}

with limites as (
    -- 1. Aqui está o segredo: Pegamos os limites que a macro definiu
    -- Se o Airflow mandou uma data retroativa, o 'end_time' será essa data.
    select start_time, end_time from {{ ref('stg_iba_time_window') }}
),

dados_janela as (
    -- 2. Buscamos o último dado DENTRO da janela para o cálculo do t_total
    select 
        max(data_hora) as last_signal_dt
    from {{ ref('stg_iba_data_raw') }}
    cross join limites l
    where data_hora between l.start_time and l.end_time
),

metricas as (
    -- 3. Cruzamos com os Marts que já foram filtrados pela mesma macro
    select
        m.segundos_on as t_operacao,
        e.efic_prod as eficiencia_decimal,
        l.start_time,
        l.end_time,
        d.last_signal_dt
    from {{ ref('sum_on') }} m
    cross join {{ ref('mart_eficiencia_prod') }} e
    cross join limites l
    cross join dados_janela d
),

calculo_final as (
    select
        -- t_total: tempo do início da janela até o último sinal recebido nela
        extract(epoch from (last_signal_dt - start_time)) as t_total,
        t_operacao,
        eficiencia_decimal * 100 as eficiencia,
        -- Usamos o end_time da janela como a chave de tempo (âncora)
        end_time as dt_referencia
    from metricas
)

select
    dt_referencia as dt,
    eficiencia as "EFIC",
    case 
        when t_operacao > t_total then 100 
        else (t_operacao / nullif(t_total, 0)) * 100 
    end as "DISP"
from calculo_final

{% if is_incremental() %}
  -- No modo incremental, o dbt só insere se o DT for novo.
  -- Isso permite processar janelas do passado sem duplicar.
  where dt_referencia not in (select dt from {{ this }})
{% endif %}