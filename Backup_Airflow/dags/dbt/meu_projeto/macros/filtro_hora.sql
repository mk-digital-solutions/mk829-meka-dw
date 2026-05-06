{% macro filtro_hora(coluna_timestamp, horas_padrao=3) %}

    {# 1. Captura as variáveis (agora chamadas de ts_inicio e ts_fim para indicar timestamp) #}
    {% set var_inicio = var("ts_inicio", "") %}
    {% set var_fim = var("ts_fim", "") %}

    {# 2. Se vazio, calcula o padrão (Ex: Agora menos 3 horas) #}
    {% set inicio_final = var_inicio if var_inicio != "" else (run_started_at - modules.datetime.timedelta(hours=horas_padrao)).strftime("%Y-%m-%d %H:%M:%S") %}
    {% set fim_final = var_fim if var_fim != "" else run_started_at.strftime("%Y-%m-%d %H:%M:%S") %}

    {# 3. Imprime a regra SQL com cast para timestamptz (para respeitar o -0300 da sua tabela) #}
    {{ coluna_timestamp }} >= cast('{{ inicio_final }}' as timestamptz)
    and {{ coluna_timestamp }} <= cast('{{ fim_final }}' as timestamptz)

{% endmacro %}