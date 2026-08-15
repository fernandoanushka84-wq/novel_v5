"""
Wingsaga feature module — tables, seeds, and API routes for:
- Unique usernames
- Social media links + share profile
- Guest country recommendations
- Continue reading / Latest books
- Wingsaga writer achievements (20)
- Developer help / feature requests
- Reading progress tracking
All schema changes are idempotent and intended to run on backend startup.
"""
from __future__ import annotations

import logging
import re
from typing import Any, Callable

from fastapi import Depends, Header, HTTPException, Query, Request
from pydantic import BaseModel, Field

LOGGER = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Wingsaga writer achievements (exact titles from product requirements)
# ---------------------------------------------------------------------------
WINGSAGA_ACHIEVEMENTS = [
    # Easy
    ("Easy", 1, "First Flight", "පළමු පියාසරය — Publish the first chapter of the writer's first story.", "0/1", "1", "bronze", 1),
    ("Easy", 1, "Nest Building", "කූඩුව හැදීම — Complete the writer profile and gain the first follower.", "0/1", "1", "bronze", 2),
    ("Easy", 1, "Word Smith", "වචන ශිල්පපියා — Reach 10,000 total words across the writer's stories.", "0/10000", "10000", "bronze", 3),
    ("Easy", 1, "Gathering the Flock", "පිරිස එකතු කිරීම — Reach 50 followers.", "0/50", "50", "bronze", 4),
    # Medium
    ("Medium", 2, "Consistency King", "නනාබිඳුණු උත්සාහය — Publish at least one chapter every week for 4 consecutive weeks.", "0/4", "4", "silver", 1),
    ("Medium", 2, "Rising Feather", "නැගී එන පිහාටුව — Reach 250 followers.", "0/250", "250", "silver", 2),
    ("Medium", 2, "Cliffhanger Master", "කුතුහලනේ උපත — Receive more than 500 total comments across the writer's stories.", "0/500", "500", "silver", 3),
    ("Medium", 2, "Crowd Pleaser", "ජනප්‍රිය තරුව — Reach 1,000 followers.", "0/1000", "1000", "silver", 4),
    # Hard
    ("Hard", 3, "Page Turner", "පිටුනවන් පිටුවට — Have 1,000 readers complete a story from first to final chapter.", "0/1000", "1000", "gold", 1),
    ("Hard", 3, "The Novelist", "නවකතාකරු — Complete a single story after exceeding 50,000 words.", "0/50000", "50000", "gold", 2),
    ("Hard", 3, "Saga Influencer", "පුරාවෘත්ත බලපෑම්කරු — Reach 5,000 followers.", "0/5000", "5000", "gold", 3),
    ("Hard", 3, "Trendsetter", "කතානේ රැල්පල — Keep a story in Trending continuously for 7 days.", "0/7", "7", "gold", 4),
    # Very Hard
    ("Very Hard", 4, "Saga Architect", "පුරාවෘත්ත නිර්මාතෘ — Complete 5 stories on Wingsaga.", "0/5", "5", "dark", 1),
    ("Very Hard", 4, "The Cult Leader", "රසික හමුදාව — Reach 15,000 followers.", "0/15000", "15000", "dark", 2),
    ("Very Hard", 4, "Engaging Storyteller", "කතාබනහේ හිතවතා — Personally reply to 2,000 reader comments.", "0/2000", "2000", "dark", 3),
    ("Very Hard", 4, "Viral Pen", "පැතිනරන පෑන — Reach 100,000 reads on a single story.", "0/100000", "100000", "dark", 4),
    # Insane & Mythic
    ("Insane & Mythic", 5, "Grandmaster of Wings", "පියාපත්වල අධිපතියා — Reach 50,000 followers and qualify among top writers.", "0/50000", "50000", "mythic", 1),
    ("Insane & Mythic", 5, "Serial Writer", "නනානවතන යන්රය — For 90 consecutive days, write and update at least 500 words every day.", "0/90", "90", "mythic", 2),
    ("Insane & Mythic", 5, "Wingsaga Legend", "පියාපත්වල පුරාවෘත්තය — Reach 100,000 followers.", "0/100000", "100000", "mythic", 3),
    ("Insane & Mythic", 5, "Wingsaga Immortal", "නලෝක පූජිත නල්පඛකයා — Reach 1,000,000 total reads across all stories.", "0/1000000", "1000000", "mythic", 4),
]

