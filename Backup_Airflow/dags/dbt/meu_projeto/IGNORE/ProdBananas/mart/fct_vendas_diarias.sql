{{
    config(
        materialized='incremental',
        unique_key='pedido_id'
    )
}}

with dados_enriquecidos as (
    select * from {{ ref('int_vendas__enriquecidas') }}
),

final as (
    select
        pedido_id,
        data_pedido::date as data_referencia,
        cliente_id,
        tipo_banana,
        tipo_cliente,
        quantidade_kg,
        valor_total,
        preco_medio_kg,
        status_venda
    from dados_enriquecidos
    
    where status_venda != 'Cancelada'
)

select * from final