#!/usr/bin/env bash
set -eo pipefail
 
: "${BUCKET_BACKUP_NAME:?не задано BUCKET_BACKUP_NAME}"
: "${BACKUP_FILE_PREFIX:=backup}"
: "${POSTGRES_DB:?не задано POSTGRES_DB}"
: "${POSTGRES_USER:?не задано POSTGRES_USER}"
: "${POSTGRES_HOST:?не задано POSTGRES_HOST}"
: "${MINIO_BACKUP_ACCESS_KEY:?не задано MINIO_BACKUP_ACCESS_KEY}"
: "${MINIO_BACKUP_SECRET_KEY:?не задано MINIO_BACKUP_SECRET_KEY}"
: "${POSTGRES_PORT_INNER:?не задано POSTGRES_PORT_INNER}"
 
mc alias set backupminio http://minio:9000 "$MINIO_BACKUP_ACCESS_KEY" "$MINIO_BACKUP_SECRET_KEY"
 
list_objects() {
  mc ls --json "backupminio/${BUCKET_BACKUP_NAME}" \
    | jq -r 'select(.type=="file") | .key' \
    | sed '/^$/d' \
    | sort
}

if [ "${1:-}" = "--list" ]; then
  echo "Доступные дампы в backupminio/${BUCKET_BACKUP_NAME}:"
  list_objects
  exit 0
fi
 
if [ -n "${1:-}" ]; then
  TARGET_FILE="$1"
else
  TARGET_FILE=$(list_objects | tail -n 1)
fi
 
if [ -z "$TARGET_FILE" ]; then
  echo "ОШИБКА: в бакете нет ни одного дампа для восстановления." >&2
  exit 1
fi
 
LOCAL_FILE="/tmp/${TARGET_FILE}"
 
echo "==> Восстанавливаю базу '${POSTGRES_DB}' из дампа: ${TARGET_FILE}"
 
mc cp "backupminio/${BUCKET_BACKUP_NAME}/${TARGET_FILE}" "$LOCAL_FILE"
 
pg_restore \
  -U "$POSTGRES_USER" \
  -h "$POSTGRES_HOST" \
  -p "$POSTGRES_PORT_INNER" \
  -d "$POSTGRES_DB" \
  --clean \
  --if-exists \
  --no-owner \
  -j 4 \
  "$LOCAL_FILE"
 
echo "==> Восстановление завершено успешно из ${TARGET_FILE}"
 
rm -f "$LOCAL_FILE"