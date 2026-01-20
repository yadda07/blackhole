-------------------------------------------------------------------------------
-- BLACKHOLE - Data Recovery System
-- File: 04_trigger_attachment_example.sql
-- Purpose: Example of how to attach the trigger to source tables
-- Usage: Replicate this pattern for each table you want to audit
-- Param: Target audit table passed as argument (e.g., 'suppresions.rip_avg_json')
-- Author: Youcef Adda - NGE Energies Solutions
-- License: MIT
-------------------------------------------------------------------------------

-- Trigger: recover_json

-- DROP TRIGGER IF EXISTS recover_json ON rip_avg_nge.infra_pt_pot;

CREATE OR REPLACE TRIGGER recover_json
    AFTER INSERT OR DELETE OR UPDATE 
    ON rip_avg_nge.infra_pt_pot
    FOR EACH ROW
    EXECUTE FUNCTION suppresions.recover_json('suppresions.rip_avg_json');