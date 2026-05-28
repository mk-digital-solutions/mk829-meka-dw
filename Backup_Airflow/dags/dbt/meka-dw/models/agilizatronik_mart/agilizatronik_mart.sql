-- dbt/models/agilizatronik/agilizatronik_mart.sql

{{ config(
    materialized='table',
    schema='_mart_agilizatronik',
    alias='fct_agilizatronik'
) }}

{% set debug = var('modo_debug', False) %}

SELECT
    _airbyte_raw_id,
    _airbyte_extracted_at,
    _airbyte_meta,
    COALESCE(_airbyte_generation_id, 0) AS _airbyte_generation_id,
    COALESCE("ID_", 0) AS "ID_",
    COALESCE("Body", '') AS "Body",
    COALESCE("Status", '') AS "Status",
    COALESCE("Priority", '') AS "Priority",
    COALESCE("Followers", '') AS "Followers",
    COALESCE("Department", '') AS "Department",
    COALESCE("Estimation", '') AS "Estimation",
    COALESCE("TicketType", '') AS "TicketType",
    "CanBeClosed",
    "changedDate",
    "createdDate",
    COALESCE("Accountables", '') AS "Accountables",
    "ExpectedDate",
    COALESCE("Satisfaction", 0) AS "Satisfaction",
    COALESCE("BriefDescription", '') AS "BriefDescription",
    COALESCE("RequesterDepartment", '') AS "RequesterDepartment",
    "IsConclusionNotified"

FROM {{ ref('agilizatronik_stg') }}
