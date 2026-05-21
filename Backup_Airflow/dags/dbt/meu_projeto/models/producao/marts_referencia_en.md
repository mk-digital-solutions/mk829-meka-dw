# Marts Reference — Chlorum Project (English)

> Document for LLM agents. Contains the complete description of each mart,
> including purpose, columns, units, source tags and business rules applied.
> Use this file to understand what to query and how to interpret each column
> before generating queries or explanations.

All marts live in the `dbt_producao` schema. All series are time-series,
keyed by `dt` (`timestamptz`). Grafana applies visual reductions (last, sum, avg)
— the mart always exposes the full series.

---

## Index

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

**Group:** MB_45 — Bipolar Electrolytic Membrane 45
**Purpose:** Real-time monitoring of membrane operation: electric current, average voltage per
electrode, operational availability and Cl2 production efficiency.

**Granularity:** 1 record per minute of operation.

**Business rules applied before the mart:**
- Voltage is automatically zeroed when the plant is off (`Planta Membrana Ligada = 0`).
- Total voltage divided by 92 electrodes to get average voltage per cell.
- Availability calculated as `hours_on / 24 × 100`, capped at 100%.
- Efficiency calculated by electrochemical formula: `sensor_value / (filtered_current × 1.4923 × n_cell × hours_on × 100)`.
- `producao_cl2` calculated once per day and repeated each minute via JOIN by date.
- `status = 1` when `corrente > 3`, indicating the plant is operating.

**Source tags:**

| Tag | Instrument | Role |
|---|---|---|
| `II113RC001\U` | Membrane ammeter | Plant current (kA) |
| `EI113RC001\U` | General voltmeter | Total membrane voltage (V) |
| `Planta Membrana Ligada` | PLC status | On/off gate for voltage |
| `WQI13107_100\V` | Caustic soda totalizer | Base for efficiency calculation |

**Columns:**

| Column | Type | Unit | Description |
|---|---|---|---|
| `dt` | timestamptz | — | Record timestamp. Main series axis. |
| `corrente` | numeric | kA | Current read from `II113RC001\U`. MAX raw value per minute. |
| `tensao_media` | numeric | V | Average voltage per electrode (`total_voltage / 92`). **0** when `Planta Membrana Ligada = 0`. |
| `horas_on` | numeric | hours | Hours with current > 2.8 A on the day. Daily value repeated each minute. |
| `disponibilidade` | numeric | % | `hours_on / 24 × 100`, capped at 100%. Daily value repeated per minute. |
| `eficiencia` | numeric | % | Electrochemical conversion efficiency for the day. Daily value repeated per minute. |
| `producao_cl2` | numeric | ton | Cl2 production for the day. Daily value repeated per minute. |
| `plan_diario` | numeric | ton | Daily production target (fixed 42.7 ton/day). Repeated per minute. |
| `status` | integer | 0 or 1 | **1** when `corrente > 3` (plant operating), **0** otherwise. |

**Grafana reference query:**
```sql
SELECT dt, corrente, tensao_media, disponibilidade, eficiencia,
       producao_cl2, plan_diario, status
FROM dbt_producao.producao__mb_45
WHERE $__timeFilter(dt)
ORDER BY dt
```

---

## 2. `producao__solenis`

**Group:** Solenis — By-product sales
**Purpose:** Minute-by-minute monitoring of chlorine, steam and caustic soda sales flow to
Solenis. Includes binary "no-sale" flags and an operating status flag.

**Granularity:** 1 record per minute.

**Business rules applied before the mart:**
- Negative values zeroed in all flow columns.
- `sem_cloro`: triggered when `venda_cloro ≤ 0.2`.
- `sem_vapor` and `sem_soda`: triggered when sale is `≤ 0`.
- `status = 1` when the sum of any sale (chlorine + steam + soda) is greater than zero.

**Source tags:**

| Tag | Instrument | Role |
|---|---|---|
| `FI01507\U` | Flow meter | Chlorine flow sold |
| `FIC076012\PV_IN` | Flow controller | Steam flow sold |
| `Soda_solenis` | Soda tag | Caustic soda flow sold |

**Columns:**

