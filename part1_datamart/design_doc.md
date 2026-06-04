# PortOps Data Warehouse — Design Document

---

## 📐 Design Rationale

The model follows a **Galaxy Schema** approach to support analytical reporting, KPI calculations, historical tracking, and Power BI performance.

---

## 🏗️ Overall Design Principles

### Galaxy Schema

The warehouse uses a galaxy schema consisting of:

| Component | Count |
|-----------|-------|
| Dimensions | 5 |
| Fact Tables | 3 |

This design was selected because it:

- Simplifies reporting and analytics.
- Improves query performance.
- Reduces join complexity.
- Supports Power BI best practices.
- Provides a clear separation between descriptive attributes and measurable business events.

> The **dimensions** contain business context, while the **fact tables** store operational transactions and measurements.

---

## 📅 `dim_date`

### Purpose
Provides a centralized calendar dimension used across all fact tables.

### Design Rationale

A dedicated date dimension was created instead of relying on raw date fields because it:

- Enables consistent time intelligence calculations.
- Supports Year-to-Date (YTD), Month-to-Date (MTD), and Year-over-Year (YoY) reporting.
- Simplifies filtering and slicing in Power BI.
- Eliminates repetitive date calculations in reports.

### Fiscal Calendar Support

> The business fiscal year begins on **1 April**.

Additional fiscal attributes are included:

| Attribute | Description |
|-----------|-------------|
| Fiscal Year | Based on April 1 start |
| Fiscal Quarter | Q1–Q4 per fiscal year |
| Fiscal Month | Month number within fiscal year |

This allows financial reporting to align with business accounting periods rather than the standard calendar year.

### Key Choice

`full_date` is used as the primary key because:

- Dates are naturally unique.
- Simplifies ETL lookups.
- Reduces unnecessary surrogate key maintenance.

---

## 👤 `dim_customer`

### Purpose
Stores customer master data and customer history.

### Design Type
**Slowly Changing Dimension — Type 2 (SCD Type 2)**

### Design Rationale

Customer information changes over time, including:

- Customer Tier
- Credit Limit
- Country
- Active Status

Business users often need to answer questions such as:

- *What tier was the customer in at the time of the transaction?*
- *What was the customer's credit limit when a vessel call occurred?*

Using Type 1 would overwrite historical values and lose business history. Therefore, **Type 2** was selected to preserve historical versions.

### History Source

Customer changes are sourced from: `CustomerHistory`

This source provides the required historical records needed to build Type 2 dimension versions.

### Additional Columns

| Column | Purpose |
|--------|---------|
| `effective_from` | Start date of this version |
| `effective_to` | End date of this version |
| `active_flag` | Indicates the current active record |
| `change_reason` | Reason for the change |

These fields allow point-in-time analysis and historical tracking.

---

## 📦 `fact_container_movement`

**Business Process:** Container handling operations.

**Grain:** One row per container move.

### Design Rationale

Provides detailed operational visibility and supports:

- Productivity analysis
- Equipment utilization
- Shift performance
- Customer activity reporting

### Dimensions Referenced

| Dimension | Role |
|-----------|------|
| `dim_date` | Move date |
| `dim_customer` | Customer linked to the move |
| `dim_terminal` | Terminal where the move occurred |
| `dim_equipment` | Equipment used |
| `dim_shift` | Shift during which the move occurred |

### Derived Measure — Crane Cycle Time

```sql
DATEDIFF(SECOND, move_start_time, move_end_time)
```

Used for:
- Average cycle time
- Productivity monitoring
- Equipment performance analysis

### ETL Source Query

