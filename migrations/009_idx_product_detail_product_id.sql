--liquibase formatted sql

--changeset student:009_idx_product_detail_product_id
CREATE INDEX IF NOT EXISTS idx_product_detail_product_id
ON product_detail(product_id);

--rollback DROP INDEX IF EXISTS idx_product_detail_product_id;
