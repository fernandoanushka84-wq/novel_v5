import sqlite3
from pathlib import Path

DB = Path(__file__).resolve().parents[1] / 'novel_app.db'
conn = sqlite3.connect(DB)
cur = conn.cursor()
for tbl in ['menu_items','achievements','reading_lists','profiles','write_screen']:
    try:
        cur.execute(f'SELECT COUNT(*) FROM {tbl}')
        print(tbl, cur.fetchone()[0])
    except Exception as e:
        print(tbl, 'ERROR', e)
conn.close()
