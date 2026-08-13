import os
import random
import time
from decimal import Decimal

import psycopg2
from psycopg2.extras import execute_values
from faker import Faker


env = os.getenv("APP_ENV", "prod")
if env == "prod":
    print("Skip seed")
    exit(0)

seed_count = int(os.getenv("SEED_COUNT", "100"))
seed_version = os.getenv("SEED_VERSION", "005")
batch_size = int(os.getenv("SEED_BATCH_SIZE", "1000"))

fake = Faker("ru_RU")
Faker.seed(42)
random.seed(42)

conn = psycopg2.connect(
    host=os.getenv("DB_HOST"),
    port=os.getenv("DB_PORT"),
    dbname=os.getenv("DB_NAME"),
    user=os.getenv("DB_USER"),
    password=os.getenv("DB_PASSWORD")
)
cur = conn.cursor()


def table_exists(table):
    cur.execute("""
        SELECT EXISTS (
            SELECT FROM information_schema.tables
            WHERE table_schema = 'public' AND table_name = %s
        )
    """, (table,))
    return cur.fetchone()[0]


def columns_for_table(table):
    cur.execute("""
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = %s
    """, (table,))
    return [r[0] for r in cur.fetchall()]


def table_has_rows(table):
    cur.execute(f"SELECT EXISTS (SELECT 1 FROM {table} LIMIT 1)")
    return cur.fetchone()[0]


def biased_recent_date(start_days_ago, end_days_ago=0):
    """Дата с перекосом к более свежим: квадратичное распределение."""
    bias = random.random() ** 2  # ближе к 0 → ближе к 'сейчас'
    days_ago = end_days_ago + bias * (start_days_ago - end_days_ago)
    return fake.date_time_between(
        start_date=f"-{int(days_ago)}d",
        end_date=f"-{int(max(0, days_ago - 1))}d"
    )


VERSION_TABLES = {
    "001": ["region", "product_category", "product_subcategory"],
    "002": ["region", "product_category", "product_subcategory",
            "users", "address", "payment_card", "seller"],
    "003": ["region", "product_category", "product_subcategory",
            "users", "address", "payment_card", "seller",
            "delivery_method", "delivery_tariff",
            "product", "product_detail", "product_price_history",
            "favorites", "cart_items"],
    "004": ["region", "product_category", "product_subcategory",
            "users", "address", "payment_card", "seller",
            "delivery_method", "delivery_tariff",
            "product", "product_detail", "product_price_history",
            "favorites", "cart_items", "order_header", "order_detail"],
    "005": ["region", "product_category", "product_subcategory",
            "users", "address", "payment_card", "seller",
            "delivery_method", "delivery_tariff",
            "product", "product_detail", "product_price_history",
            "favorites", "cart_items", "order_header", "order_detail",
            "review_sellers", "review_products"]
}

if seed_version not in VERSION_TABLES:
    seed_version = "005"

ALLOWED_TABLES = VERSION_TABLES[seed_version]


SEED_COUNT = {
    "region":               max(10, int(0.2 * seed_count)),
    "product_category":     max(5,  int(0.1 * seed_count)),
    "product_subcategory":  max(10, int(0.2 * seed_count)),
    "users":                seed_count,
    "address":              seed_count,
    "payment_card":         seed_count,
    "seller":               max(1,  int(0.3 * seed_count)),
    "delivery_method":      max(3,  int(0.05 * seed_count)),
    "delivery_tariff":      max(10, int(0.3 * seed_count)),
    "product":              3 * seed_count,
    "product_detail":       6 * seed_count,
    "product_price_history": 30 * seed_count,   # ← растёт быстрее всех
    "favorites":            2 * seed_count,
    "cart_items":           2 * seed_count,
    "order_header":         4 * seed_count,
    "order_detail":         8 * seed_count,
    "review_sellers":       seed_count,
    "review_products":      2 * seed_count
}


