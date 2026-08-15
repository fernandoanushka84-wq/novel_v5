"""Extra tag/book routes registered at startup (avoids full main.py rewrite)."""
from __future__ import annotations

from fastapi import HTTPException


def register_extra_routes(app, *, fetch_all, fetch_one=None, execute_write=None, serialize_book=None):
    """Attach tag-related routes onto an existing FastAPI app."""

    def _fetch_one(query: str, params: tuple | None = None):
        if fetch_one is not None:
            return fetch_one(query, params)
        rows = fetch_all(query, params)
        if not rows:
            return None
        return rows[0]

    def _serialize(row):
        if serialize_book is not None:
            return serialize_book(row)
        if isinstance(row, dict):
            return row
        return dict(row)

    @app.get("/api/tags")
    def list_tags(q: str | None = None):
        if q and q.strip():
            rows = fetch_all(
                "SELECT id, name FROM tags WHERE name LIKE %s ORDER BY name LIMIT 50",
                (f"%{q.strip().lstrip('#')}%",),
            )
        else:
            rows = fetch_all("SELECT id, name FROM tags ORDER BY name LIMIT 200")
        items = []
        for row in rows:
            if isinstance(row, dict):
                items.append({"id": row.get("id"), "name": row.get("name")})
            else:
                items.append({"id": row[0], "name": row[1]})
        return {"items": items}

    @app.get("/api/tags/{tag_name}/books")
    def list_books_by_tag(tag_name: str):
        clean = tag_name.strip().lstrip("#")
        rows = fetch_all(
            """
            SELECT b.* FROM books b
            JOIN book_tags bt ON bt.book_id = b.id
            JOIN tags t ON t.id = bt.tag_id
            WHERE t.name = %s
            ORDER BY b.id DESC
            LIMIT 100
            """,
            (clean,),
        )
        return {"items": [_serialize(row) for row in rows], "tag": clean}

    @app.get("/api/books/{book_id}/public")
    def get_public_book(book_id: int):
        row = _fetch_one("SELECT * FROM books WHERE id=%s", (book_id,))
        if not row:
            raise HTTPException(status_code=404, detail="Book not found")
        book = _serialize(row)
        tag_rows = fetch_all(
            """
            SELECT t.name FROM tags t
            JOIN book_tags bt ON bt.tag_id = t.id
            WHERE bt.book_id = %s
            """,
            (book_id,),
        )
        tags = []
        for tr_row in tag_rows:
            if isinstance(tr_row, dict):
                tags.append(tr_row.get("name") or "")
            else:
                tags.append(tr_row[0] if tr_row else "")
        book["tags"] = [t for t in tags if t]
        return book
