

Design Rationale

The model follows a galaxy schema approach to support analytical reporting, KPI calculations, historical tracking, and Power BI performance.


## Overall Design Principles
galaxy Schema

The warehouse uses a galaxy schema consisting of:

5 Dimensions
3 Fact Tables

This design was selected because it:

Simplifies reporting and analytics.
Improves query performance.
Reduces join complexity.
Supports Power BI best practices.
Provides a clear separation between descriptive attributes and measurable business events.

The dimensions contain business context, while the fact tables store operational transactions and measurements.



## dim_date
Purpose

Provides a centralized calendar dimension used across all fact tables.

Design Rationale

A dedicated date dimension was created instead of relying on raw date fields because:

Enables consistent time intelligence calculations.
Supports Year-to-Date (YTD), Month-to-Date (MTD), and Year-over-Year (YoY) reporting.
Simplifies filtering and slicing in Power BI.
Eliminates repetitive date calculations in reports.
Fiscal Calendar Support

The business fiscal year begins on 1 April.

Additional fiscal attributes are included:

Fiscal Year
Fiscal Quarter
Fiscal Month

This allows financial reporting to align with business accounting periods rather than the standard calendar year.

Key Choice

full_date is used as the primary key because:

Dates are naturally unique.
Simplifies ETL lookups.
Reduces unnecessary surrogate key maintenance.


## dim_customer
Purpose

Stores customer master data and customer history.

Design Type

Slowly Changing Dimension Type 2 (SCD Type 2)

Design Rationale

Customer information changes over time:

Customer Tier
Credit Limit
Country
Active Status

Business users often need to answer questions such as:

What tier was the customer in at the time of the transaction?
What was the customer's credit limit when a vessel call occurred?

Using Type 1 would overwrite historical values and lose business history.

Therefore Type 2 was selected to preserve historical versions.

History Source

Customer changes are sourced from:

CustomerHistory

This source provides the required historical records needed to build Type 2 dimension versions.

Additional Columns
effective_from
effective_to
active_flag
change_reason

These fields allow point-in-time analysis and historical tracking.

fact_container_movement

Business Process: Container handling operations.

Grain: One row per container move.

Design Rationale:
Provides detailed operational visibility and supports:

Productivity analysis
Equipment utilization
Shift performance
Customer activity reporting

Dimensions:

Date
Customer
Terminal
Equipment
Shift

Derived Measure – Crane Cycle Time

DATEDIFF(SECOND, move_start_time, move_end_time)

Used for:

Average cycle time
Productivity monitoring
Equipment performance analysis
fact_vessel_call

Business Process: Vessel arrival and departure operations.

Grain: One row per vessel call.

Design Rationale:
Captures vessel-level performance without storing individual container movements.

Dimensions:

ETA Date
ATA Date
ATD Date
Customer
Terminal

Derived Measures

Berth Delay

DATEDIFF(HOUR, eta_datetime, ata_datetime)

Measures vessel arrival delay.

Vessel Stay Hours

DATEDIFF(HOUR, ata_datetime, atd_datetime)

Measures total vessel stay duration.

Planned vs Actual Moves Variance

actual_moves - planned_moves

Measures operational performance against plan.

Dual Date Keys
ETA Date ATA Date ATD Date

fact_gate_transaction

Business Process: Gate entry and exit operations.

Grain: One row per gate transaction.

Design Rationale:
Supports analysis of gate throughput, truck turnaround times, and terminal congestion.

Dimensions:

Gate In Date
Gate Out Date
Customer
Terminal
Shift

Dual Date Keys

Both gate_in_date and gate_out_date reference dim_date.

This enables analysis by:

Entry date
Exit date
Turnaround time

The second date relationship is kept inactive in Power BI and activated when needed using USERELATIONSHIP().


-------------------------------------------------------------------------------------------------------------------
## SCD Approach

### Type 1 Implementation

A Type 1 approach was used as part of the incremental loading strategy for both the staging and data warehouse layers. This approach was applied to the following tables:

* fact_vessel_call
* fact_container_movement
* fact_gate_transaction

The remaining dimensions (`dim_terminal`, `dim_equipment`, and `dim_shift`) are relatively small and were loaded using a full refresh strategy.

The incremental load process was implemented using SSIS Lookup components:

