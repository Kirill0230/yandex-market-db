#!/usr/bin/env bash
set -eo pipefail

: "${BACKUP_RETENTION_COUNT:?не задано BACKUP_RETENTION_COUNT}"
: "${BUCKET_BACKUP_NAME:?не задано BUCKET_BACKUP_NAME}"
: "${BACKUP_FILE_PREFIX:=backup}"
: "${POSTGRES_DB:?не задано POSTGRES_DB}"
: "${POSTGRES_USER:?не задано POSTGRES_USER}"
: "${POSTGRES_HOST:?не задано POSTGRES_HOST}"
: "${MINIO_BACKUP_ACCESS_KEY:?не задано MINIO_BACKUP_ACCESS_KEY}"
: "${MINIO_BACKUP_SECRET_KEY:?не задано MINIO_BACKUP_SECRET_KEY}"
: "${POSTGRES_PORT_INNER:?не задано POSTGRES_PORT_INNER}"

TIMESTAMP=$(date +%Y%m%d%H%M%S)
FILENAME="${BACKUP_FILE_PREFIX}_${POSTGRES_DB}_${TIMESTAMP}.dump"
LOCAL_FILE="/tmp/${FILENAME}"
pg_dump \
  -U "$POSTGRES_USER" \
  -h "$POSTGRES_HOST" \
  -p "$POSTGRES_PORT_INNER" \
  -d "$POSTGRES_DB" \
  -Fc \
  -f "$LOCAL_FILE"

mc alias set backupminio http://minio:9000 "$MINIO_BACKUP_ACCESS_KEY" "$MINIO_BACKUP_SECRET_KEY"

mc cp "$LOCAL_FILE" "backupminio/${BUCKET_BACKUP_NAME}/${FILENAME}"

SIZE_BYTES=$(stat -c%s "$LOCAL_FILE")
LAST_SUCCESS_TS=$(date +%s)
METRICS_FILE="/shared/backup_metrics.prom"

cat > "$METRICS_FILE" <<EOF
backup_last_success_timestamp_seconds ${LAST_SUCCESS_TS}
backup_last_size_bytes ${SIZE_BYTES}
EOF

OBJECTS=$(mc ls --json "backupminio/${BUCKET_BACKUP_NAME}" | jq -r 'select(.type=="file") | .key')
COUNT=$(printf "%s\n" "$OBJECTS" | sed '/^$/d' | wc -l | tr -d ' ')

if [ "$COUNT" -gt "$BACKUP_RETENTION_COUNT" ]; then
  TO_DELETE=$((COUNT - BACKUP_RETENTION_COUNT))
  printf "%s\n" "$OBJECTS" | sort | head -n "$TO_DELETE" | while read -r oldfile; do
    mc rm "backupminio/${BUCKET_BACKUP_NAME}/${oldfile}"
  done
fi

rm -f "$LOCAL_FILE"