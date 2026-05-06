{{ config(
    materialized='ephemeral' 
) }}

WITH error_events AS (
    SELECT
        t.tag,
        COUNT(*) AS error_count
    FROM (
        SELECT
            i.tag,
            i.dt,
            i.fb_falha AS error,
            LAG(i.fb_falha) OVER (
                PARTITION BY i.tag
                ORDER BY i.dt
            ) AS prev_error
        FROM {{ ref('stg_bombas_window') }} i
    ) t 
    WHERE t.prev_error = 0 
      AND t.error = 1
    GROUP BY t.tag
)

SELECT
    m.tag,
    e.error_count,
    m.n_falhas + COALESCE(e.error_count,0) AS total_errors
FROM {{ ref('stg_maqRotativas_raw') }} m
LEFT JOIN error_events e
ON m.tag = e.tag
    