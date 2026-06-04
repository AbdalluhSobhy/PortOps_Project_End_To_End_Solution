-- ============================================================
--  PortOps Data Warehouse
--  Database: PortOps_DW
-- ============================================================

USE master;
GO

IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'PortOps_DW')
BEGIN
    ALTER DATABASE PortOps_DW SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE PortOps_DW;
END
GO

CREATE DATABASE PortOps_DW;
GO

USE PortOps_DW;
GO

-- ============================================================
--  SCHEMAS
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dim')
    EXEC('CREATE SCHEMA dim');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'fact')
    EXEC('CREATE SCHEMA fact');
GO


-- ============================================================
--  DIMENSION TABLES
-- ============================================================

-- ------------------------------------------------------------
--  dim.date
-- ------------------------------------------------------------
CREATE TABLE dim.[date]
(
    full_date           DATE PRIMARY KEY,

    day_of_week         TINYINT,
    day_name            NVARCHAR(10),

    week_number         TINYINT,

    month_number        TINYINT,
    month_name          NVARCHAR(10),

    quarter             TINYINT,
    [year]              SMALLINT,

    fiscal_month        TINYINT,
    fiscal_quarter      TINYINT,
    fiscal_year         SMALLINT,

    is_weekend          BIT,
    is_holiday          BIT
);
GO
-- ------------------------------------------------------------
--  dim.customer  — SCD Type 2
-- ------------------------------------------------------------
CREATE TABLE dim.customer
(
    customer_key    INT             IDENTITY(1,1),
    customer_id     INT,
    customer_code   NVARCHAR(20),
    customer_name   NVARCHAR(100),
    country         NVARCHAR(50),
    customer_tier   NVARCHAR(20),
    credit_limit    DECIMAL(18,2),
    active_flag     BIT,
    onboarded_date  DATE,
    effective_from  DATE,
    effective_to    DATE,
    change_reason   NVARCHAR(200),

);
GO


-- ------------------------------------------------------------
--  dim.terminal
-- ------------------------------------------------------------
CREATE TABLE dim.terminal
(
    terminal_key    INT             IDENTITY(1,1),
    terminal_id     INT,
    terminal_code   NVARCHAR(20),
    terminal_name   NVARCHAR(100),
    zone            NVARCHAR(50),
    terminal_type   NVARCHAR(50),

   
);
GO

-- ------------------------------------------------------------
--  dim.equipment
-- ------------------------------------------------------------
CREATE TABLE dim.equipment
(
    equipment_key   INT             IDENTITY(1,1),
    equipment_id    INT,
    equipment_code  NVARCHAR(20),
    equipment_type  NVARCHAR(50),
    terminal_id     INT,
    capacity_tons   DECIMAL(10,2),
    acquired_date   DATE,
    [status]        NVARCHAR(20),

);
GO

-- ------------------------------------------------------------
--  dim.shift
-- ------------------------------------------------------------
CREATE TABLE dim.shift
(
    shift_key       INT             IDENTITY(1,1),
    shift_id        INT,
    shift_code      NVARCHAR(20),
    shift_name      NVARCHAR(50),
    start_time      TIME,
    end_time        TIME,

);
GO

-- ============================================================
--  FACT TABLES
-- ============================================================

-- ------------------------------------------------------------
--  fact.container_movement
-- ------------------------------------------------------------
CREATE TABLE fact.container_movement
(
    movement_sk             INT IDENTITY(1,1),

    -- Date keys
    move_start_date         DATE,
    move_end_date           DATE,

    -- Time columns
    move_start_time         TIME,
    move_end_time           TIME,

    customer_key            INT,
    terminal_key            INT,
    equipment_key           INT,
    shift_key               INT,

    movement_id             INT,
    vessel_call_id          INT,

    container_no            NVARCHAR(20),
    container_size          NVARCHAR(10),
    move_type               NVARCHAR(20),

    is_reefer               BIT,
    weight_tons             DECIMAL(10,2)
);
GO

CREATE NONCLUSTERED INDEX IX_fcm_move_start_date ON fact.container_movement (move_start_date);
CREATE NONCLUSTERED INDEX IX_fcm_move_end_date   ON fact.container_movement (move_end_date);
CREATE NONCLUSTERED INDEX IX_fcm_customer_key    ON fact.container_movement (customer_key);
CREATE NONCLUSTERED INDEX IX_fcm_terminal_key    ON fact.container_movement (terminal_key);
CREATE NONCLUSTERED INDEX IX_fcm_equipment_key   ON fact.container_movement (equipment_key);
CREATE NONCLUSTERED INDEX IX_fcm_shift_key       ON fact.container_movement (shift_key);
GO


