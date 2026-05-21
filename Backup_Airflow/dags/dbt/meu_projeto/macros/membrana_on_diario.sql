{% macro membrana_on_diario() %}

{#
  Replica acum_membrana_on() como série temporal diária.
  Lógica: gera todos os minutos do período, forward-fill da corrente (II113RC001\U),
  conta os minutos em que corrente > 2.8 e converte para horas.
  Lê de stg_producao_data para manter-se dentro do pipeline dbt.
#}

with _leituras as (
    select
        date_trunc('minute', data_hora) as dt_min,
        max(tag_value)                  as corrente
    from {{ ref('stg_producao_data') }}
    where tag_name = 'II113RC001\U'
    group by 1
),

_limites as (
    select
        min(dt_min) as dt_inicio,
        max(dt_min) as dt_fim
    from _leituras
),

_serie as (
    select
        date_trunc('day', gs)::timestamptz as dt,
        gs                                 as dt_min
    from _limites,
         generate_series(dt_inicio, dt_fim, interval '1 minute') gs
),

_ffill as (
    select
        s.dt,
        s.dt_min,
        max(l.corrente) filter (where l.corrente is not null)
            over (order by s.dt_min rows between unbounded preceding and current row)
            as corrente
    from _serie s
    left join _leituras l on s.dt_min = l.dt_min
)

select
    dt,
    count(*) filter (where corrente > 2.8) * 60.0  as segundos_on,
    count(*) filter (where corrente > 2.8) / 60.0  as horas_on
from _ffill
group by dt

{% endmacro %}
