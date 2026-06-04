# Power BI DAX Measures Documentation

This document provides a complete reference for all DAX calculations used in the Terminal Operations Dashboard. Measures are organized by functional area.

---

## 1. Core Throughput KPIs

| Measure | Description |
|---------|-------------|
| **Total Container Moves** | Primary operational throughput KPI |
| **Average Daily Moves** | Throughput normalized by operating days |

### Total Container Moves

Counts all records in the container movement fact table.

```dax
Total Container Moves = 
COUNTROWS( 'fact container_movement' )
```

### Average Daily Moves

Total moves divided by the number of distinct operating days.

```dax
Average Daily Moves = 
DIVIDE(
    [Total Container Moves],
    DISTINCTCOUNT( 'fact container_movement'[move_start_date] ),
    0
)
```

---

## 2. Crane & Operational Efficiency

| Measure | Description |
|---------|-------------|
| **Avg Crane Cycle Seconds** | Average crane cycle time (seconds) |
| **Moves 7-Day Rolling Avg** | Smooths daily fluctuations in activity |

### Avg Crane Cycle Seconds

Only includes valid movements where `move_end_time > move_start_time`.

```dax
Avg Crane Cycle Seconds = 
VAR ValidMoves =
    FILTER(
        'fact container_movement',
        'fact container_movement'[move_end_time]
            > 'fact container_movement'[move_start_time]
    )
RETURN
DIVIDE(
    SUMX(
        ValidMoves,
        DATEDIFF(
            'fact container_movement'[move_start_time],
            'fact container_movement'[move_end_time],
            SECOND
        )
    ),
    COUNTROWS( ValidMoves ),
    0
)
```

### Moves 7-Day Rolling Avg

```dax
Moves 7-Day Rolling Avg = 
DIVIDE(
    CALCULATE(
        [Total Container Moves],
        DATESINPERIOD(
            'dim date'[full_date],
            MAX( 'dim date'[full_date] ),
            -7,
            DAY
        )
    ),
    7,
    0
)
```

---

## 3. Vessel & Berth Performance

| Measure | Description |
|---------|-------------|
| **Avg Vessel Stay Hours** | Terminal stay duration (ATA to ATD) |
| **Berth Delay Avg Hours** | Schedule adherence (ETA vs ATA) |
| **Berth Occupancy %** | Berth utilization rate |
| **Moves Variance** | Actual vs planned vessel moves |
| **Moves YoY %** | Year-over-year growth (fiscal) |

### Avg Vessel Stay Hours

Filters for valid vessel calls with complete and logical timestamps.

```dax
Avg Vessel Stay Hours = 
VAR ValidCalls =
    FILTER(
        'fact vessel_call',
        NOT ISBLANK( 'fact vessel_call'[ata_date] )
            && NOT ISBLANK( 'fact vessel_call'[atd_date] )
            &&
            ( 'fact vessel_call'[atd_date]
                + 'fact vessel_call'[atd_time] )
            >
            ( 'fact vessel_call'[ata_date]
                + 'fact vessel_call'[ata_time] )
    )
RETURN
AVERAGEX(
    ValidCalls,
    DATEDIFF(
        'fact vessel_call'[ata_date] + 'fact vessel_call'[ata_time],
        'fact vessel_call'[atd_date] + 'fact vessel_call'[atd_time],
        HOUR
    )
)
```

### Berth Delay Avg Hours

Average delay between Estimated Time of Arrival (ETA) and Actual Time of Arrival (ATA).

```dax
Berth Delay Avg Hours = 
VAR ValidCalls =
    FILTER(
        'fact vessel_call',
        NOT ISBLANK( 'fact vessel_call'[eta_date] )
            && NOT ISBLANK( 'fact vessel_call'[ata_date] )
            &&
            ( 'fact vessel_call'[ata_date]
                + 'fact vessel_call'[ata_time] )
            >
            ( 'fact vessel_call'[eta_date]
                + 'fact vessel_call'[eta_time] )
    )
RETURN
AVERAGEX(
    ValidCalls,
    DATEDIFF(
        'fact vessel_call'[eta_date] + 'fact vessel_call'[eta_time],
        'fact vessel_call'[ata_date] + 'fact vessel_call'[ata_time],
        HOUR
    )
)
```

### Berth Occupancy %

Total vessel berth days ÷ (total available berths × period days).  
*Note: `TotalBerths` is hardcoded as 10 — adjust per terminal configuration.*

```dax
Berth Occupancy % = 
VAR TotalBerthDays =
    SUMX(
        'fact vessel_call',
        DATEDIFF(
            'fact vessel_call'[ata_date],
            'fact vessel_call'[atd_date],
            DAY
        )
    )
VAR PeriodDays =
    DATEDIFF(
        MIN( 'dim date'[full_date] ),
        MAX( 'dim date'[full_date] ),
        DAY
    ) + 1
VAR TotalBerths = 10
RETURN
    DIVIDE( TotalBerthDays, TotalBerths * PeriodDays, 0 )
```

