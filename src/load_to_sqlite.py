import csv
import sqlite3

DB_FILE = 'data/portfolio.db'
CLEAN_FILE = 'data/staging/orders_clean.csv'

conn = sqlite3.connect(DB_FILE)
cur = conn.cursor()

cur.execute('DROP TABLE IF EXISTS orders')
cur.execute('''
    CREATE TABLE orders (
        order_id TEXT,
        customer_id TEXT,
        amount REAL,
        status TEXT,
        created_at TEXT,
        updated_at TEXT
    )
''')

with open(CLEAN_FILE, newline='') as f:
    reader = csv.DictReader(f)
    rows = [
        (row['order_id'], row['customer_id'], float(row['amount']), row['status'], row['created_at'], row['updated_at'])
        for row in reader
    ]

cur.executemany('INSERT INTO orders VALUES (?, ?, ?, ?, ?, ?)', rows)
conn.commit()
conn.close()

print(f'loaded {len(rows)} rows into {DB_FILE} table orders')
