--liquibase formatted sql

--changeset student:008_create_order_status_log
CREATE TABLE order_status_log (
    log_id          BIGSERIAL PRIMARY KEY,
    order_header_id INT NOT NULL REFERENCES order_header(order_header_id),
    status          VARCHAR(50) NOT NULL,
    changed_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
--rollback DROP TABLE order_status_log;