```sql
--  fact.container_movement
--  Null handling + casting + transformation applied here
-- ============================================================
SELECT DISTINCT
    -- Surrogate keys
    ISNULL(dc.customer_key,  -1)                        AS customer_key,
    ISNULL(dt.terminal_key,  -1)                        AS terminal_key,
    ISNULL(de.equipment_key, -1)                        AS equipment_key,
    ISNULL(ds.shift_key,     -1)                        AS shift_key,

    -- Date keys
    CASE
        WHEN cm.move_start_time IS NULL THEN '9999-12-31'
        ELSE CAST(cm.move_start_time AS DATE)
    END                                                 AS move_start_date,
    CASE
        WHEN cm.move_end_time IS NULL THEN '9999-12-31'
        ELSE CAST(cm.move_end_time AS DATE)
    END                                                 AS move_end_date,

    -- Time columns
    CASE
        WHEN cm.move_start_time IS NULL THEN '00:00:00'
        ELSE CAST(cm.move_start_time AS TIME)
    END                                                 AS move_start_time,
    CASE
        WHEN cm.move_end_time IS NULL THEN '00:00:00'
        ELSE CAST(cm.move_end_time AS TIME)
    END                                                 AS move_end_time,

    -- INT columns
    CASE
        WHEN cm.movement_id    IS NULL THEN 9999
        ELSE cm.movement_id
    END                                                 AS movement_id,
    CASE
        WHEN cm.vessel_call_id IS NULL THEN 9999
        ELSE cm.vessel_call_id
    END                                                 AS vessel_call_id,
    CASE
        WHEN TRIM(cm.container_size) IS NULL
          OR TRIM(cm.container_size) = '' THEN 'N.A'
        ELSE UPPER(TRIM(cm.container_size))
    END                                                 AS container_size,

    -- NVARCHAR columns
    CASE
        WHEN TRIM(cm.container_no) IS NULL
          OR TRIM(cm.container_no) = '' THEN 'N.A'
        ELSE UPPER(TRIM(cm.container_no))
    END                                                 AS container_no,
    CASE
        WHEN TRIM(cm.move_type) IS NULL
          OR TRIM(cm.move_type) = '' THEN 'N.A'
        ELSE UPPER(TRIM(cm.move_type))
    END                                                 AS move_type,

    -- BIT columns
    CASE
        WHEN cm.is_reefer IS NULL THEN 0
        ELSE cm.is_reefer
    END                                                 AS is_reefer,

    -- DECIMAL columns
    CASE
        WHEN cm.weight_tons IS NULL THEN 9999.99
        ELSE CAST(cm.weight_tons AS DECIMAL(10,2))
    END                                                 AS weight_tons

FROM PortOps_STG.stg.ContainerMovements cm
LEFT JOIN PortOps_DW.dim.customer dc
    ON  cm.customer_id  = dc.customer_id
    AND dc.effective_to = '9999-12-31'
LEFT JOIN PortOps_DW.dim.terminal dt
    ON  cm.terminal_id  = dt.terminal_id
LEFT JOIN PortOps_DW.dim.equipment de
    ON  cm.equipment_id = de.equipment_id
LEFT JOIN PortOps_DW.dim.shift ds
    ON  cm.shift_id     = ds.shift_id
WHERE cm.modified_date >= ?
ORDER BY movement_id;
```

---

## 🚢 `fact_vessel_call`

**Business Process:** Vessel arrival and departure operations.

**Grain:** One row per vessel call.

### Design Rationale

Captures vessel-level performance without storing individual container movements.

### Dimensions Referenced

| Dimension | Role |
|-----------|------|
| `dim_date` (ETA) | Estimated time of arrival date |
| `dim_date` (ATA) | Actual time of arrival date |
| `dim_date` (ATD) | Actual time of departure date |
| `dim_customer` | Customer linked to the vessel call |
| `dim_terminal` | Terminal where the vessel berthed |

> The three date relationships use **dual/triple date keys**. Inactive relationships are activated in Power BI using `USERELATIONSHIP()` when needed.

### Derived Measures

| Measure | Formula | Purpose |
|---------|---------|---------|
| Berth Delay | `DATEDIFF(HOUR, eta_datetime, ata_datetime)` | Measures vessel arrival delay |
| Vessel Stay Hours | `DATEDIFF(HOUR, ata_datetime, atd_datetime)` | Measures total vessel stay duration |
| Planned vs Actual Moves Variance | `actual_moves - planned_moves` | Measures operational performance against plan |

### ETL Source Query

