-- ============================================================
--  PortOps DW — Truncate All Tables
--  Order: Facts first, then Dimensions
--  (facts must be truncated before dims to avoid FK issues)
-- ============================================================

USE PortOps_DW;
GO

-- Facts first
TRUNCATE TABLE fact.container_movement;
TRUNCATE TABLE fact.gate_transaction;
TRUNCATE TABLE fact.vessel_call;

-- Then Dimensions
TRUNCATE TABLE dim.customer;
TRUNCATE TABLE dim.date;
TRUNCATE TABLE dim.equipment;
TRUNCATE TABLE dim.shift;
TRUNCATE TABLE dim.terminal;
GO
