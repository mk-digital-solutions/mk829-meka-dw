{{ config(
    materialized='ephemeral' 
) }}

WITH status_base AS (
    SELECT
        m.tag,
        s.new_status,
        s.old_status,
        m.tempo_atual,
        m.tempo_falha,
        m.tempo_ok,
        s.exec_delta
    FROM {{ ref('stg_maqRotativas_raw') }} m
    JOIN {{ ref('int_status') }} s
      ON m.tag = s.tag
)

SELECT
    tag,
    new_status AS status,
    CASE
      WHEN old_status = new_status THEN tempo_atual + exec_delta
      ELSE 0
    END AS tempo_atual,
    CASE
      WHEN new_status = 3 THEN tempo_falha + exec_delta
      ELSE tempo_falha
    END AS tempo_falha,
    CASE
      WHEN new_status != 3 THEN tempo_ok + exec_delta
      ELSE tempo_ok
    END AS tempo_ok
FROM status_base

