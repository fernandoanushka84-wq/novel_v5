#!/usr/bin/env python3
"""
Initialize the novel_app database with the schema expected by the backend.
Run from: python backend/scripts/init_db.py
"""

import os
import sys
from pathlib import Path

# Add parent to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

import mysql.connector
from dotenv import load_dotenv

# Load environment
load_dotenv(os.path.join(Path(__file__).parent.parent, '.env.local'))

CONNECT_ARGS = dict(
    host=os.getenv("MYSQL_HOST", "127.0.0.1"),
    port=int(os.getenv("MYSQL_PORT", "3306")),
    user=os.getenv("MYSQL_USER", "root"),
    password=os.getenv("MYSQL_PASSWORD", ""),
    # Use pure-Python implementation. The bundled C extension
    # (_mysql_connector.cp313-win_amd64.pyd) crashes with an access
    # violation (0xC0000005) on this machine.
    use_pure=True,
)


def init_database():
    """Create the database (if needed) and apply the backend schema."""
    try:
        database = os.getenv("MYSQL_DATABASE", "novel_app_db")

        # 1. Connect without a database and create it if missing
        print(f"[OK] Connecting to MySQL...")
        conn = mysql.connector.connect(**CONNECT_ARGS, autocommit=False)
        cursor = conn.cursor()
        cursor.execute(
            f"CREATE DATABASE IF NOT EXISTS `{database}` "
            "CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
        )
        conn.commit()
        cursor.close()
        conn.close()
        print(f"[OK] Database '{database}' ready.")

        # 2. Read the backend-compatible schema
        sql_file = Path(__file__).parent.parent / 'sql' / 'setup_railway.sql'
        sql_content = sql_file.read_text(encoding='utf-8')

        # 3. Parse statements (split by ';' respecting string literals)
        statements = []
        current_stmt = ""
        in_string = False
        string_char = None

        for i, char in enumerate(sql_content):
            if char in ('"', "'") and (i == 0 or sql_content[i - 1] != '\\'):
                if not in_string:
                    in_string = True
                    string_char = char
                elif char == string_char:
                    in_string = False

            if char == ';' and not in_string:
                current_stmt += char
                stmt = current_stmt.strip()
                if stmt and not stmt.startswith('--'):
                    statements.append(stmt)
                current_stmt = ""
            else:
                current_stmt += char

        # 4. Reconnect to the database and execute schema statements
        conn = mysql.connector.connect(**CONNECT_ARGS, database=database, autocommit=False)
        cursor = conn.cursor()
        executed = 0
        for statement in statements:
            try:
                cursor.execute(statement)
                conn.commit()
                executed += 1
                if "CREATE TABLE" in statement.upper():
                    table_name = statement.split("CREATE TABLE")[1].split("(")[0].strip()
                    print(f"  [OK] Created table: {table_name}")
            except mysql.connector.Error as e:
                # Ignore idempotent creation/seeding issues
                if e.errno not in (1050, 1061, 1062, 1091):
                    print(f"Error: {e}\nStatement: {statement[:200]}...")
                    raise

        cursor.close()
        conn.close()

        print(f"[OK] Database initialized successfully! ({executed} statements executed)")

    except Exception as e:
        print(f"[ERROR] Database initialization failed: {e}")
        sys.exit(1)


if __name__ == '__main__':
    init_database()