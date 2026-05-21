# Referência de Marts — Projeto Chlorum (Português-BR)

> Documento destinado a agentes LLM. Contém a descrição completa de cada mart,
> incluindo finalidade, colunas, unidades, tags de origem e regras de negócio
> aplicadas. Use este arquivo para entender o que consultar e como interpretar
> cada coluna antes de gerar queries ou explicações.

Todos os marts vivem no schema `dbt_producao`. Todas as séries são temporais,
keyed por `dt` (`timestamptz`). O Grafana aplica reduções visuais (last, sum, avg)
— o mart sempre expõe a série completa.

---

## Índice

1. [producao__mb_45](#1-producao__mb_45)
2. [producao__solenis](#2-producao__solenis)
3. [producao__hcl](#3-producao__hcl)
4. [producao__hipo](#4-producao__hipo)
5. [producao__liquefacao](#5-producao__liquefacao)
6. [producao__estoque_cloro](#6-producao__estoque_cloro)
7. [producao__estoque_hcl](#7-producao__estoque_hcl)
8. [producao__estoque_hipo](#8-producao__estoque_hipo)
9. [producao__estoque_naoh](#9-producao__estoque_naoh)
10. [producao__producao_diaria](#10-producao__producao_diaria)

---

## 1. `producao__mb_45`

**Grupo:** MB_45 — Membrana Eletrolítica Bipolar 45
**Finalidade:** Monitoramento em tempo real da operação da membrana: corrente elétrica, tensão
média por eletrodo, disponibilidade operacional e eficiência de produção de Cl2.

**Granularidade:** 1 registro por minuto de operação.

**Regras aplicadas antes do mart:**
- Tensão zerada automaticamente quando a planta está desligada (`Planta Membrana Ligada = 0`).
- Divisão da tensão total por 92 eletrodos para obter tensão média por célula.
- Disponibilidade calculada como `horas_on / 24 × 100`, limitada a 100%.
- Eficiência calculada pela fórmula eletroquímica: `sensor_value / (corrente_filtrada × 1,4923 × n_cell × horas_on × 100)`.
- `producao_cl2` calculada uma vez por dia e repetida em cada minuto via JOIN por data.
- `status = 1` quando `corrente > 3`, indicando planta em operação.

**Tags de origem:**

| Tag | Instrumento | Papel |
|---|---|---|
| `II113RC001\U` | Amperímetro da membrana | Corrente da planta (kA) |
| `EI113RC001\U` | Voltímetro geral | Tensão total da membrana (V) |
| `Planta Membrana Ligada` | Status PLC | Gate liga/desliga para a tensão |
| `WQI13107_100\V` | Totalizador de soda | Base do cálculo de eficiência |

**Colunas:**

| Coluna | Tipo | Unidade | Descrição |
|---|---|---|---|
| `dt` | timestamptz | — | Timestamp do registro. Eixo principal da série. |
| `corrente` | numeric | kA | Corrente lida da tag `II113RC001\U`. Valor bruto MAX por minuto. |
| `tensao_media` | numeric | V | Tensão média por eletrodo (`soma_tensao / 92`). Vale **0** quando `Planta Membrana Ligada = 0`. |
| `horas_on` | numeric | horas | Horas com corrente > 2,8 A no dia. Valor diário repetido por minuto. |
| `disponibilidade` | numeric | % | `horas_on / 24 × 100`, limitado a 100%. Valor diário repetido por minuto. |
| `eficiencia` | numeric | % | Eficiência de conversão eletroquímica do dia. Valor diário repetido por minuto. |
| `producao_cl2` | numeric | ton | Produção de Cl2 do dia. Valor diário repetido por minuto. |
| `plan_diario` | numeric | ton | Meta de produção diária (42,7 ton/dia fixo). Repetido por minuto. |
| `status` | integer | 0 ou 1 | **1** quando `corrente > 3` (planta em operação), **0** caso contrário. |

**Query de referência para o Grafana:**
```sql
SELECT dt, corrente, tensao_media, disponibilidade, eficiencia,
       producao_cl2, plan_diario, status
FROM dbt_producao.producao__mb_45
WHERE $__timeFilter(dt)
ORDER BY dt
```

---

## 2. `producao__solenis`

**Grupo:** Solenis — Vendas de subprodutos
**Finalidade:** Monitoramento minuto a minuto do fluxo de venda de cloro, vapor e soda para a
Solenis. Inclui flags binárias de "sem venda" e status de operação.

**Granularidade:** 1 registro por minuto.

**Regras aplicadas antes do mart:**
- Valores negativos zerados em todas as colunas de fluxo.
- `sem_cloro`: acionado quando `venda_cloro ≤ 0,2`.
- `sem_vapor` e `sem_soda`: acionados quando a venda é `≤ 0`.
- `status = 1` quando a soma de qualquer venda (cloro + vapor + soda) for maior que zero.

**Tags de origem:**

| Tag | Instrumento | Papel |
|---|---|---|
| `FI01507\U` | Medidor de fluxo | Fluxo de cloro vendido |
| `FIC076012\PV_IN` | Controlador de vazão | Fluxo de vapor vendido |
| `Soda_solenis` | Tag de soda | Fluxo de soda vendida |

**Colunas:**

| Coluna | Tipo | Unidade | Descrição |
|---|---|---|---|
| `dt` | timestamptz | — | Timestamp do registro. |
| `venda_cloro` | numeric | — | Fluxo de cloro vendido (`FI01507\U`). Negativos zerados. |
| `venda_vapor` | numeric | — | Fluxo de vapor vendido (`FIC076012\PV_IN`). Negativos zerados. |
| `venda_soda` | numeric | — | Fluxo de soda vendida (`Soda_solenis`). Negativos zerados. |
| `sem_cloro` | integer | 0 ou 1 | **1** quando `venda_cloro ≤ 0,2`. |
| `sem_vapor` | integer | 0 ou 1 | **1** quando `venda_vapor ≤ 0`. |
| `sem_soda` | integer | 0 ou 1 | **1** quando `venda_soda ≤ 0`. |
| `status` | integer | 0 ou 1 | **1** quando qualquer venda (cloro + vapor + soda) > 0, **0** quando todas as vendas são zero. |

**Query de referência para o Grafana:**
```sql
SELECT dt, venda_cloro, venda_vapor, venda_soda,
       sem_cloro, sem_vapor, sem_soda, status
FROM dbt_producao.producao__solenis
WHERE $__timeFilter(dt)
ORDER BY dt
```

---

## 3. `producao__hcl`

**Grupo:** HCl — Produção de Ácido Clorídrico
**Finalidade:** Série temporal da produção incremental de HCl, sua concentração e a fração da
capacidade instalada em uso a cada minuto.

**Granularidade:** 1 registro por minuto.

**Regras aplicadas antes do mart:**
- `producao_hcl` é um **delta incremental** via `LAG + GREATEST(..., 0)`.
- `capacidade_atual` normalizada pela capacidade máxima (495 unidades). Zerada quando ≤ 0.
- `status = 1` quando `producao_hcl > 0`.

**Tags de origem:**

| Tag | Instrumento | Papel |
|---|---|---|
| `Producao_HCL` | Totalizador acumulado | Base do delta de produção |
| `Concentracao_HCL` | Analisador | Concentração percentual |
| `FIC051025C\PV_IN` | Controlador de fluxo | Fluxo de entrada para cálculo de capacidade |

**Colunas:**

| Coluna | Tipo | Unidade | Descrição |
|---|---|---|---|
| `dt` | timestamptz | — | Timestamp do registro. |
| `producao_hcl` | numeric | ton | Produção incremental de HCl no intervalo. Nunca negativo. |
| `concentracao` | numeric | % | Concentração de HCl no minuto. Valor médio, sem transformação. |
| `capacidade_atual` | numeric | fração (0–1) | `FIC051025C\PV_IN / 495`. **0** quando fluxo bruto ≤ 0. |
| `status` | integer | 0 ou 1 | **1** quando `producao_hcl > 0`, **0** caso contrário. |

**Query de referência para o Grafana:**
```sql
SELECT dt, producao_hcl, concentracao, capacidade_atual, status
FROM dbt_producao.producao__hcl
WHERE $__timeFilter(dt)
ORDER BY dt
```

---

## 4. `producao__hipo`

**Grupo:** Hipo — Hipoclorito de Sódio
**Finalidade:** Série temporal das métricas do processo de produção de hipoclorito de sódio
(NaClO): produção, consumo de NaOH, capacidade, vazão de água, flag de operação,
consumo de cloro instantâneo e produção em toneladas.

**Granularidade:** 1 registro por minuto.

**Regras aplicadas antes do mart:**
- `naclo`: convertida de unidade interna para toneladas (÷ 60.000). Negativos = 0.
- `consumo_naoh`: amplificado por fator estequiométrico (× 357). Negativos = 0.
- `capacidade`: `naoh_raw × (350 / 15)` — teto teórico de produção dado o fluxo de NaOH.
- `vazao_agua`: negativos zerados.
- `cl2_on = 1` quando `FIC12718\MV ≥ 1`.
- `consumo_cloro`: `(consumo_naoh × 1560 + vazao_agua × 1210) / 60.000`.
- `producao_hipo_ton`: `(naoh_valid × 1560 + vazao_agua × 1210) × cl2_on / 60.000`, onde `naoh_valid` é `naoh_raw` com negativos zerados (sem o fator × 357).

**Tags de origem:**

| Tag | Instrumento | Papel |
|---|---|---|
| `FI_NaCl0\U` | Medidor de fluxo | Produção de NaClO |
| `FIC12702\PV_IN` | Controlador de vazão | Vazão de NaOH para produção de hipo |
| `FIC12703\PV_IN` | Controlador de vazão | Vazão de água de diluição |
| `FIC12718\MV` | Controlador de Cl2 | Variável manipulada (0–100%) — gate de produção |

**Colunas:**

| Coluna | Tipo | Unidade | Descrição |
|---|---|---|---|
| `dt` | timestamptz | — | Timestamp do registro. |
| `naclo` | numeric | ton | Produção de NaClO no minuto (`FI_NaCl0\U / 60.000`). Negativos = 0. |
| `consumo_naoh` | numeric | — | Consumo de NaOH calculado (`FIC12702\PV_IN × 357`). Negativos = 0. |
| `capacidade` | numeric | % | Capacidade de produção (`FIC12702\PV_IN × 350/15`). Painel 124. |
| `vazao_agua` | numeric | — | Vazão de água de diluição (`FIC12703\PV_IN`). Negativos zerados. |
| `cl2_on` | integer | 0 ou 1 | **1** quando `FIC12718\MV ≥ 1` (Cl2 ligado), **0** caso contrário. |
| `consumo_cloro` | numeric | — | Consumo de cloro instantâneo: `(consumo_naoh×1560 + vazao_agua×1210) / 60.000`. Painel 73 — reduzir com `lastNotNull`. |
| `producao_hipo_ton` | numeric | ton | Produção de hipo por intervalo: `(naoh_valid×1560 + vazao_agua×1210) × cl2_on / 60.000`. Painel 123 — reduzir com `SUM`. |

**Query de referência para o Grafana:**
```sql
SELECT dt, naclo, consumo_naoh, capacidade, vazao_agua,
       cl2_on, consumo_cloro, producao_hipo_ton
FROM dbt_producao.producao__hipo
WHERE $__timeFilter(dt)
ORDER BY dt
```

---

## 5. `producao__liquefacao`

**Grupo:** Liquefação — Compressão de Cl2 Líquido
**Finalidade:** Série temporal da taxa de compressão de Cl2 líquido em cada tanque, status dos
compressores CPC e capacidade dos compressores Sabroe.

**Granularidade:** 1 registro por minuto.

**Regras aplicadas antes do mart:**
- Pesos fora de `[-900, 130.000]` g são descartados.
- `taxa_compressao` calculada via `regr_slope` sobre os últimos 10 registros × 3.600 (g/s → g/h).
- Taxas ≥ 4.500 kg/h são descartadas (outliers).
- `status = 1` quando a soma de qualquer compressor ou Sabroe ativo for maior que zero.

**Tags de origem:**

| Tag | Instrumento | Papel |
|---|---|---|
| `Peso%Tanque%` (LIKE) | Células de carga | Peso bruto de Cl2 por tanque |
| `YLL CCL-COM-CPC - A` | PLC | Status do compressor CPC-A |
| `YLL CCL-COM-CPC- B` | PLC | Status do compressor CPC-B |
| `YLL CCL-COM-CPC - C` | PLC | Status do compressor CPC-C |
| `YLL CCL-COM-CPC- 3` | PLC | Status do compressor CPC-3 |
| `Capacidade - Sabroe 01` | PLC | Capacidade percentual do Sabroe 01 |
| `Capacidade - Sabroe 02` | PLC | Capacidade percentual do Sabroe 02 |

**Colunas:**

| Coluna | Tipo | Unidade | Descrição |
|---|---|---|---|
| `dt` | timestamptz | — | Timestamp do registro. |
| `cpc_tanque_01` a `cpc_tanque_06` | numeric | kg/h | Taxa de compressão por tanque via regressão linear. Nula com menos de 10 leituras válidas. |
| `status_cpc_a` | integer | 0 ou 1 | Status do compressor CPC-A. |
| `status_cpc_b` | integer | 0 ou 1 | Status do compressor CPC-B. |
| `status_cpc_c` | integer | 0 ou 1 | Status do compressor CPC-C. |
| `status_cpc_3` | integer | 0 ou 1 | Status do compressor CPC-3. |
| `cap_sabroe_01` | numeric | % | Capacidade em uso do Sabroe 01. |
| `cap_sabroe_02` | numeric | % | Capacidade em uso do Sabroe 02. |
| `status` | integer | 0 ou 1 | **1** quando qualquer compressor/Sabroe estiver ativo, **0** quando todos estão desligados. |

**Query de referência para o Grafana:**
```sql
SELECT dt, cpc_tanque_01, cpc_tanque_02, cpc_tanque_03, cpc_tanque_04,
       cpc_tanque_05, cpc_tanque_06, status_cpc_a, status_cpc_b,
       status_cpc_c, status_cpc_3, cap_sabroe_01, cap_sabroe_02, status
FROM dbt_producao.producao__liquefacao
WHERE $__timeFilter(dt)
ORDER BY dt
```

---

## 6. `producao__estoque_cloro`

**Grupo:** Estoque Cloro — Estoque de Cl2 Líquido
**Finalidade:** Série temporal do estoque total de cloro líquido nos tanques, em toneladas.

**Granularidade:** 1 registro por leitura dos sensores de peso.

**Regras aplicadas antes do mart:**
- Pesos fora de `[-900, 130.000]` g descartados por tanque.
- Soma em gramas convertida para toneladas (÷ 1.000).
- `status = 1` quando `peso_total_ton > 0`.

**Tags de origem:**

| Tag | Instrumento | Papel |
|---|---|---|
| `Peso%Tanque%0%` (LIKE) | Células de carga | Peso de Cl2 por tanque |

**Colunas:**

| Coluna | Tipo | Unidade | Descrição |
|---|---|---|---|
| `dt` | timestamptz | — | Timestamp do registro. |
| `peso_total_ton` | numeric | toneladas | Estoque total de Cl2: soma dos pesos válidos convertida de gramas para toneladas. |
| `status` | integer | 0 ou 1 | **1** quando `peso_total_ton > 0`. |

**Query de referência para o Grafana:**
```sql
SELECT dt, peso_total_ton, status
FROM dbt_producao.producao__estoque_cloro
WHERE $__timeFilter(dt)
ORDER BY dt
```

---

## 7. `producao__estoque_hcl`

**Grupo:** Estoque HCl — Estoque de Ácido Clorídrico
**Finalidade:** Série temporal do nível total de HCl armazenado nos tanques.

**Granularidade:** 1 registro por leitura dos transmissores de nível.

**Regras aplicadas antes do mart:**
- Leituras fora de `[-900, 130.000]` descartadas.
- Fator de 95% aplicado (`× 0,95`).
- `status = 1` quando `nivel_total > 0`.

**Tags de origem:**

| Tag | Instrumento | Papel |
|---|---|---|
| `READ_TRANSMITERS\LI0510%.PV` (LIKE) | Transmissores de nível | Nível de HCl por tanque |

**Colunas:**

| Coluna | Tipo | Unidade | Descrição |
|---|---|---|---|
| `dt` | timestamptz | — | Timestamp do registro. |
| `nivel_total` | numeric | — | Nível total de HCl: soma × 0,95. |
| `status` | integer | 0 ou 1 | **1** quando `nivel_total > 0`. |

**Query de referência para o Grafana:**
```sql
SELECT dt, nivel_total, status
FROM dbt_producao.producao__estoque_hcl
WHERE $__timeFilter(dt)
ORDER BY dt
```

---

## 8. `producao__estoque_hipo`

**Grupo:** Estoque Hipo — Estoque de Hipoclorito de Sódio
**Finalidade:** Série temporal do nível total de NaClO armazenado nos tanques.

**Granularidade:** 1 registro por leitura dos transmissores de nível.

**Regras aplicadas antes do mart:**
- Leituras fora de `[-900, 130.000]` descartadas.
- Fator de 95% aplicado (`× 0,95`).
- `status = 1` quando `nivel_total > 0`.

**Tags de origem:**

| Tag | Instrumento | Papel |
|---|---|---|
| `LI0264%\U` (LIKE) | Transmissores de nível | Nível de NaClO por tanque |

**Colunas:**

| Coluna | Tipo | Unidade | Descrição |
|---|---|---|---|
| `dt` | timestamptz | — | Timestamp do registro. |
| `nivel_total` | numeric | — | Nível total de NaClO: soma × 0,95. |
| `status` | integer | 0 ou 1 | **1** quando `nivel_total > 0`. |

**Query de referência para o Grafana:**
```sql
SELECT dt, nivel_total, status
FROM dbt_producao.producao__estoque_hipo
WHERE $__timeFilter(dt)
ORDER BY dt
```

---

## 9. `producao__estoque_naoh`

**Grupo:** Estoque NaOH — Estoque de Soda Cáustica
**Finalidade:** Série temporal do nível total de NaOH armazenado nos tanques.

**Granularidade:** 1 registro por leitura dos transmissores de nível.

**Regras aplicadas antes do mart:**
- Leituras fora de `[-900, 130.000]` descartadas.
- Fator de 95% aplicado (`× 0,95`).
- `status = 1` quando `nivel_total > 0`.

**Tags de origem:**

| Tag | Instrumento | Papel |
|---|---|---|
| `LI0000%\U` (LIKE) | Transmissores de nível | Nível de NaOH por tanque |

**Colunas:**

| Coluna | Tipo | Unidade | Descrição |
|---|---|---|---|
| `dt` | timestamptz | — | Timestamp do registro. |
| `nivel_total` | numeric | — | Nível total de NaOH: soma × 0,95. |
| `status` | integer | 0 ou 1 | **1** quando `nivel_total > 0`. |

**Query de referência para o Grafana:**
```sql
SELECT dt, nivel_total, status
FROM dbt_producao.producao__estoque_naoh
WHERE $__timeFilter(dt)
ORDER BY dt
```

---

## 10. `producao__producao_diaria`

**Grupo:** Produção Diária — Visão Consolidada de Produção
**Finalidade:** Mart mais abrangente do projeto. Consolida numa única série temporal todas as
métricas de produção: soda, HCl, Cl2 líquido, demanda elétrica, tensão, fator de potência,
produção de Cl2, plano diário, consumo de energia e eficiência energética.

**Granularidade:** 1 registro por minuto.

**Regras aplicadas antes do mart:**
- `producao_soda` e `producao_hcl`: deltas de totalizadores via `LAG + GREATEST(..., 0)`.
- `vazao_agua`: negativos zerados.
- `cl2_on = 1` quando `FIC12718\MV ≥ 1`.
- `cl2_liquido`: fluxo de Cl2 líquido (`FI01507\U`), negativos zerados.
- `demanda`: convertida de W para kW (÷ 1.000).
- `producao_cl2` e `plan_diario`: calculados uma vez por dia e repetidos por minuto via JOIN por data.
- `kwh_diario`: valor diário de `dashboard.geral_hist` (tag `total_kwh_diario`), repetido por minuto.
- `kwh_por_ton = CEIL(kwh_diario / producao_cl2)`: eficiência energética calculada no mart.

**Tags de origem:**

| Tag | Instrumento | Papel |
|---|---|---|
| `WQI13107_100\V` | Totalizador de soda | Base do delta de produção de soda |
| `Producao_HCL` | Totalizador de HCl | Base do delta de produção de HCl |
| `FIC12702\PV_IN` | Controlador de vazão | Vazão de NaOH |
| `FIC12703\PV_IN` | Controlador de vazão | Vazão de água |
| `FIC12718\MV` | Controlador | Sinal de Cl2 ligado |
| `FI01507\U` | Medidor de fluxo | Fluxo de Cl2 líquido |
| `Demanda Variável` | Medidor de energia | Demanda elétrica total da planta |
| `Tensão Média FF` | Medidor elétrico | Tensão média da rede de alimentação |
| `Fator de Potência` | Medidor elétrico | Fator de potência da planta |

**Colunas:**

| Coluna | Tipo | Unidade | Descrição |
|---|---|---|---|
| `dt` | timestamptz | — | Timestamp do registro. Eixo principal. |
| `producao_soda` | numeric | — | Delta do totalizador `WQI13107_100\V`. Nunca negativo. |
| `producao_hcl` | numeric | — | Delta do totalizador `Producao_HCL`. Nunca negativo. |
| `vazao_naoh` | numeric | — | Vazão de NaOH (`FIC12702\PV_IN`). Sem transformação. |
| `vazao_agua` | numeric | — | Vazão de água (`FIC12703\PV_IN`). Negativos zerados. |
| `cl2_on` | integer | 0 ou 1 | **1** quando `FIC12718\MV ≥ 1`. |
| `cl2_liquido` | numeric | — | Fluxo de Cl2 líquido (`FI01507\U`). Negativos zerados. Painel 158: `SUM(cl2_liquido) / 105.0 = ton/mês`. |
| `demanda` | numeric | kW | Demanda elétrica total (`Demanda Variável / 1.000`). |
| `tensao_ff` | numeric | V | Tensão média da rede (`Tensão Média FF`). |
| `fator_potencia` | numeric | — | Fator de potência da planta. |
| `producao_cl2` | numeric | ton | Produção de Cl2 do dia. Valor diário repetido por minuto. |
| `plan_diario` | numeric | ton | Meta diária (42,7 ton/dia). Repetido por minuto. |
| `kwh_diario` | numeric | kWh | Consumo de energia do dia (`dashboard.geral_hist` — `total_kwh_diario`). Valor diário repetido por minuto. |
| `kwh_por_ton` | numeric | kWh/ton | Eficiência energética: `CEIL(kwh_diario / producao_cl2)`. Painel 113 — reduzir com `lastNotNull`. |

**Query de referência para o Grafana:**
```sql
SELECT dt, producao_soda, producao_hcl, vazao_naoh, vazao_agua,
       cl2_on, cl2_liquido, demanda, tensao_ff, fator_potencia,
       producao_cl2, plan_diario, kwh_diario, kwh_por_ton
FROM dbt_producao.producao__producao_diaria
WHERE $__timeFilter(dt)
ORDER BY dt
```

---

## Notas gerais para o agente

- **Série temporal sempre:** todos os marts retornam séries completas. Reduções (soma, último valor) são responsabilidade do painel Grafana, nunca do mart.
- **Valores diários repetidos por minuto:** `horas_on`, `disponibilidade`, `eficiencia`, `producao_cl2`, `plan_diario`, `kwh_diario` e `kwh_por_ton` têm granularidade diária mas aparecem repetidos em cada linha minuto. Ao agregar, use `MAX()` ou `DISTINCT ON (date_trunc('day', dt))` para evitar dupla contagem.
- **Fator 95% nos estoques:** presente em `estoque_hcl`, `estoque_hipo` e `estoque_naoh`. Representa calibração de engenharia, não erro.
- **Coluna `status`:** presente em todos os marts. Sempre `0` ou `1`. Indica se o grupo estava operando no minuto. A lógica varia por grupo (ver descrição de cada seção).
- **Backslash em tags:** tags como `II113RC001\U` contêm barra invertida literal. Em SQL, dentro de string de aspas simples, `\` é literal — nunca duplique.
- **Schema:** `dbt_producao` (gerado pela macro `generate_schema_name` diretamente, sem prefixo adicional).
