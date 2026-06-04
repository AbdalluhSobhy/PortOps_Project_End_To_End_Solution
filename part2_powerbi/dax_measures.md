## Power BI Dashboard Design

The Power BI report was designed with usability and navigation in mind, targeting operations management users who need quick access to key operational KPIs and performance metrics.

### Report Structure

The report consists of four pages:

1. **Landing Page**

   * Serves as the report home page.
   * Contains page navigators that allow users to quickly move between report sections.
   * Provides a clean entry point and improves the overall user experience.

2. **Operations Overview**

   * Displays high-level operational KPIs such as container moves, crane cycle time, berth occupancy, and gate transaction volume.
   * Includes trend analysis and operational breakdowns by terminal and shift.

3. **Gate Performance**

   * Focuses on gate activity, gate-in versus gate-out analysis, truck turnaround times, and customer gate performance.

4. **Customer & Vessel Performance**

   * Highlights top customers, year-over-year performance, vessel efficiency metrics, and SCD Type 2 historical customer analysis.

### Visual Design

The report follows a consistent visual design across all pages to improve readability and maintain a professional appearance.

The color palette was inspired by the company's logo to align the dashboard with the organization's visual identity. Primary and secondary colors from the logo were applied consistently across KPIs, charts, navigation elements, and page headers to create a unified reporting experience.

### User Experience

To improve report usability and navigation, a set of persistent navigation icons was implemented across all report pages:

* **Home Icon**: Returns the user directly to the Landing Page from any report page.
* **Menu Icon**: Opens a navigation panel containing links to all report pages, allowing users to move quickly between report sections.
* **Filter Icon**: Opens a dedicated filter panel containing all report slicers and filtering options in a single location, helping maximize report viewing space.
* **Information Icon (!) **: Opens an information panel that provides a brief explanation of the current page, its purpose, and the meaning of the visualizations displayed, helping business users interpret the metrics correctly.

These navigation elements were designed to create a more intuitive user experience, reduce navigation effort, and improve report accessibility for both technical and non-technical users.





DAX Measures Documentation (README)
Total Container Moves

Counts all records in the container movement fact table. This measure represents the core operational throughput KPI used across the entire dashboard.

Total Container Moves = 
COUNTROWS( 'fact container_movement' )
Average Daily Moves

Calculates the average number of container moves per operating day by dividing total moves by the number of distinct movement dates.

Average Daily Moves = 
DIVIDE(
    [Total Container Moves],
    DISTINCTCOUNT( 'fact container_movement'[move_start_date] ),
    0
)
Avg Crane Cycle Seconds

Calculates the average crane cycle time in seconds. Only valid movements where end time is greater than start time are included.

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
Avg Vessel Stay Hours

Calculates the average duration vessels stay in the terminal from ATA to ATD. Only valid and complete timestamps are included.

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
Berth Delay Avg Hours

Measures the average delay between ETA and ATA for vessels, indicating schedule adherence and port efficiency.

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
Berth Occupancy %

Calculates berth utilization by comparing total vessel berth days against total available berth capacity.

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
Moves 7-Day Rolling Avg

Calculates a rolling 7-day average of container moves to smooth daily fluctuations.

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
Avg Truck Turnaround Minutes

Calculates average truck time inside the terminal from gate-in to gate-out using valid transactions only.

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
Gate Volume

Counts all gate transactions regardless of direction.

Gate Volume = 
COUNTROWS( 'fact gate_transaction' )
Gate-Ins Count

Counts only inbound gate transactions.

Gate-Ins Count = 
CALCULATE(
    COUNTROWS( 'fact gate_transaction' ),
    'fact gate_transaction'[direction] = "IN"
)
Gate-Outs Count

Counts outbound gate transactions using inactive relationship on gate-out date.

Gate-Outs Count = 
CALCULATE(
    COUNTROWS( 'fact gate_transaction' ),
    'fact gate_transaction'[direction] = "OUT",
    USERELATIONSHIP(
        'fact gate_transaction'[gate_out_date],
        'dim date'[full_date]
    )
)
Turnaround Bucket (Calculated Column)

Classifies truck turnaround time into operational performance ranges.

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
Moves Variance

Measures variance between actual and planned vessel moves.

Moves Variance = 
SUMX(
    'fact vessel_call',
        'fact vessel_call'[total_moves_actual] -
        'fact vessel_call'[total_moves_planned]
)
Moves YoY %

Calculates year-over-year growth in container moves using fiscal year and fiscal month context.

Important: This measure returns BLANK when there is less than 2 years of data available, because YoY comparison requires a previous fiscal year.

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