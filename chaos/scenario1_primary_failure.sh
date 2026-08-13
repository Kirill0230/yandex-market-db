#!/usr/bin/env bash
# Сценарий 1 — отказ primary PostgreSQL.
# Убиваем primary, ждём failover, проверяем доступность через HAProxy, восстанавливаем.
set -u
cd "$(dirname "$0")/.."

LOG_DIR="chaos/logs"; mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/scenario1_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

if [ -f .env ]; then set -a; . ./.env; set +a; fi
PG_USER="${POSTGRES_USER:-postgres}"
PG_PASS="${POSTGRES_PASSWORD:-postgres}"
PG_DB="${POSTGRES_DB:-yandex_market}"
HAPROXY_PORT="${HAPROXY_PORT:-15432}"

banner() { echo; echo "==== $* ===="; }

who_is_primary() {
  for node in postgres1 postgres2; do
    role=$(docker exec "$node" curl -s http://localhost:8008/ 2>/dev/null \
      | python3 -c "import sys,json;print(json.load(sys.stdin).get('role',''))" 2>/dev/null || true)
    if [ "$role" = "master" ] || [ "$role" = "primary" ]; then echo "$node"; return 0; fi
  done
  echo ""; return 1
}

show_cluster() {
  docker exec postgres1 patronictl -c /config/patroni.yml list 2>/dev/null \
    || docker exec postgres2 patronictl -c /config/patroni.yml list 2>/dev/null \
    || echo "недоступен"
}

probe_sql() {
  PGPASSWORD="$PG_PASS" psql -h 127.0.0.1 -p "$HAPROXY_PORT" -U "$PG_USER" -d "$PG_DB" \
    -tAc "select inet_server_addr()::text, now()" 2>&1
}

banner "ШАГ 1. Стартовое состояние"
show_cluster
PRIMARY=$(who_is_primary)
[ -z "$PRIMARY" ] && { echo "Кластер не готов"; exit 1; }

banner "ШАГ 2. Доступность через HAProxy ДО отказа"
probe_sql || true

banner "ШАГ 3. ИНЪЕКЦИЯ: docker kill $PRIMARY"
T0=$(date +%s); docker kill "$PRIMARY"

banner "ШАГ 4. Ждём failover (до 60 с)"
NEW_PRIMARY=""
for i in $(seq 1 30); do
  sleep 2
  C=$(who_is_primary || true)
  if [ -n "$C" ] && [ "$C" != "$PRIMARY" ]; then
    NEW_PRIMARY="$C"; echo "primary: $C (через $(( $(date +%s) - T0 )) с)"; break
  fi
  echo "  попытка $i"
done
[ -z "$NEW_PRIMARY" ] && echo "FAILOVER нету" || echo "FAILOVER да"

show_cluster

for i in 1 2 3; do probe_sql || true; sleep 1; done

docker start "$PRIMARY" >/dev/null
sleep 30
show_cluster
echo "Лог: $LOG"