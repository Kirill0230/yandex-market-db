# Лабораторная №7

## Архитектура

- 1 `etcd`  для Patroni;
- 2  Patroni + PostgreSQL 17 (`postgres1`, `postgres2`);
- `haproxy` — единая точка входа  `httpchk GET /primary`;
- `prometheus` + `grafana` — мониторинг;
- метрики берутся с `postgres_exporter`, `patroni` (`:8008/metrics`), `etcd` (`:2379/metrics`), `haproxy` (`:8404/metrics`).

Логи прогонов сохраняются в `chaos/logs/`.

## Инструмент инъекции отказов

команды Docker:
- `docker kill <container>` — мгновенная остановка процесса (сценарий 1);
- `docker network disconnect <net> etcd` — изоляция etcd от сети (сценарий 2).

---

## Сценарий 1 — отказ primary PostgreSQL

**Инъекция:** `docker kill <primary>`. Скрипт определяет текущий primary автоматически.

### Поведение системы

Реплика по истечении TTL ключа лидера в etcd (`ttl: 30` в `patroni*.yml`) забрала роль leader в DCS и промоутнула свой PostgreSQL. HAProxy через 2–6 секунд по `httpchk GET /primary` переключил бэкенд на новый primary, потому что старый перестал отвечать 200, а новый начал.

### автоматическое переключение

 **Время failover в нашем прогоне — 30 секунд** (TTL ключа лидера + интервал http-check HAProxy). Видно в `chaos/logs/scenario1_*.log` по строке `Новый primary: postgres1 (через 30 с)`.

### ошибки у клиентов

В окне ~5–10 секунд после промоушена клиенты через HAProxy получали:
- `server closed the connection unexpectedly` — HAProxy ещё не успел переключить бэкенд (нужно 2 успешные http-check по 2 с = ~4 с минимум).

После завершения failover новые соединения работали

### Восстановление

После `docker start` бывшего primary Patroni поднял его как replica, выполнил `pg_rewind` от нового лидера и подключил к потоковой репликации. Финальное состояние:

```
| postgres1 | Leader  | running   | TL=28
| postgres2 | Replica | streaming | TL=28 | Lag=0
```

---

## Сценарий 2 — потеря связи с etcd


### Поведение системы

Patroni мгновенно потерял связь с DCS. В логах бывшего лидера (postgres2):

```
Error communicating with DCS
demoting self because DCS is not accessible and I was a leader
Demoting self (offline)
database system is ready to accept read-only connections
demoted self because DCS is not accessible and I was a leader
```

Это by-design защита от split-brain: без подтверждения через DCS Patroni не может оставаться лидером.

### failover без координатора

**Невозможен.** postgres1 (бывшая реплика) тоже потерял связь с etcd и не претендует на роль лидера. Никакая нода не может ни промоутнуться, ни подтвердить, что она лидер.

### Поведение узлов и доступность БД

- Оба узла Patroni логируют `EtcdConnectionFailed('No more machines in the cluster')` и ретраят каждую секунду.
- Бывший primary через несколько секунд **демотируется в read-only**.
- Реплика остаётся репликой.
- HAProxy не получает положительный ответ на `httpchk GET /primary` ни от одного узла → закрывает клиентские соединения. Все 4 пробы записи в окне 60 секунд после инъекции вернули `server closed the connection unexpectedly`.

### возврат etcd

После `docker network connect ... etcd`  кластер восстановился за ~30 секунд:

```
| postgres1 | Leader  | running   | TL=34
| postgres2 | Replica | streaming | TL=34 | Lag=0
```

Запись через HAProxy сразу прошла (`INSERT 0 1`).

---

## Мониторинг

В Grafana добавлен дашборд **`Chaos / Failover`** (`grafana/dashboards/chaos.json`):

| Панель | Метрика | Что показывает |
|---|---|---|
| Patroni: роль | `patroni_primary`, `patroni_replica` | роль каждого узла во времени; на failover видно переключение 0↔1 |
| etcd up | `up{job="etcd"}` | UP/DOWN координатора; на сценарии 2 видно провал до 0 |
| Patroni up | `up{job="patroni"}` | живы ли REST API узлов |
| HAProxy backend | `haproxy_server_status{proxy="postgres_back",state="UP"}` | состояние серверов в бэкенде; провалы в моменты failover |
| pg_up | `pg_up` | доступность PostgreSQL через `postgres_exporter` |

Источники метрик настроены в `prometheus/prometheus.yml`:
- Patroni: `postgresN:8008/metrics` (встроенный prometheus endpoint Patroni);
- etcd: `etcd:2379/metrics`;
- HAProxy: `haproxy:8404/metrics` (включён prometheus-exporter во `frontend prometheus` в `haproxy.cfg`);
- PostgreSQL: `postgres_exporter:9187/metrics`.

---

## Способы повышения устойчивости

Текущая конфигурация выдерживает отказ одного PostgreSQL-узла, но имеет несколько слабых мест:

1. **etcd-кластер из 3 узлов** вместо одного — устраняет SPOF координатора.
2. **3-й узел Patroni** 
3. **Второй HAProxy + keepalived/VIP** — сейчас HAProxy тоже SPOF.
4. **PgBouncer перед HAProxy** — снижает число оборванных коннектов во время failover: клиенты переподключаются к пулу, а пул переоткроет коннект к новому primary.
5. **Алерты в Grafana/Alertmanager** 