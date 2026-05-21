{{ config(materialized='view') }}

{{ sum_on_cell_diario() }}
