{{ config(materialized='view') }}

-- Produz flags de "sem venda" por minuto.
-- O painel Grafana conta o total de minutos (COUNT(*) WHERE flag = 1).
-- Limiar cloro: <= 0.2 (regra de negócio documentada). Vapor e soda: <= 0.
with base as (
    select * from {{ ref('int_producao__solenis_pivot') }}
)

select
    dt,
    case when venda_cloro < 0 then 0 else venda_cloro end       as venda_cloro,
    case when venda_vapor < 0 then 0 else venda_vapor end       as venda_vapor,
    case when venda_soda  < 0 then 0 else venda_soda  end       as venda_soda,
    case when venda_cloro <= 0.2 then 1 else 0 end              as sem_cloro,
    case when venda_vapor <= 0   then 1 else 0 end              as sem_vapor,
    case when venda_soda  <= 0   then 1 else 0 end              as sem_soda,
    case when
        (case when venda_cloro < 0 then 0 else venda_cloro end)
      + (case when venda_vapor < 0 then 0 else venda_vapor end)
      + (case when venda_soda  < 0 then 0 else venda_soda  end) > 0
    then 1 else 0 end                                           as status
from base
