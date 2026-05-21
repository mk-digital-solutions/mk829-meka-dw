{{ config(materialized='view') }}

-- Eixo: leituras de peso dos tanques (uma linha por timestamp/tanque).
-- As colunas de status dos compressores e capacidade Sabroe são
-- trazidas via LEFT JOIN e preenchidas com 0 quando não há leitura exata.
with tanques as (
    select data_hora as dt, tag_name as tanque, tag_value as peso_bruto
    from {{ ref('stg_producao_data') }}
    where tag_name like 'Peso%Tanque%'
),

cpc_a as (
    select data_hora, max(tag_value) as status_cpc_a
    from {{ ref('stg_producao_data') }}
    where tag_name = 'YLL CCL-COM-CPC - A'
    group by data_hora
),

cpc_b as (
    select data_hora, max(tag_value) as status_cpc_b
    from {{ ref('stg_producao_data') }}
    where tag_name = 'YLL CCL-COM-CPC- B'
    group by data_hora
),

cpc_c as (
    select data_hora, max(tag_value) as status_cpc_c
    from {{ ref('stg_producao_data') }}
    where tag_name = 'YLL CCL-COM-CPC - C'
    group by data_hora
),

cpc_3 as (
    select data_hora, max(tag_value) as status_cpc_3
    from {{ ref('stg_producao_data') }}
    where tag_name = 'YLL CCL-COM-CPC- 3'
    group by data_hora
),

sabroe_01 as (
    select data_hora, max(tag_value) as cap_sabroe_01
    from {{ ref('stg_producao_data') }}
    where tag_name = 'Capacidade - Sabroe 01'
    group by data_hora
),

sabroe_02 as (
    select data_hora, max(tag_value) as cap_sabroe_02
    from {{ ref('stg_producao_data') }}
    where tag_name = 'Capacidade - Sabroe 02'
    group by data_hora
)

select
    t.dt,
    t.tanque,
    t.peso_bruto,
    coalesce(ca.status_cpc_a,  0) as status_cpc_a,
    coalesce(cb.status_cpc_b,  0) as status_cpc_b,
    coalesce(cc.status_cpc_c,  0) as status_cpc_c,
    coalesce(c3.status_cpc_3,  0) as status_cpc_3,
    coalesce(s1.cap_sabroe_01, 0) as cap_sabroe_01,
    coalesce(s2.cap_sabroe_02, 0) as cap_sabroe_02
from tanques t
left join cpc_a     ca on t.dt = ca.data_hora
left join cpc_b     cb on t.dt = cb.data_hora
left join cpc_c     cc on t.dt = cc.data_hora
left join cpc_3     c3 on t.dt = c3.data_hora
left join sabroe_01 s1 on t.dt = s1.data_hora
left join sabroe_02 s2 on t.dt = s2.data_hora
