# Маркетплейс «Яндекс Маркет» — платформа на PostgreSQL

Проектирование и эксплуатация базы данных маркетплейса — от ER-модели до
отказоустойчивого кластера PostgreSQL с мониторингом, бэкапами, нагрузочным
тестированием, chaos-инжинирингом и BI-пайплайном для аналитики.

---

## 1. Предметная область

Маркетплейс — платформа, на которой продавцы размещают товары, а
пользователи просматривают товары, добавляют их в корзину, оформляют заказы
и оставляют отзывы. База данных обеспечивает хранение всей информации,
необходимой для работы такой платформы.

Функциональные требования:

- **Пользователи** — профиль, несколько адресов доставки, несколько
  банковских карт на одного пользователя.
- **Продавцы** — привязаны к учётной записи пользователя, размещают товары.
- **Каталог** — товары, категории и подкатегории, дополнительные
  характеристики; один товар может продаваться несколькими продавцами
  (сущность `product_detail`).
- **Корзина** — добавление товаров, изменение количества.
- **Избранное** — список избранных товаров на пользователя.
- **Заказы** — привязка к пользователю, дате, доставке и платёжной карте;
  один заказ может содержать несколько товаров.
- **Доставка** — несколько способов доставки, стоимость зависит от региона.
- **Отзывы** — на товары и на продавцов, с текстовым комментарием.
- **История цен** — хранение истории изменения цены товара.