### Moves Variance

Actual moves minus planned moves per vessel.

```dax
Moves Variance = 
SUMX(
    'fact vessel_call',
    'fact vessel_call'[total_moves_actual] -
    'fact vessel_call'[total_moves_planned]
)
```

### Moves YoY %

Returns `BLANK()` when less than two years of data are available.

```dax
Moves YoY % = 
VAR CurrentFiscalYear =
    SELECTEDVALUE(
        'dim date'[fiscal_year],
        MAX( 'dim date'[fiscal_year] )
    )
VAR CurrentFiscalMonths =
    CALCULATETABLE(
        VALUES( 'dim date'[fiscal_month] ),
        ALLSELECTED( 'dim date' )
    )
VAR CurrentMoves =
    [Total Container Moves]
VAR PreviousYearMoves =
    CALCULATE(
        [Total Container Moves],
        FILTER(
            ALL( 'dim date' ),
            'dim date'[fiscal_year] = CurrentFiscalYear - 1
                && 'dim date'[fiscal_month] IN CurrentFiscalMonths
        )
    )
RETURN
    DIVIDE(
        CurrentMoves - PreviousYearMoves,
        PreviousYearMoves,
        BLANK()
    )
```

---

## 4. Gate Performance

| Measure / Column | Description |
|------------------|-------------|
| **Avg Truck Turnaround Minutes** | Average time from gate-in to gate-out |
| **Gate Volume** | Total gate transactions |
| **Gate-Ins Count** | Inbound gate transactions only |
| **Gate-Outs Count** | Outbound gate transactions (inactive relationship) |
| **Turnaround Bucket** | Categorical performance range (calculated column) |

### Avg Truck Turnaround Minutes

Uses `USERELATIONSHIP` to respect `gate_out_date` as the active date context.

```dax
Avg Truck Turnaround Minutes = 
VAR ValidTransactions =
    FILTER(
        'fact gate_transaction',
        NOT ISBLANK( 'fact gate_transaction'[gate_out_time] )
            &&
            ( 'fact gate_transaction'[gate_out_date]
                + 'fact gate_transaction'[gate_out_time] )
            >
            ( 'fact gate_transaction'[gate_in_date]
                + 'fact gate_transaction'[gate_in_time] )
    )
RETURN
CALCULATE(
    DIVIDE(
        SUMX(
            ValidTransactions,
            DATEDIFF(
                'fact gate_transaction'[gate_in_date]
                    + 'fact gate_transaction'[gate_in_time],
                'fact gate_transaction'[gate_out_date]
                    + 'fact gate_transaction'[gate_out_time],
                MINUTE
            )
        ),
        COUNTROWS( ValidTransactions ),
        0
    ),
    USERELATIONSHIP(
        'fact gate_transaction'[gate_out_date],
        'dim date'[full_date]
    )
)
```

### Gate Volume

```dax
Gate Volume = 
COUNTROWS( 'fact gate_transaction' )
```

### Gate-Ins Count

```dax
Gate-Ins Count = 
CALCULATE(
    COUNTROWS( 'fact gate_transaction' ),
    'fact gate_transaction'[direction] = "IN"
)
```

### Gate-Outs Count

```dax
Gate-Outs Count = 
CALCULATE(
    COUNTROWS( 'fact gate_transaction' ),
    'fact gate_transaction'[direction] = "OUT",
    USERELATIONSHIP(
        'fact gate_transaction'[gate_out_date],
        'dim date'[full_date]
    )
)
```

### Turnaround Bucket (Calculated Column)

Classifies truck turnaround time into operational ranges.

```dax
Turnaround Bucket = 
VAR GateInDateTime =
    'fact gate_transaction'[gate_in_date]
        + 'fact gate_transaction'[gate_in_time]
VAR GateOutDateTime =
    'fact gate_transaction'[gate_out_date]
        + 'fact gate_transaction'[gate_out_time]
VAR Minutes =
    DATEDIFF(
        GateInDateTime,
        GateOutDateTime,
        MINUTE
    )
RETURN
    SWITCH(
        TRUE(),
        Minutes < 0,    "Invalid",
        Minutes <= 30,  "0–30 min",
        Minutes <= 60,  "30–60 min",
        Minutes <= 90,  "60–90 min",
        "90+ min"
    )
```

---

## 5. Dashboard Structure (Quick Reference)

| Page | Focus Area |
|------|-------------|
| **Landing Page** | Home with page navigators |
| **Operations Overview** | Container moves, crane cycles, berth occupancy, trends |
| **Gate Performance** | Gate-in/out, truck turnaround, customer performance |
| **Customer & Vessel Performance** | Top customers, YoY, vessel efficiency, SCD Type 2 |

### Persistent Navigation Icons

| Icon | Function |
|------|----------|
| 🏠 Home | Returns to Landing Page |
| ☰ Menu | Opens page navigation panel |
| 🔍 Filter | Opens centralized slicer panel |
| ℹ️ Info | Shows page help and metric definitions |

---