# Country → preferred languages (guest recommendations)
COUNTRY_LANGUAGES = {
    "LK": ["Sinhala", "English", "Tamil"],
    "IN": ["English", "Hindi", "Tamil"],
    "JP": ["Japanese"],
    "US": ["English"],
    "GB": ["English"],
    "AU": ["English"],
    "CA": ["English", "French"],
    "SG": ["English", "Chinese", "Malay", "Tamil"],
    "MY": ["English", "Malay", "Chinese"],
    "BD": ["Bengali", "English"],
    "PK": ["Urdu", "English"],
    "NP": ["Nepali", "English"],
}

USERNAME_RE = re.compile(r"^[a-zA-Z0-9_]{3,30}$")


class UsernameSetRequest(BaseModel):
    username: str


class SocialLinksUpdateRequest(BaseModel):
    instagram: str | None = None
    twitter: str | None = None
    facebook: str | None = None
    tiktok: str | None = None
    youtube: str | None = None
    website: str | None = None


class FeatureRequestCreate(BaseModel):
    category: str = Field(default="feature")  # feature | bug | improvement
    title: str
    description: str
    email: str = ""


class ReadingProgressRequest(BaseModel):
    book_id: int
    chapter_number: int = 1
    progress_percent: int = 0


def _exec(execute_write: Callable, query: str, params: tuple = ()) -> Any:
    try:
        return execute_write(query, params)
    except Exception as exc:
        LOGGER.debug("wingsaga exec skipped: %s | %s", query[:80], exc)
        return None