ER-модель — `schema.dbml` (открывается в [dbdiagram.io](https://dbdiagram.io)).

---

## 2. Что сделано

Проект собирался пошагово, слой за слоем. Ниже — сквозной обзор по
подсистемам.

### 2.1. Схема БД и миграции (`migrations/`)

Схема разворачивается версионируемыми SQL-миграциями (накатываются вручную
либо через `liquibase/`, changelog — `migrations/changelog.xml`):

| Миграция | Назначение |
|---|---|
| `001_create_reference_tables.sql` | справочники (регионы, категории и т.д.) |
| `002_create_users_related.sql` | пользователи, адреса, карты |
| `003_create_catalog.sql` | товары, категории, предложения продавцов |
| `004_create_ordering.sql` | корзина, заказы, доставка |
| `005_create_reviews.sql` | отзывы на товары и продавцов |
| `006_create_monitoring_user.sql` | служебный пользователь для `postgres_exporter` |
| `007_add_product_views_count.sql` | денормализация — счётчик просмотров товара |
| `008_create_order_status_log.sql` | журнал смены статусов заказа (insert-only) |
| `009–011` | индексы под нагрузочные запросы (`product_detail`, подзапросы карточки товара, история цен) |
| `012_mv_revenue_by_category.sql` | материализованное представление «выручка по категориям» |
| `013_enable_pg_stat_statements.sql` | включение расширения для профилирования запросов |
| `014_cdc_setup.sql` | логическая репликация (`pgoutput`, публикация) для CDC |
| `015_create_metabase_db.sql` | служебная БД метаданных Metabase |

### 2.2. Наполнение данными (`seed/`)

Python-скрипты (`seed_v005.py`, `seed_v008.py`) генерируют синтетические
данные объёмом, задаваемым `SEED_COUNT` (по умолчанию 200 000 строк на
таблицу), включая реалистичный набор статусов заказа
(`created / paid / packed / shipped / delivered / cancelled`) для
`order_status_log`.

### 2.3. Backend API (`backend/`)

Java + Spring Boot (Gradle) сервис поверх БД: контроллеры для карточки
товара, корзины, истории цен, событий изменения цены, выручки по
категориям и топ продавцов (`ru/kirill0230/controller/...`), с
соответствующими репозиториями и DTO. Используется как источник нагрузки
для профилирования и как потребитель данных о ценах.

### 2.4. Высокая доступность PostgreSQL (`patroni/`, `haproxy/`)

- **Patroni + etcd** — кластер из двух узлов PostgreSQL 17
  (`postgres1`, `postgres2`) под управлением Patroni, координация через
  `etcd` (DCS). Автоматический failover при потере лидера.
- **HAProxy** — единая точка входа для клиентов, health-check
  `GET /primary` определяет текущего лидера и направляет трафик только на
  него.
- Проверено вручную (`patroni/step5.md`): при `docker stop` текущего
  лидера кластер выбирает новый leader и HAProxy отдаёт `pg_is_in_recovery()
  = false` на новом узле.

### 2.5. Мониторинг (`prometheus/`, `grafana/`)

Prometheus собирает метрики с `postgres_exporter`, Patroni REST API
(`:8008/metrics`), `etcd` (`:2379/metrics`) и HAProxy (`:8404/metrics`).
Grafana поднимается с готовыми дашбордами (`grafana/dashboards/`):
`postgres.json`, `chaos.json` (роли Patroni, доступность etcd/HAProxy/
PostgreSQL), `optimization.json`, `backup-minio.json`.

### 2.6. Бэкапы (`backup/`, `backup-exporter/`, `minio/`)

- `backup/db_backup.sh` — снятие дампа PostgreSQL и загрузка в MinIO
  (S3-совместимое хранилище) по расписанию (`BACKUP_INTERVAL`), с ротацией
  (`BACKUP_RETENTION_COUNT`).
- `backup/restore.sh` — восстановление из самого свежего дампа, из
  конкретного файла или просмотр списка доступных дампов (`--list`).
- `backup-exporter/` — экспортёр метрик о бэкапах (возраст, размер, статус
  последнего запуска) для Prometheus/Grafana.
- `minio/init-minio.sh` и `minio/policies/backup-policy.json` — создание
  бакета и политики доступа для отдельного backup-пользователя.

### 2.7. Нагрузочное тестирование и профилирование (`load/`, `profiling/`)

Нагрузка генерируется через k6 (`load/k6_script.js` — смешанный профиль,
`load/k6_write_only.js` — только запись), метрики запросов снимаются через
`pg_stat_statements`. Три прогона зафиксированы в `profiling/1..3`:

1. **Baseline** — p95 224.70 ms, avg 41.22 ms, 3.15% HTTP-ошибок.
2. **Деградация** — после добавления денормализованной колонки, новой
   таблицы с FK и усложнения запроса карточки товара подзапросами: p95
   вырос до 1353.09 ms (+502%). Причины по каждому запросу разобраны в
   `profiling/README.md` (Seq Scan вместо индекса, HashAggregate на диске
   и т.д.).
3. **Оптимизация** — добавлены индексы (`009`–`011`) и материализованное
   представление (`012`): p95 просел до 54.09 ms, деградация на запись
   (INSERT в корзину/историю цен) — незначительная.

Итоговая сводка по каждому запросу — в `profiling/README.md`.

### 2.8. Chaos engineering (`chaos/`)

Проверка отказоустойчивости кластера инъекцией реальных сбоев, логи
прогонов — `chaos/logs/`, разбор — `chaos/README.md`:

- **Сценарий 1 — отказ primary PostgreSQL** (`docker kill`). Failover занял
  30 секунд (TTL лидерского ключа в etcd + интервал health-check
  HAProxy), клиенты в этом окне получали `server closed the connection
  unexpectedly`. После восстановления бывший primary поднимается как
  реплика через `pg_rewind`.
- **Сценарий 2 — потеря связи с etcd** (`docker network disconnect`).
  Работающий лидер сам демотируется в read-only (защита от split-brain по
  дизайну Patroni), новый лидер выбрать некому — HAProxy не пропускает
  запросы на запись до восстановления связи с DCS.

В `chaos/README.md` также перечислены слабые места текущей конфигурации
(etcd/HAProxy как SPOF) и way forward (кластер etcd из 3 узлов, второй
HAProxy + VIP, PgBouncer, алерты).

### 2.9. BI-пайплайн: CDC → Kafka → ClickHouse → Metabase (`debezium/`, `clickhouse/`, `docker-compose.bi.yml`)

Для BI-аналитики выбрана таблица `order_status_log` — insert-only журнал,
растущий быстрее остальных таблиц и содержащий всё нужное для метрик
(временная метка, категориальный статус, идентификаторы).

```
PostgreSQL (Patroni) → Debezium → Kafka (KRaft) → ClickHouse (Kafka Engine → MV → MergeTree) → Metabase
```

- **PostgreSQL** — логическая репликация (`pgoutput`), публикация
  `bi_publication`, `REPLICA IDENTITY FULL` на `order_status_log`
  (`014_cdc_setup.sql`); Debezium подключается через HAProxy, попадая на
  актуального primary.
- **Debezium** — коннектор `postgres-connector` (Kafka Connect REST API,
  порт 8083), конфиг `debezium/connector.config.json`, идемпотентная
  регистрация через `debezium/register.sh`. `snapshot.mode=initial` —
  первичная загрузка существующих строк, дальше — потоковая репликация.
- **Kafka** — режим KRaft (без ZooKeeper), топик `ym.public.order_status_log`
  создаётся автоматически.
- **ClickHouse** — `Kafka Engine` читает сырые сообщения, Materialized View
  парсит их в `MergeTree`-таблицу `bi.order_status_log`
  (`clickhouse/init/01_create_tables.sql`).
- **Metabase** — подключён к PostgreSQL (свои метаданные,
  `015_create_metabase_db.sql`) и к ClickHouse (read-only пользователь
  `metabase`). Дашборд включает как минимум три визуализации: KPI за 7
  дней, тренд событий за 30 дней по дням, распределение по статусам, плюс
  конверсию `created → delivered`. SQL-запросы — в разделе про Metabase
  ниже.
- Сквозная проверка пайплайна — `./test-e2e.sh` (INSERT/UPDATE/DELETE в
  PostgreSQL → проверка результата в ClickHouse).

### 2.10. CI (`.gitlab-ci.yml`)

Подключён внешний shared-пайплайн `db-infra/lab-stage-ci` (`testing-job.yml`)
для прогона тестовой стадии.

---

## 3. Технологический стек

PostgreSQL 17 · Patroni · etcd · HAProxy · Prometheus · Grafana · MinIO ·
Liquibase · Java / Spring Boot (Gradle) · k6 · Kafka (KRaft) · Kafka
Connect + Debezium · ClickHouse · Metabase · Docker Compose.

---

## 4. Структура репозитория

```
.
├── backend/            # Spring Boot API (Java, Gradle)
├── backup/             # скрипты бэкапа/восстановления PostgreSQL → MinIO
├── backup-exporter/    # экспортёр метрик бэкапов для Prometheus
├── chaos/              # сценарии и логи chaos-тестирования HA-кластера
├── clickhouse/         # инициализация ClickHouse (Kafka Engine, MV, MergeTree)
├── debezium/           # конфиг коннектора CDC и скрипт регистрации
├── grafana/            # дашборды и provisioning
├── haproxy/            # конфигурация HAProxy
├── liquibase/          # образ для наката миграций через Liquibase
├── load/               # сценарии нагрузочного тестирования (k6)
├── migrations/         # SQL-миграции схемы + changelog.xml
├── minio/              # инициализация бакета и политик доступа
├── patroni/            # конфигурация Patroni-кластера
├── profiling/          # результаты нагрузочных прогонов и профилирования
├── prometheus/         # конфигурация сбора метрик
├── scripts/            # вспомогательные CI/entrypoint-скрипты
├── seed/               # генерация синтетических данных
├── schema.dbml         # ER-модель (dbdiagram.io)
├── docker-compose.yml       # основной стек (БД, HA, мониторинг, бэкап, backend)
├── docker-compose.bi.yml    # BI-стек (Kafka, Debezium, ClickHouse, Metabase)
├── test-e2e.sh          # сквозная проверка CDC-пайплайна
└── .env.example         # шаблон переменных окружения
```

---

## 5. Запуск

1. Скопировать `.env.example` в `.env` и при необходимости поправить
   значения.
2. Основной стек:

   ```bash
   docker compose up -d --build
   ```

3. С BI-пайплайном:

   ```bash
   docker compose -f docker-compose.yml -f docker-compose.bi.yml up -d --build
   ```

Полезные команды — в `help.txt` (бэкапы/восстановление, накат/откат одной
миграции через Liquibase, остановка/старт узлов Patroni, нагрузочный
прогон k6, сброс статистики `pg_stat_statements`).

UI после запуска BI-стека:

- Metabase — http://localhost:3001
- kafka-ui — http://localhost:8090
- ClickHouse HTTP — http://localhost:8123
- Kafka Connect REST — http://localhost:8083

> **Важно:** каталог `metabase-plugins/` (JDBC-драйверы для Metabase,
> ~180 МБ) в репозиторий не включается — см. `.gitignore`. Если требуется
> подключать в Metabase дополнительные источники (Oracle, BigQuery,
> Snowflake и т.д.), драйверы нужно скачать отдельно и положить в эту
> папку локально.

---

## 6. Переменные окружения

Полный список — в `.env.example`. Файл `.env` с реальными значениями в
репозиторий не попадает (см. `.gitignore`).
