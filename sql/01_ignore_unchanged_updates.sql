-------------------------------------------------------------------------------
-- BLACKHOLE - Data Recovery System
-- File: 01_ignore_unchanged_updates.sql
-- Purpose: Optimization trigger to prevent redundant audit entries
-- Description: Cancels UPDATE operations when no actual data change occurred
-- Author: Youcef Adda - NGE Energies Solutions
-- License: MIT
-------------------------------------------------------------------------------

-- FUNCTION: suppresions.ignore_update_if_no_change()
-- DROP FUNCTION IF EXISTS suppresions.ignore_update_if_no_change();

CREATE OR REPLACE FUNCTION suppresions.ignore_update_if_no_change()
    RETURNS trigger
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE NOT LEAKPROOF
AS $BODY$
BEGIN
    IF ROW(NEW.*) IS NOT DISTINCT FROM ROW(OLD.*) THEN
        RETURN NULL;
    END IF;
    RETURN NEW;
END;
$BODY$;

ALTER FUNCTION suppresions.ignore_update_if_no_change()
    OWNER TO yadda;

GRANT EXECUTE ON FUNCTION suppresions.ignore_update_if_no_change() TO PUBLIC;

GRANT EXECUTE ON FUNCTION suppresions.ignore_update_if_no_change() TO yadda;

