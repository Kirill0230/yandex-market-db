#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 -d postgres <<-EOSQL
  DO \$\$
  BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'user') THEN
      CREATE ROLE "user" LOGIN PASSWORD 'user' CREATEDB CREATEROLE;
    END IF;
  END
  \$\$;

  GRANT pg_monitor TO "user" WITH ADMIN OPTION;

  SELECT 'CREATE DATABASE yandex_market OWNER "user"'
  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'yandex_market')\gexec

  SELECT 'CREATE DATABASE yandex_market_test OWNER "user"'
  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'yandex_market_test')\gexec
EOSQL

psql -v ON_ERROR_STOP=1 -d yandex_market <<-EOSQL
  GRANT ALL ON SCHEMA public TO "user";
EOSQL

psql -v ON_ERROR_STOP=1 -d yandex_market_test <<-EOSQL
  GRANT ALL ON SCHEMA public TO "user";
EOSQL