def ensure_wingsaga_schema(execute_write: Callable, fetch_all: Callable, use_sqlite: bool) -> dict[str, int]:
    """Idempotent schema + seed for Wingsaga features. Called from startup."""
    report = {"tables": 0, "columns": 0, "achievements": 0}

    if use_sqlite:
        statements = [
            """CREATE TABLE IF NOT EXISTS user_social_links (
                user_id INTEGER PRIMARY KEY,
                instagram TEXT DEFAULT '',
                twitter TEXT DEFAULT '',
                facebook TEXT DEFAULT '',
                tiktok TEXT DEFAULT '',
                youtube TEXT DEFAULT '',
                website TEXT DEFAULT '',
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP
            )""",
            """CREATE TABLE IF NOT EXISTS feature_requests (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER,
                category TEXT NOT NULL DEFAULT 'feature',
                title TEXT NOT NULL,
                description TEXT NOT NULL,
                email TEXT DEFAULT '',
                status TEXT NOT NULL DEFAULT 'open',
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )""",
            """CREATE TABLE IF NOT EXISTS reading_progress (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                book_id INTEGER NOT NULL,
                chapter_number INTEGER NOT NULL DEFAULT 1,
                progress_percent INTEGER NOT NULL DEFAULT 0,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(user_id, book_id)
            )""",
            """CREATE TABLE IF NOT EXISTS user_achievements (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                achievement_title TEXT NOT NULL,
                unlocked_at TEXT DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(user_id, achievement_title)
            )""",
            """CREATE TABLE IF NOT EXISTS guest_preferences (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                cookie_key TEXT NOT NULL UNIQUE,
                country_code TEXT DEFAULT '',
                preferred_languages TEXT DEFAULT '',
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP
            )""",
        ]
    else:
        statements = [
            """CREATE TABLE IF NOT EXISTS user_social_links (
                user_id INT PRIMARY KEY,
                instagram VARCHAR(255) DEFAULT '',
                twitter VARCHAR(255) DEFAULT '',
                facebook VARCHAR(255) DEFAULT '',
                tiktok VARCHAR(255) DEFAULT '',
                youtube VARCHAR(255) DEFAULT '',
                website VARCHAR(255) DEFAULT '',
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )""",
            """CREATE TABLE IF NOT EXISTS feature_requests (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id INT NULL,
                category VARCHAR(40) NOT NULL DEFAULT 'feature',
                title VARCHAR(255) NOT NULL,
                description TEXT NOT NULL,
                email VARCHAR(255) DEFAULT '',
                status VARCHAR(40) NOT NULL DEFAULT 'open',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )""",
            """CREATE TABLE IF NOT EXISTS reading_progress (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id INT NOT NULL,
                book_id INT NOT NULL,
                chapter_number INT NOT NULL DEFAULT 1,
                progress_percent INT NOT NULL DEFAULT 0,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                UNIQUE KEY uq_rp (user_id, book_id)
            )""",
            """CREATE TABLE IF NOT EXISTS user_achievements (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id INT NOT NULL,
                achievement_title VARCHAR(120) NOT NULL,
                unlocked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY uq_ua (user_id, achievement_title)
            )""",
            """CREATE TABLE IF NOT EXISTS guest_preferences (
                id INT AUTO_INCREMENT PRIMARY KEY,
                cookie_key VARCHAR(64) NOT NULL UNIQUE,
                country_code VARCHAR(8) DEFAULT '',
                preferred_languages VARCHAR(255) DEFAULT '',
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )""",
        ]

    for sql in statements:
        before = report["tables"]
        try:
            execute_write(sql, ())
            report["tables"] += 1
        except Exception as exc:
            LOGGER.debug("table ensure: %s", exc)

    # username column on app_users (unique when set)
    for col_sql in (
        "ALTER TABLE app_users ADD COLUMN username VARCHAR(40) NULL",
        "ALTER TABLE app_users ADD COLUMN country_code VARCHAR(8) DEFAULT ''",
    ):
        try:
            execute_write(col_sql, ())
            report["columns"] += 1
        except Exception:
            pass

    # Seed Wingsaga achievements if missing
    for group_name, group_order, title, subtitle, progress_label, badge_value, style, sort_order in WINGSAGA_ACHIEVEMENTS:
        try:
            rows = fetch_all(
                "SELECT id FROM achievements WHERE title=%s LIMIT 1",
                (title,),
            )
            if not rows:
                execute_write(
                    """
                    INSERT INTO achievements
                    (group_name, group_order, title, subtitle, progress_label, badge_value, style, sort_order)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                    """,
                    (group_name, group_order, title, subtitle, progress_label, badge_value, style, sort_order),
                )
                report["achievements"] += 1
        except Exception as exc:
            LOGGER.debug("achievement seed %s: %s", title, exc)

    return report


