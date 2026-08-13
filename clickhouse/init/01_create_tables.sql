CREATE DATABASE IF NOT EXISTS bi;

CREATE TABLE IF NOT EXISTS bi.kafka_order_status_log_raw
(
    raw_json String
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list = 'kafka:9092',
    kafka_topic_list = 'ym.public.order_status_log',
    kafka_group_name = 'clickhouse_bi_consumer_ym',
    kafka_format = 'JSONAsString',
    kafka_num_consumers = 1,
    kafka_skip_broken_messages = 100;

CREATE TABLE IF NOT EXISTS bi.order_status_log
(
    log_id          Int64,
    order_header_id Nullable(Int64),
    status          LowCardinality(String),
    changed_at      Nullable(DateTime64(3, 'UTC')),
    op              LowCardinality(String),
    ts_ms           DateTime64(3, 'UTC'),
    is_deleted      UInt8
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(ts_ms)
ORDER BY (ts_ms, log_id);

CREATE MATERIALIZED VIEW IF NOT EXISTS bi.mv_order_status_log
TO bi.order_status_log AS
SELECT
    JSONExtract(raw_json, 'log_id', 'Int64') AS log_id,
    JSONExtract(raw_json, 'order_header_id', 'Nullable(Int64)') AS order_header_id,
    JSONExtractString(raw_json, 'status') AS status,
    parseDateTime64BestEffortOrNull(JSONExtractString(raw_json, 'changed_at'), 3) AS changed_at,
    JSONExtractString(raw_json, '__op') AS op,
    toDateTime64(JSONExtract(raw_json, '__ts_ms', 'Int64') / 1000.0, 3, 'UTC') AS ts_ms,
    if(JSONExtractString(raw_json, '__deleted') = 'true', 1, 0) AS is_deleted
FROM bi.kafka_order_status_log_raw;

CREATE USER IF NOT EXISTS metabase IDENTIFIED WITH plaintext_password BY 'metabase';
GRANT SELECT ON bi.* TO metabase;
