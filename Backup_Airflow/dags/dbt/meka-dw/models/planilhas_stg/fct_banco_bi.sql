-- dbt/models/planilhas_stg/fct_banco_bi.sql

{{ config(
    materialized='table',
    schema='_stg_planilhas',
    alias='fct_banco_bi'
) }}

{#
  Bronze: unifica as tabelas <nome>_<sobrenome>_BANCO_BI de raw_planilhas numa
  única tabela (uma planilha de BI por colaborador, gravada pelo Airbyte com
  prefixo por conexão). Mesmo desenho dos cronogramas (banco_stg/atividades_stg):
  union_relations + conversão de tipos das colunas de negócio.

  As tabelas de origem NÃO são copiadas individualmente para stg_planilhas — o
  modelo planilhas_stg as ignora justamente por causa deste modelo.
#}

{% set raw_schema = var('raw_schema', 'raw_planilhas') %}
{% set debug = var('modo_debug', False) %}

{# Acentos -> ASCII, para casar o nome citado no texto da entrega com o slug do
   colaborador (que é sem acento). Os dois conjuntos têm o mesmo tamanho. #}
{% set acentos     = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ' %}
{% set sem_acentos = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC' %}

{# 1. Localiza as tabelas de origem: <pessoa>_BANCO_BI (ex.: wollace_dantas_BANCO_BI).
      A tabela BANCO_BI sem prefixo (modelo antigo, uma única tabela para todo
      mundo) não entra, porque o filtro exige o "_" antes de BANCO_BI. #}
{% set relacoes_encontradas = [] %}
{% if execute %}
    {% set tabelas_query %}
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = '{{ raw_schema }}'
          AND table_type = 'BASE TABLE'
          AND table_name LIKE '%\_BANCO\_BI'
        ORDER BY table_name
    {% endset %}

    {% for tabela in run_query(tabelas_query).columns[0].values() %}
        {% set rel = adapter.get_relation(
            database=target.database,
            schema=raw_schema,
            identifier=tabela
        ) %}
        {% if rel %}
            {% do relacoes_encontradas.append(rel) %}
        {% endif %}
    {% endfor %}

    {% do log('[planilhas] fct_banco_bi: ' ~ relacoes_encontradas | length ~ ' tabela(s) <pessoa>_BANCO_BI encontrada(s) em ' ~ raw_schema, info=True) %}
{% endif %}

{# 2. União das tabelas raw (gerada uma única vez e reaproveitada na CTE e na
      detecção de tipos). #}
{% set union_sql %}
    {% if relacoes_encontradas | length > 0 %}
        {{ dbt_utils.union_relations(
            relations=relacoes_encontradas,
            source_column_name='tabela_origem'
        ) }}
    {% else %}
        SELECT 'NENHUMA_TABELA' AS tabela_origem LIMIT 0
    {% endif %}
{% endset %}

{# 3. Colunas da união: as geradas pelo Airbyte (_airbyte_*) passam intactas; as
      de negócio têm o tipo convertido (varchar -> numeric/date) conforme os
      dados reais (ver macros/conversao_tipos.sql). #}
{% set colunas_airbyte = [] %}
{% set colunas_negocio = [] %}
{% if execute and relacoes_encontradas | length > 0 %}
    {% set nomes = [] %}
    {% for r in relacoes_encontradas %}
        {% do nomes.append(r.identifier) %}
    {% endfor %}
    {% set col_query %}
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = '{{ raw_schema }}'
          AND table_name IN ('{{ nomes | join("','") }}')
        GROUP BY column_name
        ORDER BY MIN(ordinal_position), column_name
    {% endset %}
    {% for c in run_query(col_query).columns[0].values() %}
        {% if c.startswith('_airbyte') %}
            {% do colunas_airbyte.append(c) %}
        {% else %}
            {% do colunas_negocio.append(c) %}
        {% endif %}
    {% endfor %}
{% endif %}

{# "___Faturado_" é percentual: guardado como fração (ex.: 50% -> 0.50). #}
{% set exprs_tipadas = conv__lista_select('(' ~ union_sql ~ ') AS _u', colunas_negocio, dividir_cem=['___Faturado_']) %}

{# Colunas de entrega e de data da planilha (hoje "_Entrega_" e "DATA"). #}
{% set col_entrega = [] %}
{% set col_data = [] %}
{% for c in colunas_negocio %}
    {% if not col_entrega and 'entrega' in c | lower %}{% do col_entrega.append(c) %}{% endif %}
    {% if not col_data and c | upper == 'DATA' %}{% do col_data.append(c) %}{% endif %}
{% endfor %}

{# Entregas dos cronogramas, de onde vem a DATA_DE_CONCLUSAO. #}
{% set tabela_entregas = var('tabela_entregas', 'mart_cronogramas.fct_entregas') %}

WITH source_data AS (
    {{ union_sql }}
),

banco AS (
    SELECT
        {# 4. Colaborador dono da planilha, extraído do nome da tabela de origem:
              "...raw_planilhas"."wollace_dantas_BANCO_BI" -> wollace_dantas #}
        LOWER(SUBSTRING(tabela_origem FROM '(?i)([A-Za-z0-9_]+)_BANCO_BI')) AS colaborador_planilha,
        tabela_origem
        {%- for c in colunas_airbyte %},
        "{{ c }}"
        {%- endfor %}
        {%- for e in exprs_tipadas %},
        {{ e }}
        {%- endfor %}
    FROM source_data
),

{# 4b. Universo de colaboradores que têm planilha própria (donos distintos) e
      seus tokens (nome_sobrenome). Serve para identificar, no texto da entrega,
      quem de fato faturou — só reatribui para quem é colaborador com planilha. #}
donos AS (
    SELECT DISTINCT
        colaborador_planilha AS slug,
        string_to_array(colaborador_planilha, '_') AS tokens
    FROM banco
),

{# 5. Entrega sem o prefixo, para casar com fct_entregas.ENTREGA:
      "MK830 ENTREGA 4 - ABRIL/2026 - Fulano - MK830" -> "ENTREGA 4 - ABRIL/2026 - Fulano - MK830".
      O prefixo é o centro de custo da entrega (MK830), no mesmo formato de
      fct_entregas.CENTRO_DE_CUSTO. Atenção: centro de custo NÃO é o código do
      cronograma — um cronograma pode trazer entregas de outro centro de custo
      (ex.: cronograma mk522 com entregas do MK609). #}
banco_chave AS (
    SELECT
        b.*,
        {% if col_entrega -%}
        upper(replace((regexp_match(trim(b."{{ col_entrega[0] }}"), '^(mk\s?[0-9]+)\s', 'i'))[1], ' ', '')) AS centro_de_custo,
        regexp_replace(trim(b."{{ col_entrega[0] }}"), '^mk\s?[0-9]+\s+', '', 'i') AS entrega_sem_prefixo
        {%- else -%}
        NULL::text AS centro_de_custo,
        NULL::text AS entrega_sem_prefixo
        {%- endif %}
    FROM banco b
),

{# 6. Data de conclusão por entrega. A chave é centro de custo + texto da
      entrega: o texto sozinho se repete entre projetos (ex.: "ENTREGA 1 -
      STARTUP" existe em dezenas de projetos, com datas diferentes).
      DATA_DE_CONCLUSAO vem como texto DD/MM/AA (e às vezes DD/MM/AAAA); aqui
      vira date, com o ano completo. Se a mesma entrega aparece mais de uma vez
      com datas diferentes, fica a mais recente.
      O tipo da coluna em fct_entregas depende dos dados (conv__tipos_colunas):
      é date quando todos os valores são datas válidas e text caso contrário.
      Por isso o ::text e o caso AAAA-MM-DD (date convertido para texto). #}
entregas AS (
    SELECT
        upper(replace(trim("CENTRO_DE_CUSTO"), ' ', '')) AS centro_de_custo,
        regexp_replace(trim("ENTREGA"), '\s+', ' ', 'g') AS entrega_chave,
        max(CASE
            WHEN trim("DATA_DE_CONCLUSAO"::text) ~ '^\d{4}-\d{2}-\d{2}$' THEN trim("DATA_DE_CONCLUSAO"::text)::date
            WHEN trim("DATA_DE_CONCLUSAO"::text) ~ '^\d{1,2}/\d{1,2}/\d{4}$' THEN to_date(trim("DATA_DE_CONCLUSAO"::text), 'DD/MM/YYYY')
            WHEN trim("DATA_DE_CONCLUSAO"::text) ~ '^\d{1,2}/\d{1,2}/\d{2}$' THEN to_date(trim("DATA_DE_CONCLUSAO"::text), 'DD/MM/YY')
        END) AS data_de_conclusao
    FROM {{ tabela_entregas }}
    WHERE trim(coalesce("ENTREGA", '')) <> ''
      AND trim(coalesce("CENTRO_DE_CUSTO", '')) <> ''
    GROUP BY 1, 2
)

SELECT
    {# colaborador_planilha = quem REALMENTE faturou. Se a entrega cita um
       colaborador que tem planilha própria (dono), usa ele; caso contrário,
       mantém o dono da planilha de alocação. Apenas o VALOR muda — o schema
       (ordem de colunas) é idêntico ao original, para não deslocar consumidores
       que leem por posição (ex.: Power BI "Alocação Individual"). #}
    COALESCE(col_real.slug, bc.colaborador_planilha) AS colaborador_planilha,
    bc.tabela_origem
    {%- for c in colunas_airbyte %},
    bc."{{ c }}"
    {%- endfor %}
    {%- for c in colunas_negocio %},
    {% if col_entrega and c == col_entrega[0] -%}
    bc.entrega_sem_prefixo AS "{{ c }}",
    bc.centro_de_custo AS "CENTRO_DE_CUSTO"
    {%- else -%}
    bc."{{ c }}"
    {%- endif %}
    {%- if col_data and c == col_data[0] %},
    e.data_de_conclusao AS "DATA_DE_CONCLUSAO"
    {%- endif %}
    {%- endfor %}
    {%- if not col_entrega %},
    bc.centro_de_custo AS "CENTRO_DE_CUSTO"
    {%- endif %}
    {%- if not col_data %},
    e.data_de_conclusao AS "DATA_DE_CONCLUSAO"
    {%- endif %}
FROM banco_chave bc
{# Identifica na entrega o colaborador (dono com planilha) cujo nome completo
   — TODOS os tokens do slug — aparece no texto já normalizado (sem acento,
   minúsculo, sem pontuação). Entre vários, vence o de nome mais específico
   (mais tokens). Se nenhum casa, col_real.slug fica NULL e mantém-se o dono. #}
LEFT JOIN LATERAL (
    SELECT d.slug
    FROM donos d
    WHERE {% if col_entrega %}d.tokens <@ regexp_split_to_array(
              trim(regexp_replace(
                  lower(translate(coalesce(bc."{{ col_entrega[0] }}", ''), '{{ acentos }}', '{{ sem_acentos }}')),
                  '[^a-z0-9]+', ' ', 'g')),
              '\s+'){% else %}false{% endif %}
    ORDER BY cardinality(d.tokens) DESC, d.slug
    LIMIT 1
) col_real ON true
LEFT JOIN entregas e
       ON e.centro_de_custo = bc.centro_de_custo
      AND e.entrega_chave = regexp_replace(bc.entrega_sem_prefixo, '\s+', ' ', 'g')