| Column | Type | Unit | Description |
|---|---|---|---|
| `dt` | timestamptz | — | Record timestamp. |
| `venda_cloro` | numeric | — | Chlorine flow sold (`FI01507\U`). Negatives zeroed. |
| `venda_vapor` | numeric | — | Steam flow sold (`FIC076012\PV_IN`). Negatives zeroed. |
| `venda_soda` | numeric | — | Caustic soda flow sold (`Soda_solenis`). Negatives zeroed. |
| `sem_cloro` | integer | 0 or 1 | **1** when `venda_cloro ≤ 0.2`. |
| `sem_vapor` | integer | 0 or 1 | **1** when `venda_vapor ≤ 0`. |
| `sem_soda` | integer | 0 or 1 | **1** when `venda_soda ≤ 0`. |
| `status` | integer | 0 or 1 | **1** when any sale (chlorine + steam + soda) > 0, **0** when all sales are zero. |

**Grafana reference query:**
```sql
SELECT dt, venda_cloro, venda_vapor, venda_soda,
       sem_cloro, sem_vapor, sem_soda, status
FROM dbt_producao.producao__solenis
WHERE $__timeFilter(dt)
ORDER BY dt
```

---

## 3. `producao__hcl`

**Group:** HCl — Hydrochloric Acid Production
**Purpose:** Time series of incremental HCl production, its concentration and the fraction of
installed capacity in use each minute.

**Granularity:** 1 record per minute.

**Business rules applied before the mart:**
- `producao_hcl` is an **incremental delta** via `LAG + GREATEST(..., 0)`. Never negative.
- `capacidade_atual` normalised by maximum plant capacity (495 flow units). Zeroed when ≤ 0.
- `status = 1` when `producao_hcl > 0`.

**Source tags:**

| Tag | Instrument | Role |
|---|---|---|
| `Producao_HCL` | Accumulated totalizer | Base for production delta |
| `Concentracao_HCL` | Analyser | Percentage concentration |
| `FIC051025C\PV_IN` | Flow controller | Inlet flow for capacity calculation |

**Columns:**

| Column | Type | Unit | Description |
|---|---|---|---|
| `dt` | timestamptz | — | Record timestamp. |
| `producao_hcl` | numeric | ton | Incremental HCl production in the interval. Never negative. |
| `concentracao` | numeric | % | HCl concentration in the minute. Average value, no unit transformation. |
| `capacidade_atual` | numeric | fraction (0–1) | `FIC051025C\PV_IN / 495`. **0** when raw flow ≤ 0. |
| `status` | integer | 0 or 1 | **1** when `producao_hcl > 0`, **0** otherwise. |

**Grafana reference query:**
```sql
SELECT dt, producao_hcl, concentracao, capacidade_atual, status
FROM dbt_producao.producao__hcl
WHERE $__timeFilter(dt)
ORDER BY dt
```

---

## 4. `producao__hipo`

**Group:** Hipo — Sodium Hypochlorite
**Purpose:** Time series of sodium hypochlorite (NaClO) production process metrics: production,
NaOH consumption, capacity, water flow, operation flag, instantaneous chlorine consumption
and production in tonnes.

**Granularity:** 1 record per minute.

**Business rules applied before the mart:**
- `naclo`: converted from internal unit to tonnes (÷ 60,000). Negatives = 0.
- `consumo_naoh`: amplified by stoichiometric factor (× 357). Negatives = 0.
- `capacidade`: `naoh_raw × (350 / 15)` — theoretical production ceiling given current NaOH flow.
- `vazao_agua`: negatives zeroed.
- `cl2_on = 1` when `FIC12718\MV ≥ 1`.
- `consumo_cloro`: `(consumo_naoh × 1560 + vazao_agua × 1210) / 60,000`.
- `producao_hipo_ton`: `(naoh_valid × 1560 + vazao_agua × 1210) × cl2_on / 60,000`, where `naoh_valid` is `naoh_raw` with negatives zeroed (without the × 357 factor).

**Source tags:**

| Tag | Instrument | Role |
|---|---|---|
| `FI_NaCl0\U` | Flow meter | NaClO production |
| `FIC12702\PV_IN` | Flow controller | NaOH flow for hypochlorite production |
| `FIC12703\PV_IN` | Flow controller | Dilution water flow |
| `FIC12718\MV` | Cl2 controller | Manipulated variable (0–100%) — production gate |

**Columns:**

