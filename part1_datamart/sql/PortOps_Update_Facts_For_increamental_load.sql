-- ============================================================
--  fact.container_movement — UPDATE statement
--  Pattern: identical to gaming DW fact_orders update
--  WHERE: movement_id (business / natural key)
-- ============================================================

UPDATE PortOps_DW.fact.container_movement
SET
    [move_start_date]   = ?,
    [move_end_date]     = ?,
    [move_start_time]   = ?,
    [move_end_time]     = ?,
    [customer_key]      = ?,
    [terminal_key]      = ?,
    [equipment_key]     = ?,
    [shift_key]         = ?,
    [vessel_call_id]    = ?,
    [container_no]      = ?,
    [container_size]    = ?,
    [move_type]         = ?,
    [is_reefer]         = ?,
    [weight_tons]       = ?
WHERE
    [movement_id]       = ?;


-- ============================================================
--  fact.gate_transaction — UPDATE statement
--  Pattern: identical to gaming DW fact_orders update
--  WHERE: gate_txn_id (business / natural key)
-- ============================================================

-- ============================================================
--  fact.vessel_call — UPDATE statement
--  Pattern: identical to gaming DW fact_orders update
--  WHERE: vessel_call_id (business / natural key)
-- ============================================================

UPDATE PortOps_DW.fact.vessel_call
SET
    [eta_date]              = ?,
    [ata_date]              = ?,
    [atd_date]              = ?,
    [eta_time]              = ?,
    [ata_time]              = ?,
    [atd_time]              = ?,
    [customer_key]          = ?,
    [terminal_key]          = ?,
    [vessel_name]           = ?,
    [voyage_no]             = ?,
    [status]                = ?,
    [total_moves_planned]   = ?,
    [total_moves_actual]    = ?
WHERE
    [vessel_call_id]        = ?;


-- ============================================================
--  fact.gate_transaction — UPDATE statement
--  Pattern: identical to gaming DW fact_orders update
--  WHERE: gate_txn_id (business / natural key)
-- ============================================================

UPDATE PortOps_DW.fact.gate_transaction
SET
    [gate_in_date]   = ?,
    [gate_out_date]  = ?,
    [gate_in_time]   = ?,
    [gate_out_time]  = ?,
    [customer_key]   = ?,
    [terminal_key]   = ?,
    [shift_key]      = ?,
    [truck_plate]    = ?,
    [container_no]   = ?,
    [direction]      = ?
WHERE
    [gate_txn_id]    = ?;
