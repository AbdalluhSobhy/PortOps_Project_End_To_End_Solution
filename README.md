# PortOps Data Warehouse — Project README

---

## 📦 Tool Versions

| Tool | Version | Purpose |
|------|---------|---------|
| Microsoft SQL Server | SQL Server 2019 Developer Edition | Data warehouse database, staging layer, dimensions, fact tables, and ETL support |
| SQL Server Integration Services (SSIS) | SSIS 2022 | ETL development, data transformation, and loading |
| Microsoft Visual Studio | Visual Studio 2026 | SSIS package development and deployment |
| Power BI Desktop | Latest Version | Data modeling, DAX measures, and dashboard reporting |
| Python | Python 3.x | Converting source Excel files into CSV files prior to ETL processing |
| Pandas | Latest Stable Version | Reading Excel files and generating CSV files to avoid Excel driver architecture conflicts |
| Microsoft Excel | Microsoft 365  | Original source data files provided for ingestion |

---

## 🐍 Python (Pandas) — Excel to CSV Conversion

Python with the Pandas library was used to convert the source Excel files into CSV files before loading them into SSIS. During development, the SSIS Excel Source component generated connection errors because of an architecture mismatch between the installed Excel driver (32-bit) and the development environment running on a 64-bit architecture.

**Two solutions were considered:**

1. **Convert the Excel files to CSV files using Python (Pandas)** — this was the approach implemented in this project. The conversion script and the generated CSV files are included in the repository.
2. **Install the appropriate Microsoft Access Database Engine (32-bit) driver** to match the Excel source files. While this is generally the preferred solution, it was not used because it would have required additional system configuration changes and modifications to the existing development environment.

The CSV conversion approach provided a simple, reliable, and repeatable solution that eliminated driver compatibility issues while allowing the ETL process to proceed without interruption.

> **Note:** Parameterise external paths (source workbook location, connection strings) so the solution is portable across environments.

---

## ⚙️ Setup Steps

### 1. Install SQL Server

- Install **SQL Server 2019 Developer Edition**.
- Enable the following features:
  - Database Engine Services
  - SQL Server Agent
- Configure SQL Server authentication and grant the required permissions.

---

### 2. Install Visual Studio and SSIS

- Install **Visual Studio 2026**.
- Install the **SQL Server Integration Services (SSIS) Extension**.
- Verify that SSIS project templates are available:
  - `File → New Project → Integration Services Project`

---

### 3. Design the Conceptual and Logical Model

Design the conceptual model and logical model for the DW.

---

### 4. Create STG and DW Databases

Create a database for STG and data warehouse in SQL Server using SQL code. You can find the code in this link().

> In the DW code creation you can find how to create the SK key and the default row creation to handle unknown or late-arriving members explicitly. A default row (surrogate key = **-1**) in each dimension is one accepted pattern.

---

### 5. Generate and Populate `dim_date`

You can find the code in this link().

> The fiscal year starts on **1 April**.

Run the date dimension generation script to populate the required reporting period and fiscal attributes, including:

| Attribute | Description |
|-----------|-------------|
| Fiscal Year | Based on fiscal calendar starting April 1 |
| Fiscal Quarter | Q1–Q4 per fiscal year |
| Fiscal Month | Month number within fiscal year |
| Calendar Year | Standard calendar year |
| Calendar Month | Standard calendar month |
| Week Number | ISO week number |

---

### 6. Configure SSIS Packages

Two SSIS packages were developed:

#### 6.1 — `PortOps_STG` Package

The `PortOps_STG` package is responsible for loading source files into the staging database and performing data cleansing activities. Small lookup and dimension source tables were cleansed, standardized, and validated in this layer before being loaded into the data warehouse.

The large fact-source datasets were loaded into staging with minimal transformation. Date-related transformations were intentionally deferred to the data warehouse layer because they were easier to implement and maintain using SQL. During development, the SSIS Derived Column component had limitations when handling some of the required date calculations and business rules, so SQL-based transformations were used instead.

#### 6.2 — `PortOps_DW` Package

The `PortOps_DW` package loads the cleansed staging data into the dimensional model and applies business logic.

**Dimensions Loaded:**

