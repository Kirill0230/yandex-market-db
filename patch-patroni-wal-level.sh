#!/usr/bin/env bash
set -euo pipefail

docker exec postgres1 sh -c "curl -s -XPATCH -H 'Content-Type: application/json' -d '{
  \"postgresql\": {
    \"parameters\": {
      \"wal_level\": \"logical\",
      \"max_wal_senders\": 10,
      \"max_replication_slots\": 10
    },
    \"pg_hba\": [
      \"local all all trust\",
      \"host all all 127.0.0.1/32 trust\",
      \"host replication replicator 0.0.0.0/0 md5\",
      \"host replication debezium 0.0.0.0/0 md5\",
      \"host all debezium 0.0.0.0/0 md5\",
      \"host all all 0.0.0.0/0 md5\"
    ]
  }
}' http://localhost:8008/config"

docker exec postgres1 patronictl -c /config/patroni.yml reload postgres-cluster --force
docker exec postgres2 patronictl -c /config/patroni.yml reload postgres-cluster --force

docker exec postgres1 patronictl -c /config/patroni.yml restart postgres-cluster --force

docker exec postgres1 psql -U postgres -c "SHOW wal_level;"