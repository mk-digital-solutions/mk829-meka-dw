{{ config(
    materialized='ephemeral' 
) }}

WITH latest_rows AS (

    SELECT
        i.*,
        ROW_NUMBER() OVER (
            PARTITION BY i.tag
            ORDER BY i.dt DESC
        ) AS rn

    FROM {{ ref('stg_bombas_window') }} i

),

bit_status AS (

    SELECT
        l.*,
        m.last_timestamp,
        m.status AS old_status,

        EXTRACT(EPOCH FROM (l.dt - m.last_timestamp)) / 60 AS exec_delta

    FROM latest_rows l

    LEFT JOIN {{ ref('stg_maqRotativas_raw') }} m
        ON l.tag = m.tag

    WHERE l.rn = 1

),

status_check AS (

    SELECT
        b.*,

        CASE
            WHEN b.fb_on = 1 THEN 1
            WHEN b.fb_on = 0 AND b.fb_falha = 0 THEN 2
            WHEN b.fb_on = 0 AND b.fb_falha = 1 THEN 3
        END AS new_status

    FROM bit_status b

)

SELECT 
    tag,
    new_status,
    old_status,
    ROUND(exec_delta) as exec_delta
FROM status_check

