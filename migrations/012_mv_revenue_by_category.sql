--liquibase formatted sql

--changeset student:012_mv_revenue_by_category
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_revenue_by_category AS
SELECT
    pc.product_category_id,
    pc.name AS category_name,
    COUNT(DISTINCT oh.order_header_id) AS orders_count,
    SUM(od.quantity * pd.price) AS revenue,
    AVG(od.quantity * pd.price) AS avg_order_line
FROM order_header oh
JOIN order_detail od ON od.order_header_id = oh.order_header_id
JOIN product_detail pd ON pd.product_detail_id = od.product_detail_id
JOIN product p ON p.product_id = pd.product_id
JOIN product_subcategory ps ON ps.product_subcategory_id = p.product_subcategory_id
JOIN product_category pc ON pc.product_category_id = ps.product_category_id
GROUP BY pc.product_category_id, pc.name;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_revenue_by_category_id
ON mv_revenue_by_category(product_category_id);

--rollback DROP MATERIALIZED VIEW IF EXISTS mv_revenue_by_category;