| Dimension | SCD Type | Implementation Notes |
|-----------|----------|----------------------|
| `dim_date` | — | Full date dimension including fiscal attributes. Fiscal year starts on 1 April. |
| `dim_customer` | Type 2 | SCD Type 2 implementation using the `CustomerHistory` source sheet. |
| `dim_terminal` | Type 1 | Overwrite on change. |
| `dim_equipment` | Type 1 | Overwrite on change. Includes equipment type and capacity. |
| `dim_shift` | Type 1 | Small static dimension. |

**Fact Tables Loaded:**

| Fact Table | Grain | Notes |
|------------|-------|-------|
| `fact_container_movement` | One row per container move | Includes derived crane cycle time in seconds. |
| `fact_vessel_call` | One row per vessel call | Includes berth delay, vessel stay hours, and planned-versus-actual moves variance. |
| `fact_gate_transaction` | One row per gate transaction | Contains separate Gate-In and Gate-Out date foreign keys to support inactive relationships in Power BI. |

> Fact tables were implemented using an **incremental load strategy**. New records are inserted during each ETL execution while avoiding the need to reload the entire dataset. This approach improves performance and supports future scalability.

---

### 6.3 — Auditing and Logging

To support monitoring and troubleshooting, every package execution is logged to an ETL audit table. The audit process captures:

| Field | Description |
|-------|-------------|
| Package Name | Name of the SSIS package executed |
| Start Time | Execution start timestamp |
| End Time | Execution end timestamp |
| Execution Status | `Success` or `Failed` |
| Row Counts | Rows loaded per table |
| Error Information | Error details when applicable |

This logging framework provides traceability, simplifies reconciliation, and helps identify ETL failures or unexpected data volume changes.

---

## ❓ Technical Q&A

### 🗄️ Data Warehousing

#### Q1 — Explain the practical difference between SCD Type 1 and Type 2. Using examples from this assessment, justify where you applied each.

SCD Type 1 updates existing records and does not preserve historical values, while SCD Type 2 preserves history by creating a new version of the record whenever a tracked attribute changes.

In this project, I applied a Type 1 approach as part of the incremental load strategy used for loading data into the fact tables. I implemented this using SSIS Lookup components. The first Lookup compares the business key from the source with the destination table. If the business key does not exist, the record is inserted as a new row. If the business key already exists, the record is passed to a second Lookup that compares the remaining attributes. When differences are detected, the changed record is sent to an Execute SQL component that updates the existing row in the destination table.

For SCD Type 2, I implemented it on the `dim_customer` dimension using data from the `CustomerHistory` source sheet. Whenever a tracked customer attribute changes, the existing record is expired and a new version is inserted while preserving the historical record. This allows historical facts to remain associated with the correct customer version that was valid at the time of the transaction. The SQL implementation used for this logic is included in the project code folder and referenced in the repository.

---

#### Q2 — Why should a fact table reference a dimension via surrogate key rather than natural key? Give at least two reasons specific to your `dim_customer` implementation.

The fact tables in this project reference `dim_customer` using a surrogate key rather than the customer business key because `dim_customer` is implemented as a Type 2 Slowly Changing Dimension. When a customer's tracked attributes change, a new dimension record is created while the original record remains available for historical reporting. The surrogate key allows fact records to be linked to the correct version of the customer that was valid at the time the transaction occurred.

Another reason is that business keys can change or be inconsistent across source systems, while surrogate keys remain stable within the data warehouse. Using an integer surrogate key also improves join performance and reduces storage requirements compared to storing longer business keys in large fact tables. This design ensures historical accuracy, better query performance, and independence from source-system changes.

---

#### Q3 — Your `dim_date` is bounded. What happens if a fact arrives with a date outside that range, and how would you design the pipeline to handle it without failure?

If a fact record contains a date that does not exist in `dim_date`, the date lookup will fail and the fact record cannot be assigned a valid date key.

To avoid ETL failure, unmatched records should be redirected to an error table and logged in the audit table. The pipeline can then automatically extend `dim_date` with the missing dates before reprocessing the failed records.

As an additional data quality check, date constraints can be applied in the tables in DW or STG using add constraint in the date column to ensure dates fall within an acceptable range. Any record that violates these rules is redirected to the error table for review instead of being loaded into the warehouse.

---

### 🔄 SSIS

