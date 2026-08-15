
from pathlib import Path
import logging
from typing import Any

from .database import (
    initialize_database_if_needed,
    run_startup_migrations,
    get_connection,
    USE_SQLITE,
)
from . import mysql_compat

LOGGER = logging.getLogger(__name__)

DEFAULT_TAGS = [
    "Romance",
    "Love",
    "Romance/Drama",
    "Love Story",
    "Fantasy",
    "Dark",
    "Alpha Male",
    "Werewolves",
    "Paranormal",
    "Erotica",
    "Mystery",
    "Thriller",
    "Young Adult",
    "Adventure",
    "Horror",
    "SciFi",
    "Drama",
    "Humor",
    "LGBTQ+",
    "Boyxboy",
    "Omegaverse",
]


def _query_count(connection, table: str) -> int:
    cursor = connection.cursor()
    try:
        cursor.execute(f"SELECT COUNT(*) FROM {table}")
        row = cursor.fetchone()
        return int(row[0]) if row is not None else 0
    except Exception:
        return 0
    finally:
        cursor.close()


def _ensure_mysql_extra_tables(connection) -> int:
    """Create/alter missing MySQL tables and columns used by the API."""
    from . import database as db_mod

    if db_mod.USE_SQLITE:
        return 0

    cursor = connection.cursor()
    added = 0
    statements = [
        (
            "tags",
            """
            CREATE TABLE IF NOT EXISTS tags (
                id INT AUTO_INCREMENT PRIMARY KEY,
                name VARCHAR(80) NOT NULL UNIQUE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            """,
        ),
        (
            "book_tags",
            """
            CREATE TABLE IF NOT EXISTS book_tags (
                book_id INT NOT NULL,
                tag_id INT NOT NULL,
                PRIMARY KEY (book_id, tag_id),
                CONSTRAINT fk_bt_book FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE,
                CONSTRAINT fk_bt_tag FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
            )
            """,
        ),
        (
            "book_reviews",
            """
            CREATE TABLE IF NOT EXISTS book_reviews (
                id INT AUTO_INCREMENT PRIMARY KEY,
                book_id INT NOT NULL,
                user_id INT NOT NULL,
                rating TINYINT NOT NULL DEFAULT 5,
                comment TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                CONSTRAINT fk_review_book FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
            )
            """,
        ),
        (
            "author_follows",
            """
            CREATE TABLE IF NOT EXISTS author_follows (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id INT NOT NULL,
                author_id INT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY uq_follow (user_id, author_id)
            )
            """,
        ),
        (
            "book_likes",
            """
            CREATE TABLE IF NOT EXISTS book_likes (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id INT NOT NULL,
                book_id INT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY uq_book_like (user_id, book_id)
            )
            """,
        ),
        (
            "genres",
            """
            CREATE TABLE IF NOT EXISTS genres (
                id INT AUTO_INCREMENT PRIMARY KEY,
                name VARCHAR(80) NOT NULL UNIQUE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            """,
        ),
        (
            "reading_list_items",
            """
            CREATE TABLE IF NOT EXISTS reading_list_items (
                id INT AUTO_INCREMENT PRIMARY KEY,
                reading_list_id INT NOT NULL,
                book_id INT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY uq_list_book (reading_list_id, book_id),
                CONSTRAINT fk_rli_list FOREIGN KEY (reading_list_id) REFERENCES reading_lists(id) ON DELETE CASCADE,
                CONSTRAINT fk_rli_book FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
            )
            """,
        ),
    ]
    try:
        for name, sql in statements:
            cursor.execute(f"SHOW TABLES LIKE '{name}'")
            if cursor.fetchone() is None:
                cursor.execute(sql)
                added += 1
                LOGGER.info("Created missing table: %s", name)

        # Column patches on existing tables
        column_patches = [
            ("app_users", "cover_url", "ALTER TABLE app_users ADD COLUMN cover_url TEXT NULL"),
            ("app_users", "bio", "ALTER TABLE app_users ADD COLUMN bio TEXT NULL"),
            ("app_users", "username", "ALTER TABLE app_users ADD COLUMN username VARCHAR(40) NULL"),
            ("app_users", "country_code", "ALTER TABLE app_users ADD COLUMN country_code VARCHAR(8) DEFAULT ''"),
            ("author_follows", "user_id", "ALTER TABLE author_follows ADD COLUMN user_id INT NULL"),
            ("author_follows", "author_id", "ALTER TABLE author_follows ADD COLUMN author_id INT NULL"),
            ("app_users", "followers_count", "ALTER TABLE app_users ADD COLUMN followers_count INT NOT NULL DEFAULT 0"),
            ("books", "user_id", "ALTER TABLE books ADD COLUMN user_id INT NULL AFTER id"),
            ("books", "primary_genre", "ALTER TABLE books ADD COLUMN primary_genre VARCHAR(80) NOT NULL DEFAULT ''"),
            ("books", "secondary_genre", "ALTER TABLE books ADD COLUMN secondary_genre VARCHAR(80) NOT NULL DEFAULT ''"),
            ("books", "is_completed", "ALTER TABLE books ADD COLUMN is_completed TINYINT(1) NOT NULL DEFAULT 0"),
            ("reading_lists", "user_id", "ALTER TABLE reading_lists ADD COLUMN user_id INT NULL AFTER id"),
            ("library_entries", "user_id", "ALTER TABLE library_entries ADD COLUMN user_id INT NULL AFTER id"),
            ("book_reviews", "comment", "ALTER TABLE book_reviews ADD COLUMN comment TEXT NULL"),
        ]
        for table, column, alter_sql in column_patches:
            try:
                cursor.execute(f"SHOW COLUMNS FROM {table} LIKE '{column}'")
                if cursor.fetchone() is None:
                    cursor.execute(alter_sql)
                    added += 1
                    LOGGER.info("Added column %s.%s", table, column)
            except Exception as col_exc:
                LOGGER.warning("Column patch %s.%s skipped: %s", table, column, col_exc)

        # If book_reviews has body but not comment, copy/rename
        try:
            cursor.execute("SHOW COLUMNS FROM book_reviews LIKE 'body'")
            has_body = cursor.fetchone() is not None
            cursor.execute("SHOW COLUMNS FROM book_reviews LIKE 'comment'")
            has_comment = cursor.fetchone() is not None
            if has_body and has_comment:
                cursor.execute(
                    "UPDATE book_reviews SET comment = body WHERE (comment IS NULL OR comment = '') AND body IS NOT NULL"
                )
            elif has_body and not has_comment:
                cursor.execute("ALTER TABLE book_reviews CHANGE body comment TEXT NOT NULL")
                added += 1
        except Exception as rev_exc:
            LOGGER.warning("book_reviews comment/body patch skipped: %s", rev_exc)

        connection.commit()
    except Exception as exc:
        LOGGER.warning("ensure_mysql_extra_tables failed: %s", exc)
        try:
            connection.rollback()
        except Exception:
            pass
    finally:
        cursor.close()
    return added


