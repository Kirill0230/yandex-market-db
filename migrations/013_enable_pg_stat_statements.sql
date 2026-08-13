--liquibase formatted sql
 
--changeset student:013_enable_pg_stat_statements
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
 
--rollback DROP EXTENSION IF EXISTS pg_stat_statements;