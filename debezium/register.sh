#!/bin/sh
set -e

CONNECT_URL="http://kafka-connect:8083"
NAME="${CONNECTOR_NAME:-postgres-connector}"

 i=0
until curl -sf "${CONNECT_URL}/" >/dev/null; do
    i=$((i + 1))
    if [ "$i" -gt 60 ]; then
        echo "Kafka Connect not ready, giving up."
        exit 1
    fi
    sleep 2
done

curl -sS -X PUT \
    -H "Content-Type: application/json" \
    --data @/connector.config.json \
    "${CONNECT_URL}/connectors/${NAME}/config"
echo

curl -sS "${CONNECT_URL}/connectors/${NAME}/status" || true
echo
