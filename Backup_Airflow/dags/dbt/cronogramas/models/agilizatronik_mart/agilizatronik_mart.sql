-- dbt/models/agilizatronik/agilizatronik_mart.sql

{{ config(
    materialized='table',
    schema='_mart_agilizatronik',
    alias='fct_agilizatronik'
) }}

{% set stg_schema = var('stg_schema', 'stg_agilizatronik') %}
{% set debug = var('modo_debug', False) %}

SELECT
    _airbyte_raw_id,
    _airbyte_extracted_at,
    _airbyte_meta,
    COALESCE(_airbyte_generation_id, 0) AS _airbyte_generation_id,
    COALESCE("ID_", 0) AS "ID_",
    COALESCE("Body", 'vazio') AS "Body",
    COALESCE("Status", 'vazio') AS "Status",
    COALESCE("Priority", 'vazio') AS "Priority",
    COALESCE("Followers", 'vazio') AS "Followers",
    COALESCE("Department", 'vazio') AS "Department",
    COALESCE("Estimation", 'vazio') AS "Estimation",
    COALESCE("TicketType", 'vazio') AS "TicketType",
    "CanBeClosed",
    "changedDate",
    "createdDate",
    COALESCE("Accountables", 'vazio') AS "Accountables",
    "ExpectedDate",
    COALESCE("Satisfaction", 0) AS "Satisfaction",
    COALESCE("BriefDescription", 'vazio') AS "BriefDescription",
    COALESCE("RequesterDepartment", 'vazio') AS "RequesterDepartment",
    "IsConclusionNotified"

FROM {{ stg_schema }}."fct_agilizatronik"
{% if debug %} LIMIT 100 {% endif %}
