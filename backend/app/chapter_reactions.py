"""Chapter end reactions (Inkitt-style emoji grid).

- GET  /api/books/{book_id}/chapters/{chapter_number}/reactions
- POST /api/books/{book_id}/chapters/{chapter_number}/reactions  body {"label":"Funny"}
  toggles the reaction for the current user.
"""
from __future__ import annotations

from typing import Any

from fastapi import Depends, Header, HTTPException
from pydantic import BaseModel


class ChapterReactionRequest(BaseModel):
    label: str


def register_chapter_reaction_routes(
    app,
    *,
    require_user,
    fetch_all,
    execute_write,
    LOGGER,
    USE_SQLITE: bool,
):
    def _ensure_table() -> None:
        try:
            if USE_SQLITE:
                execute_write(
                    """
                    CREATE TABLE IF NOT EXISTS chapter_reactions (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        book_id INTEGER NOT NULL,
                        chapter_number INTEGER NOT NULL,
                        user_id INTEGER NOT NULL,
                        label TEXT NOT NULL,
                        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                        UNIQUE(book_id, chapter_number, user_id, label)
                    )
                    """,
                    (),
                )
            else:
                execute_write(
                    """
                    CREATE TABLE IF NOT EXISTS chapter_reactions (
                        id INT AUTO_INCREMENT PRIMARY KEY,
                        book_id INT NOT NULL,
                        chapter_number INT NOT NULL,
                        user_id INT NOT NULL,
                        label VARCHAR(64) NOT NULL,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        UNIQUE KEY uq_ch_react (book_id, chapter_number, user_id, label),
                        INDEX (book_id, chapter_number)
                    )
                    """,
                    (),
                )
        except Exception as exc:
            LOGGER.warning("chapter_reactions ensure failed: %s", exc)

    def _optional_user_id(authorization: str | None) -> int | None:
        if not authorization or not authorization.lower().startswith("bearer "):
            return None
        try:
            # Reuse require_user path by calling it is heavy; parse lightly via dependency when needed.
            return None
        except Exception:
            return None

    @app.get("/api/books/{book_id}/chapters/{chapter_number}/reactions")
    def list_chapter_reactions(
        book_id: int,
        chapter_number: int,
        authorization: str | None = Header(default=None),
    ):
        """Public counts + optional mine[] when Authorization bearer is valid."""
        _ensure_table()
        user_id = None
        if authorization and authorization.lower().startswith("bearer "):
            try:
                u = require_user(authorization)
                user_id = int(u["user_id"])
            except Exception:
                user_id = None

        rows = fetch_all(
            """
            SELECT label, COUNT(*) AS c
            FROM chapter_reactions
            WHERE book_id=%s AND chapter_number=%s
            GROUP BY label
            """,
            (book_id, chapter_number),
        )
        counts = {str(r["label"]): int(r["c"]) for r in rows}

        mine: list[str] = []
        if user_id is not None:
            mine_rows = fetch_all(
                """
                SELECT label FROM chapter_reactions
                WHERE book_id=%s AND chapter_number=%s AND user_id=%s
                """,
                (book_id, chapter_number, user_id),
            )
            mine = [str(r["label"]) for r in mine_rows]

        return {"counts": counts, "mine": mine, "total": sum(counts.values())}

    @app.post("/api/books/{book_id}/chapters/{chapter_number}/reactions")
    def toggle_chapter_reaction(
        book_id: int,
        chapter_number: int,
        payload: ChapterReactionRequest,
        user: dict[str, Any] = Depends(require_user),
    ):
        """Toggle a reaction label for the current user on this chapter."""
        _ensure_table()
        label = (payload.label or "").strip()
        if not label:
            raise HTTPException(status_code=400, detail="label required")
        if len(label) > 64:
            raise HTTPException(status_code=400, detail="label too long")

        existing = fetch_all(
            """
            SELECT id FROM chapter_reactions
            WHERE book_id=%s AND chapter_number=%s AND user_id=%s AND label=%s
            LIMIT 1
            """,
            (book_id, chapter_number, user["user_id"], label),
        )
        if existing:
            execute_write(
                """
                DELETE FROM chapter_reactions
                WHERE book_id=%s AND chapter_number=%s AND user_id=%s AND label=%s
                """,
                (book_id, chapter_number, user["user_id"], label),
            )
            selected = False
        else:
            if USE_SQLITE:
                execute_write(
                    """
                    INSERT OR IGNORE INTO chapter_reactions
                        (book_id, chapter_number, user_id, label)
                    VALUES (%s, %s, %s, %s)
                    """,
                    (book_id, chapter_number, user["user_id"], label),
                )
            else:
                execute_write(
                    """
                    INSERT IGNORE INTO chapter_reactions
                        (book_id, chapter_number, user_id, label)
                    VALUES (%s, %s, %s, %s)
                    """,
                    (book_id, chapter_number, user["user_id"], label),
                )
            selected = True

        count_rows = fetch_all(
            """
            SELECT COUNT(*) AS c FROM chapter_reactions
            WHERE book_id=%s AND chapter_number=%s AND label=%s
            """,
            (book_id, chapter_number, label),
        )
        count = int(count_rows[0]["c"]) if count_rows else 0
        return {"ok": True, "label": label, "selected": selected, "count": count}