#### Q1 — Why is the built-in SSIS SCD Wizard not suitable for a production Type 2 load at scale? Give specific technical reasons.

The SSIS SCD Wizard is not suitable for large-scale production loads because it processes records row by row, which can significantly impact performance when handling large datasets.

In this project, I implemented the SCD Type 2 logic for `dim_customer` using SQL rather than the SCD Wizard. A SQL-based approach is easier to maintain, performs better on large volumes of data, and provides greater control over history tracking.

---

#### Q2 — Describe how you would implement automated row-count reconciliation between source, staging, and target — including what should happen when counts disagree.

Row-count reconciliation is implemented by capturing record counts at each ETL stage (source, staging, and target) and storing them in an audit table with a batch identifier.

In SSIS, the process can be designed using parallel execution paths. One path is responsible for loading data into the destination tables, while the second path independently calculates row counts from source and staging. These counts are then recorded in an audit table that includes table name, batch ID, row count, and execution timestamp.

After both paths complete, the counts are compared. If the values match, the load is marked as successful. If there is a mismatch, the batch is flagged as failed, and the process is stopped or redirected to an error handling workflow to prevent incorrect data propagation.

This approach ensures both data loading and validation run in parallel, improving performance while maintaining data integrity through centralized audit logging.

---

#### Q3 — What is the role of a staging layer in a data warehouse load? What would go wrong if you loaded the Excel file directly into the final fact tables?

The staging layer acts as an intermediate zone between the source system and the data warehouse. It is used to clean, validate, standardize, and temporarily store raw data before applying business rules and loading it into dimension and fact tables. In this project, staging was also used to handle data quality checks and transformations that were not efficiently supported in SSIS components.

If the Excel file were loaded directly into the final fact tables, several issues would occur. Data quality problems such as missing values, duplicates, and incorrect formats would directly impact reporting accuracy. It would also make debugging and error handling difficult because there would be no controlled layer to isolate and identify issues. In addition, business rules and transformations would be harder to manage, leading to inconsistent and unreliable data in the warehouse.

---

### 📊 Power BI

#### Q1 — Why does Power BI allow only one active relationship between two tables? What ambiguity would multiple active relationships create?

Power BI allows only one active relationship between two tables to ensure a single, clear filter path for calculations. This prevents ambiguity in how filters are propagated through the data model.

If multiple relationships were active at the same time, Power BI would not know which path to use when filtering data in a visual or measure. For example, if a fact table is connected to a date table using both Order Date and Delivery Date, Power BI would produce conflicting results because both relationships would try to filter the same data differently. This could lead to inconsistent or incorrect KPI values.

To handle this, Power BI keeps only one relationship active by default and allows the use of inactive relationships through DAX functions like `USERELATIONSHIP` when needed.

---

#### Q2 — Explain the difference between `USERELATIONSHIP` and `CROSSFILTER`. When is each the right choice?

`USERELATIONSHIP` is used to temporarily activate an inactive relationship between two tables within a specific DAX measure. It is mainly used when a table has multiple date relationships (for example, Order Date and Delivery Date), and you want to switch to a non-active relationship for a specific calculation.

`CROSSFILTER` is used to modify the filtering behavior between two related tables, such as changing the filter direction or disabling the relationship for a measure evaluation. It affects how filters propagate rather than selecting a different relationship.

In summary, `USERELATIONSHIP` is the right choice when you want to use an alternative existing relationship, while `CROSSFILTER` is used when you need to control or change how filters flow between tables.

---

#### Q3 — A business user reports that a KPI on the dashboard does not respect the date slicer. List the most likely causes in the order you would investigate them.

1. **Incorrect date column in measure** — Check whether the KPI measure is using the correct date column from `dim_date` and not a fact table date column or a disconnected field. This is the most common reason slicers appear not to work.

2. **Inactive or misconfigured relationship** — Verify the relationship between `dim_date` and the fact table is active, correctly defined, and filtering in the right direction (single direction from dimension to fact).

3. **Filter-overriding DAX functions** — Review the DAX measure for functions that remove or override filters such as `ALL()`, `REMOVEFILTERS()`, or incorrect time intelligence logic, which can ignore slicer context.

4. **Conflicting report/page/visual filters** — Check report-level, page-level, and visual-level filters to ensure there are no conflicting filters overriding the date slicer selection.

---
