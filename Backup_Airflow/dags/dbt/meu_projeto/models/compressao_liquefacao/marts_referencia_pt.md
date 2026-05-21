# Referência de Marts — Dashboard Compressão - Liquefação (Português-BR)

> Documento destinado a agentes LLM. Contém a descrição completa de cada mart,
> incluindo finalidade, colunas, unidades, tags de origem e regras de negócio
> aplicadas. Use este arquivo para entender o que consultar e como interpretar
> cada coluna antes de gerar queries ou explicações.

Todos os marts vivem no schema `dbt_compressao_liquefacao`. Todas as séries são
temporais, keyed por `dt` (`timestamptz`). O Grafana aplica reduções visuais
(last, mean) — o mart sempre expõe a série completa.

Os compressores Sabroe são compressores de refrigeração a amônia (NH3) que resfriam
e liquefazem o cloro gasoso produzido pela eletrólise.

---

## Índice

1. [compressao_liquefacao__comp_sabroe_1](#1-compressao_liquefacao__comp_sabroe_1)
2. [compressao_liquefacao__comp_sabroe_2](#2-compressao_liquefacao__comp_sabroe_2)
3. [var_compressao_liquefacao__tags](#3-var_compressao_liquefacao__tags)

---

## 1. `compressao_liquefacao__comp_sabroe_1`

**Grupo:** Compressor Sabroe 01 — Refrigeração de Liquefação
**Finalidade:** Série temporal com os parâmetros operacionais do compressor de refrigeração
Sabroe 01: corrente, capacidade, pressões e temperaturas de descarga/aspiração e óleo.
Usado para monitorar o estado operacional e detectar desvios de processo.

**Granularidade:** 1 registro por leitura dos sensores (tipicamente por minuto).

**Regras aplicadas antes do mart:**
- Nenhuma transformação de negócio. Todos os valores são leituras brutas diretas do sensor.
- Spine de timestamps via UNION de todos os `data_hora` das 10 tags.
- `COALESCE(..., 0)` aplicado a cada coluna para resiliência a ausências pontuais de leitura.

**Tags de origem:**

| Tag | Instrumento | Papel |
|---|---|---|
| `Corrente - Sabroe 01` | Amperímetro | Corrente elétrica do compressor (A) |
| `Capacidade - Sabroe 01` | PLC | Capacidade percentual em uso (%) |
| `Pressão de Descarga - Sabroe 01` | Transdutor de pressão | Pressão na saída do compressor (bar) |
| `Temperatura de Descarga - Sabroe 01` | Termopar | Temperatura do gás na descarga (°C) |
| `Pressão de Óleo - Sabroe 01` | Transdutor de pressão | Pressão do óleo de lubrificação (bar) |
| `Temperatura do Óleo - Sabroe 01` | Termopar | Temperatura do óleo de lubrificação (°C) |
| `Superaquecimento de Aspiração - Sabroe 01` | Sensor de temperatura | Superaquecimento do refrigerante na aspiração (°C) |
| `Pressão de Aspiração - Sabroe 01` | Transdutor de pressão | Pressão na entrada do compressor (bar) |
| `Temperatura de Processo - Sabroe 01` | Termopar | Temperatura do processo de refrigeração (°C) |
| `Temperatura de Aspiração - Sabroe 01` | Termopar | Temperatura do gás na aspiração (°C) |

**Colunas:**

| Coluna | Tipo | Unidade | Descrição |
|---|---|---|---|
| `dt` | timestamptz | — | Timestamp do registro. Eixo principal da série. |
| `corrente` | numeric | A | Corrente elétrica do compressor (`Corrente - Sabroe 01`). Valor MAX por dt. **0** quando sem leitura no intervalo. |
| `capacidade` | numeric | % | Capacidade percentual em uso do compressor (`Capacidade - Sabroe 01`). Indica o quanto da capacidade nominal está sendo utilizada. **0** quando sem leitura. |
| `pressao_descarga` | numeric | bar | Pressão de descarga do compressor (`Pressão de Descarga - Sabroe 01`). Valores altos indicam possível sobrecarga. Threshold de alerta: 16 bar. |
| `temp_descarga` | numeric | °C | Temperatura do gás na descarga (`Temperatura de Descarga - Sabroe 01`). Threshold de alerta: 120 °C. |
| `pressao_oleo` | numeric | bar | Pressão do óleo de lubrificação (`Pressão de Óleo - Sabroe 01`). Faixa nominal: 3,2–6,5 bar. Fora desse intervalo indica problema de lubrificação. |
| `temp_oleo` | numeric | °C | Temperatura do óleo de lubrificação (`Temperatura do Óleo - Sabroe 01`). Faixa nominal: 25–75 °C. |
| `superaquecimento_aspiracao` | numeric | °C | Superaquecimento do refrigerante (amônia) na aspiração (`Superaquecimento de Aspiração - Sabroe 01`). Valores negativos indicam presença de líquido na aspiração (perigoso para o compressor). |
| `pressao_aspiracao` | numeric | bar | Pressão na entrada do compressor (`Pressão de Aspiração - Sabroe 01`). Faixa nominal: 0,8–1,5 bar. |
| `temp_processo` | numeric | °C | Temperatura do processo de refrigeração (`Temperatura de Processo - Sabroe 01`). |
| `temp_aspiracao` | numeric | °C | Temperatura do gás refrigerante na aspiração (`Temperatura de Aspiração - Sabroe 01`). |

**Query de referência para o Grafana:**
```sql
SELECT dt, corrente, capacidade, pressao_descarga, temp_descarga,
       pressao_oleo, temp_oleo, superaquecimento_aspiracao,
       pressao_aspiracao, temp_processo, temp_aspiracao
FROM dbt_compressao_liquefacao.compressao_liquefacao__comp_sabroe_1
WHERE $__timeFilter(dt)
ORDER BY dt
```

---

## 2. `compressao_liquefacao__comp_sabroe_2`

**Grupo:** Compressor Sabroe 02 — Refrigeração de Liquefação
**Finalidade:** Idêntico ao `comp_sabroe_1`, mas para o segundo compressor de refrigeração.
Série temporal com os 10 parâmetros operacionais do Sabroe 02.

**Granularidade:** 1 registro por leitura dos sensores (tipicamente por minuto).

**Regras aplicadas antes do mart:**
- Nenhuma transformação de negócio. Todos os valores são leituras brutas diretas do sensor.
- Spine de timestamps via UNION de todos os `data_hora` das 10 tags.
- `COALESCE(..., 0)` aplicado a cada coluna para resiliência a ausências pontuais de leitura.

**Tags de origem:**

| Tag | Instrumento | Papel |
|---|---|---|
| `Corrente - Sabroe 02` | Amperímetro | Corrente elétrica do compressor (A) |
| `Capacidade - Sabroe 02` | PLC | Capacidade percentual em uso (%) |
| `Pressão de Descarga - Sabroe 02` | Transdutor de pressão | Pressão na saída do compressor (bar) |
| `Temperatura de Descarga - Sabroe 02` | Termopar | Temperatura do gás na descarga (°C) |
| `Pressão de Óleo - Sabroe 02` | Transdutor de pressão | Pressão do óleo de lubrificação (bar) |
| `Temperatura do Óleo - Sabroe 02` | Termopar | Temperatura do óleo de lubrificação (°C) |
| `Superaquecimento de Aspiração - Sabroe 02` | Sensor de temperatura | Superaquecimento do refrigerante na aspiração (°C) |
| `Pressão de Aspiração - Sabroe 02` | Transdutor de pressão | Pressão na entrada do compressor (bar) |
| `Temperatura de Processo - Sabroe 02` | Termopar | Temperatura do processo de refrigeração (°C) |
| `Temperatura de Aspiração - Sabroe 02` | Termopar | Temperatura do gás na aspiração (°C) |

**Colunas:**

| Coluna | Tipo | Unidade | Descrição |
|---|---|---|---|
| `dt` | timestamptz | — | Timestamp do registro. Eixo principal da série. |
| `corrente` | numeric | A | Corrente elétrica do compressor (`Corrente - Sabroe 02`). |
| `capacidade` | numeric | % | Capacidade percentual em uso (`Capacidade - Sabroe 02`). |
| `pressao_descarga` | numeric | bar | Pressão de descarga (`Pressão de Descarga - Sabroe 02`). Threshold de alerta: 16 bar. |
| `temp_descarga` | numeric | °C | Temperatura de descarga (`Temperatura de Descarga - Sabroe 02`). Threshold de alerta: 120 °C. |
| `pressao_oleo` | numeric | bar | Pressão do óleo (`Pressão de Óleo - Sabroe 02`). Faixa nominal: 3,2–6,5 bar. |
| `temp_oleo` | numeric | °C | Temperatura do óleo (`Temperatura do Óleo - Sabroe 02`). Faixa nominal: 25–75 °C. |
| `superaquecimento_aspiracao` | numeric | °C | Superaquecimento na aspiração (`Superaquecimento de Aspiração - Sabroe 02`). |
| `pressao_aspiracao` | numeric | bar | Pressão de aspiração (`Pressão de Aspiração - Sabroe 02`). Faixa nominal: 0,8–1,5 bar. |
| `temp_processo` | numeric | °C | Temperatura de processo (`Temperatura de Processo - Sabroe 02`). |
| `temp_aspiracao` | numeric | °C | Temperatura de aspiração (`Temperatura de Aspiração - Sabroe 02`). |

**Query de referência para o Grafana:**
```sql
SELECT dt, corrente, capacidade, pressao_descarga, temp_descarga,
       pressao_oleo, temp_oleo, superaquecimento_aspiracao,
       pressao_aspiracao, temp_processo, temp_aspiracao
FROM dbt_compressao_liquefacao.compressao_liquefacao__comp_sabroe_2
WHERE $__timeFilter(dt)
ORDER BY dt
```

---

## 3. `var_compressao_liquefacao__tags`

**Tipo:** View de variável (não é mart — não tem hypertable, não é incremental).
**Finalidade:** Popula o dropdown `$Tags` do dashboard Grafana. Lista os parâmetros disponíveis
para os painéis multi-série (painéis 60 e 67), removendo o sufixo `- Sabroe 01/02` para
exibir nomes legíveis ao operador.

**Colunas:**

| Coluna | Tipo | Descrição |
|---|---|---|
| `tags` | text | Nome do parâmetro sem sufixo de compressor (ex: `Temperatura de Processo`). |

**Query simplificada para o Grafana (configuração da variável):**
```sql
SELECT tags FROM dbt_compressao_liquefacao.var_compressao_liquefacao__tags ORDER BY 1
```

**Parâmetros disponíveis** (derivados do padrão `~* '^(Pressão|Temperatura|Superaquecimento).*Sabroe'`):
- Pressão de Aspiração
- Pressão de Descarga
- Pressão de Óleo
- Superaquecimento de Aspiração
- Temperatura de Aspiração
- Temperatura de Descarga
- Temperatura de Processo
- Temperatura do Óleo

---

## Notas gerais para o agente

- **Série temporal sempre:** ambos os marts retornam séries completas. Reduções (último valor,
  média) são responsabilidade do painel Grafana, nunca do mart.
- **COALESCE(0):** ausência de leitura em qualquer tag resulta em `0`, não em `NULL`. Ao
  filtrar "compressor desligado", prefira `corrente = 0 AND capacidade = 0` ao invés de
  `IS NULL`.
- **Dois compressores independentes:** `comp_sabroe_1` e `comp_sabroe_2` são séries separadas —
  podem ter timestamps diferentes e frequências de leitura distintas.
- **Schema real:** `dbt_compressao_liquefacao` (gerado pela macro `generate_schema_name` que
  usa o `custom_schema_name` diretamente, sem prefixo adicional).
- **Estratégia incremental:** ambos os marts usam `unique_key='dt'` com
  `WHERE dt > MAX(dt in this)`. Na primeira execução completa carregam toda a time window;
  nas seguintes, apenas novos registros são inseridos.
- **Relação com producao__liquefacao:** os campos `cap_sabroe_01` e `cap_sabroe_02` do mart
  `producao__liquefacao` (schema `dbt_producao`) usam as mesmas tags de capacidade deste
  dashboard. Para detalhamento operacional completo dos Sabroes, use este dashboard.
