--liquibase formatted sql

--changeset student:007_add_product_views_count
ALTER TABLE product ADD COLUMN views_count INT;
--rollback ALTER TABLE product DROP COLUMN views_count;