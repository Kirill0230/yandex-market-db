# Маркетплейс Яндекс Маркет

## 1. Описание системы

Разрабатываемая база данных предназначена для поддержки работы маркетплейсас Яндекс Маркета.

Маркетплейс представляют собой платформу, на которой продавцы размещают товары, а пользователи могут просматривать товары, добавлять товары в корзину, оформлять заказы и оставлять отзывы.

Система должна обеспечивать хранение информации необходимой для работы маркетплейса.

---


## 2. Функциональные требования

### Пользователи

Система должна поддерживать:

- хранение информации о пользователях
- возможность хранения нескольких адресов доставки для одного пользователя
- возможность хранения нескольких банковских карт пользователя

---

###  Продавцы

Система должна поддерживать:

- связь продавца с учетной записью пользователя
- размещения товаров

---

###  Каталог товаров

Система должна поддерживать:

- хранение информации о товарах
- разделение товаров на категории и подкатегории
- хранение дополнительных характеристик товара

Один товар может продаваться несколькими продавцами.

---

### Предложения товаров

Система должна поддерживать:

- хранение информации о товаре у конкретного продавца
- хранение количества товара

---

### Корзина

Система должна поддерживать:

- добавление товаров в корзину пользователя
- возможность изменения количества товара в корзине

---

### Избранные товары

Система должна поддерживать:

- размещение товаров в список избранного для каждого пользователя

---

### Заказы

Система должна поддерживать:

- связь заказа с пользователем
- хранение даты заказа
- связь с доставкой
- связь с платежной картой

Один заказ может содержать несколько товаров.

---

### Доставка

Система должна поддерживать:

- хранение различных способов доставки
- зависимость стоимости доставки от региона
---

###  Отзывы

Система должна поддерживать:

- возможность оставлять отзывы о товарах
- возможность оставлять отзывы о продавцах
- возмжность добавлять текстовый коментарий

---

###  История цен

Система должна поддерживать:

- хранение истории изменения цены товара

---

## BI-метрики: CDC PostgreSQL → Kafka → ClickHouse → Metabase

### Выбранная таблица

Для BI-аналитики выбрана таблица `public.order_status_log` (миграция
`008_create_order_status_log.sql`).

Почему именно она:

- **растёт быстрее остальных** — каждое изменение статуса любого заказа
  порождает новую строку (insert-only журнал), в отличие от справочников и
  агрегатных таблиц вроде `order_header`;
- **наполнена сидами** из ЛР по сидингу (`seed_v008.py` генерирует
  `5 * SEED_COUNT` строк, статусы выбираются из реалистичного набора
  `created / paid / packed / shipped / delivered / cancelled`);
- **содержит все поля для метрик** — временная метка (`changed_at`),
  категориальная величина (`status`), идентификаторы (`log_id`,
  `order_header_id`), что покрывает требования к BI-метрикам.

Поля, используемые в метриках:

| поле              | роль в BI                                  |
|-------------------|--------------------------------------------|
| `log_id`          | счётчик событий (`count()`), уникальность  |
| `order_header_id` | связь с заказом, кол-во уникальных заказов |
| `status`          | категориальный срез                        |
| `changed_at`      | временная ось, тренды                      |

### Архитектура пайплайна

```
PostgreSQL (Patroni)  →  Debezium  →  Kafka (KRaft)  →  ClickHouse Kafka Engine
        │                                                       │
        └── метаданные Metabase                                  └── MergeTree
                  │                                                       │
                  └──────────── Metabase ── дашборд ──────────────────────┘
```

- **PostgreSQL** — источник, logical replication через `pgoutput`,
  публикация `bi_publication`, `REPLICA IDENTITY FULL` для `order_status_log`
  (миграция `014_cdc_setup.sql`). Debezium ходит через HAProxy
  (`haproxy:5000`) и попадает на текущего primary в кластере Patroni.
- **Debezium** — коннектор `postgres-connector` (Kafka Connect REST API на
  порту 8083). Конфиг — `debezium/connector.config.json`, регистрация —
  идемпотентный `PUT /connectors/{name}/config` через `debezium/register.sh`.
  `snapshot.mode = initial` обеспечивает начальную загрузку существующих
  строк, далее — streaming.
- **Kafka** — режим KRaft (без ZooKeeper), один брокер, имя
  `kafka:9092` рекламируется через `KAFKA_CFG_ADVERTISED_LISTENERS`. Топик
  CDC: `ym.public.order_status_log` (создаётся автоматически).
  Consumer group для CH — `clickhouse_bi_consumer_ym` (уникальный).
- **ClickHouse** — `Kafka Engine` читает сырые JSON-сообщения,
  `Materialized View` парсит их и пишет в `MergeTree`-таблицу
  `bi.order_status_log` (см. `clickhouse/init/01_create_tables.sql`).
- **Metabase** — два подключения: к PostgreSQL (своя БД `metabase` для
  метаданных, миграция `015_create_metabase_db.sql`) и к ClickHouse
  (только SELECT, пользователь `metabase`).

### Запуск

```bash
docker compose -f docker-compose.yml -f docker-compose.bi.yml up -d --build
```

Старые сервисы (Patroni, HAProxy, Prometheus, Grafana, MinIO, бэкап,
backend и т. д.) остаются работать без изменений — добавляются только
Kafka, kafka-ui, Kafka Connect, Debezium-register, ClickHouse и Metabase.

UI:

- Metabase — http://localhost:3001 (первичная настройка через мастер)
- kafka-ui — http://localhost:8090
- ClickHouse HTTP — http://localhost:8123 (`bi`/`bi`)
- Kafka Connect REST — http://localhost:8083

### Проверка пайплайна end-to-end

Скрипт `./test-e2e.sh` выполняет INSERT/UPDATE/DELETE по
`order_status_log` в PostgreSQL и читает результат из ClickHouse.

### Дашборд Metabase

В Metabase создаётся дашборд минимум с тремя визуализациями разных типов.
SQL-запросы выполняются к ClickHouse-датасорсу:

1. **KPI: количество событий смены статуса за 7 дней** (число)

   ```sql
   SELECT count() AS events_7d
   FROM bi.order_status_log
   WHERE is_deleted = 0
     AND changed_at >= now() - INTERVAL 7 DAY;
   ```

2. **Тренд событий по дням за последние 30 дней** (линейный график)

   ```sql
   SELECT toDate(changed_at) AS day,
          count() AS events
   FROM bi.order_status_log
   WHERE is_deleted = 0
     AND changed_at >= today() - 30
   GROUP BY day
   ORDER BY day;
   ```

3. **Распределение статусов** (bar / pie chart)

   ```sql
   SELECT status,
          count() AS events,
          uniqExact(order_header_id) AS orders
   FROM bi.order_status_log
   WHERE is_deleted = 0
   GROUP BY status
   ORDER BY events DESC;
   ```

Дополнительная метрика — доля доставленных заказов от созданных
(конверсия воронки):

```sql
SELECT
    countIf(status = 'created')   AS created,
    countIf(status = 'delivered') AS delivered,
    round(countIf(status = 'delivered') / nullIf(countIf(status = 'created'), 0) * 100, 2)
        AS delivered_pct
FROM bi.order_status_log
WHERE is_deleted = 0;
```
