{{
    config(
        materialized='incremental',
        unique_key='pedido_id' 
    )
}}
-- Evita duplicação se o Airflow rodar duas vezes o mesmo dia
with source_data as (
    select * from {{ source('erp_fazenda', 'raw_vendas_banana') }}
),

limpeza_inicial as (
    select
        pedido_id,
        data_pedido,
        cliente_id,
        tipo_banana,
        quantidade_kg,
        valor_total,
        status_venda
    from source_data
    
    -- O filtro do Airflow já garante que a tabela receba apenas o lote (Append) de dados novos!
    where {{ filtro_data('data_pedido::date') }}
)

select * from limpeza_inicial