-- ============================================================
--  PortOps Staging Layer
--  Database: PortOps_STG
-- ============================================================

-- Create Database
IF DB_ID('PortOps_STG') IS NULL
BEGIN
    CREATE DATABASE PortOps_STG;
END
GO

-- Use Database
USE PortOps_STG;
GO

-- Create Staging Schema
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'stg')
BEGIN
    EXEC('CREATE SCHEMA stg');
END
GO

-- ============================================================
--  DROP IF EXISTS 
-- ============================================================
IF OBJECT_ID('stg.GateTransactions',    'U') IS NOT NULL DROP TABLE stg.GateTransactions;
IF OBJECT_ID('stg.ContainerMovements',  'U') IS NOT NULL DROP TABLE stg.ContainerMovements;
IF OBJECT_ID('stg.VesselCalls',         'U') IS NOT NULL DROP TABLE stg.VesselCalls;
IF OBJECT_ID('stg.CustomerHistory',     'U') IS NOT NULL DROP TABLE stg.CustomerHistory;
IF OBJECT_ID('stg.Customers',           'U') IS NOT NULL DROP TABLE stg.Customers;
IF OBJECT_ID('stg.Equipment',           'U') IS NOT NULL DROP TABLE stg.Equipment;
IF OBJECT_ID('stg.Shifts',              'U') IS NOT NULL DROP TABLE stg.Shifts;
IF OBJECT_ID('stg.Terminals',           'U') IS NOT NULL DROP TABLE stg.Terminals;
GO


-- ============================================================
--  stg.Customers
-- ============================================================
CREATE TABLE stg.Customers
(
    customer_id      INT,
    customer_code    NVARCHAR(20),
    customer_name    NVARCHAR(100),
    country          NVARCHAR(50),
    customer_tier    NVARCHAR(20),
    credit_limit     DECIMAL(18,2),
    active_flag      BIT,
    onboarded_date   DATE,

    modified_date    DATETIME2 DEFAULT GETDATE()
);
GO


-- ============================================================
--  stg.CustomerHistory
-- ============================================================
CREATE TABLE stg.CustomerHistory
(
    customer_id      INT,
    effective_from   DATE,
    effective_to     DATE,
    customer_tier    NVARCHAR(20),
    credit_limit     DECIMAL(18,2),
    change_reason    NVARCHAR(200),

    modified_date    DATETIME2 DEFAULT GETDATE()
);
GO


-- ============================================================
--  stg.Terminals
-- ============================================================
CREATE TABLE stg.Terminals
(
    terminal_id      INT,
    terminal_code    NVARCHAR(20),
    terminal_name    NVARCHAR(100),
    zone             NVARCHAR(50),
    terminal_type    NVARCHAR(50),

    modified_date    DATETIME2 DEFAULT GETDATE()
);
GO


-- ============================================================
--  stg.Equipment
-- ============================================================
CREATE TABLE stg.Equipment
(
    equipment_id     INT,
    equipment_code   NVARCHAR(20),
    equipment_type   NVARCHAR(50),
    terminal_id      INT,
    capacity_tons    DECIMAL(10,2),
    acquired_date    DATE,
    [status]         NVARCHAR(20),

    modified_date    DATETIME2 DEFAULT GETDATE()
);
GO


-- ============================================================
--  stg.Shifts
-- ============================================================
CREATE TABLE stg.Shifts
(
    shift_id         VARCHAR(20),
    shift_code       VARCHAR(20),
    shift_name       VARCHAR(50),
    start_time       VARCHAR(20),
    end_time         VARCHAR(20),

    modified_date    DATETIME2 DEFAULT GETDATE()
);
GO


-- ============================================================
--  stg.VesselCalls
-- ============================================================
CREATE TABLE stg.VesselCalls
(
    vessel_call_id           VARCHAR(20),
    vessel_name              VARCHAR(100),
    voyage_no                VARCHAR(30),
    customer_id              VARCHAR(20),
    terminal_id              VARCHAR(20),
    eta                      VARCHAR(30),
    ata                      VARCHAR(30),
    atd                      VARCHAR(30),
    total_moves_planned      VARCHAR(20),
    total_moves_actual       VARCHAR(20),
    [status]                 VARCHAR(20),

    modified_date            DATETIME2 DEFAULT GETDATE()
);
GO


-- ============================================================
--  stg.ContainerMovements
-- ============================================================
CREATE TABLE stg.ContainerMovements
(
    movement_id          VARCHAR(20),
    vessel_call_id       VARCHAR(20),
    container_no         VARCHAR(20),
    container_size       VARCHAR(10),
    move_type            VARCHAR(20),
    equipment_id         VARCHAR(20),
    shift_id             VARCHAR(20),
    customer_id          VARCHAR(20),
    terminal_id          VARCHAR(20),
    move_start_time      VARCHAR(30),
    move_end_time        VARCHAR(30),
    is_reefer            VARCHAR(10),
    weight_tons          VARCHAR(20),

    modified_date        DATETIME2 DEFAULT GETDATE()
);
GO


-- ============================================================
--  stg.GateTransactions
-- ============================================================
CREATE TABLE stg.GateTransactions
(
    gate_txn_id      VARCHAR(20),
    truck_plate      VARCHAR(20),
    container_no     VARCHAR(20),
    customer_id      VARCHAR(20),
    terminal_id      VARCHAR(20),
    direction        VARCHAR(10),
    gate_in_time     VARCHAR(30),
    gate_out_time    VARCHAR(30),
    shift_id         VARCHAR(20),

    modified_date    DATETIME2 DEFAULT GETDATE()
);
GO


CREATE TABLE dbo.ETL_Audit_Log
(
    start_time     DATETIME2(0),
    end_time       DATETIME2(0),
    Packages_name     NVARCHAR(200),
    row_count      INT,
    status         NVARCHAR(20)
);
GO


INSERT INTO dbo.ETL_Audit_Log
(
    start_time,
    end_time,
    Packages_name,
    row_count,
    status
)
VALUES
(
    '1999-01-01 00:00:00',
    '1999-01-01 00:00:00',
    'STG_Packages',
   0,
    'faill'
);
GO