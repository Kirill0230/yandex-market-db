#!/usr/bin/env bash
set -euo pipefail

PG="docker exec -e PGPASSWORD=postgres postgres1 psql -h haproxy -p 5000 -U postgres -d yandex_market -tA"
CH="docker exec clickhouse clickhouse-client --query"

banner() { echo; echo "==== $* ===="; }

$PG -c "
  INSERT INTO order_status_log (order_header_id, status, changed_at)
  VALUES (1, 'created', now())
  RETURNING log_id;
"

$PG -c "UPDATE order_status_log SET status = 'shipped' WHERE order_header_id = 1 AND status = 'created' AND changed_at > now() - interval '1 minute';"

$PG -c "DELETE FROM order_status_log WHERE order_header_id = 1 AND status = 'shipped' AND changed_at > now() - interval '1 minute';"

sleep 10

$CH "
  SELECT log_id, order_header_id, status, op, ts_ms
  FROM bi.order_status_log
  WHERE order_header_id = 1
  ORDER BY ts_ms DESC
  LIMIT 10
  FORMAT PrettyCompact
"

$CH "SELECT count() FROM bi.order_status_log FORMAT PrettyCompact"

echo
