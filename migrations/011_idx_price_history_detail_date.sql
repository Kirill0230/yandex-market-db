--liquibase formatted sql

--changeset student:011_idx_price_history_detail_date
CREATE INDEX IF NOT EXISTS idx_price_history_detail_date
ON product_price_history(product_detail_id, change_date);

--rollback DROP INDEX IF EXISTS idx_price_history_detail_date;
