{{ config(materialized='table') }}

{% set query_limites %}
    select start_time, end_time from {{ ref('stg_iba_time_window') }}
{% endset %}

{% set resultados = run_query(query_limites) %}

{% if execute and resultados | length > 0 %}
    {% set inicio_txt = resultados.columns[0].values()[0] %}
    {% set fim_txt = resultados.columns[1].values()[0] %}
{% else %}
    {% set inicio_txt = '2000-01-01 00:00:00' %}
    {% set fim_txt = '2000-01-01 01:00:00' %}
{% endif %}

select
    time_bucket_gapfill(
        '1 minute', 
        i.dt, 
        '{{ inicio_txt }}'::timestamptz, 
        '{{ fim_txt }}'::timestamptz
    ) as data_hora,

    locf(
        avg(i.value) FILTER (WHERE t.description = '{{ var("tag_corrente", "II113RC001\\U") }}')
    ) as corrente,
    
    -- *** ADICIONE ESTE BLOCO AQUI ***
    locf(
        avg(i.value) FILTER (WHERE t.description = '{{ var("tag_tensao", "EI113RC001\\U") }}')
    ) as tensao,
    -- ********************************

    locf(
        avg(i.value) FILTER (WHERE t.description = '{{ var("tag_wqi", "WQI13107_100\\V") }}')
    ) as wqi

from {{ source('variables', 'inspections') }} i
inner join {{ source('variables', 'params') }} t on i.id_param_fk = t.id

where i.dt >= '{{ inicio_txt }}'::timestamptz 
  and i.dt < '{{ fim_txt }}'::timestamptz
  and t.description in (
      '{{ var("tag_corrente", "II113RC001\\U") }}',
      '{{ var("tag_wqi", "WQI13107_100\\V") }}',
      '{{ var("tag_tensao", "EI113RC001\\U") }}' -- Não esqueça de adicionar a tag aqui também!
  )
group by 1