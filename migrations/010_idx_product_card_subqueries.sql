--liquibase formatted sql

--changeset student:010_idx_product_card_subqueries
CREATE INDEX IF NOT EXISTS idx_review_products_product_detail_id
ON review_products(product_detail_id);

CREATE INDEX IF NOT EXISTS idx_favorites_product_id
ON favorites(product_id);

--rollback DROP INDEX IF EXISTS idx_review_products_product_detail_id;
--rollback DROP INDEX IF EXISTS idx_favorites_product_id;
