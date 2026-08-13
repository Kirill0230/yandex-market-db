#!/usr/bin/env bash

set -u
cd "$(dirname "$0")/.."

LOG_DIR="chaos/logs"; mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/scenario2_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

banner() { echo; echo "==== $* ===="; }

run_timeout() {
  local secs=$1; shift
  ( "$@" ) &
  local pid=$!
  ( sleep "$secs" && kill -TERM "$pid" 2>/dev/null && sleep 1 && kill -KILL "$pid" 2>/dev/null ) &
  local watcher=$!
  wait "$pid" 2>/dev/null
  local rc=$?
  kill -TERM "$watcher" 2>/dev/null
  wait "$watcher" 2>/dev/null
  return $rc
}

NET=$(docker inspect etcd -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}' 2>/dev/null | head -n1)
if [ -z "$NET" ]; then
  exit 1
fi
echo "Сеть: $NET"

show_cluster() {
  run_timeout 8 docker exec postgres1 patronictl -c /config/patroni.yml list 2>&1 \
    | grep -v -E 'WARNING|Retrying|ERROR.*KVCache|Failed to get list|failed to resolve' \
    | grep -v '^$' \
    | head -20
  echo
}

probe_write() {
  local out
  out=$(run_timeout 5 docker exec -e PGPASSWORD=postgres postgres1 \
    psql -h haproxy -p 5000 -U postgres -d yandex_market \
    -v ON_ERROR_STOP=1 -tAc \
    "insert into chaos_probe default values returning id, ts" 2>&1)
  local rc=$?
  if [ $rc -eq 0 ]; then
    echo "запись прошла"
  else
    echo "запись недоступна"
  fi
}

docker exec -e PGPASSWORD=postgres postgres1 psql -h haproxy -p 5000 -U postgres -d yandex_market \
  -tAc "create table if not exists chaos_probe(id serial primary key, ts timestamptz default now())" >/dev/null 2>&1

show_cluster

probe_write

docker network disconnect "$NET" etcd || { echo "Не удалось отключить etcd"; exit 1; }
T0=$(date +%s)

for t in 15 30 45 60; do
  sleep 15
  echo
  echo "--- t+${t}c ($(date '+%H:%M:%S')) ---"
  show_cluster
  probe_write
done

docker logs postgres1 --since "${T0}" 2>&1 \
  | grep -Ei 'DCS is not accessible|EtcdConnectionFailed|demot|read-only|lost leader|Error communicating' \
  | head -8
echo "--- postgres2 (replica) ---"
docker logs postgres2 --since "${T0}" 2>&1 \
  | grep -Ei 'DCS is not accessible|EtcdConnectionFailed|demot|read-only|lost leader|Error communicating' \
  | head -8

docker network connect "$NET" etcd
sleep 30
echo "Кластер после восстановления:"
show_cluster
echo "Запись после восстановления:"
probe_write

echo
echo "Лог: $LOG"