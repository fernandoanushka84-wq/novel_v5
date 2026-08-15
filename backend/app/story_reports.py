"""Story report routes: user report + admin list.

- POST /api/books/{book_id}/report  (auth) — one report per user per book
- GET  /api/admin/reports            (admin) — aggregated by book

After 3 unique reporters, flagged_for_admin becomes true.
"""
from __future__ import annotations

from typing import Any

from fastapi import Depends, HTTPException
from pydantic import BaseModel


class StoryReportCreateRequest(BaseModel):
    reason: str = ""


def register_story_report_routes(
    app,
    *,
    require_user,
    require_admin,
    fetch_all,
    execute_write,
    bump_content_version,
    LOGGER,
    USE_SQLITE: bool,
):
    def _ensure_story_reports_table() -> None:
        try:
            if USE_SQLITE:
                execute_write(
                    """
                    CREATE TABLE IF NOT EXISTS story_reports (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        book_id INTEGER NOT NULL,
                        user_id INTEGER NOT NULL,
                        reason TEXT NOT NULL DEFAULT '',
                        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                        UNIQUE(book_id, user_id)
                    )
                    """,
                    (),
                )
            else:
                execute_write(
                    """
                    CREATE TABLE IF NOT EXISTS story_reports (
                        id INT AUTO_INCREMENT PRIMARY KEY,
                        book_id INT NOT NULL,
                        user_id INT NOT NULL,
                        reason TEXT NOT NULL,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        UNIQUE KEY uq_story_report (book_id, user_id),
                        INDEX (book_id),
                        INDEX (user_id)
                    )
                    """,
                    (),
                )
        except Exception as exc:
            LOGGER.warning("story_reports ensure failed: %s", exc)

    @app.post("/api/books/{book_id}/report")
    def report_book(
        book_id: int,
        payload: StoryReportCreateRequest | None = None,
        user: dict[str, Any] = Depends(require_user),
    ):
        """Record a unique user report. Returns flagged_for_admin when count >= 3."""
        _ensure_story_reports_table()
        books = fetch_all("SELECT id FROM books WHERE id=%s LIMIT 1", (book_id,))
        if not books:
            raise HTTPException(status_code=404, detail="Book not found")

        reason = ""
        if payload is not None:
            reason = (payload.reason or "").strip()[:500]

        existing = fetch_all(
            "SELECT id FROM story_reports WHERE book_id=%s AND user_id=%s LIMIT 1",
            (book_id, user["user_id"]),
        )
        if not existing:
            try:
                if USE_SQLITE:
                    execute_write(
                        """
                        INSERT OR IGNORE INTO story_reports (book_id, user_id, reason)
                        VALUES (%s, %s, %s)
                        """,
                        (book_id, user["user_id"], reason),
                    )
                else:
                    execute_write(
                        """
                        INSERT IGNORE INTO story_reports (book_id, user_id, reason)
                        VALUES (%s, %s, %s)
                        """,
                        (book_id, user["user_id"], reason),
                    )
            except Exception as exc:
                LOGGER.warning("story_report insert failed: %s", exc)
                # Fallback without IGNORE
                try:
                    execute_write(
                        """
                        INSERT INTO story_reports (book_id, user_id, reason)
                        VALUES (%s, %s, %s)
                        """,
                        (book_id, user["user_id"], reason),
                    )
                except Exception:
                    pass  # likely unique conflict — treat as already reported

        count_rows = fetch_all(
            "SELECT COUNT(*) AS c FROM story_reports WHERE book_id=%s",
            (book_id,),
        )
        count = int(count_rows[0]["c"]) if count_rows else 0
        flagged = count >= 3
        try:
            bump_content_version()
        except Exception:
            pass
        return {
            "ok": True,
            "report_count": count,
            "flagged_for_admin": flagged,
            "already_reported": bool(existing),
        }

    @app.get("/api/admin/reports")
    def admin_list_story_reports(_: dict[str, Any] = Depends(require_admin)):
        """Aggregated reports per book for Admin → Reports."""
        _ensure_story_reports_table()
        rows = fetch_all(
            """
            SELECT r.book_id,
                   COUNT(*) AS report_count,
                   MAX(r.created_at) AS last_report_at,
                   b.title,
                   b.author,
                   b.status_text,
                   b.cover_path
            FROM story_reports r
            LEFT JOIN books b ON b.id = r.book_id
            GROUP BY r.book_id
            ORDER BY report_count DESC, last_report_at DESC
            LIMIT 200
            """
        )
        items = []
        for row in rows:
            items.append(
                {
                    "book_id": row.get("book_id"),
                    "report_count": int(row.get("report_count") or 0),
                    "last_report_at": str(row.get("last_report_at") or ""),
                    "title": row.get("title") or "",
                    "author": row.get("author") or "",
                    "status_text": row.get("status_text") or "",
                    "cover_path": row.get("cover_path") or "",
                    "flagged_for_admin": int(row.get("report_count") or 0) >= 3,
                }
            )
        return {"items": items}
