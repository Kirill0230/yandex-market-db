--liquibase formatted sql

--changeset student:015_metabase_db splitStatements:false runOnChange:false
SELECT 'CREATE DATABASE metabase OWNER metabase'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'metabase')\gexec
--rollback SELECT 1;

--changeset student:015_metabase_public_grants splitStatements:false runOnChange:true
CREATE EXTENSION IF NOT EXISTS dblink;
SELECT dblink_exec(
  'dbname=metabase',
  'ALTER SCHEMA public OWNER TO metabase; GRANT ALL ON SCHEMA public TO metabase; CREATE EXTENSION IF NOT EXISTS citext;'
);
--rollback SELECT 1;
