--liquibase formatted sql

--changeset student:006_create_monitoring_user splitStatements:false
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'postgres_exporter') THEN
        CREATE USER postgres_exporter WITH PASSWORD 'password';
    END IF;
END
$$;
GRANT pg_monitor TO postgres_exporter;
--rollback DROP USER IF EXISTS postgres_exporter