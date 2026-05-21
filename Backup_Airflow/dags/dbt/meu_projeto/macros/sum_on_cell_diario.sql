{% macro sum_on_cell_diario() %}

{#
  Replica acum_sum_on_cell() como série diária.
  Une EI113RC001\U (tensão) e II113RC001\U (corrente) por minuto.
  Filtra apenas intervalos válidos (tensão > 227 AND corrente > 2.8).
  Soma (duração_intervalo_segundos × 91 células) por dia.
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

_join as (
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
        dt,
        dt_min,
        lag(dt_min) over (partition by dt order by dt_min) as prev_dt_min,
        tensao_valida,
        lag(tensao_valida) over (partition by dt order by dt_min) as prev_tensao_valida
    from _join
)

select
    dt::timestamptz as dt,
    sum(
        case
            when tensao_valida is not null and prev_tensao_valida is not null
            then extract(epoch from (dt_min - prev_dt_min)) * 91
            else 0
        end
    ) as cell_segundos
from _intervalos
group by dt

{% endmacro %}