```sql
--  fact.vessel_call
--  Null handling + casting + transformation applied here
-- ============================================================
SELECT DISTINCT
    -- Surrogate keys
    ISNULL(dc.customer_key, -1)                         AS customer_key,
    ISNULL(dt.terminal_key, -1)                         AS terminal_key,

    -- Date columns
    CASE
        WHEN vc.eta IS NULL THEN '9999-12-31'
        ELSE CAST(vc.eta AS DATE)
    END                                                 AS eta_date,
    CASE
        WHEN vc.ata IS NULL THEN '9999-12-31'
        ELSE CAST(vc.ata AS DATE)
    END                                                 AS ata_date,
    CASE
        WHEN vc.atd IS NULL THEN '9999-12-31'
        ELSE CAST(vc.atd AS DATE)
    END                                                 AS atd_date,

    -- Time columns
    CASE
        WHEN vc.eta IS NULL THEN '00:00:00'
        ELSE CAST(vc.eta AS TIME)
    END                                                 AS eta_time,
    CASE
        WHEN vc.ata IS NULL THEN '00:00:00'
        ELSE CAST(vc.ata AS TIME)
    END                                                 AS ata_time,
    CASE
        WHEN vc.atd IS NULL THEN '00:00:00'
        ELSE CAST(vc.atd AS TIME)
    END                                                 AS atd_time,

    -- INT columns
    CASE
        WHEN vc.vessel_call_id      IS NULL THEN 9999
        ELSE vc.vessel_call_id
    END                                                 AS vessel_call_id,
    CASE
        WHEN vc.total_moves_planned IS NULL THEN 9999
        ELSE vc.total_moves_planned
    END                                                 AS total_moves_planned,
    CASE
        WHEN vc.total_moves_actual  IS NULL THEN 9999
        ELSE vc.total_moves_actual
    END                                                 AS total_moves_actual,

    -- NVARCHAR columns
    CASE
        WHEN TRIM(vc.vessel_name) IS NULL
          OR TRIM(vc.vessel_name) = '' THEN 'N.A'
        ELSE UPPER(TRIM(vc.vessel_name))
    END                                                 AS vessel_name,
    CASE
        WHEN TRIM(vc.voyage_no) IS NULL
          OR TRIM(vc.voyage_no) = '' THEN 'N.A'
        ELSE UPPER(TRIM(vc.voyage_no))
    END                                                 AS voyage_no,
    CASE
        WHEN TRIM(vc.[status]) IS NULL
          OR TRIM(vc.[status]) = '' THEN 'N.A'
        ELSE UPPER(TRIM(vc.[status]))
    END                                                 AS [status]

FROM PortOps_STG.stg.VesselCalls vc
LEFT JOIN PortOps_DW.dim.customer dc
    ON  vc.customer_id  = dc.customer_id
    AND dc.effective_to = '9999-12-31'
LEFT JOIN PortOps_DW.dim.terminal dt
    ON  vc.terminal_id  = dt.terminal_id
WHERE vc.modified_date >= ?
ORDER BY vessel_call_id;
```

---

## 🚛 `fact_gate_transaction`

**Business Process:** Gate entry and exit operations.

**Grain:** One row per gate transaction.

### Design Rationale

Supports analysis of gate throughput, truck turnaround times, and terminal congestion.

### Dimensions Referenced

| Dimension | Role |
|-----------|------|
| `dim_date` (Gate In) | Entry date |
| `dim_date` (Gate Out) | Exit date |
| `dim_customer` | Customer linked to the transaction |
| `dim_terminal` | Terminal where the transaction occurred |
| `dim_shift` | Shift during which the transaction occurred |

### Dual Date Keys

Both `gate_in_date` and `gate_out_date` reference `dim_date`.

This enables analysis by:
- Entry date
- Exit date
- Turnaround time

> The second date relationship is kept **inactive** in Power BI and activated when needed using `USERELATIONSHIP()`.

### ETL Source Query

