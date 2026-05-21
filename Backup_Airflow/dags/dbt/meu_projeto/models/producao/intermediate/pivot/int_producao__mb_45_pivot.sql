{{ config(materialized='view') }}

-- Mescla as três fontes do grupo MB_45 numa granularidade de uma linha por data_hora:
--
--   · tensao   — SOMA dos maiores valores dos 92 eletrodos (tags PL1_EL01_*_Umeas_calc,
--                filtradas entre 0 e 4 V) por timestamp.
--   · planta   — Planta Membrana Ligada (flag 0/1)
--   · corrente — II113RC001\U
--
-- Estratégia resiliente a tag ausente:
-- O eixo do JOIN é uma ESPINHA de timestamps (união dos data_hora de todas as
-- fontes). Assim, se uma das tags não for encontrada no banco, a view continua
-- retornando linhas para os timestamps das outras duas, com a coluna ausente
-- preenchida com 0 via coalesce.


with
tensao as (
    select
        data_hora,
        max(tag_value) as soma_tensao
    from {{ ref('stg_producao_data') }}
    where tag_name = 'EI113RC001\U'
    group by data_hora
),

planta as (
    select
        data_hora,
        max(tag_value) as planta_membrana_ligada
    from {{ ref('stg_producao_data') }}
    where tag_name = 'Planta Membrana Ligada'
    group by data_hora
),

corrente as (
    select
        data_hora,
        max(tag_value) as corrente
    from {{ ref('stg_producao_data') }}
    where tag_name = 'II113RC001\U'
    group by data_hora
),

-- Espinha de timestamps: união dos data_hora de TODAS as fontes.
-- Garante que a view tenha linhas mesmo se uma das tags estiver ausente.
timestamps as (
    select data_hora from tensao
    union
    select data_hora from planta
    union
    select data_hora from corrente
)

select
    ts.data_hora                                  as dt,
    coalesce(t.soma_tensao, 0)                    as soma_tensao,
    coalesce(p.planta_membrana_ligada, 0)         as planta_membrana_ligada,
    coalesce(c.corrente, 0)                       as corrente
from timestamps ts
left join tensao                 t   on ts.data_hora = t.data_hora
left join planta                 p   on ts.data_hora = p.data_hora
left join corrente               c   on ts.data_hora = c.data_hora
