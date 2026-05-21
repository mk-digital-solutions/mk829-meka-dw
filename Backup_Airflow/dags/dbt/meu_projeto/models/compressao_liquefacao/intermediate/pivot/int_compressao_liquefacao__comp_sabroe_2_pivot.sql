{{ config(materialized='view') }}

with corrente as (
    select data_hora, max(tag_value) as corrente
    from {{ ref('stg_compressao_liquefacao_data') }}
    where tag_name = 'Corrente - Sabroe 02'
    group by data_hora
),

capacidade as (
    select data_hora, max(tag_value) as capacidade
    from {{ ref('stg_compressao_liquefacao_data') }}
    where tag_name = 'Capacidade - Sabroe 02'
    group by data_hora
),

pressao_descarga as (
    select data_hora, max(tag_value) as pressao_descarga
    from {{ ref('stg_compressao_liquefacao_data') }}
    where tag_name = 'Pressão de Descarga - Sabroe 02'
    group by data_hora
),

temp_descarga as (
    select data_hora, max(tag_value) as temp_descarga
    from {{ ref('stg_compressao_liquefacao_data') }}
    where tag_name = 'Temperatura de Descarga - Sabroe 02'
    group by data_hora
),

pressao_oleo as (
    select data_hora, max(tag_value) as pressao_oleo
    from {{ ref('stg_compressao_liquefacao_data') }}
    where tag_name = 'Pressão de Óleo - Sabroe 02'
    group by data_hora
),

temp_oleo as (
    select data_hora, max(tag_value) as temp_oleo
    from {{ ref('stg_compressao_liquefacao_data') }}
    where tag_name = 'Temperatura do Óleo - Sabroe 02'
    group by data_hora
),

superaquecimento_aspiracao as (
    select data_hora, max(tag_value) as superaquecimento_aspiracao
    from {{ ref('stg_compressao_liquefacao_data') }}
    where tag_name = 'Superaquecimento de Aspiração - Sabroe 02'
    group by data_hora
),

pressao_aspiracao as (
    select data_hora, max(tag_value) as pressao_aspiracao
    from {{ ref('stg_compressao_liquefacao_data') }}
    where tag_name = 'Pressão de Aspiração - Sabroe 02'
    group by data_hora
),

temp_processo as (
    select data_hora, max(tag_value) as temp_processo
    from {{ ref('stg_compressao_liquefacao_data') }}
    where tag_name = 'Temperatura de Processo - Sabroe 02'
    group by data_hora
),

temp_aspiracao as (
    select data_hora, max(tag_value) as temp_aspiracao
    from {{ ref('stg_compressao_liquefacao_data') }}
    where tag_name = 'Temperatura de Aspiração - Sabroe 02'
    group by data_hora
),

timestamps as (
    select data_hora from corrente
    union select data_hora from capacidade
    union select data_hora from pressao_descarga
    union select data_hora from temp_descarga
    union select data_hora from pressao_oleo
    union select data_hora from temp_oleo
    union select data_hora from superaquecimento_aspiracao
    union select data_hora from pressao_aspiracao
    union select data_hora from temp_processo
    union select data_hora from temp_aspiracao
)

select
    ts.data_hora                                        as dt,
    coalesce(co.corrente,                          0)  as corrente,
    coalesce(ca.capacidade,                        0)  as capacidade,
    coalesce(pd.pressao_descarga,                  0)  as pressao_descarga,
    coalesce(td.temp_descarga,                     0)  as temp_descarga,
    coalesce(po.pressao_oleo,                      0)  as pressao_oleo,
    coalesce(tol.temp_oleo,                        0)  as temp_oleo,
    coalesce(sa.superaquecimento_aspiracao,         0)  as superaquecimento_aspiracao,
    coalesce(pa.pressao_aspiracao,                  0)  as pressao_aspiracao,
    coalesce(tp.temp_processo,                      0)  as temp_processo,
    coalesce(ta.temp_aspiracao,                     0)  as temp_aspiracao
from timestamps ts
left join corrente                 co  on ts.data_hora = co.data_hora
left join capacidade               ca  on ts.data_hora = ca.data_hora
left join pressao_descarga         pd  on ts.data_hora = pd.data_hora
left join temp_descarga            td  on ts.data_hora = td.data_hora
left join pressao_oleo             po  on ts.data_hora = po.data_hora
left join temp_oleo                tol on ts.data_hora = tol.data_hora
left join superaquecimento_aspiracao sa on ts.data_hora = sa.data_hora
left join pressao_aspiracao        pa  on ts.data_hora = pa.data_hora
left join temp_processo            tp  on ts.data_hora = tp.data_hora
left join temp_aspiracao           ta  on ts.data_hora = ta.data_hora
