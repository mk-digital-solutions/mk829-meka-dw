-- dbt/models/agilizatronik_stg/agilizatronik_stg.sql

{{ config(
    materialized='table',
    schema='_stg_agilizatronik',
    alias='fct_agilizatronik'
) }}

{% set debug = var('modo_debug', False) %}

SELECT
    _airbyte_raw_id,
    _airbyte_extracted_at,
    _airbyte_meta,
    _airbyte_generation_id,
    "ID_",

    -- Remove tags HTML e colapsa espaços em branco
    TRIM(
        regexp_replace(
            regexp_replace(
                regexp_replace("Body", '<[^>]*>', ' ', 'g'),
                '&[a-zA-Z]+;|&#[0-9]+;', ' ', 'g'
            ),
            '\s+', ' ', 'g'
        )
    ) AS "Body",

    -- Remove o prefixo "_N_" (ex.: "_7_COMPLETED" -> "COMPLETED")
    regexp_replace("Status", '^_\d+_', '') AS "Status",
    regexp_replace("Priority", '^_\d+_', '') AS "Priority",

    -- Extrai FullName de cada elemento do array JSON, separados por vírgula
    (
        SELECT string_agg(elem->>'FullName', ', ')
        FROM jsonb_array_elements("Followers") AS elem
    ) AS "Followers",

    -- Extrai o campo Description do objeto JSON
    "Department"->>'Description' AS "Department",

    "Estimation",

    -- Extrai o campo Description do objeto JSON
    "TicketType"->>'Description' AS "TicketType",

    "CanBeClosed",
    "changedDate",
    "createdDate",

    -- Extrai Email de cada elemento do array JSON, separados por vírgula
    (
        SELECT string_agg(elem->>'Email', ', ')
        FROM jsonb_array_elements("Accountables") AS elem
    ) AS "Accountables",

    "ExpectedDate",
    "Satisfaction",
    "BriefDescription",

    -- Extrai o campo Description do objeto JSON (mesma estrutura de Department)
    "RequesterDepartment"->>'Description' AS "RequesterDepartment",

    "IsConclusionNotified"

FROM {{ source('raw_agilizatronik', 'fct_Meka_OData_Agilizatronik') }}
