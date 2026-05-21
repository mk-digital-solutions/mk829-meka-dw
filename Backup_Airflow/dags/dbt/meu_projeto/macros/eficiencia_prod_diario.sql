{% macro eficiencia_prod_diario() %}

{#
  Replica acum_eficiencia_prod() como série diária.
  Internamente computa:
    - sensor_value : (MAX - MIN) de WQI13107_100\V × 100000
    - corrente_filtrada : avg_corrente_planta → 16 quando corrente >= 7
    - membrana_seconds : acum_membrana_on → forward fill de II113RC001\U
    - sum_cell : acum_sum_on_cell → intervalo × 91 com tensão + corrente válidos
    - n_cell : sum_cell / membrana_seconds, limitado a 92
    - eficiencia : sensor_value / (corrente_filtrada × 1.4923 × n_cell × horas_on × 100)
#}

with _corrente as (
    select
        date_trunc('day',    data_hora)::date as dt,
        date_trunc('minute', data_hora)       as dt_min,
        max(tag_value)                        as corrente
    from {{ ref('stg_producao_data') }}
    where tag_name = 'II113RC001\U'
    group by 1, 2
),

_tensao as (
    select
        date_trunc('day',    data_hora)::date as dt,
        date_trunc('minute', data_hora)       as dt_min,
        max(tag_value)                        as tensao
    from {{ ref('stg_producao_data') }}
    where tag_name = 'EI113RC001\U'
    group by 1, 2
),

_soda as (
    select
        date_trunc('day', data_hora)::date         as dt,
        (max(tag_value) - min(tag_value)) * 100000 as sensor_value
    from {{ ref('stg_producao_data') }}
    where tag_name = 'WQI13107_100\V'
    group by 1
),

-- avg_corrente_planta: retorna 16 para leituras com corrente >= 7
_avg_corrente as (
    select
        dt,
        avg(case when corrente >= 7 then 16 else null end) as corrente_filtrada
    from _corrente
    group by dt
),

-- membrana_on: forward fill de corrente, conta minutos > 2.8 → segundos
_limites as (
    select min(dt_min) as dt_inicio, max(dt_min) as dt_fim from _corrente
),
_serie as (
    select
        date_trunc('day', gs)::date as dt,
        gs                          as dt_min
    from _limites,
         generate_series(dt_inicio, dt_fim, interval '1 minute') gs
),
_ffill as (
    select
        s.dt,
        s.dt_min,
        max(c.corrente) filter (where c.corrente is not null)
            over (order by s.dt_min rows between unbounded preceding and current row)
            as corrente
    from _serie s
    left join _corrente c on s.dt_min = c.dt_min
),
_membrana as (
    select
        dt,
        count(*) filter (where corrente > 2.8) * 60.0 as segundos_on
    from _ffill
    group by dt
),

-- sum_on_cell: intervalo × 91 para (tensão > 227 AND corrente > 2.8)
_join_tc as (
    select
        c.dt,
        c.dt_min,
        case
            when t.tensao > 227 and c.corrente > 2.8 then t.tensao
            else null
        end as tensao_valida
    from _corrente c
    left join _tensao t on c.dt = t.dt and c.dt_min = t.dt_min
),
_intervalos as (
    select
        dt, dt_min,
        lag(dt_min)      over (partition by dt order by dt_min) as prev_dt_min,
        tensao_valida,
        lag(tensao_valida) over (partition by dt order by dt_min) as prev_tensao_valida
    from _join_tc
),
_sum_cell as (
    select
        dt,
        sum(
            case
                when tensao_valida is not null and prev_tensao_valida is not null
                then extract(epoch from (dt_min - prev_dt_min)) * 91
                else 0
            end
        ) as cell_segundos
    from _intervalos
    group by dt
),

-- n_cell: sum_cell / membrana_seconds, limitado a 92
_n_cell as (
    select
        sc.dt,
        case
            when (sc.cell_segundos / nullif(m.segundos_on, 0)) >= 90 then 92
            else sc.cell_segundos / nullif(m.segundos_on, 0)
        end as n_cell
    from _sum_cell sc
    left join _membrana m on sc.dt = m.dt
)

select
    s.dt::timestamptz as dt,
    s.sensor_value
        / nullif(
            ac.corrente_filtrada * 1.4923 * nc.n_cell * (m.segundos_on / 3600.0) * 100,
            0
        )                          as eficiencia
from _soda s
left join _avg_corrente ac on s.dt = ac.dt
left join _n_cell        nc on s.dt = nc.dt
left join _membrana       m on s.dt = m.dt

{% endmacro %}
