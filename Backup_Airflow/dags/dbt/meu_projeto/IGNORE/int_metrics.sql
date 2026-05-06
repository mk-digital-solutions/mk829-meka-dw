{{ config(
    materialized='table' 
) }}

WITH error_base AS (
    SELECT
        m.tag,
        m.mtbf,
        m.mttr,
        s.tempo_falha,
        s.tempo_ok,
        e.total_errors
    FROM {{ ref('stg_maqRotativas_raw') }} m
    JOIN {{ ref('int_status') }} s
      ON m.tag = s.tag
    JOIN {{ ref('int_error') }} e
      ON m.tag = e.tag
)

SELECT
    total_errors as n_falhas
    CASE
  WHEN total_errors > 0
  THEN ROUND(
    (tempo_ok / 1440) / total_errors,
    2
  )
  ELSE 0
  END AS mtbf,
  CASE
  WHEN total_errors > 0
  THEN ROUND(
    (tempo_ok / 1440) / total_errors,
    2
  )
  ELSE 0
END AS mtbf
    CASE
      WHEN (sc.old_n_falhas + CASE WHEN g.falha_prev = 0 AND g.bit_4 = 1 THEN 1 ELSE 0 END) > 0
      THEN ROUND(
        ((sc.old_tempo_falha::NUMERIC + CASE WHEN sc.status = 3 THEN sc.exec_delta ELSE 0 END) / 1440)
        / (sc.old_n_falhas + CASE WHEN g.falha_prev = 0 AND g.bit_4 = 1 THEN 1 ELSE 0 END)::NUMERIC,
        2)
      ELSE 0
    END AS mttr,