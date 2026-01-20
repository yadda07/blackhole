-------------------------------------------------------------------------------
-- BLACKHOLE - Data Recovery System
-- File: 02_audit_table_schema.sql
-- Purpose: JSONB audit table structure for centralized data capture
-- Description: Schema-agnostic storage for all INSERT/UPDATE/DELETE operations
-- Note: Create one table per schema (rip_avg_json, rbal_json, geofibre_json...)
-- Author: Youcef Adda - NGE Energies Solutions
-- License: MIT
-------------------------------------------------------------------------------

-- Table: suppresions.rip_avg_json

-- DROP TABLE IF EXISTS suppresions.rip_avg_json;

CREATE TABLE IF NOT EXISTS suppresions.rip_avg_json
(
    audit_id integer NOT NULL DEFAULT nextval('suppresions.rip_avg_json_audit_id_seq'::regclass),
    table_name character varying(255) COLLATE pg_catalog."default",
    operation_type character varying(50) COLLATE pg_catalog."default",
    old_values jsonb,
    audit_timestamp timestamp without time zone DEFAULT now(),
    user_name character varying(255) COLLATE pg_catalog."default",
    is_recent boolean,
    CONSTRAINT rip_avg_json_pkey PRIMARY KEY (audit_id)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS suppresions.rip_avg_json
    OWNER to ownergrp_auvergne;

REVOKE ALL ON TABLE suppresions.rip_avg_json FROM bayari;
REVOKE ALL ON TABLE suppresions.rip_avg_json FROM consult_auvergne;

GRANT ALL ON TABLE suppresions.rip_avg_json TO auvergne_sch_etudes;

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE suppresions.rip_avg_json TO bayari;

GRANT ALL ON TABLE suppresions.rip_avg_json TO cboulogne;

GRANT SELECT ON TABLE suppresions.rip_avg_json TO consult_auvergne;

GRANT ALL ON TABLE suppresions.rip_avg_json TO ngeconsult;

GRANT ALL ON TABLE suppresions.rip_avg_json TO ownergrp_auvergne;

COMMENT ON TABLE suppresions.rip_avg_json
    IS '- Table nettoyée le 2025-10-22
    - Données disponibles à partir de juillet 2025';
ALTER TABLE IF EXISTS suppresions.rip_avg_json
    ALTER COLUMN old_values SET STORAGE EXTERNAL;
-- Index: idx_rip_avg_json_table_op_time_desc

-- DROP INDEX IF EXISTS suppresions.idx_rip_avg_json_table_op_time_desc;

CREATE INDEX IF NOT EXISTS idx_rip_avg_json_table_op_time_desc
    ON suppresions.rip_avg_json USING btree
    (table_name COLLATE pg_catalog."default" ASC NULLS LAST, operation_type COLLATE pg_catalog."default" ASC NULLS LAST, audit_timestamp DESC NULLS FIRST)
    TABLESPACE pg_default;

-- Trigger: check_changement

-- DROP TRIGGER IF EXISTS check_changement ON suppresions.rip_avg_json;

CREATE OR REPLACE TRIGGER check_changement
    BEFORE UPDATE 
    ON suppresions.rip_avg_json
    FOR EACH ROW
    EXECUTE FUNCTION suppresions.ignore_update_if_no_change();