--liquibase formatted sql

--changeset student:014_cdc_users splitStatements:false
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'debezium') THEN
    CREATE USER debezium WITH PASSWORD 'debezium' REPLICATION;
  ELSE
    ALTER USER debezium WITH PASSWORD 'debezium' REPLICATION;
  END IF;

  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'metabase') THEN
    CREATE USER metabase WITH PASSWORD 'metabase' CREATEDB;
  ELSE
    ALTER USER metabase WITH PASSWORD 'metabase';
  END IF;
END
$$;
--rollback SELECT 1;

--changeset student:014_cdc_grants splitStatements:false
GRANT USAGE ON SCHEMA public TO debezium;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO debezium;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO debezium;
--rollback SELECT 1;

--changeset student:014_replica_identity splitStatements:false
ALTER TABLE public.order_status_log REPLICA IDENTITY FULL;
--rollback SELECT 1;

--changeset student:014_publication splitStatements:false runOnChange:true
DROP PUBLICATION IF EXISTS bi_publication;
CREATE PUBLICATION bi_publication FOR TABLE public.order_status_log;
ALTER PUBLICATION bi_publication OWNER TO debezium;
--rollback SELECT 1;