```sql
--  fact.gate_transaction
--  Null handling + casting + transformation applied here
-- ============================================================
SELECT DISTINCT
    -- Surrogate keys
    ISNULL(dc.customer_key, -1)                         AS customer_key,
    ISNULL(dt.terminal_key, -1)                         AS terminal_key,
    ISNULL(ds.shift_key,    -1)                         AS shift_key,

    -- Date columns
    CASE
        WHEN gt.gate_in_time  IS NULL THEN '9999-12-31'
        ELSE CAST(gt.gate_in_time  AS DATE)
    END                                                 AS gate_in_date,
    CASE
        WHEN gt.gate_out_time IS NULL THEN '9999-12-31'
        ELSE CAST(gt.gate_out_time AS DATE)
    END                                                 AS gate_out_date,

    -- Time columns
    CASE
        WHEN gt.gate_in_time  IS NULL THEN '00:00:00'
        ELSE CAST(gt.gate_in_time  AS TIME)
    END                                                 AS gate_in_time,
    CASE
        WHEN gt.gate_out_time IS NULL THEN '00:00:00'
        ELSE CAST(gt.gate_out_time AS TIME)
    END                                                 AS gate_out_time,

    -- INT columns
    CASE
        WHEN gt.gate_txn_id IS NULL THEN 9999
        ELSE gt.gate_txn_id
    END                                                 AS gate_txn_id,

    -- NVARCHAR columns
    CASE
        WHEN TRIM(gt.truck_plate) IS NULL
          OR TRIM(gt.truck_plate) = '' THEN 'N.A'
        ELSE UPPER(TRIM(gt.truck_plate))
    END                                                 AS truck_plate,
    CASE
        WHEN TRIM(gt.container_no) IS NULL
          OR TRIM(gt.container_no) = '' THEN 'N.A'
        ELSE UPPER(TRIM(gt.container_no))
    END                                                 AS container_no,
    CASE
        WHEN TRIM(gt.direction) IS NULL
          OR TRIM(gt.direction) = '' THEN 'N.A'
        ELSE UPPER(TRIM(gt.direction))
    END                                                 AS direction

FROM PortOps_STG.stg.GateTransactions gt
LEFT JOIN PortOps_DW.dim.customer dc
    ON  gt.customer_id  = dc.customer_id
    AND dc.effective_to = '9999-12-31'
LEFT JOIN PortOps_DW.dim.terminal dt
    ON  gt.terminal_id  = dt.terminal_id
LEFT JOIN PortOps_DW.dim.shift ds
    ON  gt.shift_id     = ds.shift_id
WHERE gt.modified_date >= ?
ORDER BY gate_txn_id;
```

---

## 🔄 SCD Approach

### Type 1 Implementation

A Type 1 approach was used as part of the incremental loading strategy for both the staging and data warehouse layers. This approach was applied to the following tables:

- `fact_vessel_call`
- `fact_container_movement`
- `fact_gate_transaction`

> The remaining dimensions (`dim_terminal`, `dim_equipment`, and `dim_shift`) are relatively small and were loaded using a **full refresh** strategy.

The incremental load process was implemented using SSIS Lookup components:

1. The first Lookup checks whether the business key already exists in the target table.
2. If the business key is **not found**, the record is inserted as a new row.
3. If the business key **exists**, the record is passed to a second Lookup that compares the remaining attributes.
4. When differences are detected, the existing record is updated through an OLE DB Command Task.

> A `ModifiedDate` column is maintained to identify new or changed records, allowing subsequent ETL executions to process only incremental data rather than reloading the entire dataset.

---

### Type 2 Implementation

A Slowly Changing Dimension Type 2 (SCD Type 2) was implemented for `dim_customer` using data from the `CustomerHistory` source sheet.

Whenever a tracked customer attribute changes:

- The current record is **expired** by updating its effective end date.
- A **new record** is inserted with a new surrogate key and updated attribute values.
- **Historical versions** are preserved for reporting and auditing purposes.

This approach ensures that fact records remain associated with the correct customer version that was valid at the time the business event occurred.

**SQL Implementation:**

```sql
SELECT DISTINCT
    c.customer_id,
    c.customer_code,
    c.customer_name,
    c.country,
    ISNULL(ch.customer_tier,  c.customer_tier)  AS customer_tier,
    ISNULL(ch.credit_limit,   c.credit_limit)   AS credit_limit,
    c.active_flag,
    c.onboarded_date,
    ISNULL(ch.effective_from, c.onboarded_date) AS effective_from,
    ch.effective_to,
    ch.change_reason
FROM PortOps_STG.stg.Customers c
LEFT JOIN PortOps_STG.stg.CustomerHistory ch
    ON c.customer_id = ch.customer_id;
```

