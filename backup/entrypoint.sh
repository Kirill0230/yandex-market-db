#!/usr/bin/env bash
set -eo pipefail

PGPASS_PATH="/root/.pgpass"

cat <<PGEOF > "$PGPASS_PATH"
${POSTGRES_HOST}:${POSTGRES_PORT_INNER}:${POSTGRES_DB}:${POSTGRES_USER}:${POSTGRES_PASSWORD}
PGEOF

chmod 600 "$PGPASS_PATH"
chown root:root "$PGPASS_PATH"

(
  echo "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  echo "POSTGRES_HOST=${POSTGRES_HOST}"
  echo "POSTGRES_PORT_INNER=${POSTGRES_PORT_INNER}"
  echo "POSTGRES_DB=${POSTGRES_DB}"
  echo "POSTGRES_USER=${POSTGRES_USER}"
  echo "POSTGRES_PASSWORD=${POSTGRES_PASSWORD}"
  echo "MINIO_BACKUP_ACCESS_KEY=${MINIO_BACKUP_ACCESS_KEY}"
  echo "MINIO_BACKUP_SECRET_KEY=${MINIO_BACKUP_SECRET_KEY}"
  echo "BUCKET_BACKUP_NAME=${BUCKET_BACKUP_NAME}"
  echo "BACKUP_RETENTION_COUNT=${BACKUP_RETENTION_COUNT}"
  echo "${BACKUP_INTERVAL} /usr/local/bin/db_backup.sh >> /var/log/db_backup.log 2>&1"
) | crontab -

exec "$@"