| Column | Type | Unit | Description |
|---|---|---|---|
| `dt` | timestamptz | — | Record timestamp. |
| `naclo` | numeric | ton | NaClO production in the minute (`FI_NaCl0\U / 60,000`). Negatives = 0. |
| `consumo_naoh` | numeric | — | NaOH consumption (`FIC12702\PV_IN × 357`). Negatives = 0. |
| `capacidade` | numeric | % | Production capacity (`FIC12702\PV_IN × 350/15`). Panel 124. |
| `vazao_agua` | numeric | — | Dilution water flow (`FIC12703\PV_IN`). Negatives zeroed. |
| `cl2_on` | integer | 0 or 1 | **1** when `FIC12718\MV ≥ 1` (Cl2 on), **0** otherwise. |
| `consumo_cloro` | numeric | — | Instantaneous chlorine consumption: `(consumo_naoh×1560 + vazao_agua×1210) / 60,000`. Panel 73 — reduce with `lastNotNull`. |
| `producao_hipo_ton` | numeric | ton | Hypochlorite production per interval: `(naoh_valid×1560 + vazao_agua×1210) × cl2_on / 60,000`. Panel 123 — reduce with `SUM`. |

**Grafana reference query:**
```sql
SELECT dt, naclo, consumo_naoh, capacidade, vazao_agua,
       cl2_on, consumo_cloro, producao_hipo_ton
FROM dbt_producao.producao__hipo
WHERE $__timeFilter(dt)
ORDER BY dt
```

---

## 5. `producao__liquefacao`

**Group:** Liquefação — Liquid Cl2 Compression
**Purpose:** Time series of liquid Cl2 compression rate per tank, CPC compressor status and
Sabroe compressor capacity.

**Granularity:** 1 record per minute.

**Business rules applied before the mart:**
- Weights outside `[-900, 130,000]` g are discarded.
- `taxa_compressao` calculated via `regr_slope` over the last 10 weight records × 3,600 (g/s → g/h).
- Rates ≥ 4,500 kg/h discarded (outliers).
- `status = 1` when any compressor or Sabroe is active.

**Source tags:**

| Tag | Instrument | Role |
|---|---|---|
| `Peso%Tanque%` (LIKE) | Load cells | Raw Cl2 weight per tank |
| `YLL CCL-COM-CPC - A` | PLC | CPC-A compressor status |
| `YLL CCL-COM-CPC- B` | PLC | CPC-B compressor status |
| `YLL CCL-COM-CPC - C` | PLC | CPC-C compressor status |
| `YLL CCL-COM-CPC- 3` | PLC | CPC-3 compressor status |
| `Capacidade - Sabroe 01` | PLC | Sabroe 01 percentage capacity |
| `Capacidade - Sabroe 02` | PLC | Sabroe 02 percentage capacity |

**Columns:**

| Column | Type | Unit | Description |
|---|---|---|---|
| `dt` | timestamptz | — | Record timestamp. |
| `cpc_tanque_01` to `cpc_tanque_06` | numeric | kg/h | Compression rate per tank via linear regression. Null with fewer than 10 valid readings. |
| `status_cpc_a` | integer | 0 or 1 | CPC-A compressor status. |
| `status_cpc_b` | integer | 0 or 1 | CPC-B compressor status. |
| `status_cpc_c` | integer | 0 or 1 | CPC-C compressor status. |
| `status_cpc_3` | integer | 0 or 1 | CPC-3 compressor status. |
| `cap_sabroe_01` | numeric | % | Sabroe 01 capacity in use. |
| `cap_sabroe_02` | numeric | % | Sabroe 02 capacity in use. |
| `status` | integer | 0 or 1 | **1** when any compressor/Sabroe is active, **0** when all are off. |

**Grafana reference query:**
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

**Group:** Estoque Cloro — Liquid Cl2 Stock
**Purpose:** Time series of total liquid chlorine stock in plant tanks, in tonnes.

**Granularity:** 1 record per weight sensor reading.

**Business rules applied before the mart:**
- Weights outside `[-900, 130,000]` g discarded per tank.
- Sum in grams converted to tonnes (÷ 1,000).
- `status = 1` when `peso_total_ton > 0`.

**Source tags:**

| Tag | Instrument | Role |
|---|---|---|
| `Peso%Tanque%0%` (LIKE) | Load cells | Cl2 weight per tank |

**Columns:**

