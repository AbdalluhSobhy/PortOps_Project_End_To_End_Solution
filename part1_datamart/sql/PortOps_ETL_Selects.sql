-- ============================================================
--  PortOps DW — ETL SELECT Queries
--  Source DB:  PortOps_STG
--  Target DB:  PortOps_DW
--  Null handling (facts only):
--    NVARCHAR → 'N.A' | INT → 9999 | DECIMAL → 9999.99
--  Replace ? with your incremental date parameter
-- ============================================================


-- ============================================================
--  dim.customer  — no casting, cleaned in staging
-- ============================================================
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
WHERE c.modified_date  >= ?
   OR ch.modified_date >= ?;


-- ============================================================
--  dim.terminal  — no casting, cleaned in staging
-- ============================================================
SELECT DISTINCT
    t.terminal_id,
    t.terminal_code,
    t.terminal_name,
    t.zone,
    t.terminal_type
FROM PortOps_STG.stg.Terminals t
WHERE t.modified_date >= ?;


-- ============================================================
--  dim.equipment  — no casting, cleaned in staging
-- ============================================================
SELECT DISTINCT
    e.equipment_id,
    e.equipment_code,
    e.equipment_type,
    e.terminal_id,
    e.capacity_tons,
    e.acquired_date,
    e.[status]
FROM PortOps_STG.stg.Equipment e
WHERE e.modified_date >= ?;


-- ============================================================
--  dim.shift  — casting + UPPER/TRIM applied here
-- ============================================================
SELECT DISTINCT
    s.shift_id,
    CAST(UPPER(TRIM(s.shift_code)) AS NVARCHAR(20))  AS shift_code,
    CAST(UPPER(TRIM(s.shift_name)) AS NVARCHAR(50))  AS shift_name,
    CAST(s.start_time AS TIME)                  AS start_time,
    CAST(s.end_time   AS TIME)                  AS end_time
FROM PortOps_STG.stg.Shifts s
WHERE s.modified_date >= ?;


-- ============================================================
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


-- ============================================================
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


-- ============================================================
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
