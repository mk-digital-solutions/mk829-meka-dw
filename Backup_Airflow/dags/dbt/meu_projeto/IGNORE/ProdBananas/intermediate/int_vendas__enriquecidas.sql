with staging as (
    select * from {{ ref('stg_vendas__pedidos') }}
),

regras_de_negocio as (
    select
        pedido_id,
        data_pedido,
        cliente_id,
        tipo_banana,
        quantidade_kg,
        valor_total,
        status_venda,
        
        -- Lógica 1: Descobre o preço que foi pago por KG arredondado
        round(valor_total / nullif(quantidade_kg, 0), 2) as preco_medio_kg,
        
        -- Lógica 2: Classifica o tamanho da venda
        case
            when quantidade_kg > 300 then 'Atacado'
            else 'Varejo'
        end as tipo_cliente
        
    from staging
)

select * from regras_de_negocio