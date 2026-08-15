"""Runtime MySQL compatibility and tag/chapter helpers used by main.py."""
from __future__ import annotations

from typing import Any, Callable


def to_db_query(query: str, use_sqlite: bool) -> str:
    """Adapt SQL for SQLite vs MySQL (INSERT OR IGNORE -> INSERT IGNORE)."""
    if use_sqlite:
        return query.replace("%s", "?")
    q = query.replace("INSERT OR IGNORE", "INSERT IGNORE")
    q = q.replace("INSERT OR REPLACE", "REPLACE")
    return q


def set_story_tags(
    story_id: int,
    tag_names: list[str] | None,
    *,
    fetch_all: Callable,
    execute_write: Callable,
) -> None:
    """Attach up to 3 existing admin hashtags. Authors cannot invent tags."""
    if tag_names is None:
        return
    normalized = [n.strip().lstrip("#") for n in tag_names if n and str(n).strip()]
    if not normalized:
        execute_write("DELETE FROM book_tags WHERE book_id=%s", (story_id,))
        return
    normalized = normalized[:3]
    placeholders = ",".join(["%s"] * len(normalized))
    existing = fetch_all(
        f"SELECT id, name FROM tags WHERE name IN ({placeholders})",
        tuple(normalized),
    )
    tag_ids = [row["id"] for row in existing]
    execute_write("DELETE FROM book_tags WHERE book_id=%s", (story_id,))
    for tag_id in tag_ids:
        execute_write(
            "INSERT OR IGNORE INTO book_tags (book_id, tag_id) VALUES (%s, %s)",
            (story_id, tag_id),
        )


def patch_execute_write(main_mod, use_sqlite: bool) -> None:
    """Wrap main.execute_write so lastrowid is recovered on MySQL/SQLite."""
    original = main_mod.execute_write

    def execute_write(query: str, params: tuple = ()):
        last_id, affected = original(query, params)
        if not last_id and str(query).strip().upper().startswith("INSERT"):
            try:
                rows = main_mod.fetch_all(
                    "SELECT last_insert_rowid() AS id"
                    if use_sqlite
                    else "SELECT LAST_INSERT_ID() AS id"
                )
                if rows:
                    row = rows[0]
                    last_id = row["id"] if isinstance(row, dict) else row[0]
            except Exception:
                pass
        return last_id, affected

    main_mod.execute_write = execute_write  # type: ignore[attr-defined]