def _seed_tags(connection) -> int:
    cursor = connection.cursor()
    inserted = 0
    try:
        from . import database as db_mod

        use_sqlite = db_mod.USE_SQLITE
        for name in DEFAULT_TAGS:
            if use_sqlite:
                cursor.execute("SELECT id FROM tags WHERE name=? LIMIT 1", (name,))
                if cursor.fetchone() is None:
                    cursor.execute("INSERT INTO tags (name) VALUES (?)", (name,))
                    inserted += 1
            else:
                cursor.execute("SELECT id FROM tags WHERE name=%s LIMIT 1", (name,))
                if cursor.fetchone() is None:
                    cursor.execute("INSERT INTO tags (name) VALUES (%s)", (name,))
                    inserted += 1
        connection.commit()
    except Exception as exc:
        LOGGER.warning("Tag seed skipped or partial: %s", exc)
        try:
            connection.rollback()
        except Exception:
            pass
    finally:
        cursor.close()
    return inserted


def _apply_runtime_patches() -> None:
    try:
        from . import main as main_mod
        from . import database as db_mod

        def _to_db_query(query: str) -> str:
            return mysql_compat.to_db_query(query, db_mod.USE_SQLITE)

        main_mod._to_db_query = _to_db_query  # type: ignore[attr-defined]

        def _set_story_tags(story_id: int, tag_names: list[str] | None) -> None:
            mysql_compat.set_story_tags(
                story_id,
                tag_names,
                fetch_all=main_mod.fetch_all,
                execute_write=main_mod.execute_write,
            )

        main_mod._set_story_tags = _set_story_tags  # type: ignore[attr-defined]

        def _fetch_one(query: str, params=None):
            rows = main_mod.fetch_all(query, params)
            return rows[0] if rows else None

        try:
            from .tag_routes import register_extra_routes

            serialize = getattr(main_mod, "_serialize_book", None)
            register_extra_routes(
                main_mod.app,
                fetch_all=main_mod.fetch_all,
                fetch_one=_fetch_one,
                execute_write=main_mod.execute_write,
                serialize_book=serialize,
            )
            LOGGER.info("Registered extra tag/book routes")
        except Exception as route_exc:
            LOGGER.warning("Extra routes not registered: %s", route_exc)

        try:
            from .inkitt_routes import register_inkitt_routes

            register_inkitt_routes(
                main_mod.app,
                fetch_all=main_mod.fetch_all,
                fetch_one=_fetch_one,
                execute_write=main_mod.execute_write,
                require_user=getattr(main_mod, "require_user", None),
                require_admin=getattr(main_mod, "require_admin", None),
                bump_content_version=getattr(main_mod, "bump_content_version", None),
            )
            LOGGER.info("Registered inkitt routes")
        except Exception as inkitt_exc:
            LOGGER.warning("Inkitt routes not registered: %s", inkitt_exc)

        try:
            from .auth_professional import apply_professional_auth

            apply_professional_auth(main_mod)
            LOGGER.info("Professional auth hardening applied")
        except Exception as auth_exc:
            LOGGER.warning("Professional auth not applied: %s", auth_exc)

        try:
            mysql_compat.patch_execute_write(main_mod, db_mod.USE_SQLITE)
            LOGGER.info("Patched execute_write for lastrowid recovery")
        except Exception as ew_exc:
            LOGGER.warning("execute_write patch skipped: %s", ew_exc)


        # --- Wingsaga feature routes ---
        try:
            from .wingsaga_features import register_wingsaga_routes

            register_wingsaga_routes(
                main_mod.app,
                fetch_all=main_mod.fetch_all,
                execute_write=main_mod.execute_write,
                require_user=getattr(main_mod, "require_user", None),
                optional_user=getattr(main_mod, "optional_user", None),
                bump_content_version=getattr(main_mod, "bump_content_version", None),
                serialize_book=getattr(main_mod, "_serialize_book", None),
                use_sqlite=db_mod.USE_SQLITE,
            )
            LOGGER.info("Registered Wingsaga feature routes")
        except Exception as wf_exc:
            LOGGER.warning("Wingsaga routes not registered: %s", wf_exc)

        LOGGER.info(
            "Applied runtime patches (db_mode=%s)",
            "sqlite" if db_mod.USE_SQLITE else "mysql",
        )
    except Exception as exc:
        LOGGER.warning("Runtime patches not applied: %s", exc)


