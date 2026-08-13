#!/bin/sh
set -e

POSTGRES_HOST="${POSTGRES_HOST:-postgres}"
POSTGRES_PORT_INNER="${POSTGRES_PORT_INNER:-5432}"

MAIN_DB="${POSTGRES_DB:?POSTGRES_DB is required}"
TEST_DB="${POSTGRES_TEST_DB:?POSTGRES_TEST_DB is required}"

export PGPASSWORD="${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"

until pg_isready -h "$POSTGRES_HOST" -p "$POSTGRES_PORT_INNER" -U "$POSTGRES_USER" -d postgres; do
  echo "Wait"
  sleep 2
done

psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT_INNER" -U "$POSTGRES_USER" -d postgres -v ON_ERROR_STOP=1 <<SQL
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = '${TEST_DB}'
  AND pid <> pg_backend_pid();

DROP DATABASE IF EXISTS ${TEST_DB};
CREATE DATABASE ${TEST_DB};
SQL

TEST_JDBC_URL="jdbc:postgresql://${POSTGRES_HOST}:${POSTGRES_PORT_INNER}/${TEST_DB}"
MAIN_JDBC_URL="jdbc:postgresql://${POSTGRES_HOST}:${POSTGRES_PORT_INNER}/${MAIN_DB}"
TEST_PG_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT_INNER}/${TEST_DB}?sslmode=disable"

export LIQUIBASE_COMMAND_USERNAME="${POSTGRES_USER}"
export LIQUIBASE_COMMAND_PASSWORD="${POSTGRES_PASSWORD}"
export LIQUIBASE_COMMAND_CHANGELOG_FILE="changelog.xml"

export LIQUIBASE_COMMAND_URL="${TEST_JDBC_URL}"

seqwall staircase \
  --postgres-url "${TEST_PG_URL}" \
  --migrations-path /liquibase/changelog \
  --migrations-extension .sql \
  --upgrade "sh /scripts/ci-up-one.sh {current_migration}" \
  --downgrade "sh /scripts/ci-down-one.sh {current_migration}" \
  || echo "WARNING: seqwall staircase failed, continuing to apply migrations to main DB"

export LIQUIBASE_COMMAND_URL="${MAIN_JDBC_URL}"

if [ -n "${MIGRATION_VERSION:-}" ]; then
  COUNT="$(printf '%s' "$MIGRATION_VERSION" | sed 's/^0*//')"
  [ -n "$COUNT" ] || COUNT=0
  liquibase --search-path=/liquibase/changelog --changelog-file=changelog.xml update-count --count="${COUNT}"
else
  liquibase --search-path=/liquibase/changelog --changelog-file=changelog.xml update
fi
 
if [ "${APP_ENV:-prod}" != "prod" ]; then
  export DB_HOST="${POSTGRES_HOST}"
  export DB_PORT="${POSTGRES_PORT_INNER}"
  export DB_NAME="${MAIN_DB}"
  export DB_USER="${POSTGRES_USER}"
  export DB_PASSWORD="${POSTGRES_PASSWORD}"

  SEED_VER="${SEED_VERSION:-005}"
  SEED_SCRIPT="/seed/seed_v${SEED_VER}.py"

  if [ -f "$SEED_SCRIPT" ]; then
    echo "Running seed script: $SEED_SCRIPT"
    python3 "$SEED_SCRIPT"
  else
    echo "Seed script not found: $SEED_SCRIPT"
    exit 1
  fi
else
  echo "Skip seed in prod"
fi

echo "OK"