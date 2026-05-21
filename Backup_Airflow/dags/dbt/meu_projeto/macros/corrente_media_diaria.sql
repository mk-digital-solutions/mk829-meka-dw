{% macro corrente_media_diaria() %}
    select
        date_trunc('day', data_hora)::date as dt,
        avg(tag_value)                     as corrente_media
    from {{ ref('stg_producao_data') }}
    where tag_name = 'II113RC001\U'
    group by 1
{% endmacro %}
