{{ config(
    materialized='view'
) }}


with limites as (
    select start_time, end_time from {{ ref('stg_time_window') }}
),

tags_alvo as (
    -- Usamos o dbt para injetar a lista de tags de forma limpa.
    -- O 'default' entra em ação se você não configurar a variável no seu dbt_project.yml
    select id, description
    from {{ source('variables', 'params') }}
    where (
        description in (
            'II113RC001\U', -- Corrente
            'Planta Membrana Ligada', -- Eletrolise — status da planta
            'EI113RC001\U', -- Tensão
            -- HCl
            'Producao_HCL',
            'Concentracao_HCL',
            'FIC051025C\PV_IN',
            -- producao_dia
            'WQI13107_100\V',
            'FIC12702\PV_IN',
            'FIC12703\PV_IN',
            'FIC12718\MV',
            'Demanda Variável',
            'Tensão Média FF',
            'Fator de Potência',
            -- Hipo
            'FI_NaCl0\U',
            -- intervalo_dia
            'FI01507\U',
            'FIC076012\PV_IN',
            'Soda_solenis',
            -- MB_45 performance / producao
            'EI113RC001\U',
            -- liquefacao (compressores e Sabroe)
            'YLL CCL-COM-CPC - A',
            'YLL CCL-COM-CPC- B',
            'YLL CCL-COM-CPC - C',
            'YLL CCL-COM-CPC- 3',
            'Capacidade - Sabroe 01',
            'Capacidade - Sabroe 02'
        )
        or description like 'PL1_EL01_%_Umeas_calc' -- Tensão(92 células)
        or description like 'Peso%Tanque%'           -- liquefacao / estoque_cloro
        or description like 'LI0264%\U'              -- estoque_hipo
        or description like 'READ_TRANSMITERS\LI0510%.PV' -- estoque_HCl
        or description like 'LI0000%\U'              -- estoque_NaOH
    )
)

select
    i.dt as data_hora,
    t.description as tag_name,
    i.value as tag_value

from {{ source('variables', 'inspections') }} i
cross join limites l
inner join tags_alvo t on i.id_param_fk = t.id

where i.dt >= l.start_time 
  and i.dt <= l.end_time