| Column | Type | Unit | Description |
|---|---|---|---|
| `dt` | timestamptz | — | Record timestamp. |
| `peso_total_ton` | numeric | tonnes | Total Cl2 stock: sum of valid weights converted from grams to tonnes. |
| `status` | integer | 0 or 1 | **1** when `peso_total_ton > 0`. |

**Grafana reference query:**
```sql
SELECT dt, peso_total_ton, status
FROM dbt_producao.producao__estoque_cloro
WHERE $__timeFilter(dt)
ORDER BY dt
```

---

## 7. `producao__estoque_hcl`

**Group:** Estoque HCl — Hydrochloric Acid Stock
**Purpose:** Time series of total HCl level stored in tanks.

**Granularity:** 1 record per level transmitter reading.

**Business rules applied before the mart:**
- Readings outside `[-900, 130,000]` discarded.
- 95% factor applied (`× 0.95`).
- `status = 1` when `nivel_total > 0`.

**Source tags:**

| Tag | Instrument | Role |
|---|---|---|
| `READ_TRANSMITERS\LI0510%.PV` (LIKE) | Level transmitters | HCl level per tank |

**Columns:**

| Column | Type | Unit | Description |
|---|---|---|---|
| `dt` | timestamptz | — | Record timestamp. |
| `nivel_total` | numeric | — | Total HCl level: sum × 0.95. |
| `status` | integer | 0 or 1 | **1** when `nivel_total > 0`. |

**Grafana reference query:**
```sql
SELECT dt, nivel_total, status
FROM dbt_producao.producao__estoque_hcl
WHERE $__timeFilter(dt)
ORDER BY dt
```

---

## 8. `producao__estoque_hipo`

**Group:** Estoque Hipo — Sodium Hypochlorite Stock
**Purpose:** Time series of total NaClO level stored in tanks.

**Granularity:** 1 record per level transmitter reading.

**Business rules applied before the mart:**
- Readings outside `[-900, 130,000]` discarded.
- 95% factor applied (`× 0.95`).
- `status = 1` when `nivel_total > 0`.

**Source tags:**

| Tag | Instrument | Role |
|---|---|---|
| `LI0264%\U` (LIKE) | Level transmitters | NaClO level per tank |

**Columns:**

| Column | Type | Unit | Description |
|---|---|---|---|
| `dt` | timestamptz | — | Record timestamp. |
| `nivel_total` | numeric | — | Total NaClO level: sum × 0.95. |
| `status` | integer | 0 or 1 | **1** when `nivel_total > 0`. |

**Grafana reference query:**
```sql
SELECT dt, nivel_total, status
FROM dbt_producao.producao__estoque_hipo
WHERE $__timeFilter(dt)
ORDER BY dt
```

---

## 9. `producao__estoque_naoh`

**Group:** Estoque NaOH — Caustic Soda Stock
**Purpose:** Time series of total NaOH level stored in tanks.

**Granularity:** 1 record per level transmitter reading.

**Business rules applied before the mart:**
- Readings outside `[-900, 130,000]` discarded.
- 95% factor applied (`× 0.95`).
- `status = 1` when `nivel_total > 0`.

**Source tags:**

| Tag | Instrument | Role |
|---|---|---|
| `LI0000%\U` (LIKE) | Level transmitters | NaOH level per tank |

**Columns:**

| Column | Type | Unit | Description |
|---|---|---|---|
| `dt` | timestamptz | — | Record timestamp. |
| `nivel_total` | numeric | — | Total NaOH level: sum × 0.95. |
| `status` | integer | 0 or 1 | **1** when `nivel_total > 0`. |

**Grafana reference query:**
```sql
SELECT dt, nivel_total, status
FROM dbt_producao.producao__estoque_naoh
WHERE $__timeFilter(dt)
ORDER BY dt
```

---

## 10. `producao__producao_diaria`

**Group:** Produção Diária — Consolidated Daily Production View
**Purpose:** The broadest mart in the project. Consolidates all production metrics into a single
time series: caustic soda, HCl, liquid Cl2, electrical demand, supply voltage, power factor,
Cl2 production, daily plan, energy consumption and energy efficiency.

**Granularity:** 1 record per minute.

