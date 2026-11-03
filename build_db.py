"""
build_db.py
-----------
Build a SQLite retail warehouse from synthetic data, then run the analytical
queries in queries.sql and print the results.

Zero external dependencies — uses only Python's standard library (sqlite3).
Run it and you get a populated retail.db plus the query output.

    python build_db.py            # build db + run all queries
    python build_db.py --rebuild  # drop and rebuild from scratch
"""

import argparse
import os
import random
import sqlite3
from datetime import date, timedelta

DB_PATH = "retail.db"
RNG = random.Random(42)

REGIONS = {"Central": "Texas", "West": "California", "South": "Florida", "East": "New York"}
STORES = ["STORE_ATX", "STORE_HOU", "STORE_LAX", "STORE_MIA", "STORE_NYC"]
PRODUCTS = {
    "SKU_COLA_12PK":    ("Beverage", 6.99),
    "SKU_WATER_24PK":   ("Beverage", 5.49),
    "SKU_CEREAL_OAT":   ("Breakfast", 4.49),
    "SKU_GRANOLA":      ("Breakfast", 5.99),
    "SKU_CANDY_BAR":    ("Candy", 1.29),
    "SKU_GUMMIES":      ("Candy", 2.49),
    "SKU_CHIPS_FAMILY": ("Snacks", 3.99),
    "SKU_PRETZELS":     ("Snacks", 2.99),
}

START = date(2025, 1, 1)
DAYS = 180


def build(conn):
    with open("schema.sql") as f:
        conn.executescript(f.read())
    cur = conn.cursor()

    # dim_store
    for i, sid in enumerate(STORES, 1):
        region = list(REGIONS.keys())[(i - 1) % len(REGIONS)]
        cur.execute("INSERT INTO dim_store VALUES (?,?,?,?)",
                    (i, sid, region, REGIONS[region]))

    # dim_product
    for i, (sku, (cat, price)) in enumerate(PRODUCTS.items(), 1):
        cur.execute("INSERT INTO dim_product VALUES (?,?,?,?)", (i, sku, cat, price))

    # dim_date
    for n in range(DAYS):
        d = START + timedelta(days=n)
        dk = int(d.strftime("%Y%m%d"))
        q = (d.month - 1) // 3 + 1
        cur.execute("INSERT INTO dim_date VALUES (?,?,?,?,?,?,?)",
                    (dk, d.isoformat(), d.year, q, d.month,
                     d.weekday(), 1 if d.weekday() >= 5 else 0))

    # fact_sales
    sale_id = 1
    store_keys = {sid: i for i, sid in enumerate(STORES, 1)}
    prod_keys = {sku: i for i, sku in enumerate(PRODUCTS, 1)}
    base = {"Beverage": 40, "Breakfast": 25, "Candy": 60, "Snacks": 35}
    rows = []
    for n in range(DAYS):
        d = START + timedelta(days=n)
        dk = int(d.strftime("%Y%m%d"))
        weekend_mult = 1.3 if d.weekday() >= 5 else 1.0
        for sid in STORES:
            for sku, (cat, price) in PRODUCTS.items():
                promo = 1 if RNG.random() < 0.1 else 0
                promo_mult = 1.8 if promo else 1.0
                units = max(0, int(RNG.gauss(base[cat] * weekend_mult * promo_mult,
                                             base[cat] * 0.3)))
                if units == 0:
                    continue
                rows.append((sale_id, dk, store_keys[sid], prod_keys[sku],
                             units, round(units * price, 2), promo))
                sale_id += 1
    cur.executemany("INSERT INTO fact_sales VALUES (?,?,?,?,?,?,?)", rows)
    conn.commit()
    return len(rows)


def run_queries(conn):
    """Execute each ;-terminated statement in queries.sql and print results."""
    with open("queries.sql") as f:
        sql = f.read()

    # Split on the labeled query banners so we can print titles.
    blocks = []
    current_title, current_sql = None, []
    for line in sql.splitlines():
        if line.startswith("-- Q") and "." in line:
            current_title = line.lstrip("- ").strip()
        elif line.strip() and not line.strip().startswith("--"):
            current_sql.append(line)
            if line.strip().endswith(";"):
                blocks.append((current_title, "\n".join(current_sql)))
                current_sql = []

    cur = conn.cursor()
    for title, stmt in blocks:
        cur.execute(stmt)
        cols = [c[0] for c in cur.description]
        rows = cur.fetchall()
        print(f"\n{'='*70}\n{title or 'Query'}\n{'='*70}")
        print(" | ".join(cols))
        print("-" * 70)
        for r in rows[:10]:
            print(" | ".join(str(x) for x in r))
        if len(rows) > 10:
            print(f"... ({len(rows)} rows total)")


def main(rebuild=False):
    if rebuild and os.path.exists(DB_PATH):
        os.remove(DB_PATH)
    first_build = not os.path.exists(DB_PATH)
    conn = sqlite3.connect(DB_PATH)
    if first_build:
        n = build(conn)
        print(f"Built {DB_PATH}: {n:,} fact rows, "
              f"{len(STORES)} stores, {len(PRODUCTS)} products, {DAYS} days.")
    run_queries(conn)
    conn.close()


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--rebuild", action="store_true")
    args = p.parse_args()
    main(rebuild=args.rebuild)
