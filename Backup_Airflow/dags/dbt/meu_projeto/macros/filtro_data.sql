-- Arquivo: macros/filtro_data.sql
{% macro filtro_data(coluna_data, dias_padrao=3) %}

    {# 1. Captura o que veio do Airflow (se não vier nada, assume string vazia) #}
    {% set var_inicio = var("dt_inicio", "") %}
    {% set var_fim = var("dt_fim", "") %}

    {# 2. Se a string estiver vazia, calcula o padrão (D-3 e Hoje) #}
    {% set inicio_final = var_inicio if var_inicio != "" else (run_started_at - modules.datetime.timedelta(days=dias_padrao)).strftime("%Y-%m-%d") %}
    {% set fim_final = var_fim if var_fim != "" else run_started_at.strftime("%Y-%m-%d") %}

    {# 3. Imprime a regra SQL final #}
    {{ coluna_data }} >= cast('{{ inicio_final }}' as date)
    and {{ coluna_data }} <= cast('{{ fim_final }}' as date)

{% endmacro %}