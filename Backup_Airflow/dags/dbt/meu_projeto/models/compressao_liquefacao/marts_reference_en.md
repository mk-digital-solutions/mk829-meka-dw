# Marts Reference — Compressão - Liquefação Dashboard (English)

> Document intended for LLM agents. Contains a complete description of each mart,
> including purpose, columns, units, source tags, and applied business rules.
> Use this file to understand what to query and how to interpret each column
> before generating queries or explanations.

All marts live in schema `dbt_compressao_liquefacao`. All series are time series
keyed by `dt` (`timestamptz`). Grafana applies visual reductions (last, mean) —
the mart always exposes the full series.

The Sabroe compressors are ammonia (NH3) refrigeration compressors that cool and
liquefy the chlorine gas produced by electrolysis.

---

## Index

1. [compressao_liquefacao__comp_sabroe_1](#1-compressao_liquefacao__comp_sabroe_1)
2. [compressao_liquefacao__comp_sabroe_2](#2-compressao_liquefacao__comp_sabroe_2)
3. [var_compressao_liquefacao__tags](#3-var_compressao_liquefacao__tags)

---

## 1. `compressao_liquefacao__comp_sabroe_1`

**Group:** Compressor Sabroe 01 — Liquefaction Refrigeration
**Purpose:** Time series of the operational parameters of Sabroe 01 refrigeration compressor:
current, capacity, discharge/suction pressures and temperatures, and oil conditions.
Used to monitor operational state and detect process deviations.

**Granularity:** 1 record per sensor reading (typically per minute).

**Business rules applied before the mart:**
- No business logic transformations. All values are raw direct sensor readings.
- Timestamp spine built from UNION of all `data_hora` across the 10 source tags.
- `COALESCE(..., 0)` applied to each column for resilience against sporadic missing readings.

**Source tags:**

| Tag | Instrument | Role |
|---|---|---|
| `Corrente - Sabroe 01` | Ammeter | Compressor electric current (A) |
| `Capacidade - Sabroe 01` | PLC | Percent capacity in use (%) |
| `Pressão de Descarga - Sabroe 01` | Pressure transducer | Discharge pressure (bar) |
| `Temperatura de Descarga - Sabroe 01` | Thermocouple | Discharge gas temperature (°C) |
| `Pressão de Óleo - Sabroe 01` | Pressure transducer | Lubrication oil pressure (bar) |
| `Temperatura do Óleo - Sabroe 01` | Thermocouple | Lubrication oil temperature (°C) |
| `Superaquecimento de Aspiração - Sabroe 01` | Temperature sensor | Suction refrigerant superheat (°C) |
| `Pressão de Aspiração - Sabroe 01` | Pressure transducer | Suction pressure (bar) |
| `Temperatura de Processo - Sabroe 01` | Thermocouple | Process refrigeration temperature (°C) |
| `Temperatura de Aspiração - Sabroe 01` | Thermocouple | Suction gas temperature (°C) |

**Columns:**

| Column | Type | Unit | Description |
|---|---|---|---|
| `dt` | timestamptz | — | Record timestamp. Main series axis. |
| `corrente` | numeric | A | Compressor electric current (`Corrente - Sabroe 01`). MAX value per dt. **0** when no reading in the interval. |
| `capacidade` | numeric | % | Percent capacity in use (`Capacidade - Sabroe 01`). Indicates how much of the nominal capacity is being used. **0** when no reading. |
| `pressao_descarga` | numeric | bar | Discharge pressure (`Pressão de Descarga - Sabroe 01`). High values indicate possible overload. Alert threshold: 16 bar. |
| `temp_descarga` | numeric | °C | Discharge gas temperature (`Temperatura de Descarga - Sabroe 01`). Alert threshold: 120 °C. |
| `pressao_oleo` | numeric | bar | Lubrication oil pressure (`Pressão de Óleo - Sabroe 01`). Nominal range: 3.2–6.5 bar. Outside this range indicates a lubrication issue. |
| `temp_oleo` | numeric | °C | Lubrication oil temperature (`Temperatura do Óleo - Sabroe 01`). Nominal range: 25–75 °C. |
| `superaquecimento_aspiracao` | numeric | °C | Refrigerant (ammonia) suction superheat (`Superaquecimento de Aspiração - Sabroe 01`). Negative values indicate liquid presence at suction inlet (dangerous for the compressor). |
| `pressao_aspiracao` | numeric | bar | Suction pressure (`Pressão de Aspiração - Sabroe 01`). Nominal range: 0.8–1.5 bar. |
| `temp_processo` | numeric | °C | Process refrigeration temperature (`Temperatura de Processo - Sabroe 01`). |
| `temp_aspiracao` | numeric | °C | Suction gas temperature (`Temperatura de Aspiração - Sabroe 01`). |

**Reference Grafana query:**
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

**Group:** Compressor Sabroe 02 — Liquefaction Refrigeration
**Purpose:** Identical to `comp_sabroe_1`, but for the second refrigeration compressor.
Time series with the 10 operational parameters of Sabroe 02.

**Granularity:** 1 record per sensor reading (typically per minute).

**Business rules applied before the mart:**
- No business logic transformations. All values are raw direct sensor readings.
- Timestamp spine built from UNION of all `data_hora` across the 10 source tags.
- `COALESCE(..., 0)` applied to each column for resilience against sporadic missing readings.

**Source tags:**

| Tag | Instrument | Role |
|---|---|---|
| `Corrente - Sabroe 02` | Ammeter | Compressor electric current (A) |
| `Capacidade - Sabroe 02` | PLC | Percent capacity in use (%) |
| `Pressão de Descarga - Sabroe 02` | Pressure transducer | Discharge pressure (bar) |
| `Temperatura de Descarga - Sabroe 02` | Thermocouple | Discharge gas temperature (°C) |
| `Pressão de Óleo - Sabroe 02` | Pressure transducer | Lubrication oil pressure (bar) |
| `Temperatura do Óleo - Sabroe 02` | Thermocouple | Lubrication oil temperature (°C) |
| `Superaquecimento de Aspiração - Sabroe 02` | Temperature sensor | Suction refrigerant superheat (°C) |
| `Pressão de Aspiração - Sabroe 02` | Pressure transducer | Suction pressure (bar) |
| `Temperatura de Processo - Sabroe 02` | Thermocouple | Process refrigeration temperature (°C) |
| `Temperatura de Aspiração - Sabroe 02` | Thermocouple | Suction gas temperature (°C) |

**Columns:**

| Column | Type | Unit | Description |
|---|---|---|---|
| `dt` | timestamptz | — | Record timestamp. Main series axis. |
| `corrente` | numeric | A | Compressor electric current (`Corrente - Sabroe 02`). |
| `capacidade` | numeric | % | Percent capacity in use (`Capacidade - Sabroe 02`). |
| `pressao_descarga` | numeric | bar | Discharge pressure (`Pressão de Descarga - Sabroe 02`). Alert threshold: 16 bar. |
| `temp_descarga` | numeric | °C | Discharge temperature (`Temperatura de Descarga - Sabroe 02`). Alert threshold: 120 °C. |
| `pressao_oleo` | numeric | bar | Oil pressure (`Pressão de Óleo - Sabroe 02`). Nominal range: 3.2–6.5 bar. |
| `temp_oleo` | numeric | °C | Oil temperature (`Temperatura do Óleo - Sabroe 02`). Nominal range: 25–75 °C. |
| `superaquecimento_aspiracao` | numeric | °C | Suction superheat (`Superaquecimento de Aspiração - Sabroe 02`). |
| `pressao_aspiracao` | numeric | bar | Suction pressure (`Pressão de Aspiração - Sabroe 02`). Nominal range: 0.8–1.5 bar. |
| `temp_processo` | numeric | °C | Process temperature (`Temperatura de Processo - Sabroe 02`). |
| `temp_aspiracao` | numeric | °C | Suction temperature (`Temperatura de Aspiração - Sabroe 02`). |

**Reference Grafana query:**
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

**Type:** Variable view (not a mart — no hypertable, not incremental).
**Purpose:** Populates the `$Tags` dropdown in the Grafana dashboard. Lists the available
parameters for the multi-series panels (panels 60 and 67), removing the `- Sabroe 01/02`
suffix to display human-readable names to the operator.

**Columns:**

| Column | Type | Description |
|---|---|---|
| `tags` | text | Parameter name without compressor suffix (e.g. `Temperatura de Processo`). |

**Grafana variable configuration query:**
```sql
SELECT tags FROM dbt_compressao_liquefacao.var_compressao_liquefacao__tags ORDER BY 1
```

**Available parameters** (derived from pattern `~* '^(Pressão|Temperatura|Superaquecimento).*Sabroe'`):
- Pressão de Aspiração
- Pressão de Descarga
- Pressão de Óleo
- Superaquecimento de Aspiração
- Temperatura de Aspiração
- Temperatura de Descarga
- Temperatura de Processo
- Temperatura do Óleo

---

## General notes for the agent

- **Always a time series:** both marts return complete series. Reductions (last value, mean) are
  the Grafana panel's responsibility, never the mart's.
- **COALESCE(0):** missing readings for any tag result in `0`, not `NULL`. When filtering for
  "compressor off", prefer `corrente = 0 AND capacidade = 0` over `IS NULL`.
- **Two independent compressors:** `comp_sabroe_1` and `comp_sabroe_2` are separate series —
  they may have different timestamps and reading frequencies.
- **Actual schema:** `dbt_compressao_liquefacao` (generated by the `generate_schema_name` macro,
  which uses the `custom_schema_name` directly without any additional prefix).
- **Incremental strategy:** both marts use `unique_key='dt'` with
  `WHERE dt > MAX(dt in this)`. On the first full run they load the entire time window;
  on subsequent runs only new records are appended.
- **Relationship with producao__liquefacao:** the `cap_sabroe_01` and `cap_sabroe_02` columns
  in the `producao__liquefacao` mart (`dbt_producao` schema) use the same capacity tags as
  this dashboard. For full operational detail of the Sabroe compressors, use this dashboard.