SEED_TARGETS = {
    "region": lambda: {
        "name": fake.city()
    },
    "product_category": lambda: {
        "name": fake.word().capitalize()
    },
    "product_subcategory": lambda: {
        "product_category_id": random.randint(1, SEED_COUNT["product_category"]),
        "name": fake.word().capitalize()
    },
    "users": lambda: {
        "login": fake.user_name(),
        "email": fake.email(),
        "phone": fake.phone_number(),
        "password": fake.password()
    },
    "address": lambda: {
        "user_id": random.randint(1, SEED_COUNT["users"]),
        "country": "Россия",
        "region_id": random.randint(1, SEED_COUNT["region"]),
        "city": fake.city(),
        "house_number": fake.building_number(),
        "apartment_number": random.randint(1, 300)
    },
    "payment_card": lambda: {
        "user_id": random.randint(1, SEED_COUNT["users"]),
        "card_number": fake.credit_card_number(),
        "expiration_date": fake.credit_card_expire()
    },
    "seller": lambda: {
        "user_id": random.randint(1, SEED_COUNT["users"])
    },
    "delivery_method": lambda: {
        "name": random.choice(["Курьер", "ПВЗ", "Почта", "Экспресс"]),
        "description": fake.sentence(nb_words=6)
    },
    "delivery_tariff": lambda: {
        "delivery_method_id": random.randint(1, SEED_COUNT["delivery_method"]),
        "region_id": random.randint(1, SEED_COUNT["region"]),
        "price": Decimal(str(round(random.uniform(100, 1500), 2))),
        "estimated_days": random.randint(1, 14)
    },
    "product": lambda: {
        "product_subcategory_id": random.randint(1, SEED_COUNT["product_subcategory"]),
        "name": fake.word().capitalize() + " " + fake.word().capitalize(),
        "description": fake.text(max_nb_chars=200),
        "color": fake.color_name(),
        "country_origin": fake.country()
    },
    "product_detail": lambda: {
        "product_id": random.randint(1, SEED_COUNT["product"]),
        "quantity": random.randint(1, 100),
        "seller_id": random.randint(1, SEED_COUNT["seller"]),
        "price": Decimal(str(round(random.uniform(100, 50000), 2)))
    },
    "product_price_history": lambda: {
        "product_detail_id": random.randint(1, SEED_COUNT["product_detail"]),
        "price": Decimal(str(round(random.uniform(100, 50000), 2))),
        # 2 года истории с перекосом к свежим
        "change_date": biased_recent_date(start_days_ago=730)
    },
    "favorites": lambda: {
        "user_id": random.randint(1, SEED_COUNT["users"]),
        "product_id": random.randint(1, SEED_COUNT["product"])
    },
    "cart_items": lambda: {
        "user_id": random.randint(1, SEED_COUNT["users"]),
        "product_detail_id": random.randint(1, SEED_COUNT["product_detail"]),
        "quantity": random.randint(1, 5)
    },
    "order_header": lambda: {
        "user_id": random.randint(1, SEED_COUNT["users"]),
        "address_id": random.randint(1, SEED_COUNT["address"]),
        "payment_card_id": random.randint(1, SEED_COUNT["payment_card"]),
        "delivery_tariff_id": random.randint(1, SEED_COUNT["delivery_tariff"]),
        # 2 года заказов с перекосом к недавним — реалистично и даёт смысл WHERE с диапазоном
        "order_date": biased_recent_date(start_days_ago=730),
        "total_amount": Decimal(str(round(random.uniform(500, 80000), 2))),
        "delivery_cost": Decimal(str(round(random.uniform(100, 1500), 2)))
    },
    "order_detail": lambda: {
        "order_header_id": random.randint(1, SEED_COUNT["order_header"]),
        "product_detail_id": random.randint(1, SEED_COUNT["product_detail"]),
        "quantity": random.randint(1, 5)
    },
    "review_sellers": lambda: {
        "user_id": random.randint(1, SEED_COUNT["users"]),
        "seller_id": random.randint(1, SEED_COUNT["seller"]),
        "rating": random.randint(1, 5),
        "comment": fake.text(max_nb_chars=150),
        "create_date": biased_recent_date(start_days_ago=365)
    },
    "review_products": lambda: {
        "user_id": random.randint(1, SEED_COUNT["users"]),
        "product_detail_id": random.randint(1, SEED_COUNT["product_detail"]),
        "rating": random.randint(1, 5),
        "comment": fake.text(max_nb_chars=150),
        "create_date": biased_recent_date(start_days_ago=365)
    }
}


print(f"Seeding with SEED_COUNT={seed_count}, version={seed_version}, batch_size={batch_size}")

for table, generator in SEED_TARGETS.items():
    if table not in ALLOWED_TABLES:
        print(f"  skip '{table}' (not in version {seed_version})")
        continue

    if not table_exists(table):
        print(f"  skip '{table}' (table not exists)")
        continue

    if table_has_rows(table):
        print(f"  skip '{table}' (already seeded)")
        continue

    cols = columns_for_table(table)
    target_count = SEED_COUNT[table]

    started = time.time()
    print(f"  seeding '{table}': target={target_count} rows...", flush=True)

    # ключи определяем по первой записи
    sample = generator()
    keys = [k for k in sample.keys() if k in cols]
    if not keys:
        print(f"    no matching columns, skip")
        continue

    insert_stmt = f"INSERT INTO {table} ({','.join(keys)}) VALUES %s"

    batch = []
    inserted = 0
    for i in range(target_count):
        entry = generator()
        row = tuple(entry[k] for k in keys)
        batch.append(row)

        if len(batch) >= batch_size:
            execute_values(cur, insert_stmt, batch, page_size=batch_size)
            inserted += len(batch)
            batch = []

    if batch:
        execute_values(cur, insert_stmt, batch, page_size=batch_size)
        inserted += len(batch)

    conn.commit()
    elapsed = time.time() - started
    rate = inserted / elapsed if elapsed > 0 else 0
    print(f"    done '{table}': {inserted} rows in {elapsed:.1f}s ({rate:.0f} rows/s)", flush=True)


cur.close()
conn.close()
print("Seed complete")