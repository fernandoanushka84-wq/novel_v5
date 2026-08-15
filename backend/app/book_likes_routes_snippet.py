"""Add to main.py (or import from here).

Endpoints:
  GET    /api/books/{book_id}/like
  POST   /api/books/{book_id}/like
  DELETE /api/books/{book_id}/like

Table book_likes UNIQUE(user_id, book_id) — one like per user.
Also /api/me now counts followers from author_follows.
See novel_v2_changed_only.zip for full main.py + startup_tasks.py.
"""