1. The first Lookup checks whether the business key already exists in the target table.
2. If the business key is not found, the record is inserted as a new row.
3. If the business key exists, the record is passed to a second Lookup that compares the remaining attributes.
4. When differences are detected, the existing record is updated through an ole db command Task.

A `ModifiedDate` column is maintained to identify new or changed records, allowing subsequent ETL executions to process only incremental data rather than reloading the entire dataset.

### Type 2 Implementation

A Slowly Changing Dimension Type 2 (SCD Type 2) was implemented for `dim_customer` using data from the CustomerHistory source sheet.

Whenever a tracked customer attribute changes:

* The current record is expired by updating its effective end date.
* A new record is inserted with a new surrogate key and updated attribute values.
* Historical versions are preserved for reporting and auditing purposes.

This approach ensures that fact records remain associated with the correct customer version that was valid at the time the business event occurred.

The SQL logic used to implement the Type 2 process is included in the project code folder and referenced within the repository.
this is the code 
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
    ON c.customer_id = ch.customer_id
;


### Data Quality Handling

Several data quality controls were implemented during the ETL process to ensure data consistency and reliability.

#### Null Handling

Missing values were replaced with standard default values based on the data type:

| Data Type          | Default Value |
| ------------------ | ------------- |
| Character / String | N/A           |
| Integer            | 9999          |
| Decimal / Float    | 9999.99       |
| Date               | 31-12-9999    |

This approach prevents NULL values from impacting reporting and downstream processes.

#### Dimension Validation

Dimension lookups were validated during fact loading.

For late-arriving dimensions or missing dimension records, the foreign key is assigned a value of **-1 (Unknown Member)**.

This was implemented using a Left Join between the source data and dimensions, followed by mapping NULL dimension keys to **-1**.

#### Business Rule Validation

Multiple business validation rules were implemented before loading data into the warehouse.

Examples include:

* Event dates must fall within the valid range of the Date Dimension.
* Arrival time cannot be later than departure time.
* End date cannot be earlier than start date.


Database constraints and ETL validations were used to enforce these rules. Records that violate any validation rule are redirected to an Error Table for investigation rather than being loaded into the warehouse.

#### Error Logging

Invalid records are captured in dedicated Error Tables containing:

* Source record details
* Validation failure reason
* Load timestamp

This allows data issues to be investigated without interrupting the ETL process.

#### ETL Audit Logging

An `dbo.ETL_Audit_Log` table was implemented to monitor and track ETL executions.

The audit table stores:

* Package Name
* Run Start Time
* Run End Time
* Execution Status (Success / Failed)
* Number of Rows 

Most audit logging operations were implemented using SSIS Execute SQL Tasks at the start and end of each ETL package, providing complete visibility into ETL execution history and performance.


## Design Decisions and Trade-offs

### SCD Strategy

* `dim_customer` was implemented as SCD Type 2 to preserve customer history and support point-in-time reporting.
* Other dimensions (`dim_terminal`, `dim_equipment`, and `dim_shift`) use Type 1 updates because historical tracking was not a business requirement.

**Trade-off:**
Type 2 increases storage requirements and ETL complexity but preserves historical accuracy. Type 1 is simpler and faster but does not retain previous values.

---

### Incremental Loading

Fact tables are loaded incrementally using business keys and modified dates.

**Trade-off:**
Incremental loads significantly reduce ETL execution time compared to full reloads but require additional logic for change detection and auditing.

---

### Unknown Member (-1)

Late-arriving or missing dimension records are assigned to an Unknown Member (`-1`).

**Trade-off:**
This prevents fact load failures and maintains referential integrity. However, reports may temporarily contain records categorized as "Unknown" until the dimension data becomes available.

---

### Default Values for NULLs

NULL values are replaced with standard defaults:

* String → `N/A`
* Integer → `9999`
* Decimal → `9999.99`
* Date → `31-12-9999`

**Trade-off:**
This simplifies reporting and avoids NULL-related issues but requires report developers to recognize these values as placeholders rather than valid business data.

---

### Data Validation Rules

Business constraints and date validations are enforced before loading data into the warehouse.

Invalid records are redirected to error tables instead of stopping the ETL process.

**Trade-off:**
This improves ETL reliability and availability but requires ongoing monitoring of error tables to resolve data quality issues.

---

### Audit Logging

An ETL Audit table records package execution details, row counts, execution status, and timestamps.

**Trade-off:**
Audit logging introduces a small processing overhead but provides valuable traceability, monitoring, and troubleshooting capabilities.
