{# ------------------------------------------------------------------
   MACRO 1: Converte a tabela comum em Hypertable particionada
------------------------------------------------------------------- #}
{% macro create_hypertable(coluna_tempo, chunk_interval='7 days') %}

    {% if not is_incremental() %}
        SELECT create_hypertable(
            '{{ this }}', 
            '{{ coluna_tempo }}', 
            chunk_time_interval => INTERVAL '{{ chunk_interval }}',
            if_not_exists => TRUE,
            migrate_data => TRUE
        );
    {% endif %}

{% endmacro %}


{# ------------------------------------------------------------------
   MACRO 2: Habilita a compressão nativa do Timescale
------------------------------------------------------------------- #}
{% macro add_compression(coluna_segmentacao, compress_after='30 days') %}

    {% if not is_incremental() %}
        ALTER TABLE {{ this }} SET (
            timescaledb.compress,
            timescaledb.compress_segmentby = '{{ coluna_segmentacao }}'
        );

        SELECT add_compression_policy(
            '{{ this }}', 
            INTERVAL '{{ compress_after }}',
            if_not_exists => TRUE
        );
    {% endif %}

{% endmacro %}


{# ------------------------------------------------------------------
   MACRO 3: Limpeza automática de dados muito velhos
------------------------------------------------------------------- #}
{% macro add_retention(drop_after='365 days') %}

    {% if not is_incremental() %}
        SELECT add_retention_policy(
            '{{ this }}', 
            INTERVAL '{{ drop_after }}',
            if_not_exists => TRUE
        );
    {% endif %}

{% endmacro %}