-- ------------------------------------------------------------
--  fact.vessel_call
-- ------------------------------------------------------------
CREATE TABLE fact.vessel_call
(
    vessel_call_sk          INT IDENTITY(1,1),

    -- Date columns
    eta_date                DATE,
    ata_date                DATE,
    atd_date                DATE,

    -- Time columns
    eta_time                TIME,
    ata_time                TIME,
    atd_time                TIME,

    customer_key            INT,
    terminal_key            INT,

    vessel_call_id          INT,
    vessel_name             NVARCHAR(100),
    voyage_no               NVARCHAR(30),

    [status]                NVARCHAR(20),

    total_moves_planned     INT,
    total_moves_actual      INT
);
GO

CREATE NONCLUSTERED INDEX IX_fvc_eta_date     ON fact.vessel_call (eta_date);
CREATE NONCLUSTERED INDEX IX_fvc_ata_date     ON fact.vessel_call (ata_date);
CREATE NONCLUSTERED INDEX IX_fvc_atd_date     ON fact.vessel_call (atd_date);
CREATE NONCLUSTERED INDEX IX_fvc_customer_key ON fact.vessel_call (customer_key);
CREATE NONCLUSTERED INDEX IX_fvc_terminal_key ON fact.vessel_call (terminal_key);
GO


-- ------------------------------------------------------------
--  fact.gate_transaction
-- ------------------------------------------------------------
CREATE TABLE fact.gate_transaction
(
    gate_txn_sk             INT IDENTITY(1,1),

    -- Date columns
    gate_in_date            DATE,
    gate_out_date           DATE,

    -- Time columns
    gate_in_time            TIME,
    gate_out_time           TIME,

    customer_key            INT,
    terminal_key            INT,
    shift_key               INT,

    gate_txn_id             INT,

    truck_plate             NVARCHAR(20),
    container_no            NVARCHAR(20),
    direction               NVARCHAR(10)
);
GO

CREATE NONCLUSTERED INDEX IX_fgt_gate_in_date  ON fact.gate_transaction (gate_in_date);
CREATE NONCLUSTERED INDEX IX_fgt_gate_out_date ON fact.gate_transaction (gate_out_date);
CREATE NONCLUSTERED INDEX IX_fgt_customer_key  ON fact.gate_transaction (customer_key);
CREATE NONCLUSTERED INDEX IX_fgt_terminal_key  ON fact.gate_transaction (terminal_key);
CREATE NONCLUSTERED INDEX IX_fgt_shift_key     ON fact.gate_transaction (shift_key);
GO

-- ============================================================
--  UNKNOWN MEMBER ROWS  (-1 pattern)
-- ============================================================

SET IDENTITY_INSERT dim.customer ON;
INSERT INTO dim.customer
    (customer_key, customer_id, customer_code, customer_name,
     country, customer_tier, credit_limit, active_flag,
     onboarded_date, effective_from, effective_to, change_reason)
VALUES
    (-1, -1, 'UNKNOWN', 'Unknown Customer',
     'N/A', 'N/A', 0, 0,
     '1900-01-01', '1900-01-01', NULL, 'Unknown member');
SET IDENTITY_INSERT dim.customer OFF;
GO

SET IDENTITY_INSERT dim.terminal ON;
INSERT INTO dim.terminal
    (terminal_key, terminal_id, terminal_code, terminal_name, zone, terminal_type)
VALUES
    (-1, -1, 'UNKNOWN', 'Unknown Terminal', 'N/A', 'N/A');
SET IDENTITY_INSERT dim.terminal OFF;
GO

SET IDENTITY_INSERT dim.equipment ON;
INSERT INTO dim.equipment
    (equipment_key, equipment_id, equipment_code, equipment_type,
     terminal_id, capacity_tons, acquired_date, [status])
VALUES
    (-1, -1, 'UNKNOWN', 'Unknown Equipment', -1, 0, '1900-01-01', 'Unknown');
SET IDENTITY_INSERT dim.equipment OFF;
GO

SET IDENTITY_INSERT dim.shift ON;
INSERT INTO dim.shift
    (shift_key, shift_id, shift_code, shift_name, start_time, end_time)
VALUES
    (-1, -1, 'UNKNOWN', 'Unknown Shift', '00:00:00', '00:00:00');
SET IDENTITY_INSERT dim.shift OFF;
GO

INSERT INTO dim.[date]
    (full_date, day_of_week, day_name, week_number,
     month_number, month_name, quarter, [year], is_weekend, is_holiday)
VALUES
    ('1900-01-01', 1, 'Unknown', 0, 0, 'Unknown', 0, 1900, 0, 0);
GO