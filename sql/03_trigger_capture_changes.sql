-------------------------------------------------------------------------------
-- BLACKHOLE - Data Recovery System
-- File: 03_trigger_capture_changes.sql
-- Purpose: Core trigger function that captures all data changes
-- Description: Serializes OLD/NEW row values to JSONB with metadata
-- Captures: DELETE (OLD), UPDATE (OLD), INSERT (NEW)
-- Author: Youcef Adda - NGE Energies Solutions
-- License: MIT
-------------------------------------------------------------------------------

-- FUNCTION: suppresions.recover_json()
-- DROP FUNCTION IF EXISTS suppresions.recover_json();

CREATE OR REPLACE FUNCTION suppresions.recover_json()
    RETURNS trigger
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE NOT LEAKPROOF
AS $BODY$
DECLARE
    target_table TEXT := TG_ARGV[0];
    schema_name TEXT;
    table_name TEXT;
    real_user TEXT; 
BEGIN
    schema_name := split_part(target_table, '.', 1);
    table_name := split_part(target_table, '.', 2);
    real_user := COALESCE(
        current_setting('app.real_user', true),
        session_user
    );

    IF TG_OP = 'DELETE' THEN
        EXECUTE format(
            'INSERT INTO %I.%I (table_name, operation_type, old_values, audit_timestamp, user_name)
             VALUES ($1, $2, $3, $4, $5)',
            schema_name, table_name
        )
        USING TG_TABLE_NAME, TG_OP, row_to_json(OLD), NOW(), real_user;

    ELSIF TG_OP = 'UPDATE' THEN
        EXECUTE format(
            'INSERT INTO %I.%I (table_name, operation_type, old_values, audit_timestamp, user_name)
             VALUES ($1, $2, $3, $4, $5)',
            schema_name, table_name
        )
        USING TG_TABLE_NAME, TG_OP, row_to_json(OLD), NOW(), real_user;

    ELSIF TG_OP = 'INSERT' THEN
        EXECUTE format(
            'INSERT INTO %I.%I (table_name, operation_type, old_values, audit_timestamp, user_name)
             VALUES ($1, $2, $3, $4, $5)',
            schema_name, table_name
        )
        USING TG_TABLE_NAME, TG_OP, row_to_json(NEW), NOW(), real_user;
    END IF;

    -- M09 FIX: Return OLD for DELETE, NEW for others
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$BODY$;

ALTER FUNCTION suppresions.recover_json()
    OWNER TO ownergrp_auvergne;

GRANT EXECUTE ON FUNCTION suppresions.recover_json() TO PUBLIC;

GRANT EXECUTE ON FUNCTION suppresions.recover_json() TO auvergne_rbal WITH GRANT OPTION;

GRANT EXECUTE ON FUNCTION suppresions.recover_json() TO auvergne_rbal WITH GRANT OPTION;

GRANT EXECUTE ON FUNCTION suppresions.recover_json() TO auvergne_sch_etudes WITH GRANT OPTION;

GRANT EXECUTE ON FUNCTION suppresions.recover_json() TO cboulogne;

GRANT EXECUTE ON FUNCTION suppresions.recover_json() TO consult_auvergne;

GRANT EXECUTE ON FUNCTION suppresions.recover_json() TO ownergrp_auvergne;

