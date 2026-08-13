# Профилирование

## 1. Baseline

| Метрика | Значение |
|---|---:|
| p95 | 224.70 ms |
| avg | 41.22 ms |
| HTTP-ошибки | 3.15 % |

## 2. Деградация

Изменения схемы:

1. `007_add_product_views_count.sql` — nullable-колонка `views_count` в `product` (денормализация).
2. `008_create_order_status_log.sql` — новая таблица с FK на `order_header`.
3. Усложнение запроса `product_card`: добавлены подзапросы к `review_products` и `favorites`.


| Метрика | Baseline | Деградация |
|---|---:|---:|
| p95 | 224.70 ms | 1353.09 ms |
| avg | 41.22 ms | 306.14 ms |

p95 вырос на +502 %.

### Причины

| Запрос | p95 (1) | p95 (2) | причина |
|---|---:|---:|---|
| product_card | ~9 ms | 241.49 ms |  `product_detail` (нет индекса на `product_id`) + 2 коррелированных подзапроса без индексов. |
| price_history | 53.44 ms | 578.34 ms | Нет составного индекса `(product_detail_id, change_date)`, рост таблицы → Seq Scan. |
| revenue_by_category | 224.61 ms | 2063.55 ms | HashAggregate на 1.6M строк уходит на диск. |
| top_sellers | 188.07 ms | 1633.65 ms |  HashAggregate + Seq Scan по `order_detail`. |

## 3. Оптимизация

### План

| Запрос | Проблема | Решение |
|---|---|---|
| product_card | Seq Scan + подзапросы без индексов | Индексы `product_detail(product_id)`, `review_products(product_detail_id)`, `favorites(product_id)` |
| price_history | Seq Scan по истории цен | Составной индекс `(product_detail_id, change_date)` |
| revenue_by_category | Тяжёлый JOIN + GROUP BY | Materialized view `mv_revenue_by_category` | 
### Применённые миграции

- `009_idx_product_detail_product_id.sql`
- `010_idx_product_card_subqueries.sql` (2 индекса)
- `011_idx_price_history_detail_date.sql` (составной)
- `012_mv_revenue_by_category.sql` (материализованное представление)


### Эффект на запись (INSERT/UPDATE)

| Метрика | Значение |
|---|---:|
| p95 | 13.60 ms |
| HTTP-ошибки | 0 % |

| Запрос | Baseline | После опт. |
|---|---:|---:|
| INSERT cart | 0.24 ms | 0.18 ms |
| INSERT product_price_history | 0.17 ms | 0.23 ms |

Замедление записи незначительное.


## Итоговая сводная таблица

| Запрос / Эндпоинт | p95 (1) | p95 (2) | p95 (3) | Δ (1→2) | Δ (2→3) | Применённое решение |
|---|---:|---:|---:|---:|---:|---|
| mixed workload | 224.70 ms | 1353.09 ms | 54.09 ms | +502 % | −96 % | Индексы + MV |
| product_card | ~9 ms | 241.49 ms | 0.31 ms | +2580 % | −99.9 % | Индексы |
| price_history | 53.44 ms | 578.34 ms | 0.44 ms | +982 % | −99.9 % | Составной индекс |
| revenue_by_category | 224.61 ms | 2063.55 ms | 16.75 ms | +818 % | −99.2 % | Materialized view |
| top_sellers | 188.07 ms | 1633.65 ms | 1068.55 ms | +769 % | −34 % | Не оптимизирован |