---

## ✅ Data Quality Handling

### Null Handling

Missing values were replaced with standard default values based on the data type:

| Data Type | Default Value |
|-----------|---------------|
| Character / String | `N/A` |
| Integer | `9999` |
| Decimal / Float | `9999.99` |
| Date | `31-12-9999` |

> This approach prevents NULL values from impacting reporting and downstream processes.

---

### Dimension Validation

Dimension lookups were validated during fact loading.

For late-arriving dimensions or missing dimension records, the foreign key is assigned a value of **-1 (Unknown Member)**.

This was implemented using a Left Join between the source data and dimensions, followed by mapping NULL dimension keys to **-1**.

---

### Business Rule Validation

Multiple business validation rules were implemented before loading data into the warehouse. Examples include:

- Event dates must fall within the valid range of the Date Dimension.
- Arrival time cannot be later than departure time.
- End date cannot be earlier than start date.

> Database constraints and ETL validations were used to enforce these rules. Records that violate any validation rule are redirected to an **Error Table** for investigation rather than being loaded into the warehouse.

---

### Error Logging

Invalid records are captured in dedicated Error Tables containing:

| Field | Description |
|-------|-------------|
| Source Record Details | Original record from the source |
| Validation Failure Reason | Why the record was rejected |
| Load Timestamp | When the failure was captured |

> This allows data issues to be investigated without interrupting the ETL process.

---

### ETL Audit Logging

An `ETL_Audit` table was implemented to monitor and track ETL executions.

| Field | Description |
|-------|-------------|
| Package Name | Name of the SSIS package executed |
| Run Start Time | Execution start timestamp |
| Run End Time | Execution end timestamp |
| Execution Status | `Success` or `Failed` |
| Number of Rows | Row counts loaded per table |

> Most audit logging operations were implemented using SSIS **Execute SQL Tasks** at the start and end of each ETL package, providing complete visibility into ETL execution history and performance.

---

## ⚖️ Design Decisions and Trade-offs

### SCD Strategy

| Dimension | Strategy | Reason |
|-----------|----------|--------|
| `dim_customer` | SCD Type 2 | Historical tracking required |
| `dim_terminal` | SCD Type 1 | No historical tracking required |
| `dim_equipment` | SCD Type 1 | No historical tracking required |
| `dim_shift` | SCD Type 1 | No historical tracking required |

**Trade-off:** Type 2 increases storage requirements and ETL complexity but preserves historical accuracy. Type 1 is simpler and faster but does not retain previous values.

---

### Incremental Loading

Fact tables are loaded incrementally using business keys and modified dates.

**Trade-off:** Incremental loads significantly reduce ETL execution time compared to full reloads but require additional logic for change detection and auditing.

---

### Unknown Member (`-1`)

Late-arriving or missing dimension records are assigned to an Unknown Member (`-1`).

**Trade-off:** This prevents fact load failures and maintains referential integrity. However, reports may temporarily contain records categorized as *"Unknown"* until the dimension data becomes available.

---

### Default Values for NULLs

| Data Type | Default Value |
|-----------|---------------|
| String | `N/A` |
| Integer | `9999` |
| Decimal | `9999.99` |
| Date | `31-12-9999` |

**Trade-off:** This simplifies reporting and avoids NULL-related issues but requires report developers to recognize these values as placeholders rather than valid business data.

---

### Data Validation Rules

Business constraints and date validations are enforced before loading data into the warehouse. Invalid records are redirected to error tables instead of stopping the ETL process.

**Trade-off:** This improves ETL reliability and availability but requires ongoing monitoring of error tables to resolve data quality issues.

---

### Audit Logging

An ETL Audit table records package execution details, row counts, execution status, and timestamps.

**Trade-off:** Audit logging introduces a small processing overhead but provides valuable traceability, monitoring, and troubleshooting capabilities.

---
