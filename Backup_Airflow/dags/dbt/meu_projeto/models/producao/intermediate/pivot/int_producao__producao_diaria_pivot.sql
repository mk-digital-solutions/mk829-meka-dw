{{ config(materialized='view') }}

with fonte_soda as (
    select data_hora, min(tag_value) as producao_soda_raw
    from {{ ref('stg_producao_data') }}
    where tag_name = 'WQI13107_100\V'
      and tag_value >= 0
    group by data_hora
),

fonte_hcl as (
    select data_hora, min(tag_value) as producao_hcl_raw
    from {{ ref('stg_producao_data') }}
    where tag_name = 'Producao_HCL'
      and tag_value >= 0
    group by data_hora
),

fonte_naoh as (
    select data_hora, max(tag_value) as naoh_raw
    from {{ ref('stg_producao_data') }}
    where tag_name = 'FIC12702\PV_IN'
    group by data_hora
),

fonte_agua as (
    select data_hora, max(tag_value) as agua_raw
    from {{ ref('stg_producao_data') }}
    where tag_name = 'FIC12703\PV_IN'
    group by data_hora
),

fonte_cl2 as (
    select data_hora, max(tag_value) as cl2_raw
    from {{ ref('stg_producao_data') }}
    where tag_name = 'FIC12718\MV'
    group by data_hora
),

fonte_cl2_liquido as (
    select data_hora, max(tag_value) as cl2_liquido_raw
    from {{ ref('stg_producao_data') }}
    where tag_name = 'FI01507\U'
    group by data_hora
),

fonte_demanda as (
    select data_hora, max(tag_value) as demanda_raw
    from {{ ref('stg_producao_data') }}
    where tag_name = 'Demanda Variável'
    group by data_hora
),

fonte_tensao_ff as (
    select data_hora, avg(tag_value) as tensao_ff
    from {{ ref('stg_producao_data') }}
    where tag_name = 'Tensão Média FF'
    group by data_hora
),

fonte_fp as (
    select data_hora, avg(tag_value) as fator_potencia
    from {{ ref('stg_producao_data') }}
    where tag_name = 'Fator de Potência'
    group by data_hora
),

timestamps as (
    select data_hora from fonte_soda
    union select data_hora from fonte_hcl
    union select data_hora from fonte_naoh
    union select data_hora from fonte_agua
    union select data_hora from fonte_cl2
    union select data_hora from fonte_cl2_liquido
    union select data_hora from fonte_demanda
    union select data_hora from fonte_tensao_ff
    union select data_hora from fonte_fp
)

select
    ts.data_hora                            as dt,
    coalesce(fs.producao_soda_raw,  0)      as producao_soda_raw,
    coalesce(fh.producao_hcl_raw,   0)      as producao_hcl_raw,
    coalesce(fn.naoh_raw,           0)      as naoh_raw,
    coalesce(fa.agua_raw,           0)      as agua_raw,
    coalesce(fc.cl2_raw,            0)      as cl2_raw,
    coalesce(fl.cl2_liquido_raw,    0)      as cl2_liquido_raw,
    coalesce(fd.demanda_raw,        0)      as demanda_raw,
    coalesce(ft.tensao_ff,          0)      as tensao_ff,
    coalesce(fp.fator_potencia,     0)      as fator_potencia
from timestamps ts
left join fonte_soda      fs on ts.data_hora = fs.data_hora
left join fonte_hcl       fh on ts.data_hora = fh.data_hora
left join fonte_naoh      fn on ts.data_hora = fn.data_hora
left join fonte_agua      fa on ts.data_hora = fa.data_hora
left join fonte_cl2         fc on ts.data_hora = fc.data_hora
left join fonte_cl2_liquido fl on ts.data_hora = fl.data_hora
left join fonte_demanda     fd on ts.data_hora = fd.data_hora
left join fonte_tensao_ff ft on ts.data_hora = ft.data_hora
left join fonte_fp        fp on ts.data_hora = fp.data_hora
