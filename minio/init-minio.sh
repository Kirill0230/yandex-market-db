#!/bin/sh
set -e

until mc alias set local http://minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"; do
  sleep 2
done

mc mb --ignore-existing local/"$BUCKET_BACKUP_NAME"

mc admin user add local "$MINIO_BACKUP_ACCESS_KEY" "$MINIO_BACKUP_SECRET_KEY" || true

mc admin policy create local backup-policy /policies/backup-policy.json || true

mc admin policy attach local backup-policy --user "$MINIO_BACKUP_ACCESS_KEY"