**Business rules applied before the mart:**
- `producao_soda` and `producao_hcl`: totalizer deltas via `LAG + GREATEST(..., 0)`. Never negative.
- `vazao_agua`: negatives zeroed.
- `cl2_on = 1` when `FIC12718\MV ≥ 1`.
- `cl2_liquido`: liquid Cl2 flow (`FI01507\U`), negatives zeroed.
- `demanda`: converted from W to kW (÷ 1,000).
- `producao_cl2` and `plan_diario`: calculated once per day and repeated each minute via JOIN by date.
- `kwh_diario`: daily value from `dashboard.geral_hist` (tag `total_kwh_diario`), repeated per minute.
- `kwh_por_ton = CEIL(kwh_diario / producao_cl2)`: energy efficiency calculated in the mart.

**Source tags:**

| Tag | Instrument | Role |
|---|---|---|
| `WQI13107_100\V` | Caustic soda totalizer | Base for soda production delta |
| `Producao_HCL` | HCl totalizer | Base for HCl production delta |
| `FIC12702\PV_IN` | Flow controller | NaOH flow |
| `FIC12703\PV_IN` | Flow controller | Water flow |
| `FIC12718\MV` | Controller | Cl2 on signal |
| `FI01507\U` | Flow meter | Liquid Cl2 flow |
| `Demanda Variável` | Energy meter | Total plant electrical demand |
| `Tensão Média FF` | Electrical meter | Average supply grid voltage |
| `Fator de Potência` | Electrical meter | Plant power factor |

**Columns:**

| Column | Type | Unit | Description |
|---|---|---|---|
| `dt` | timestamptz | — | Record timestamp. Main axis. |
| `producao_soda` | numeric | — | Delta of `WQI13107_100\V` totalizer. Never negative. |
| `producao_hcl` | numeric | — | Delta of `Producao_HCL` totalizer. Never negative. |
| `vazao_naoh` | numeric | — | NaOH flow (`FIC12702\PV_IN`). No transformation. |
| `vazao_agua` | numeric | — | Process water flow (`FIC12703\PV_IN`). Negatives zeroed. |
| `cl2_on` | integer | 0 or 1 | **1** when `FIC12718\MV ≥ 1`. |
| `cl2_liquido` | numeric | — | Liquid Cl2 flow (`FI01507\U`). Negatives zeroed. Panel 158: `SUM(cl2_liquido) / 105.0 = ton/month`. |
| `demanda` | numeric | kW | Total plant electrical demand (`Demanda Variável / 1,000`). |
| `tensao_ff` | numeric | V | Average supply grid voltage (`Tensão Média FF`). |
| `fator_potencia` | numeric | — | Plant power factor. |
| `producao_cl2` | numeric | ton | Cl2 production for the day. Daily value repeated per minute. |
| `plan_diario` | numeric | ton | Daily production target (42.7 ton/day). Repeated per minute. |
| `kwh_diario` | numeric | kWh | Energy consumption for the day (`dashboard.geral_hist` — `total_kwh_diario`). Daily value repeated per minute. |
| `kwh_por_ton` | numeric | kWh/ton | Energy efficiency: `CEIL(kwh_diario / producao_cl2)`. Panel 113 — reduce with `lastNotNull`. |

**Grafana reference query:**
```sql
SELECT dt, producao_soda, producao_hcl, vazao_naoh, vazao_agua,
       cl2_on, cl2_liquido, demanda, tensao_ff, fator_potencia,
       producao_cl2, plan_diario, kwh_diario, kwh_por_ton
FROM dbt_producao.producao__producao_diaria
WHERE $__timeFilter(dt)
ORDER BY dt
```

---

## General notes for the agent

- **Time series always:** all marts return complete series. Reductions (daily sum, last value) are the responsibility of the Grafana panel, never the mart.
- **Daily values repeated per minute:** `horas_on`, `disponibilidade`, `eficiencia`, `producao_cl2`, `plan_diario`, `kwh_diario` and `kwh_por_ton` have daily granularity but appear repeated on each minute row. When aggregating, use `MAX()` or `DISTINCT ON (date_trunc('day', dt))` to avoid double counting.
- **95% factor in stocks:** present in `estoque_hcl`, `estoque_hipo` and `estoque_naoh`. Represents engineering calibration, not error.
- **`status` column:** present in all marts. Always `0` or `1`. Indicates whether the group was operating at that minute. Logic varies by group (see each section's description).
- **Backslash in tags:** tags such as `II113RC001\U` contain a literal backslash. In SQL, inside a single-quoted string, `\` is literal — never double it.
- **Schema:** `dbt_producao` (generated directly by the `generate_schema_name` macro, with no additional prefix).