def run_startup_tasks() -> dict[str, Any]:
    result: dict[str, Any] = {
        "initialized": False,
        "migrations": {},
        "counts": {},
        "tags_seeded": 0,
        "tables_ensured": 0,
        "patches_applied": False,
        "db_mode": "sqlite" if USE_SQLITE else "mysql",
    }

    # Ensure MySQL is reachable when configured; otherwise fall back to SQLite.
    try:
        from . import database as db_mod
        from . import db_runtime

        probe_info = db_runtime.apply_mysql_fallback_if_needed(db_mod)
        result["db_mode"] = probe_info.get("db_mode", result["db_mode"])
        if probe_info.get("mysql_fallback_reason"):
            result["mysql_fallback_reason"] = probe_info["mysql_fallback_reason"]
    except Exception as probe_exc:
        LOGGER.warning("DB probe skipped: %s", probe_exc)

    initialized = initialize_database_if_needed()
    result["initialized"] = bool(initialized)

    migration_report = run_startup_migrations()
    result["migrations"] = migration_report

    try:
        conn = get_connection()
        result["tables_ensured"] = _ensure_mysql_extra_tables(conn)
        result["tags_seeded"] = _seed_tags(conn)
        for tbl in (
            "menu_items",
            "achievements",
            "reading_lists",
            "profiles",
            "write_screen",
            "tags",
            "books",
        ):
            result["counts"][tbl] = _query_count(conn, tbl)
        conn.close()
    except Exception as exc:
        LOGGER.exception("Failed after migrations: %s", exc)


    # Wingsaga schema + achievement seed (auto on every start)
    try:
        from .wingsaga_features import ensure_wingsaga_schema
        from . import main as main_mod
        from . import database as db_mod

        wingsaga_report = ensure_wingsaga_schema(
            main_mod.execute_write,
            main_mod.fetch_all,
            db_mod.USE_SQLITE,
        )
        result["wingsaga"] = wingsaga_report
        LOGGER.info("Wingsaga schema/seed: %s", wingsaga_report)
    except Exception as wingsaga_exc:
        LOGGER.warning("Wingsaga schema step skipped: %s", wingsaga_exc)

    try:
        _apply_runtime_patches()

        result["patches_applied"] = True
    except Exception as exc:
        LOGGER.exception("Patch step failed: %s", exc)

    LOGGER.info("Startup tasks finished: %s", result)
    return result