def register_wingsaga_routes(
    app,
    *,
    fetch_all: Callable,
    execute_write: Callable,
    require_user: Callable,
    optional_user: Callable | None = None,
    bump_content_version: Callable | None = None,
    serialize_book: Callable | None = None,
    use_sqlite: bool = False,
) -> None:
    """Attach Wingsaga API endpoints to the FastAPI app."""

    def _normalize_username(raw: str) -> str:
        return (raw or "").strip().lstrip("@").lower()

    def _book_card(row: dict) -> dict:
        if serialize_book:
            return serialize_book(row)
        return dict(row) if isinstance(row, dict) else row

    # ---- Unique username ----
    @app.get("/api/username/check")
    def check_username(q: str = Query(default="")):
        name = _normalize_username(q)
        if not name:
            return {"available": False, "reason": "empty"}
        if not USERNAME_RE.match(name):
            return {
                "available": False,
                "reason": "invalid",
                "message": "Username must be 3–30 characters: letters, numbers, underscore only.",
            }
        rows = fetch_all(
            "SELECT id FROM app_users WHERE LOWER(username)=%s LIMIT 1",
            (name,),
        )
        if rows:
            return {"available": False, "reason": "taken", "message": "Username is already taken."}
        return {"available": True, "username": name}

    @app.put("/api/me/username")
    def set_my_username(
        payload: UsernameSetRequest,
        user: dict[str, Any] = Depends(require_user),
    ):
        name = _normalize_username(payload.username)
        if not USERNAME_RE.match(name):
            raise HTTPException(
                status_code=400,
                detail="Username must be 3–30 characters: letters, numbers, underscore only.",
            )
        taken = fetch_all(
            "SELECT id FROM app_users WHERE LOWER(username)=%s AND id!=%s LIMIT 1",
            (name, user["user_id"]),
        )
        if taken:
            raise HTTPException(status_code=409, detail="Username is already taken.")
        try:
            execute_write(
                "UPDATE app_users SET username=%s, updated_at=CURRENT_TIMESTAMP WHERE id=%s",
                (name, user["user_id"]),
            )
        except Exception as exc:
            # column may not exist yet on very old DBs
            LOGGER.warning("set username failed: %s", exc)
            raise HTTPException(status_code=500, detail="Could not set username. Restart backend to apply migrations.") from exc
        if bump_content_version:
            bump_content_version()
        return {"ok": True, "username": name}

    # ---- Social links ----
    @app.get("/api/users/{user_id}/social-links")
    def get_social_links(user_id: int):
        rows = fetch_all(
            "SELECT instagram, twitter, facebook, tiktok, youtube, website FROM user_social_links WHERE user_id=%s LIMIT 1",
            (user_id,),
        )
        if not rows:
            return {
                "instagram": "",
                "twitter": "",
                "facebook": "",
                "tiktok": "",
                "youtube": "",
                "website": "",
            }
        r = rows[0]
        return {
            "instagram": r.get("instagram") or "",
            "twitter": r.get("twitter") or "",
            "facebook": r.get("facebook") or "",
            "tiktok": r.get("tiktok") or "",
            "youtube": r.get("youtube") or "",
            "website": r.get("website") or "",
        }

    @app.put("/api/me/social-links")
    def update_my_social_links(
        payload: SocialLinksUpdateRequest,
        user: dict[str, Any] = Depends(require_user),
    ):
        existing = fetch_all(
            "SELECT user_id FROM user_social_links WHERE user_id=%s LIMIT 1",
            (user["user_id"],),
        )
        vals = (
            (payload.instagram or "").strip(),
            (payload.twitter or "").strip(),
            (payload.facebook or "").strip(),
            (payload.tiktok or "").strip(),
            (payload.youtube or "").strip(),
            (payload.website or "").strip(),
        )
        if existing:
            execute_write(
                """
                UPDATE user_social_links
                SET instagram=%s, twitter=%s, facebook=%s, tiktok=%s, youtube=%s, website=%s
                WHERE user_id=%s
                """,
                vals + (user["user_id"],),
            )
        else:
            execute_write(
                """
                INSERT INTO user_social_links
                (user_id, instagram, twitter, facebook, tiktok, youtube, website)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                """,
                (user["user_id"],) + vals,
            )
        return {"ok": True}

    @app.get("/api/users/{user_id}/share")
    def share_profile(user_id: int):
        """Public share payload for a profile URL."""
        rows = fetch_all(
            "SELECT id, display_name, username, photo_url, bio FROM app_users WHERE id=%s LIMIT 1",
            (user_id,),
        )
        if not rows:
            raise HTTPException(status_code=404, detail="User not found")
        u = rows[0]
        uname = (u.get("username") or u.get("display_name") or f"user{user_id}").lstrip("@")
        path = f"/u/{uname}"
        return {
            "user_id": user_id,
            "display_name": u.get("display_name") or uname,
            "username": uname,
            "photo_url": u.get("photo_url") or "",
            "bio": u.get("bio") or "",
            "share_path": path,
            "share_text": f"Check out {u.get('display_name') or uname} on Wingsaga!",
        }

    # ---- Guest location recommendations ----
    @app.get("/api/guest/recommendations")
    def guest_recommendations(request: Request, country: str = Query(default="")):
        """
        IP / query country → language-biased book list.
        Does not expose raw IP to clients.
        """
        code = (country or "").strip().upper()[:2]
        if not code:
            # Best-effort: some hosts set X-Country-Code / CF-IPCountry
            code = (
                request.headers.get("CF-IPCountry")
                or request.headers.get("X-Country-Code")
                or request.headers.get("X-Geo-Country")
                or ""
            ).upper()[:2]
        languages = COUNTRY_LANGUAGES.get(code, [])
        books = []
        try:
            if languages:
                # Prefer books whose genre / tags match language keywords (soft filter)
                rows = fetch_all(
                    """
                    SELECT id, user_id, title, author, description, cover_path, accent_hex,
                           status_text, rating, genre, section_name, cta_label
                    FROM books
                    WHERE LOWER(COALESCE(status_text, 'draft')) NOT IN ('draft', 'unpublished', 'private')
                    ORDER BY id DESC
                    LIMIT 60
                    """,
                )
                lang_lower = [l.lower() for l in languages]
                prioritized = []
                rest = []
                for row in rows or []:
                    blob = " ".join(
                        str(row.get(k) or "") for k in ("title", "description", "genre", "author")
                    ).lower()
                    if any(l in blob for l in lang_lower):
                        prioritized.append(row)
                    else:
                        rest.append(row)
                books = prioritized + rest
            else:
                books = fetch_all(
                    """
                    SELECT id, user_id, title, author, description, cover_path, accent_hex,
                           status_text, rating, genre, section_name, cta_label
                    FROM books
                    WHERE LOWER(COALESCE(status_text, 'draft')) NOT IN ('draft', 'unpublished', 'private')
                    ORDER BY id DESC
                    LIMIT 40
                    """,
                ) or []
        except Exception as exc:
            LOGGER.warning("guest recommendations failed: %s", exc)
            books = []

        return {
            "country_code": code or None,
            "languages": languages or ["English"],
            "items": [_book_card(b) for b in books[:30]],
        }

    # ---- Continue reading + Latest books ----
    @app.get("/api/home/continue-reading")
    def continue_reading(user: dict[str, Any] = Depends(require_user)):
        rows = fetch_all(
            """
            SELECT rp.book_id, rp.chapter_number, rp.progress_percent, rp.updated_at,
                   b.id, b.title, b.author, b.cover_path, b.accent_hex, b.genre, b.status_text, b.user_id
            FROM reading_progress rp
            JOIN books b ON b.id = rp.book_id
            WHERE rp.user_id=%s
              AND LOWER(COALESCE(b.status_text, 'draft')) NOT IN ('draft', 'unpublished', 'private')
            ORDER BY rp.updated_at DESC
            LIMIT 20
            """,
            (user["user_id"],),
        )
        # Fallback: library entries marked Reading
        if not rows:
            rows = fetch_all(
                """
                SELECT le.book_id, le.chapters AS chapter_number, 0 AS progress_percent,
                       b.id, b.title, b.author, b.cover_path, b.accent_hex, b.genre, b.status_text, b.user_id
                FROM library_entries le
                JOIN books b ON b.id = le.book_id
                WHERE le.user_id=%s
                  AND LOWER(le.reading_status) IN ('reading', 'in progress', 'current')
                ORDER BY le.id DESC
                LIMIT 20
                """,
                (user["user_id"],),
            )
        items = []
        for row in rows or []:
            card = _book_card(row)
            card["chapter_number"] = int(row.get("chapter_number") or 1)
            card["progress_percent"] = int(row.get("progress_percent") or 0)
            items.append(card)
        return {"items": items}

    @app.post("/api/home/reading-progress")
    def upsert_reading_progress(
        payload: ReadingProgressRequest,
        user: dict[str, Any] = Depends(require_user),
    ):
        pct = max(0, min(100, int(payload.progress_percent)))
        ch = max(1, int(payload.chapter_number))
        existing = fetch_all(
            "SELECT id FROM reading_progress WHERE user_id=%s AND book_id=%s LIMIT 1",
            (user["user_id"], payload.book_id),
        )
        if existing:
            execute_write(
                """
                UPDATE reading_progress
                SET chapter_number=%s, progress_percent=%s, updated_at=CURRENT_TIMESTAMP
                WHERE user_id=%s AND book_id=%s
                """,
                (ch, pct, user["user_id"], payload.book_id),
            )
        else:
            execute_write(
                """
                INSERT INTO reading_progress (user_id, book_id, chapter_number, progress_percent)
                VALUES (%s, %s, %s, %s)
                """,
                (user["user_id"], payload.book_id, ch, pct),
            )
        # Also keep library in sync
        try:
            lib = fetch_all(
                "SELECT id FROM library_entries WHERE user_id=%s AND book_id=%s LIMIT 1",
                (user["user_id"], payload.book_id),
            )
            if lib:
                execute_write(
                    "UPDATE library_entries SET reading_status=%s, chapters=%s WHERE id=%s",
                    ("Reading", ch, lib[0]["id"]),
                )
            else:
                execute_write(
                    """
                    INSERT INTO library_entries
                    (user_id, book_id, reading_status, updated_text, chapters, primary_genre, secondary_genre, sort_order)
                    VALUES (%s, %s, 'Reading', '', %s, '', '', 999)
                    """,
                    (user["user_id"], payload.book_id, ch),
                )
        except Exception:
            pass
        return {"ok": True}

    @app.get("/api/home/latest-books")
    def latest_books(limit: int = Query(default=20, ge=1, le=50)):
        rows = fetch_all(
            """
            SELECT id, user_id, title, author, description, cover_path, accent_hex,
                   status_text, rating, genre, section_name, cta_label
            FROM books
            WHERE LOWER(COALESCE(status_text, 'draft')) NOT IN ('draft', 'unpublished', 'private')
            ORDER BY id DESC
            LIMIT %s
            """,
            (limit,),
        )
        return {"items": [_book_card(r) for r in (rows or [])]}

    # ---- Developer Help / Feature requests ----
    @app.post("/api/developer-help")
    def create_feature_request(
        payload: FeatureRequestCreate,
        user: dict[str, Any] | None = Depends(optional_user) if optional_user else None,
    ):
        title = (payload.title or "").strip()
        description = (payload.description or "").strip()
        if not title or not description:
            raise HTTPException(status_code=400, detail="Title and description are required")
        category = (payload.category or "feature").strip().lower()
        if category not in ("feature", "bug", "improvement"):
            category = "feature"
        uid = user["user_id"] if user else None
        row_id, _ = execute_write(
            """
            INSERT INTO feature_requests (user_id, category, title, description, email, status)
            VALUES (%s, %s, %s, %s, %s, 'open')
            """,
            (uid, category, title, description, (payload.email or "").strip()),
        )
        return {"ok": True, "id": row_id}

    @app.get("/api/admin/developer-help")
    def list_feature_requests(
        status: str = Query(default=""),
        # admin auth is applied by caller wrapping if needed — use require_user fallback
    ):
        if status.strip():
            rows = fetch_all(
                """
                SELECT id, user_id, category, title, description, email, status, created_at
                FROM feature_requests WHERE LOWER(status)=LOWER(%s)
                ORDER BY created_at DESC, id DESC LIMIT 200
                """,
                (status.strip(),),
            )
        else:
            rows = fetch_all(
                """
                SELECT id, user_id, category, title, description, email, status, created_at
                FROM feature_requests
                ORDER BY created_at DESC, id DESC LIMIT 200
                """
            )
        return {"items": rows or []}

    # ---- Achievements for a writer ----
    @app.get("/api/users/{user_id}/writer-achievements")
    def writer_achievements(user_id: int):
        defs = fetch_all(
            """
            SELECT group_name, group_order, title, subtitle, progress_label, badge_value, style, sort_order
            FROM achievements
            WHERE group_name IN ('Easy', 'Medium', 'Hard', 'Very Hard', 'Insane & Mythic')
            ORDER BY group_order, sort_order
            """
        )
        unlocked_rows = fetch_all(
            "SELECT achievement_title, unlocked_at FROM user_achievements WHERE user_id=%s",
            (user_id,),
        )
        unlocked = {r["achievement_title"]: r.get("unlocked_at") for r in (unlocked_rows or [])}
        items = []
        for d in defs or []:
            title = d["title"]
            items.append({
                **d,
                "unlocked": title in unlocked,
                "unlocked_at": unlocked.get(title),
            })
        return {"items": items}

    LOGGER.info("Wingsaga feature routes registered")
