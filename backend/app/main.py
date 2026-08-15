from collections import defaultdict
import base64
from datetime import datetime, timedelta, timezone
import hashlib
import hmac
import json
import logging
import os
import sqlite3
from pathlib import Path
from typing import Any
from urllib.parse import urlencode
from urllib.request import urlopen
from uuid import uuid4

from fastapi import Depends, FastAPI, File, Header, HTTPException, Query, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
try:
    import mysql.connector as mysql_connector
except ModuleNotFoundError:
    mysql_connector = None
from pydantic import BaseModel

from .database import (
    get_connection,
    USE_SQLITE,
)

DB_INIT_EXCEPTIONS = (sqlite3.Error, FileNotFoundError, OSError, ValueError)
if mysql_connector is not None:
    DB_INIT_EXCEPTIONS = (mysql_connector.Error, sqlite3.Error, FileNotFoundError, OSError, ValueError)

app = FastAPI(title="Novel Mobile Backend")
LOGGER = logging.getLogger(__name__)
UPLOAD_ROOT = Path(os.getenv("UPLOAD_DIR", "./uploads")).resolve()
JWT_SECRET = os.getenv("JWT_SECRET", "dev-secret-key-change-in-production")
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
ADMIN_USERNAME = os.getenv("ADMIN_USERNAME", "admin_Supun")
ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD", "Ux3@f=7x2")
ADMIN_TOKEN_EXPIRES_HOURS = int(os.getenv("ADMIN_TOKEN_EXPIRES_HOURS", "24"))
GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID", "")
# Support multiple acceptable client IDs via comma-separated env var for flexibility
# e.g. GOOGLE_CLIENT_IDS=android-client-id,web-client-id
GOOGLE_CLIENT_IDS = [s.strip() for s in os.getenv("GOOGLE_CLIENT_IDS", GOOGLE_CLIENT_ID).split(",") if s.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

UPLOAD_ROOT.mkdir(parents=True, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOAD_ROOT), name="uploads")


class LibraryCreateRequest(BaseModel):
    book_id: int
    reading_status: str
    updated_text: str = ""
    chapters: int = 0
    primary_genre: str = ""
    secondary_genre: str = ""


class LibraryUpdateRequest(BaseModel):
    reading_status: str | None = None
    updated_text: str | None = None
    chapters: int | None = None
    primary_genre: str | None = None
    secondary_genre: str | None = None


class ReadingListCreateRequest(BaseModel):
    name: str
    story_count: int = 0
    cover_path: str = ""
    sort_order: int = 999


class StoryCreateRequest(BaseModel):
    title: str
    author: str
    description: str
    genre: str
    cover_path: str = ""
    tags: list[str] = []
    content_warnings: str = ""
    status_text: str = "Draft"  # pass "Published" to auto-publish on create


class StoryUpdateRequest(BaseModel):
    title: str | None = None
    author: str | None = None
    description: str | None = None
    genre: str | None = None
    cover_path: str | None = None
    tags: list[str] | None = None
    content_warnings: str | None = None
    status_text: str | None = None


class ReviewCreateRequest(BaseModel):
    rating: int
    comment: str = ""


class ChapterCommentCreateRequest(BaseModel):
    body: str


class ChapterCreateRequest(BaseModel):
    title: str
    content: str
    chapter_number: int | None = None
    notes: str | None = None
    submission_status: str | None = None
    scheduled_for: str | None = None


class ChapterUpdateRequest(BaseModel):
    title: str | None = None
    content: str | None = None
    chapter_number: int | None = None
    notes: str | None = None
    submission_status: str | None = None
    scheduled_for: str | None = None


class ProfileUpdateRequest(BaseModel):
    display_name: str | None = None
    photo_url: str | None = None
    cover_url: str | None = None
    bio: str | None = None


class CategoryCreateRequest(BaseModel):
    name: str
    topic_count: int = 0
    tab_group: str
    sort_order: int = 0


class CategoryUpdateRequest(BaseModel):
    name: str | None = None
    topic_count: int | None = None
    tab_group: str | None = None
    sort_order: int | None = None


class AdminBookCreateRequest(BaseModel):
    title: str
    author: str
    description: str
    cover_path: str = ""
    accent_hex: str = "#808080"
    section_name: str = "recently_updated"
    status_text: str = "Draft"
    rating: float = 0.0
    genre: str = ""
    cta_label: str = "Read now"
    sort_order: int = 999


class AdminBookUpdateRequest(BaseModel):
    title: str | None = None
    author: str | None = None
    description: str | None = None
    cover_path: str | None = None
    accent_hex: str | None = None
    section_name: str | None = None
    status_text: str | None = None
    rating: float | None = None
    genre: str | None = None
    cta_label: str | None = None
    sort_order: int | None = None


class AdminNotificationCreateRequest(BaseModel):
    tab_name: str
    title: str
    message: str
    created_at: str
    sort_order: int = 999


class AdminNotificationUpdateRequest(BaseModel):
    tab_name: str | None = None
    title: str | None = None
    message: str | None = None
    created_at: str | None = None
    sort_order: int | None = None


class AdminMenuItemCreateRequest(BaseModel):
    section_name: str
    section_order: int
    label: str
    icon_name: str
    route_name: str
    sort_order: int = 999


class AdminMenuItemUpdateRequest(BaseModel):
    section_name: str | None = None
    section_order: int | None = None
    label: str | None = None
    icon_name: str | None = None
    route_name: str | None = None
    sort_order: int | None = None


class AdminWriteScreenUpdateRequest(BaseModel):
    manage_tabs: str
    story_tabs: str
    filter_label: str
    sort_label: str
    empty_title: str
    empty_cta: str


class AdminProfileUpdateRequest(BaseModel):
    display_name: str
    username: str
    following: int
    followers: int
    blocked: int
    chapters_read: int
    social_karma: int
    day_streak: int


class AdminReadingListCreateRequest(BaseModel):
    profile_id: int = 1
    name: str
    story_count: int = 0
    cover_path: str = ""
    sort_order: int = 999


class AdminReadingListUpdateRequest(BaseModel):
    profile_id: int | None = None
    name: str | None = None
    story_count: int | None = None
    cover_path: str | None = None
    sort_order: int | None = None


class AdminAchievementCreateRequest(BaseModel):
    group_name: str
    group_order: int
    title: str
    subtitle: str
    progress_label: str
    badge_value: str
    style: str
    sort_order: int = 999


class AdminAchievementUpdateRequest(BaseModel):
    group_name: str | None = None
    group_order: int | None = None
    title: str | None = None
    subtitle: str | None = None
    progress_label: str | None = None
    badge_value: str | None = None
    style: str | None = None
    sort_order: int | None = None


class AdminLoginRequest(BaseModel):
    username: str
    password: str


class SupportRequestCreateRequest(BaseModel):
    email: str
    first_name: str
    issue: str
    subject: str
    description: str
    device_type: str = ""
    attachment_path: str = ""


class SupportRequestUpdateRequest(BaseModel):
    status: str


class GoogleAuthRequest(BaseModel):
    id_token: str | None = None
    access_token: str | None = None


class EmailAuthRequest(BaseModel):
    email: str
    display_name: str = ""


class GuestAuthRequest(BaseModel):
    pass


class ChatMessageCreateRequest(BaseModel):
    message: str
    sender: str = "user"


class VersionResponse(BaseModel):
    value: str
    updated_at: str | None = None


def _to_db_query(query: str) -> str:
    """Adapt SQL for the active DB dialect (SQLite vs MySQL)."""
    if USE_SQLITE:
        return query.replace("%s", "?")
    # MySQL uses INSERT IGNORE, not SQLite's INSERT OR IGNORE
    q = query.replace("INSERT OR IGNORE", "INSERT IGNORE")
    q = q.replace("INSERT OR REPLACE", "REPLACE")
    return q


def fetch_all(query: str, params: tuple[Any, ...] | None = None):
    connection = get_connection()
    cursor = connection.cursor(dictionary=True) if not USE_SQLITE else connection.cursor()
    cursor.execute(_to_db_query(query), params or ())
    rows = cursor.fetchall()
    cursor.close()
    connection.close()
    return rows


def execute_write(query: str, params: tuple[Any, ...]):
    connection = get_connection()
    cursor = connection.cursor()
    try:
        cursor.execute(_to_db_query(query), params)
        connection.commit()
        last_id = cursor.lastrowid
        affected = cursor.rowcount
        # MySQL/SQLite: if lastrowid is 0/None after INSERT, try dialect helpers
        if not last_id and query.strip().upper().startswith("INSERT"):
            try:
                from .database import USE_SQLITE
                if USE_SQLITE:
                    cursor.execute("SELECT last_insert_rowid()")
                else:
                    cursor.execute("SELECT LAST_INSERT_ID()")
                row = cursor.fetchone()
                if row is not None:
                    last_id = row[0] if not isinstance(row, dict) else next(iter(row.values()))
            except Exception:
                pass
        return last_id, affected
    except Exception:
        try:
            connection.rollback()
        except Exception:
            pass
        raise
    finally:
        try:
            cursor.close()
        except Exception:
            pass
        try:
            connection.close()
        except Exception:
            pass


def _serialize_db_datetime(value: Any) -> str | None:
    if value is None:
        return None
    if isinstance(value, str):
        return value
    if hasattr(value, "isoformat"):
        return value.isoformat()
    return str(value)


def _content_version_row() -> dict[str, Any]:
    rows = fetch_all(
        "SELECT key_value, updated_at FROM app_metadata WHERE key_name='content_version' LIMIT 1"
    )
    if rows:
        row = rows[0]
        return {
            "value": row["key_value"],
            "updated_at": _serialize_db_datetime(row["updated_at"]),
        }

    value = str(uuid4())
    execute_write(
        "INSERT INTO app_metadata (key_name, key_value) VALUES ('content_version', %s)",
        (value,),
    )
    return {"value": value, "updated_at": None}


def bump_content_version() -> dict[str, Any]:
    value = str(uuid4())
    connection = get_connection()
    cursor = connection.cursor()
    if USE_SQLITE:
        cursor.execute(
            """
            INSERT INTO app_metadata (key_name, key_value)
            VALUES ('content_version', ?)
            ON CONFLICT(key_name) DO UPDATE SET key_value = excluded.key_value
            """,
            (value,),
        )
    else:
        cursor.execute(
            """
            INSERT INTO app_metadata (key_name, key_value)
            VALUES ('content_version', %s)
            ON DUPLICATE KEY UPDATE key_value = VALUES(key_value)
            """,
            (value,),
        )
    connection.commit()
    cursor.close()
    connection.close()
    return _content_version_row()


def create_admin_token(username: str) -> str:
    expires_at = datetime.now(timezone.utc) + timedelta(hours=ADMIN_TOKEN_EXPIRES_HOURS)
    payload = {
        "sub": username,
        "role": "admin",
        "exp": expires_at.isoformat(),
    }
    encoded_payload = base64.urlsafe_b64encode(
        json.dumps(payload, separators=(",", ":")).encode("utf-8")
    ).decode("ascii")
    signature = hmac.new(
        JWT_SECRET.encode("utf-8"),
        encoded_payload.encode("ascii"),
        hashlib.sha256,
    ).hexdigest()
    return f"{encoded_payload}.{signature}"


def require_admin(authorization: str | None = Header(default=None)) -> dict[str, Any]:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing admin token")

    token = authorization.split(" ", 1)[1].strip()
    if not token:
        raise HTTPException(status_code=401, detail="Missing admin token")

    try:
        encoded_payload, provided_signature = token.split(".", 1)
    except ValueError as exc:
        raise HTTPException(status_code=401, detail="Invalid admin token") from exc

    expected_signature = hmac.new(
        JWT_SECRET.encode("utf-8"),
        encoded_payload.encode("ascii"),
        hashlib.sha256,
    ).hexdigest()
    if not hmac.compare_digest(expected_signature, provided_signature):
        raise HTTPException(status_code=401, detail="Invalid admin token")

    try:
        payload = json.loads(
            base64.urlsafe_b64decode(encoded_payload.encode("ascii")).decode("utf-8")
        )
    except (ValueError, json.JSONDecodeError) as exc:
        raise HTTPException(status_code=401, detail="Invalid admin token") from exc

    if payload.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Admin role required")

    expires_raw = payload.get("exp")
    if not isinstance(expires_raw, str):
        raise HTTPException(status_code=401, detail="Invalid admin token")

    try:
        expires_at = datetime.fromisoformat(expires_raw)
    except ValueError as exc:
        raise HTTPException(status_code=401, detail="Invalid admin token") from exc

    if expires_at <= datetime.now(timezone.utc):
        raise HTTPException(status_code=401, detail="Admin token expired")

    return payload


def _sign_token(payload: dict[str, Any]) -> str:
    encoded_payload = base64.urlsafe_b64encode(
        json.dumps(payload, separators=(",", ":")).encode("utf-8")
    ).decode("ascii")
    signature = hmac.new(
        JWT_SECRET.encode("utf-8"),
        encoded_payload.encode("ascii"),
        hashlib.sha256,
    ).hexdigest()
    return f"{encoded_payload}.{signature}"


def create_user_token(user_id: int) -> str:
    expires_at = datetime.now(timezone.utc) + timedelta(days=180)
    return _sign_token(
        {
            "sub": f"user:{user_id}",
            "role": "user",
            "exp": expires_at.isoformat(),
        }
    )




def _ensure_wall_posts_table() -> None:
    """Dedicated wall posts (profile Wall tab). Soft schema; never drops data."""
    try:
        execute_write(
            """
            CREATE TABLE IF NOT EXISTS wall_posts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                target_user_id INTEGER NOT NULL,
                body TEXT NOT NULL,
                image_path TEXT DEFAULT '',
                likes_count INTEGER NOT NULL DEFAULT 0,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
            """,
            (),
        )
    except Exception:
        # MySQL / Postgres variants
        try:
            execute_write(
                """
                CREATE TABLE IF NOT EXISTS wall_posts (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    user_id INT NOT NULL,
                    target_user_id INT NOT NULL,
                    body TEXT NOT NULL,
                    image_path VARCHAR(512) DEFAULT '',
                    likes_count INT NOT NULL DEFAULT 0,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
                """,
                (),
            )
        except Exception:
            pass

def _ensure_user_moderation_columns() -> None:
    """Soft-moderation flags: never hard-delete user rows."""
    for col_sql in (
        "ALTER TABLE app_users ADD COLUMN is_banned INT NOT NULL DEFAULT 0",
        "ALTER TABLE app_users ADD COLUMN is_suspended INT NOT NULL DEFAULT 0",
        "ALTER TABLE app_users ADD COLUMN is_deleted INT NOT NULL DEFAULT 0",
        "ALTER TABLE app_users ADD COLUMN suspended_until TEXT NULL",
        "ALTER TABLE app_users ADD COLUMN is_author_active INT NOT NULL DEFAULT 1",
    ):
        try:
            execute_write(col_sql, ())
        except Exception:
            pass



def _assert_user_can_login(user_id: int) -> None:
    reason = _user_access_block_reason(user_id)
    if reason:
        raise HTTPException(status_code=403, detail=reason)

def _user_access_block_reason(user_id: int) -> str | None:
    """Return human-readable block reason, or None if user may log in."""
    _ensure_user_moderation_columns()
    rows = fetch_all(
        """
        SELECT COALESCE(is_banned,0) AS is_banned,
               COALESCE(is_suspended,0) AS is_suspended,
               COALESCE(is_deleted,0) AS is_deleted,
               suspended_until
        FROM app_users WHERE id=%s LIMIT 1
        """,
        (user_id,),
    )
    if not rows:
        return "Account not found"
    row = rows[0]
    if int(_row_get(row, "is_deleted") or 0) == 1:
        return "This account has been deleted by an administrator"
    if int(_row_get(row, "is_banned") or 0) == 1:
        return "This account is banned. Contact support or wait for an unban."
    if int(_row_get(row, "is_suspended") or 0) == 1:
        until = _row_get(row, "suspended_until")
        if until:
            try:
                from datetime import datetime, timezone
                u = str(until).replace("Z", "+00:00")
                until_dt = datetime.fromisoformat(u)
                now = datetime.now(timezone.utc)
                if until_dt.tzinfo is None:
                    until_dt = until_dt.replace(tzinfo=timezone.utc)
                if now < until_dt:
                    return f"Account suspended until {until_dt.isoformat()}"
                # auto-lift expired suspension
                execute_write(
                    "UPDATE app_users SET is_suspended=0, suspended_until=NULL WHERE id=%s",
                    (user_id,),
                )
            except Exception:
                return "This account is temporarily suspended"
        else:
            return "This account is temporarily suspended"
    return None


def require_user(authorization: str | None = Header(default=None)) -> dict[str, Any]:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing user token")

    token = authorization.split(" ", 1)[1].strip()
    if not token:
        raise HTTPException(status_code=401, detail="Missing user token")

    try:
        encoded_payload, provided_signature = token.split(".", 1)
    except ValueError as exc:
        raise HTTPException(status_code=401, detail="Invalid user token") from exc

    expected_signature = hmac.new(
        JWT_SECRET.encode("utf-8"),
        encoded_payload.encode("ascii"),
        hashlib.sha256,
    ).hexdigest()
    if not hmac.compare_digest(expected_signature, provided_signature):
        raise HTTPException(status_code=401, detail="Invalid user token")

    try:
        payload = json.loads(
            base64.urlsafe_b64decode(encoded_payload.encode("ascii")).decode("utf-8")
        )
    except (ValueError, json.JSONDecodeError) as exc:
        raise HTTPException(status_code=401, detail="Invalid user token") from exc

    if payload.get("role") != "user":
        raise HTTPException(status_code=403, detail="User role required")

    sub = payload.get("sub")
    if not isinstance(sub, str) or not sub.startswith("user:"):
        raise HTTPException(status_code=401, detail="Invalid user token")

    expires_raw = payload.get("exp")
    if not isinstance(expires_raw, str):
        raise HTTPException(status_code=401, detail="Invalid user token")

    try:
        expires_at = datetime.fromisoformat(expires_raw)
    except ValueError as exc:
        raise HTTPException(status_code=401, detail="Invalid user token") from exc

    if expires_at <= datetime.now(timezone.utc):
        raise HTTPException(status_code=401, detail="User token expired")

    uid = int(sub.split(":", 1)[1])
    reason = _user_access_block_reason(uid)
    if reason:
        raise HTTPException(status_code=403, detail=reason)
    return {"user_id": uid}


def optional_user(authorization: str | None = Header(default=None)) -> dict[str, Any] | None:
    """Like require_user but returns None instead of 401 when no/invalid token.
    Used for public endpoints that enrich response when the caller is logged in.
    """
    if not authorization or not authorization.lower().startswith("bearer "):
        return None
    token = authorization.split(" ", 1)[1].strip()
    if not token:
        return None
    try:
        encoded_payload, provided_signature = token.split(".", 1)
    except ValueError:
        return None
    expected_signature = hmac.new(
        JWT_SECRET.encode("utf-8"),
        encoded_payload.encode("ascii"),
        hashlib.sha256,
    ).hexdigest()
    if not hmac.compare_digest(expected_signature, provided_signature):
        return None
    try:
        payload = json.loads(
            base64.urlsafe_b64decode(encoded_payload.encode("ascii")).decode("utf-8")
        )
    except (ValueError, json.JSONDecodeError):
        return None
    if payload.get("role") != "user":
        return None
    sub = payload.get("sub")
    if not isinstance(sub, str) or not sub.startswith("user:"):
        return None
    expires_raw = payload.get("exp")
    if not isinstance(expires_raw, str):
        return None
    try:
        expires_at = datetime.fromisoformat(expires_raw)
    except ValueError:
        return None
    if expires_at <= datetime.now(timezone.utc):
        return None
    try:
        uid = int(sub.split(":", 1)[1])
    except (ValueError, IndexError):
        return None
    reason = _user_access_block_reason(uid)
    if reason:
        return None
    return {"user_id": uid}


def _public_image_path(filename: str) -> str:
    return f"/uploads/{filename}"


def _normalize_cover_path(path: str | None) -> str:
    if not path:
        return ""
    raw = str(path).strip()
    if not raw:
        return ""
    if raw.startswith(("http://", "https://")):
        return raw
    # Already a public uploads path
    if raw.startswith("/uploads/"):
        return raw
    # Legacy: story_card_images/... or assets/story_card_images/...
    if "story_card_images/" in raw:
        return _public_image_path(raw.split("/")[-1])
    # Bare filename or uploads/filename without leading slash
    if "/" not in raw or raw.startswith("uploads/"):
        return _public_image_path(raw.split("/")[-1])
    return raw


def _ensure_default_write_screen() -> None:
    rows = fetch_all("SELECT id FROM write_screen LIMIT 1")
    if not rows:
        execute_write(
            "INSERT INTO write_screen (manage_tabs, story_tabs, filter_label, sort_label, empty_title, empty_cta) VALUES (%s, %s, %s, %s, %s, %s)",
            (
                "Drafts,Published",
                "Stories,Series",
                "Filter",
                "Sort",
                "Nothing here yet",
                "Create story",
            ),
        )


def _ensure_default_profile() -> None:
    rows = fetch_all("SELECT id FROM profiles LIMIT 1")
    if not rows:
        execute_write(
            "INSERT INTO profiles (display_name, username, following, followers, blocked, chapters_read, social_karma, day_streak) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
            ("Guest User", "guest", 0, 0, 0, 0, 0, 0),
        )


def _available_story_images() -> list[dict[str, str]]:
    items: list[dict[str, str]] = []
    for file_path in sorted(UPLOAD_ROOT.glob("*")):
        if not file_path.is_file():
            continue
        extension = file_path.suffix.lower()
        if extension not in {".jpg", ".jpeg", ".png", ".webp"}:
            continue
        items.append(
            {
                "name": file_path.name,
                "path": _public_image_path(file_path.name),
            }
        )
    return items


def _fetch_google_json(endpoint: str, query: dict[str, str]) -> dict[str, Any]:
    url = f"{endpoint}?{urlencode(query)}"
    with urlopen(url, timeout=10) as response:
        return json.loads(response.read().decode("utf-8"))


def _verify_google_payload(payload: GoogleAuthRequest) -> dict[str, Any]:
    """Verify Google id_token or access_token.

    If GOOGLE_CLIENT_IDS is empty, audience is not enforced (dev-friendly).
    Set GOOGLE_CLIENT_ID or GOOGLE_CLIENT_IDS in production to lock audiences.
    """
    def _check_audience(audience: str, token_info: dict[str, Any]) -> None:
        if not GOOGLE_CLIENT_IDS:
            LOGGER.warning(
                "GOOGLE_CLIENT_ID(s) not set — accepting Google token without audience check (dev mode). "
                "Set GOOGLE_CLIENT_IDS in backend .env for production."
            )
            return
        if audience and audience not in GOOGLE_CLIENT_IDS:
            LOGGER.warning(
                "Google audience mismatch: aud=%s allowed=%s tokeninfo=%s",
                audience,
                GOOGLE_CLIENT_IDS,
                token_info,
            )
            raise HTTPException(
                status_code=401,
                detail=(
                    "Google audience mismatch. Add this client ID to GOOGLE_CLIENT_IDS on the backend: "
                    f"{audience or '(empty)'}"
                ),
            )

    if payload.id_token:
        try:
            token_info = _fetch_google_json(
                "https://oauth2.googleapis.com/tokeninfo",
                {"id_token": payload.id_token},
            )
        except Exception as exc:
            LOGGER.exception("Google id_token verification failed")
            raise HTTPException(
                status_code=401,
                detail=f"Google id_token verification failed: {exc}",
            ) from exc
        LOGGER.debug("Google tokeninfo (id_token): %s", token_info)
        if token_info.get("error"):
            raise HTTPException(
                status_code=401,
                detail=f"Invalid Google id_token: {token_info.get('error_description') or token_info.get('error')}",
            )
        audience = (
            token_info.get("aud")
            or token_info.get("audience")
            or token_info.get("issued_to")
            or ""
        )
        _check_audience(str(audience), token_info)

        email = token_info.get("email", "")
        subject = token_info.get("sub", "")
        if not email or not subject:
            raise HTTPException(status_code=401, detail="Invalid Google token (missing email/sub)")

        return {
            "email": email,
            "subject": subject,
            "display_name": token_info.get("name") or email.split("@")[0],
            "photo_url": token_info.get("picture") or "",
        }

    if payload.access_token:
        try:
            token_info = _fetch_google_json(
                "https://oauth2.googleapis.com/tokeninfo",
                {"access_token": payload.access_token},
            )
        except Exception as exc:
            LOGGER.exception("Google access_token verification failed")
            raise HTTPException(
                status_code=401,
                detail=f"Google access_token verification failed: {exc}",
            ) from exc
        LOGGER.debug("Google tokeninfo (access_token): %s", token_info)
        audience = (
            token_info.get("aud")
            or token_info.get("audience")
            or token_info.get("issued_to")
            or ""
        )
        _check_audience(str(audience), token_info)

        try:
            user_info = _fetch_google_json(
                "https://www.googleapis.com/oauth2/v2/userinfo",
                {"access_token": payload.access_token},
            )
        except Exception as exc:
            LOGGER.exception("Google userinfo failed")
            raise HTTPException(
                status_code=401,
                detail=f"Google userinfo failed: {exc}",
            ) from exc
        LOGGER.debug("Google userinfo: %s", user_info)
        email = user_info.get("email", "")
        subject = user_info.get("id", "") or token_info.get("sub", "")
        if not email or not subject:
            raise HTTPException(status_code=401, detail="Invalid Google token (missing email/id)")

        return {
            "email": email,
            "subject": subject,
            "display_name": user_info.get("name") or email.split("@")[0],
            "photo_url": user_info.get("picture") or "",
        }

    raise HTTPException(
        status_code=400,
        detail="Missing Google token. App must send id_token or access_token from Google Sign-In.",
    )


def _parse_optional_datetime(value: str | None) -> datetime | None:
    if value is None or value.strip() == "":
        return None
    normalized = value.strip().replace("Z", "+00:00")
    try:
        return datetime.fromisoformat(normalized)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Invalid scheduled date") from exc


def _serialize_datetime(value: datetime | str | None) -> str | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.isoformat()
    return str(value)


def _record_chapter_revision(
    chapter_id: int,
    title: str,
    content: str,
    notes: str,
    submission_status: str,
    scheduled_for: datetime | None,
) -> None:
    scheduled_value = scheduled_for.isoformat() if isinstance(scheduled_for, datetime) else scheduled_for
    execute_write(
        """
        INSERT INTO chapter_revisions (chapter_id, title, content, notes, submission_status, scheduled_for)
        VALUES (%s, %s, %s, %s, %s, %s)
        """,
        (chapter_id, title, content, notes, submission_status, scheduled_value),
    )


@app.get("/")
def healthcheck():
    return {"message": "Novel Mobile backend is running."}


@app.on_event("startup")
def startup_initialize_database():
    try:
        # Delegate startup tasks (schema init, migrations, seeding, basic checks)
        from .startup_tasks import run_startup_tasks

        summary = run_startup_tasks()
        LOGGER.info("Startup tasks summary: %s", summary)
        _content_version_row()
    except DB_INIT_EXCEPTIONS as exc:
        LOGGER.exception("Automatic database initialization failed: %s", exc)
    except Exception as exc:
        LOGGER.exception("Unexpected error running startup tasks: %s", exc)


@app.get("/api/content/version", response_model=VersionResponse)
def get_content_version():
    return _content_version_row()


@app.post("/api/admin/login")
def admin_login(payload: AdminLoginRequest):
    if payload.username != ADMIN_USERNAME or payload.password != ADMIN_PASSWORD:
        raise HTTPException(status_code=401, detail="Invalid admin credentials")

    token = create_admin_token(payload.username)
    return {
        "token": token,
        "username": payload.username,
        "expires_in_hours": ADMIN_TOKEN_EXPIRES_HOURS,
    }


@app.post("/api/auth/google")
def authenticate_google(payload: GoogleAuthRequest):
    google_user = _verify_google_payload(payload)
    rows = fetch_all("SELECT id FROM app_users WHERE email=%s LIMIT 1", (google_user["email"],))

    if rows:
        user_id = rows[0]["id"]
        execute_write(
            """
            UPDATE app_users
            SET provider=%s, provider_subject=%s, display_name=%s, photo_url=%s, last_login_at=CURRENT_TIMESTAMP
            WHERE id=%s
            """,
            (
                "google",
                google_user["subject"],
                google_user["display_name"],
                google_user["photo_url"],
                user_id,
            ),
        )
    else:
        user_id, _ = execute_write(
            """
            INSERT INTO app_users (email, provider, provider_subject, display_name, photo_url)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (
                google_user["email"],
                "google",
                google_user["subject"],
                google_user["display_name"],
                google_user["photo_url"],
            ),
        )

    _assert_user_can_login(user_id)
    return {
        "id": user_id,
        "email": google_user["email"],
        "display_name": google_user["display_name"],
        "photo_url": google_user["photo_url"],
        "provider": "google",
        "token": create_user_token(user_id),
    }


@app.post("/api/auth/email")
def authenticate_email(payload: EmailAuthRequest):
    email = payload.email.strip()
    if not email or "@" not in email:
        raise HTTPException(status_code=400, detail="Invalid email")

    display_name = (payload.display_name or "").strip() or email.split("@")[0]
    rows = fetch_all("SELECT id FROM app_users WHERE email=%s LIMIT 1", (email,))
    if rows:
        user_id = rows[0]["id"]
        execute_write(
            """
            UPDATE app_users
            SET provider='email', display_name=%s, last_login_at=CURRENT_TIMESTAMP
            WHERE id=%s
            """,
            (display_name, user_id),
        )
    else:
        user_id, _ = execute_write(
            """
            INSERT INTO app_users (email, provider, display_name, photo_url)
            VALUES (%s, 'email', %s, '')
            """,
            (email, display_name),
        )

    _assert_user_can_login(user_id)
    return {
        "id": user_id,
        "email": email,
        "display_name": display_name,
        "photo_url": "",
        "provider": "email",
        "token": create_user_token(user_id),
    }


@app.post("/api/auth/guest")
def authenticate_guest(_: GuestAuthRequest):
    email = "guest@novel.app"
    display_name = "Guest"
    rows = fetch_all("SELECT id FROM app_users WHERE email=%s LIMIT 1", (email,))
    if rows:
        user_id = rows[0]["id"]
        execute_write(
            """
            UPDATE app_users
            SET provider='guest', display_name=%s, last_login_at=CURRENT_TIMESTAMP
            WHERE id=%s
            """,
            (display_name, user_id),
        )
    else:
        user_id, _ = execute_write(
            """
            INSERT INTO app_users (email, provider, display_name, photo_url)
            VALUES (%s, 'guest', %s, '')
            """,
            (email, display_name),
        )

    _assert_user_can_login(user_id)
    return {
        "id": user_id,
        "email": email,
        "display_name": display_name,
        "photo_url": "",
        "provider": "guest",
        "token": create_user_token(user_id),
    }


@app.get("/api/me")
def get_me(user: dict[str, Any] = Depends(require_user)):
    rows = fetch_all(
        "SELECT id, email, display_name, photo_url, cover_url, bio, provider FROM app_users WHERE id=%s LIMIT 1",
        (user["user_id"],),
    )
    if not rows:
        raise HTTPException(status_code=404, detail="User not found")
    u = rows[0]
    story_count_rows = fetch_all(
        "SELECT COUNT(*) AS c FROM books WHERE user_id=%s",
        (user["user_id"],),
    )
    library_count_rows = fetch_all(
        "SELECT COUNT(*) AS c FROM library_entries WHERE user_id=%s",
        (user["user_id"],),
    )
    reading_list_count_rows = fetch_all(
        "SELECT COUNT(*) AS c FROM reading_lists WHERE user_id=%s",
        (user["user_id"],),
    )
    completed_rows = fetch_all(
        """
        SELECT COUNT(*) AS c FROM library_entries
        WHERE user_id=%s AND LOWER(reading_status) IN ('completed', 'complete', 'finished', 'done')
        """,
        (user["user_id"],),
    )
    story_count = int(story_count_rows[0]["c"]) if story_count_rows else 0
    library_count = int(library_count_rows[0]["c"]) if library_count_rows else 0
    reading_list_count = int(reading_list_count_rows[0]["c"]) if reading_list_count_rows else 0
    completed_count = int(completed_rows[0]["c"]) if completed_rows else 0
    followers = _count_followers(user["user_id"])
    following = _count_following(user["user_id"])
    display_name = _row_get(u, "display_name") or (_row_get(u, "email") or "Reader").split("@")[0]
    username = "@" + display_name.lower().replace(" ", "")
    return {
        "id": _row_get(u, "id"),
        "email": _row_get(u, "email") or "",
        "display_name": display_name,
        "username": username,
        "photo_url": _row_get(u, "photo_url") or "",
        "cover_url": _row_get(u, "cover_url") or "",
        "bio": _row_get(u, "bio") or "",
        "provider": _row_get(u, "provider") or "",
        "following": following,
        "followers": followers,
        "blocked": 0,
        "chapters_read": completed_count,
        "social_karma": story_count * 10,
        "day_streak": 0,
        "story_count": story_count,
        "library_count": library_count,
        "reading_list_count": reading_list_count,
    }


@app.get("/api/users/{user_id}")
def get_user_profile(user_id: int):
    rows = fetch_all(
        "SELECT id, email, display_name, photo_url, cover_url, bio, provider FROM app_users WHERE id=%s LIMIT 1",
        (user_id,),
    )
    if not rows:
        raise HTTPException(status_code=404, detail="User not found")
    u = rows[0]
    story_count_rows = fetch_all(
        "SELECT COUNT(*) AS c FROM books WHERE user_id=%s",
        (user_id,),
    )
    library_count_rows = fetch_all(
        "SELECT COUNT(*) AS c FROM library_entries WHERE user_id=%s",
        (user_id,),
    )
    reading_list_count_rows = fetch_all(
        "SELECT COUNT(*) AS c FROM reading_lists WHERE user_id=%s",
        (user_id,),
    )
    completed_rows = fetch_all(
        """
        SELECT COUNT(*) AS c FROM library_entries
        WHERE user_id=%s AND LOWER(reading_status) IN ('completed', 'complete', 'finished', 'done')
        """,
        (user_id,),
    )
    story_count = int(story_count_rows[0]["c"]) if story_count_rows else 0
    library_count = int(library_count_rows[0]["c"]) if library_count_rows else 0
    reading_list_count = int(reading_list_count_rows[0]["c"]) if reading_list_count_rows else 0
    completed_count = int(completed_rows[0]["c"]) if completed_rows else 0
    followers = _count_followers(user_id)
    following = _count_following(user_id)
    display_name = _row_get(u, "display_name") or (_row_get(u, "email") or "Reader").split("@")[0]
    username = "@" + display_name.lower().replace(" ", "")
    return {
        "id": _row_get(u, "id"),
        "email": _row_get(u, "email") or "",
        "display_name": display_name,
        "username": username,
        "photo_url": _row_get(u, "photo_url") or "",
        "cover_url": _row_get(u, "cover_url") or "",
        "bio": _row_get(u, "bio") or "",
        "provider": _row_get(u, "provider") or "",
        "following": following,
        "followers": followers,
        "blocked": 0,
        "chapters_read": completed_count,
        "social_karma": story_count * 10,
        "day_streak": 0,
        "story_count": story_count,
        "library_count": library_count,
        "reading_list_count": reading_list_count,
    }


@app.put("/api/me")
def update_me(
    payload: ProfileUpdateRequest,
    user: dict[str, Any] = Depends(require_user),
):
    rows = fetch_all(
        "SELECT id, display_name, photo_url, cover_url, bio FROM app_users WHERE id=%s LIMIT 1",
        (user["user_id"],),
    )
    if not rows:
        raise HTTPException(status_code=404, detail="User not found")

    current = rows[0]
    next_display_name = payload.display_name or _row_get(current, "display_name")
    next_photo_url = payload.photo_url if payload.photo_url is not None else _row_get(current, "photo_url")
    next_cover_url = payload.cover_url if payload.cover_url is not None else _row_get(current, "cover_url")
    next_bio = payload.bio if payload.bio is not None else _row_get(current, "bio")

    execute_write(
        """
        UPDATE app_users
        SET display_name=%s, photo_url=%s, cover_url=%s, bio=%s, updated_at=CURRENT_TIMESTAMP
        WHERE id=%s
        """,
        (next_display_name, next_photo_url, next_cover_url, next_bio, user["user_id"]),
    )
    return {
        "ok": True,
        "display_name": next_display_name,
        "photo_url": next_photo_url or "",
        "cover_url": next_cover_url or "",
        "bio": next_bio or "",
    }


@app.api_route("/api/admin/session", methods=["GET", "POST"])
def admin_session(_: dict[str, Any] = Depends(require_admin)):
    """Validate admin Bearer token. Accepts GET or POST so clients can use either."""
    return {"ok": True, "username": ADMIN_USERNAME}


@app.get("/api/story-images")
def list_story_images():
    return {"items": _available_story_images()}


@app.post("/api/upload-image")
async def upload_image(
    file: UploadFile = File(...),
    _: dict[str, Any] = Depends(require_admin),
):
    extension = Path(file.filename or "upload").suffix.lower()
    if extension not in {".jpg", ".jpeg", ".png", ".webp"}:
        raise HTTPException(status_code=400, detail="Unsupported image format")

    filename = f"{uuid4().hex}{extension}"
    target_path = UPLOAD_ROOT / filename
    content = await file.read()
    target_path.write_bytes(content)
    bump_content_version()
    return {"path": _public_image_path(filename), "filename": filename}


async def _save_uploaded_image(file: UploadFile) -> dict[str, str]:
    extension = Path(file.filename or "upload").suffix.lower()
    if extension not in {".jpg", ".jpeg", ".png", ".webp"}:
        raise HTTPException(status_code=400, detail="Unsupported image format")

    filename = f"{uuid4().hex}{extension}"
    target_path = UPLOAD_ROOT / filename
    target_path.write_bytes(await file.read())
    bump_content_version()
    return {"path": _public_image_path(filename), "filename": filename}


@app.post("/api/write/upload-image")
async def upload_writer_image(
    file: UploadFile = File(...),
    _user: dict[str, Any] = Depends(require_user),
):
    return await _save_uploaded_image(file)


@app.post("/api/me/upload-image")
async def upload_profile_image(
    file: UploadFile = File(...),
    _user: dict[str, Any] = Depends(require_user),
):
    return await _save_uploaded_image(file)


@app.post("/api/support/upload-attachment")
async def upload_support_attachment(file: UploadFile = File(...)):
    extension = Path(file.filename or "upload").suffix.lower()
    if extension not in {".jpg", ".jpeg", ".png", ".webp"}:
        raise HTTPException(status_code=400, detail="Unsupported attachment format")

    filename = f"support-{uuid4().hex}{extension}"
    target_path = UPLOAD_ROOT / filename
    target_path.write_bytes(await file.read())
    return {"path": _public_image_path(filename), "filename": filename}


@app.get("/api/bootstrap")
def bootstrap():
    discover_tabs = [
        row["name"]
        for row in fetch_all(
            "SELECT name FROM categories WHERE tab_group = 'discover' ORDER BY sort_order"
        )
    ]

    explore_topics = fetch_all(
        "SELECT name, topic_count FROM categories WHERE tab_group = 'explore' ORDER BY sort_order"
    )

    books = fetch_all(
        """
        SELECT id, user_id, title, author, description, cover_path, accent_hex, section_name,
               status_text, rating, genre, cta_label,
               COALESCE(primary_genre, genre) AS primary_genre,
               COALESCE(secondary_genre, '') AS secondary_genre,
               COALESCE(is_completed, 0) AS is_completed
        FROM books
        WHERE LOWER(COALESCE(status_text, 'draft')) NOT IN ('draft', 'unpublished', 'private')
        ORDER BY sort_order ASC, id DESC
        """
    )

    # One query for all home like counts (avoid N+1)
    likes_map: dict[int, int] = {}
    try:
        _ensure_book_likes_table()
        like_rows = fetch_all(
            "SELECT book_id, COUNT(*) AS c FROM book_likes GROUP BY book_id"
        )
        for lr in like_rows or []:
            bid = lr.get("book_id") if isinstance(lr, dict) else None
            if bid is not None:
                likes_map[int(bid)] = int(lr.get("c") or 0)
    except Exception as exc:
        LOGGER.warning("batch likes_map failed: %s", exc)

    def _card(book: Any) -> dict[str, Any]:
        """Full card payload for home rails (author id + live likes)."""
        bid = book["id"]
        live = int(likes_map.get(int(bid), 0))
        return {
            "id": bid,
            "user_id": book.get("user_id"),
            "author_user_id": book.get("user_id"),
            "title": book["title"],
            "author": book["author"],
            "description": book.get("description") or "",
            "cover_path": _normalize_cover_path(book.get("cover_path")),
            "accent_hex": book.get("accent_hex") or "#A1A1A1",
            "section_name": book.get("section_name") or "",
            "status_text": book.get("status_text") or "",
            "rating": book.get("rating") or 0,
            "genre": book.get("genre") or "",
            "primary_genre": book.get("primary_genre") or book.get("genre") or "",
            "secondary_genre": book.get("secondary_genre") or "",
            "is_completed": book.get("is_completed") or 0,
            "cta_label": book.get("cta_label") or "Read now",
            "likes_count": live,
            "likes": live,
        }

    recently_updated = [
        _card(book)
        for book in books
        if book["section_name"] == "recently_updated"
    ]

    recently_completed = [
        _card(book)
        for book in books
        if book["section_name"] == "recently_completed"
    ]

    featured_book = {
        "id": 0,
        "title": "No featured story available",
        "author": "",
        "description": "",
        "status_text": "",
        "rating": 0,
        "genre": "",
        "cta": "Read now",
        "cover_path": "",
        "tags": [],
    }

    featured_candidates = [b for b in books if b["section_name"] == "featured"]
    if not featured_candidates:
        featured_candidates = books[:1]

    if featured_candidates:
        featured_raw = featured_candidates[0]
        featured_book = {
            "id": featured_raw["id"],
            "user_id": featured_raw.get("user_id"),
            "author_user_id": featured_raw.get("user_id"),
            "title": featured_raw["title"],
            "author": featured_raw["author"],
            "description": featured_raw["description"],
            "status_text": featured_raw["status_text"],
            "rating": featured_raw["rating"],
            "genre": featured_raw["genre"],
            "cta": featured_raw["cta_label"],
            "cover_path": _normalize_cover_path(featured_raw["cover_path"]),
            "tags": _story_tags_for_book(featured_raw["id"]),
            "likes_count": _live_book_likes_count(featured_raw["id"]),
        }

    # Library entries are user-specific and loaded via GET /api/library after auth.
    # Bootstrap stays public (read-only discover content) so unauthenticated users can browse.
    library_payload: list[dict[str, Any]] = []

    _ensure_default_write_screen()
    _ensure_default_profile()

    _ensure_default_write_screen()
    _ensure_default_profile()

    write_meta_rows = fetch_all(
        "SELECT manage_tabs, story_tabs, filter_label, sort_label, empty_title, empty_cta FROM write_screen LIMIT 1"
    )
    if not write_meta_rows:
        raise HTTPException(status_code=500, detail="Write metadata is missing")

    write_meta = write_meta_rows[0]
    write_screen = {
        "manage_tabs": write_meta["manage_tabs"].split(","),
        "story_tabs": write_meta["story_tabs"].split(","),
        "filter_label": write_meta["filter_label"],
        "sort_label": write_meta["sort_label"],
        "empty_title": write_meta["empty_title"],
        "empty_cta": write_meta["empty_cta"],
    }

    notifications = fetch_all(
        "SELECT tab_name AS tab, title, message, created_at FROM notifications ORDER BY sort_order"
    )

    menu_rows = fetch_all(
        "SELECT section_name, label, icon_name, route_name FROM menu_items ORDER BY section_order, sort_order"
    )
    menu_map = defaultdict(list)
    for row in menu_rows:
        menu_map[row["section_name"]].append(
            {
                "label": row["label"],
                "icon": row["icon_name"],
                "route": row["route_name"],
            }
        )

    menu_sections = [
        {"section": section, "items": items}
        for section, items in menu_map.items()
    ]

    # Neutral profile shell — real stats come from /api/me and /api/users/{id}
    profile_rows = fetch_all(
        "SELECT display_name, username, following, followers, blocked, chapters_read, social_karma, day_streak FROM profiles LIMIT 1"
    )
    if profile_rows:
        profile = profile_rows[0]
    else:
        profile = {
            "display_name": "Reader",
            "username": "@reader",
            "following": 0,
            "followers": 0,
            "blocked": 0,
            "chapters_read": 0,
            "social_karma": 0,
            "day_streak": 0,
        }
    # Do NOT inject global reading_lists into every profile (causes fake data).
    # Client loads per-user lists via /api/reading-lists and /api/users/{id}/reading-lists.
    profile_payload = {
        **profile,
        "following": 0,
        "followers": 0,
        "blocked": 0,
        "chapters_read": 0,
        "social_karma": 0,
        "day_streak": 0,
        "reading_lists": [],
    }

    achievement_rows = fetch_all(
        """
        SELECT group_name, title, subtitle, progress_label, badge_value, style
        FROM achievements
        ORDER BY group_order, sort_order
        """
    )
    achievement_map = defaultdict(list)
    for row in achievement_rows:
        achievement_map[row["group_name"]].append(
            {
                "title": row["title"],
                "subtitle": row["subtitle"],
                "progress_label": row["progress_label"],
                "badge_value": row["badge_value"],
                "style": row["style"],
            }
        )

    achievements = [
        {"group_name": group_name, "items": items}
        for group_name, items in achievement_map.items()
    ]

    return {
        "discover_tabs": discover_tabs,
        "recently_updated": recently_updated,
        "recently_completed": recently_completed,
        "discover_books": [_card(book) for book in books],
        "featured_book": featured_book,
        "explore_topics": explore_topics,
        "library_entries": library_payload,
        "write_screen": write_screen,
        "notifications": notifications,
        "menu_sections": menu_sections,
        "profile": profile_payload,
        "achievements": achievements,
    }


@app.get("/api/search")
def search_stories(
    query: str = Query(default=""),
    genre: str = Query(default=""),
    min_rating: float = Query(default=0.0),
    limit: int = Query(default=40, ge=1, le=100),
):
    q = "%" + query.strip() + "%"
    g = genre.strip()
    if g:
        g_like = "%" + g + "%"
        rows = fetch_all(
            """
            SELECT id, user_id, title, author, description, cover_path, accent_hex,
                   status_text, rating, genre,
                   COALESCE(primary_genre, genre) AS primary_genre,
                   COALESCE(secondary_genre, '') AS secondary_genre,
                   COALESCE(is_completed, 0) AS is_completed,
                   section_name, cta_label
            FROM books
            WHERE (title LIKE %s OR author LIKE %s OR description LIKE %s)
              AND (
                    genre LIKE %s
                 OR COALESCE(primary_genre, '') LIKE %s
                 OR COALESCE(secondary_genre, '') LIKE %s
              )
              AND rating >= %s
              AND LOWER(COALESCE(status_text, 'draft')) NOT IN ('draft', 'unpublished', 'private')
            ORDER BY rating DESC, id DESC
            LIMIT %s
            """,
            (q, q, q, g_like, g_like, g_like, min_rating, limit),
        )
    else:
        rows = fetch_all(
            """
            SELECT id, user_id, title, author, description, cover_path, accent_hex,
                   status_text, rating, genre,
                   COALESCE(primary_genre, genre) AS primary_genre,
                   COALESCE(secondary_genre, '') AS secondary_genre,
                   COALESCE(is_completed, 0) AS is_completed,
                   section_name, cta_label
            FROM books
            WHERE (title LIKE %s OR author LIKE %s OR description LIKE %s)
              AND rating >= %s
              AND LOWER(COALESCE(status_text, 'draft')) NOT IN ('draft', 'unpublished', 'private')
            ORDER BY rating DESC, id DESC
            LIMIT %s
            """,
            (q, q, q, min_rating, limit),
        )
    return {"items": [_serialize_book(row) for row in rows]}



@app.get("/api/notifications")
def get_notifications(tab: str = Query(default="")):
    if tab.strip():
        rows = fetch_all(
            "SELECT tab_name AS tab, title, message, created_at FROM notifications WHERE LOWER(tab_name)=LOWER(%s) ORDER BY sort_order",
            (tab.strip(),),
        )
    else:
        rows = fetch_all(
            "SELECT tab_name AS tab, title, message, created_at FROM notifications ORDER BY sort_order"
        )
    return {"items": rows}


@app.post("/api/support/requests")
def create_support_request(payload: SupportRequestCreateRequest):
    request_id, affected = execute_write(
        """
        INSERT INTO support_requests (
            email, first_name, issue, subject, description,
            device_type, attachment_path, status
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s, 'open')
        """,
        (
            payload.email,
            payload.first_name,
            payload.issue,
            payload.subject,
            payload.description,
            payload.device_type,
            payload.attachment_path,
        ),
    )
    if affected == 0:
        raise HTTPException(status_code=400, detail="Failed to create support request")
    bump_content_version()
    return {"ok": True, "id": request_id}


@app.get("/api/chat/messages")
def get_chat_messages(user: dict[str, Any] = Depends(require_user)):
    rows = fetch_all(
        """
        SELECT id, user_id, sender, message, created_at
        FROM chat_messages
        WHERE user_id=%s
        ORDER BY created_at ASC, id ASC
        """,
        (user["user_id"],),
    )
    return {
        "items": [
            {
                "id": row["id"],
                "sender": row["sender"],
                "message": row["message"],
                "created_at": _serialize_db_datetime(row["created_at"]),
            }
            for row in rows
        ]
    }


@app.post("/api/chat/messages")
def create_chat_message(
    payload: ChatMessageCreateRequest,
    user: dict[str, Any] = Depends(require_user),
):
    message = payload.message.strip()
    if not message:
        raise HTTPException(status_code=400, detail="Message cannot be empty")
    sender = (payload.sender or "user").strip() or "user"
    row_id, _ = execute_write(
        "INSERT INTO chat_messages (user_id, sender, message) VALUES (%s, %s, %s)",
        (user["user_id"], sender, message),
    )
    return {"ok": True, "id": row_id}


@app.get("/api/library")
def get_library_entries(user: dict[str, Any] = Depends(require_user)):
    rows = fetch_all(
        """
        SELECT le.id, le.reading_status, le.updated_text, le.chapters, le.primary_genre,
               le.secondary_genre, b.id AS book_id, b.title, b.author, b.cover_path, b.accent_hex,
               b.description, b.status_text, b.rating, b.user_id AS author_user_id, b.primary_genre AS book_genre
        FROM library_entries le
        JOIN books b ON b.id = le.book_id
        WHERE le.user_id = %s
        ORDER BY le.sort_order, le.id
        """,
        (user["user_id"],),
    )
    return {
        "items": [
            {
                "id": row["id"],
                "book": {
                    "id": row["book_id"],
                    "title": row["title"],
                    "author": row["author"],
                    "cover_path": _normalize_cover_path(row["cover_path"]),
                    "accent_hex": row["accent_hex"],
                    "description": row.get("description") or "",
                    "status_text": row.get("status_text") or "",
                    "rating": float(row["rating"] or 0) if row.get("rating") is not None else 0.0,
                    "author_user_id": row.get("author_user_id"),
                    "primary_genre": row.get("book_genre") or row.get("primary_genre") or "",
                },
                "reading_status": row["reading_status"],
                "updated_text": row["updated_text"],
                "chapters": row["chapters"],
                "primary_genre": row["primary_genre"],
                "secondary_genre": row["secondary_genre"],
            }
            for row in rows
        ]
    }


@app.post("/api/library")
def create_library_entry(
    payload: LibraryCreateRequest,
    user: dict[str, Any] = Depends(require_user),
):
    # Upsert: if already tracking this book, refresh status (e.g. Reading again)
    existing = fetch_all(
        "SELECT id FROM library_entries WHERE user_id=%s AND book_id=%s LIMIT 1",
        (user["user_id"], payload.book_id),
    )
    if existing:
        execute_write(
            """
            UPDATE library_entries
            SET reading_status=%s, updated_text=%s, chapters=%s, primary_genre=%s, secondary_genre=%s
            WHERE id=%s
            """,
            (
                payload.reading_status,
                payload.updated_text,
                payload.chapters,
                payload.primary_genre,
                payload.secondary_genre,
                existing[0]["id"],
            ),
        )
        bump_content_version()
        return {"ok": True, "id": existing[0]["id"], "updated": True}

    entry_id, affected = execute_write(
        """
        INSERT INTO library_entries (user_id, book_id, reading_status, updated_text, chapters, primary_genre, secondary_genre, sort_order)
        VALUES (%s, %s, %s, %s, %s, %s, %s, 999)
        """,
        (
            user["user_id"],
            payload.book_id,
            payload.reading_status,
            payload.updated_text,
            payload.chapters,
            payload.primary_genre,
            payload.secondary_genre,
        ),
    )
    if affected == 0 and not entry_id:
        raise HTTPException(status_code=400, detail="Failed to create library entry")
    bump_content_version()
    return {"ok": True, "id": entry_id}


@app.put("/api/library/{entry_id}")
def update_library_entry(
    entry_id: int,
    payload: LibraryUpdateRequest,
    user: dict[str, Any] = Depends(require_user),
):
    current_rows = fetch_all(
        "SELECT * FROM library_entries WHERE id=%s AND user_id=%s",
        (entry_id, user["user_id"]),
    )
    if not current_rows:
        raise HTTPException(status_code=404, detail="Library entry not found")

    current = current_rows[0]
    _, affected = execute_write(
        """
        UPDATE library_entries
        SET reading_status=%s,
            updated_text=%s,
            chapters=%s,
            primary_genre=%s,
            secondary_genre=%s
        WHERE id=%s AND user_id=%s
        """,
        (
            payload.reading_status or current["reading_status"],
            payload.updated_text or current["updated_text"],
            payload.chapters if payload.chapters is not None else current["chapters"],
            payload.primary_genre or current["primary_genre"],
            payload.secondary_genre or current["secondary_genre"],
            entry_id,
            user["user_id"],
        ),
    )
    if affected == 0:
        raise HTTPException(status_code=400, detail="Failed to update library entry")
    bump_content_version()
    return {"ok": True}


@app.delete("/api/library/{entry_id}")
def delete_library_entry(entry_id: int, user: dict[str, Any] = Depends(require_user)):
    _, affected = execute_write(
        "DELETE FROM library_entries WHERE id=%s AND user_id=%s",
        (entry_id, user["user_id"]),
    )
    if affected == 0:
        raise HTTPException(status_code=404, detail="Library entry not found")
    bump_content_version()
    return {"ok": True}


@app.get("/api/reading-lists")
def get_public_reading_lists(user: dict[str, Any] = Depends(require_user)):
    rows = fetch_all(
        """
        SELECT id, profile_id, name, story_count, cover_path, sort_order
        FROM reading_lists
        WHERE user_id = %s OR (user_id IS NULL AND profile_id = 1)
        ORDER BY sort_order, id
        """,
        (user["user_id"],),
    )
    items = []
    for row in rows:
        lid = _row_get(row, "id")
        covers = []
        try:
            item_rows = fetch_all(
                """
                SELECT b.cover_path FROM reading_list_items rli
                JOIN books b ON b.id = rli.book_id
                WHERE rli.reading_list_id=%s
                LIMIT 4
                """,
                (lid,),
            )
            for ir in item_rows:
                pth = _normalize_cover_path(_row_get(ir, "cover_path") or "")
                if pth:
                    covers.append(pth)
        except Exception:
            pass
        items.append({
            **(dict(row) if not isinstance(row, dict) else row),
            "cover_path": _normalize_cover_path(_row_get(row, "cover_path")),
            "covers": covers,
        })
    return {"items": items}


@app.post("/api/reading-lists")
def create_public_reading_list(
    payload: ReadingListCreateRequest,
    user: dict[str, Any] = Depends(require_user),
):
    name = (payload.name or "").strip()
    if not name:
        raise HTTPException(status_code=400, detail="Reading list name is required")
    row_id, _ = execute_write(
        """
        INSERT INTO reading_lists (user_id, profile_id, name, story_count, cover_path, sort_order)
        VALUES (%s, 1, %s, %s, %s, %s)
        """,
        (
            user["user_id"],
            name,
            payload.story_count,
            _normalize_cover_path(payload.cover_path),
            payload.sort_order,
        ),
    )
    bump_content_version()
    return {"ok": True, "id": row_id}


@app.get("/api/reading-lists/{reading_list_id}")
def get_reading_list_detail(
    reading_list_id: int,
    user: dict[str, Any] = Depends(require_user),
):
    rows = fetch_all(
        "SELECT id, profile_id, user_id, name, story_count, cover_path, sort_order FROM reading_lists WHERE id=%s AND (user_id=%s OR user_id IS NULL)",
        (reading_list_id, user["user_id"]),
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Reading list not found")

    items = fetch_all(
        "SELECT r.id, r.book_id, b.title, b.author, b.cover_path, b.genre, r.created_at FROM reading_list_items r JOIN books b ON b.id = r.book_id WHERE r.reading_list_id=%s ORDER BY r.created_at DESC",
        (reading_list_id,),
    )
    return {
        **rows[0],
        "cover_path": _normalize_cover_path(_row_get(rows[0], "cover_path")),
        "items": [
            {
                **item,
                "cover_path": _normalize_cover_path(_row_get(item, "cover_path")),
            }
            for item in items
        ],
    }


@app.post("/api/reading-lists/{reading_list_id}/items")
def add_reading_list_item(
    reading_list_id: int,
    payload: dict[str, Any],
    user: dict[str, Any] = Depends(require_user),
):
    rows = fetch_all(
        "SELECT id FROM reading_lists WHERE id=%s AND (user_id=%s OR user_id IS NULL)",
        (reading_list_id, user["user_id"]),
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Reading list not found")

    book_id = int(payload.get("book_id", 0))
    book_rows = fetch_all("SELECT id FROM books WHERE id=%s", (book_id,))
    if not book_rows:
        raise HTTPException(status_code=404, detail="Book not found")

    item_id, _ = execute_write(
        "INSERT INTO reading_list_items (reading_list_id, book_id) VALUES (%s, %s)",
        (reading_list_id, book_id),
    )
    execute_write(
        "UPDATE reading_lists SET story_count = story_count + 1 WHERE id=%s",
        (reading_list_id,),
    )
    bump_content_version()
    return {"ok": True, "id": item_id}


@app.delete("/api/reading-lists/{reading_list_id}/items/{item_id}")
def remove_reading_list_item(
    reading_list_id: int,
    item_id: int,
    user: dict[str, Any] = Depends(require_user),
):
    rows = fetch_all(
        "SELECT id FROM reading_lists WHERE id=%s AND (user_id=%s OR user_id IS NULL)",
        (reading_list_id, user["user_id"]),
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Reading list not found")

    _, affected = execute_write(
        "DELETE FROM reading_list_items WHERE id=%s AND reading_list_id=%s",
        (item_id, reading_list_id),
    )
    if affected == 0:
        raise HTTPException(status_code=404, detail="Item not found")
    execute_write(
        "UPDATE reading_lists SET story_count = GREATEST(0, story_count - 1) WHERE id=%s",
        (reading_list_id,),
    )
    bump_content_version()
    return {"ok": True}


@app.delete("/api/reading-lists/{reading_list_id}")
def delete_reading_list(
    reading_list_id: int,
    user: dict[str, Any] = Depends(require_user),
):
    _, affected = execute_write(
        "DELETE FROM reading_lists WHERE id=%s AND (user_id=%s OR user_id IS NULL)",
        (reading_list_id, user["user_id"]),
    )
    if affected == 0:
        raise HTTPException(status_code=404, detail="Reading list not found")
    bump_content_version()
    return {"ok": True}


@app.get("/api/write/stories")
def get_writer_stories(user: dict[str, Any] = Depends(require_user)):
    rows = fetch_all(
        """
        SELECT id, title, author, description, genre, status_text, cover_path, accent_hex, content_warnings
        FROM books
        WHERE user_id = %s
        ORDER BY id DESC
        """,
        (user["user_id"],),
    )
    return {
        "items": [_serialize_book(row) for row in rows]
    }


@app.get("/api/write/stories/{story_id}/chapters")
def get_story_chapters(story_id: int):
    story_rows = fetch_all("SELECT id FROM books WHERE id=%s", (story_id,))
    if not story_rows:
        raise HTTPException(status_code=404, detail="Story not found")

    rows = fetch_all(
        """
        SELECT id, story_id, chapter_number, title, content, notes, submission_status, scheduled_for,
               sort_order, created_at, updated_at
        FROM chapters
        WHERE story_id=%s
        ORDER BY chapter_number, sort_order, id
        """,
        (story_id,),
    )
    return {
        "items": [
            {
                **row,
                "scheduled_for": _serialize_datetime(_row_get(row, "scheduled_for")),
                "created_at": _serialize_datetime(_row_get(row, "created_at")),
                "updated_at": _serialize_datetime(_row_get(row, "updated_at")),
            }
            for row in rows
        ]
    }


@app.get("/api/write/chapters/{chapter_id}/revisions")
def get_story_chapter_revisions(chapter_id: int):
    rows = fetch_all(
        """
        SELECT id, chapter_id, title, notes, submission_status, scheduled_for, created_at
        FROM chapter_revisions
        WHERE chapter_id=%s
        ORDER BY created_at DESC, id DESC
        """,
        (chapter_id,),
    )
    return {
        "items": [
            {
                **row,
                "scheduled_for": _serialize_datetime(_row_get(row, "scheduled_for")),
                "created_at": _serialize_datetime(_row_get(row, "created_at")),
            }
            for row in rows
        ]
    }


@app.post("/api/write/stories/{story_id}/chapters")
def create_story_chapter(story_id: int, payload: ChapterCreateRequest):
    try:
        story_rows = fetch_all("SELECT id FROM books WHERE id=%s", (story_id,))
        if not story_rows:
            raise HTTPException(status_code=404, detail="Story not found")

        chapter_number = payload.chapter_number
        if chapter_number is None:
            next_rows = fetch_all(
                "SELECT COALESCE(MAX(chapter_number), 0) + 1 AS next_chapter FROM chapters WHERE story_id=%s",
                (story_id,),
            )
            chapter_number = int(next_rows[0]["next_chapter"]) if next_rows else 1

        submission_status = (payload.submission_status or "draft").strip() or "draft"
        scheduled_for = _parse_optional_datetime(payload.scheduled_for)
        scheduled_value = (
            scheduled_for.isoformat() if isinstance(scheduled_for, datetime) else scheduled_for
        )
        row_id, _ = execute_write(
            """
            INSERT INTO chapters (
                story_id, chapter_number, title, content, notes, submission_status, scheduled_for, sort_order
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """,
            (
                story_id,
                chapter_number,
                payload.title or "Untitled",
                payload.content or "",
                payload.notes or "",
                submission_status,
                scheduled_value,
                chapter_number,
            ),
        )
        try:
            _record_chapter_revision(
                row_id,
                payload.title or "Untitled",
                payload.content or "",
                payload.notes or "",
                submission_status,
                scheduled_for,
            )
        except Exception as rev_exc:
            LOGGER.warning("Chapter revision log failed (non-fatal): %s", rev_exc)
        bump_content_version()
        return {"ok": True, "id": row_id}
    except HTTPException:
        raise
    except Exception as exc:
        LOGGER.exception("create_story_chapter failed for story %s: %s", story_id, exc)
        raise HTTPException(status_code=500, detail=f"Failed to create chapter: {exc}") from exc


@app.put("/api/write/chapters/{chapter_id}")
def update_story_chapter(chapter_id: int, payload: ChapterUpdateRequest):
    rows = fetch_all("SELECT * FROM chapters WHERE id=%s", (chapter_id,))
    if not rows:
        raise HTTPException(status_code=404, detail="Chapter not found")

    current = rows[0]
    next_title = payload.title or current["title"]
    next_content = payload.content if payload.content is not None else current["content"]
    next_notes = payload.notes if payload.notes is not None else _row_get(current, "notes", "")
    next_status = (payload.submission_status or _row_get(current, "submission_status") or "draft").strip() or "draft"
    next_scheduled_for = (
        _parse_optional_datetime(payload.scheduled_for)
        if payload.scheduled_for is not None
        else _row_get(current, "scheduled_for")
    )
    # Normalize scheduled_for for both SQLite (TEXT) and MySQL (DATETIME).
    scheduled_value = next_scheduled_for
    if isinstance(scheduled_value, datetime):
        scheduled_value = scheduled_value.isoformat()

    execute_write(
        """
        UPDATE chapters
        SET chapter_number=%s, title=%s, content=%s, notes=%s, submission_status=%s,
            scheduled_for=%s, sort_order=%s
        WHERE id=%s
        """,
        (
            payload.chapter_number
            if payload.chapter_number is not None
            else current["chapter_number"],
            next_title,
            next_content,
            next_notes,
            next_status,
            scheduled_value,
            payload.chapter_number
            if payload.chapter_number is not None
            else current["sort_order"],
            chapter_id,
        ),
    )
    # Do not treat SQLite rowcount==0 as failure: identical values still succeed.
    _record_chapter_revision(
        chapter_id,
        next_title,
        next_content,
        next_notes,
        next_status,
        next_scheduled_for if isinstance(next_scheduled_for, datetime) else (
            _parse_optional_datetime(str(next_scheduled_for)) if next_scheduled_for else None
        ),
    )
    bump_content_version()
    return {"ok": True}


@app.delete("/api/write/chapters/{chapter_id}")
def delete_story_chapter(chapter_id: int):
    _, affected = execute_write("DELETE FROM chapters WHERE id=%s", (chapter_id,))
    if affected == 0:
        raise HTTPException(status_code=404, detail="Chapter not found")
    bump_content_version()
    return {"ok": True}


def _ensure_tags_exist(names: list[str]) -> list[int]:
    normalized = [name.strip().lstrip('#') for name in names if name.strip()]
    if not normalized:
        return []

    placeholders = ",".join(["%s"] * len(normalized))
    existing = fetch_all(
        f"SELECT id, name FROM tags WHERE name IN ({placeholders})",
        tuple(normalized),
    )
    name_to_id = {row["name"]: row["id"] for row in existing}
    for name in normalized:
        if name not in name_to_id:
            execute_write(
                "INSERT INTO tags (name) VALUES (%s)",
                (name,),
            )

    all_rows = fetch_all(
        f"SELECT id, name FROM tags WHERE name IN ({placeholders})",
        tuple(normalized),
    )
    return [row["id"] for row in all_rows]


def _set_story_tags(story_id: int, tag_names: list[str]) -> None:
    """Attach up to 3 *existing* admin-created hashtags to a story.
    Authors cannot invent new tags — only select from the admin tag list.
    """
    if tag_names is None:
        return
    normalized = [n.strip().lstrip("#") for n in tag_names if n and str(n).strip()]
    if not normalized:
        execute_write("DELETE FROM book_tags WHERE book_id=%s", (story_id,))
        return
    # Cap at 3 hashtags per book
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


def _story_tags_for_book(book_id: int) -> list[str]:
    rows = fetch_all(
        "SELECT t.name FROM tags t JOIN book_tags bt ON bt.tag_id = t.id WHERE bt.book_id=%s ORDER BY t.name",
        (book_id,),
    )
    return [row["name"] for row in rows]


def _row_get(row: Any, key: str, default: Any = None) -> Any:
    if isinstance(row, dict):
        return row.get(key, default)
    try:
        return row[key]
    except (KeyError, IndexError):
        return default


def _live_book_likes_count(book_id: int | None) -> int:
    """Count likes from book_likes table (source of truth)."""
    if book_id is None:
        return 0
    try:
        _ensure_book_likes_table()
        count_rows = fetch_all(
            "SELECT COUNT(*) AS c FROM book_likes WHERE book_id=%s",
            (int(book_id),),
        )
        return int(count_rows[0]["c"]) if count_rows else 0
    except Exception as exc:
        LOGGER.warning("live likes_count failed for book %s: %s", book_id, exc)
        return 0


def _serialize_book(row: Any) -> dict[str, Any]:
    data = dict(row) if not isinstance(row, dict) else dict(row)
    book_id = _row_get(row, "id")
    live_likes = _live_book_likes_count(book_id)
    return {
        **data,
        "cover_path": _normalize_cover_path(_row_get(row, "cover_path")),
        "author_user_id": _row_get(row, "user_id"),
        "tags": _story_tags_for_book(book_id),
        "likes_count": live_likes,
        "likes": live_likes,  # alias used by some clients
    }


@app.post("/api/write/stories")
def create_writer_story(
    payload: StoryCreateRequest,
    user: dict[str, Any] = Depends(require_user),
):
    cover = _normalize_cover_path(payload.cover_path)
    warnings = (payload.content_warnings or "").strip()
    status = (payload.status_text or "Draft").strip() or "Draft"
    # Client requirement: publishing a story makes it live immediately
    if status.lower() in ("publish", "published", "live", "public"):
        status = "Published"
    story_id, _ = execute_write(
        """
        INSERT INTO books (
            user_id, title, author, description, cover_path, accent_hex, section_name,
            status_text, rating, genre, primary_genre, cta_label, sort_order, content_warnings
        )
        VALUES (%s, %s, %s, %s, %s, '#557E7A', 'recently_updated', %s, 0.0, %s, %s, 'Read now', 999, %s)
        """,
        (
            user["user_id"],
            payload.title,
            payload.author,
            payload.description,
            cover,
            status,
            payload.genre,
            payload.genre,
            warnings,
        ),
    )
    _set_story_tags(story_id, payload.tags)
    if status == "Published":
        try:
            execute_write(
                "UPDATE books SET section_name=%s, sort_order=%s WHERE id=%s",
                ("recently_updated", 0, story_id),
            )
        except Exception:
            pass
    try:
        execute_write(
            "UPDATE app_users SET is_author=1, is_author_active=1 WHERE id=%s",
            (user["user_id"],),
        )
    except Exception:
        try:
            execute_write("UPDATE app_users SET is_author=1 WHERE id=%s", (user["user_id"],))
        except Exception:
            pass
    bump_content_version()
    return {"ok": True, "id": story_id, "status_text": status}


@app.put("/api/write/stories/{story_id}")
def update_writer_story(
    story_id: int,
    payload: StoryUpdateRequest,
    user: dict[str, Any] = Depends(require_user),
):
    rows = fetch_all(
        "SELECT * FROM books WHERE id=%s AND (user_id=%s OR user_id IS NULL)",
        (story_id, user["user_id"]),
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Story not found")

    current = rows[0]
    next_warnings = (
        payload.content_warnings.strip()
        if payload.content_warnings is not None
        else (_row_get(current, "content_warnings") or "")
    )
    next_cover = (
        _normalize_cover_path(payload.cover_path)
        if payload.cover_path is not None
        else _row_get(current, "cover_path")
    )
    next_status = _row_get(current, "status_text") or "Draft"
    if payload.status_text is not None:
        st = payload.status_text.strip() or "Draft"
        if st.lower() in ("publish", "published", "live", "public"):
            st = "Published"
        next_status = st
    _, affected = execute_write(
        """
        UPDATE books
        SET title=%s, author=%s, description=%s, genre=%s, primary_genre=%s, cover_path=%s, user_id=%s, content_warnings=%s, status_text=%s
        WHERE id=%s
        """,
        (
            payload.title or _row_get(current, "title"),
            payload.author or _row_get(current, "author"),
            payload.description or _row_get(current, "description"),
            payload.genre or _row_get(current, "genre"),
            payload.genre or _row_get(current, "primary_genre") or _row_get(current, "genre"),
            next_cover,
            user["user_id"],
            next_warnings,
            next_status,
            story_id,
        ),
    )
    if affected == 0:
        raise HTTPException(status_code=400, detail="Failed to update story")

    if payload.tags is not None:
        _set_story_tags(story_id, payload.tags)

    bump_content_version()
    return {"ok": True}


@app.get("/api/write/stories/{story_id}")
def get_writer_story(story_id: int):
    rows = fetch_all(
        "SELECT id, title, author, description, genre, cover_path, accent_hex, status_text, rating, content_warnings FROM books WHERE id=%s",
        (story_id,),
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Story not found")
    story = rows[0]
    return _serialize_book(story)


@app.get("/api/books/{book_id}")
def get_public_book(book_id: int):
    rows = fetch_all(
        """
        SELECT id, user_id, title, author, description, genre, cover_path, accent_hex,
               status_text, rating, content_warnings
        FROM books WHERE id=%s
        """,
        (book_id,),
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Book not found")
    status = str(_row_get(rows[0], "status_text") or "").strip().lower()
    if status in ("draft", "unpublished", "private"):
        raise HTTPException(status_code=404, detail="Book not found")
    return _serialize_book(rows[0])


@app.get("/api/tags")
def list_tags(q: str | None = None):
    if q:
        like = f"%{q.strip().lstrip('#')}%"
        rows = fetch_all(
            """
            SELECT t.id, t.name,
                   (SELECT COUNT(*) FROM book_tags bt WHERE bt.tag_id = t.id) AS book_count
            FROM tags t
            WHERE t.name LIKE %s
            ORDER BY t.name LIMIT 20
            """,
            (like,),
        )
    else:
        rows = fetch_all(
            """
            SELECT t.id, t.name,
                   (SELECT COUNT(*) FROM book_tags bt WHERE bt.tag_id = t.id) AS book_count
            FROM tags t
            ORDER BY book_count DESC, t.name LIMIT 100
            """
        )
    return {
        "items": [
            {
                "id": row["id"],
                "name": row["name"],
                "book_count": int(row.get("book_count") or 0),
            }
            for row in rows
        ]
    }


@app.get("/api/tags/{tag_name}/books")
def list_books_by_tag(tag_name: str):
    """Return published books that have the given hashtag (admin-created tags only)."""
    clean = tag_name.strip().lstrip("#")
    rows = fetch_all(
        """
        SELECT b.* FROM books b
        JOIN book_tags bt ON bt.book_id = b.id
        JOIN tags t ON t.id = bt.tag_id
        WHERE t.name = %s
          AND LOWER(COALESCE(b.status_text, 'draft')) NOT IN ('draft', 'unpublished', 'private')
        ORDER BY b.id DESC
        LIMIT 100
        """,
        (clean,),
    )
    return {"items": [_serialize_book(row) for row in rows], "tag": clean}


@app.get("/api/me/reviews")
def list_my_reviews(user: dict[str, Any] = Depends(require_user)):
    """Books this user has reviewed — used on Profile > Reviews and to re-read."""
    rows = fetch_all(
        """
        SELECT r.id, r.rating, r.comment, r.created_at, r.book_id,
               b.title, b.author, b.cover_path, b.accent_hex, b.primary_genre, b.status_text
        FROM book_reviews r
        JOIN books b ON b.id = r.book_id
        WHERE r.user_id = %s
        ORDER BY r.created_at DESC
        """,
        (user["user_id"],),
    )
    return {
        "items": [
            {
                "id": row["id"],
                "rating": row["rating"],
                "comment": row["comment"] or "",
                "created_at": str(row["created_at"]) if row.get("created_at") is not None else "",
                "book": {
                    "id": row["book_id"],
                    "title": row["title"],
                    "author": row["author"],
                    "cover_path": _normalize_cover_path(row["cover_path"]),
                    "accent_hex": row.get("accent_hex") or "#A1A1A1",
                    "primary_genre": row.get("primary_genre") or "",
                    "status_text": row.get("status_text") or "",
                },
            }
            for row in rows
        ]
    }


@app.get("/api/books/{book_id}/reviews")
def list_book_reviews(book_id: int):
    rows = fetch_all(
        "SELECT r.id, r.rating, r.comment, r.created_at, u.display_name FROM book_reviews r JOIN app_users u ON u.id = r.user_id WHERE r.book_id=%s ORDER BY r.created_at DESC",
        (book_id,),
    )
    return {"items": [{"id": row["id"], "rating": row["rating"], "comment": row["comment"], "created_at": row["created_at"], "display_name": row["display_name"]} for row in rows]}


@app.post("/api/books/{book_id}/reviews")
def create_book_review(
    book_id: int,
    payload: ReviewCreateRequest,
    user: dict[str, Any] = Depends(require_user),
):
    if payload.rating < 1 or payload.rating > 5:
        raise HTTPException(status_code=400, detail="Rating must be between 1 and 5")
    execute_write(
        "INSERT INTO book_reviews (book_id, user_id, rating, comment) VALUES (%s, %s, %s, %s)",
        (book_id, user["user_id"], payload.rating, payload.comment.strip()),
    )
    bump_content_version()
    return {"ok": True}


def _ensure_chapter_comments_table() -> None:
    """Create chapter_comments on SQLite/MySQL if missing."""
    try:
        if USE_SQLITE:
            execute_write(
                """
                CREATE TABLE IF NOT EXISTS chapter_comments (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    chapter_id INTEGER NOT NULL,
                    book_id INTEGER NOT NULL,
                    user_id INTEGER NOT NULL,
                    body TEXT NOT NULL,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP
                )
                """,
                (),
            )
        else:
            execute_write(
                """
                CREATE TABLE IF NOT EXISTS chapter_comments (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    chapter_id INT NOT NULL,
                    book_id INT NOT NULL,
                    user_id INT NOT NULL,
                    body TEXT NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    INDEX (chapter_id),
                    INDEX (book_id),
                    INDEX (user_id)
                )
                """,
                (),
            )
    except Exception as exc:
        LOGGER.warning("chapter_comments ensure failed: %s", exc)


def _resolve_chapter_id(book_id: int, chapter_number: int) -> int | None:
    rows = fetch_all(
        "SELECT id FROM chapters WHERE story_id=%s AND chapter_number=%s ORDER BY id LIMIT 1",
        (book_id, chapter_number),
    )
    if not rows:
        return None
    return int(rows[0]["id"])


def _serialize_comment_row(row: dict[str, Any]) -> dict[str, Any]:
    name = (
        row.get("display_name")
        or row.get("username")
        or "Reader"
    )
    avatar = row.get("photo_url") or row.get("avatar_url") or ""
    created = row.get("created_at")
    return {
        "id": row["id"],
        "chapter_id": row.get("chapter_id"),
        "book_id": row.get("book_id"),
        "user_id": row.get("user_id"),
        "body": row.get("body") or "",
        "display_name": name,
        "username": row.get("username") or "",
        "photo_url": avatar,
        "created_at": str(created) if created is not None else "",
    }


@app.get("/api/books/{book_id}/chapters/{chapter_number}/comments")
def list_chapter_comments(book_id: int, chapter_number: int):
    """Public list of comments for a chapter (by book + chapter number)."""
    _ensure_chapter_comments_table()
    chapter_id = _resolve_chapter_id(book_id, chapter_number)
    if chapter_id is None:
        return {"items": []}
    rows = fetch_all(
        """
        SELECT c.id, c.chapter_id, c.book_id, c.user_id, c.body, c.created_at,
               u.display_name, u.username, u.photo_url
        FROM chapter_comments c
        LEFT JOIN app_users u ON u.id = c.user_id
        WHERE c.chapter_id = %s
        ORDER BY c.created_at DESC, c.id DESC
        """,
        (chapter_id,),
    )
    return {"items": [_serialize_comment_row(r) for r in rows]}


@app.post("/api/books/{book_id}/chapters/{chapter_number}/comments")
def create_chapter_comment(
    book_id: int,
    chapter_number: int,
    payload: ChapterCommentCreateRequest,
    user: dict[str, Any] = Depends(require_user),
):
    """Post a comment on a chapter. Requires auth."""
    _ensure_chapter_comments_table()
    body = (payload.body or "").strip()
    if not body:
        raise HTTPException(status_code=400, detail="Comment cannot be empty")
    if len(body) > 4000:
        raise HTTPException(status_code=400, detail="Comment is too long")
    chapter_id = _resolve_chapter_id(book_id, chapter_number)
    if chapter_id is None:
        # Auto-create a stub chapter row so comments can still attach when
        # the reader opened content without a DB chapter id.
        execute_write(
            """
            INSERT INTO chapters (story_id, chapter_number, title, content, sort_order)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (book_id, chapter_number, f"Chapter {chapter_number}", "", chapter_number),
        )
        chapter_id = _resolve_chapter_id(book_id, chapter_number)
        if chapter_id is None:
            raise HTTPException(status_code=404, detail="Chapter not found")
    execute_write(
        """
        INSERT INTO chapter_comments (chapter_id, book_id, user_id, body)
        VALUES (%s, %s, %s, %s)
        """,
        (chapter_id, book_id, user["user_id"], body),
    )
    bump_content_version()
    rows = fetch_all(
        """
        SELECT c.id, c.chapter_id, c.book_id, c.user_id, c.body, c.created_at,
               u.display_name, u.username, u.photo_url
        FROM chapter_comments c
        LEFT JOIN app_users u ON u.id = c.user_id
        WHERE c.chapter_id = %s AND c.user_id = %s
        ORDER BY c.id DESC
        LIMIT 1
        """,
        (chapter_id, user["user_id"]),
    )
    item = _serialize_comment_row(rows[0]) if rows else {"ok": True, "body": body}
    return {"ok": True, "item": item}


@app.get("/api/chapters/{chapter_id}/comments")
def list_comments_by_chapter_id(chapter_id: int):
    _ensure_chapter_comments_table()
    rows = fetch_all(
        """
        SELECT c.id, c.chapter_id, c.book_id, c.user_id, c.body, c.created_at,
               u.display_name, u.username, u.photo_url
        FROM chapter_comments c
        LEFT JOIN app_users u ON u.id = c.user_id
        WHERE c.chapter_id = %s
        ORDER BY c.created_at DESC, c.id DESC
        """,
        (chapter_id,),
    )
    return {"items": [_serialize_comment_row(r) for r in rows]}


def _ensure_author_follows_table() -> None:
    """Ensure author_follows exists (SQLite + MySQL) and normalize legacy column names."""
    try:
        if USE_SQLITE:
            execute_write(
                """
                CREATE TABLE IF NOT EXISTS author_follows (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id INTEGER NOT NULL,
                    author_id INTEGER NOT NULL,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE(user_id, author_id)
                )
                """,
                (),
            )
        else:
            execute_write(
                """
                CREATE TABLE IF NOT EXISTS author_follows (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    user_id INT NOT NULL,
                    author_id INT NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE KEY uq_follow (user_id, author_id)
                )
                """,
                (),
            )
    except Exception as exc:
        LOGGER.warning("author_follows create failed: %s", exc)

    # MySQL legacy column rename/backfill
    if USE_SQLITE:
        return
    try:
        cols = fetch_all("SHOW COLUMNS FROM author_follows")
        names = {str(c.get("Field") or c.get("field") or "").lower() for c in cols}
        if not names:
            return
        if "user_id" not in names and "follower_user_id" in names:
            execute_write("ALTER TABLE author_follows ADD COLUMN user_id INT NULL", ())
            execute_write(
                "UPDATE author_follows SET user_id = follower_user_id WHERE user_id IS NULL",
                (),
            )
        if "author_id" not in names and "author_user_id" in names:
            execute_write("ALTER TABLE author_follows ADD COLUMN author_id INT NULL", ())
            execute_write(
                "UPDATE author_follows SET author_id = author_user_id WHERE author_id IS NULL",
                (),
            )
    except Exception as exc:
        LOGGER.warning("author_follows column ensure failed: %s", exc)


def _count_followers(author_id: int) -> int:
    try:
        _ensure_author_follows_table()
        rows = fetch_all(
            "SELECT COUNT(*) AS c FROM author_follows WHERE author_id=%s",
            (author_id,),
        )
        return int(rows[0]["c"]) if rows else 0
    except Exception as exc:
        LOGGER.warning("count followers failed for %s: %s", author_id, exc)
        return 0


def _count_following(user_id: int) -> int:
    try:
        _ensure_author_follows_table()
        rows = fetch_all(
            "SELECT COUNT(*) AS c FROM author_follows WHERE user_id=%s",
            (user_id,),
        )
        return int(rows[0]["c"]) if rows else 0
    except Exception as exc:
        LOGGER.warning("count following failed for %s: %s", user_id, exc)
        return 0


# backward-compatible alias
def _ensure_author_follows_columns() -> None:
    _ensure_author_follows_table()




def _ensure_book_likes_table() -> None:
    try:
        if USE_SQLITE:
            execute_write(
                """
                CREATE TABLE IF NOT EXISTS book_likes (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id INTEGER NOT NULL,
                    book_id INTEGER NOT NULL,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE(user_id, book_id)
                )
                """,
                (),
            )
        else:
            execute_write(
                """
                CREATE TABLE IF NOT EXISTS book_likes (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    user_id INT NOT NULL,
                    book_id INT NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE KEY uq_book_like (user_id, book_id)
                )
                """,
                (),
            )
    except Exception as exc:
        LOGGER.warning("book_likes ensure failed: %s", exc)


@app.get("/api/books/{book_id}/like")
def get_book_like(book_id: int, user: dict[str, Any] | None = Depends(optional_user)):
    """Public: returns likes_count for everyone; includes liked=true only when authenticated."""
    _ensure_book_likes_table()
    liked = False
    if user is not None:
        rows = fetch_all(
            "SELECT id FROM book_likes WHERE user_id=%s AND book_id=%s",
            (user["user_id"], book_id),
        )
        liked = bool(rows)
    count_rows = fetch_all(
        "SELECT COUNT(*) AS c FROM book_likes WHERE book_id=%s",
        (book_id,),
    )
    return {
        "liked": liked,
        "likes_count": int(count_rows[0]["c"]) if count_rows else 0,
    }


@app.post("/api/books/{book_id}/like")
def like_book(book_id: int, user: dict[str, Any] = Depends(require_user)):
    """One like per user; repeated calls stay idempotent."""
    _ensure_book_likes_table()
    if USE_SQLITE:
        execute_write(
            "INSERT OR IGNORE INTO book_likes (user_id, book_id) VALUES (%s, %s)",
            (user["user_id"], book_id),
        )
    else:
        execute_write(
            "INSERT IGNORE INTO book_likes (user_id, book_id) VALUES (%s, %s)",
            (user["user_id"], book_id),
        )
    count_rows = fetch_all(
        "SELECT COUNT(*) AS c FROM book_likes WHERE book_id=%s",
        (book_id,),
    )
    return {
        "ok": True,
        "liked": True,
        "likes_count": int(count_rows[0]["c"]) if count_rows else 0,
    }


@app.delete("/api/books/{book_id}/like")
def unlike_book(book_id: int, user: dict[str, Any] = Depends(require_user)):
    _ensure_book_likes_table()
    execute_write(
        "DELETE FROM book_likes WHERE user_id=%s AND book_id=%s",
        (user["user_id"], book_id),
    )
    count_rows = fetch_all(
        "SELECT COUNT(*) AS c FROM book_likes WHERE book_id=%s",
        (book_id,),
    )
    return {
        "ok": True,
        "liked": False,
        "likes_count": int(count_rows[0]["c"]) if count_rows else 0,
    }

@app.post("/api/authors/{author_id}/follow")
def follow_author(author_id: int, user: dict[str, Any] = Depends(require_user)):
    _ensure_author_follows_table()
    if user["user_id"] == author_id:
        raise HTTPException(status_code=400, detail="Cannot follow yourself")
    if USE_SQLITE:
        execute_write(
            "INSERT OR IGNORE INTO author_follows (user_id, author_id) VALUES (%s, %s)",
            (user["user_id"], author_id),
        )
    else:
        execute_write(
            "INSERT IGNORE INTO author_follows (user_id, author_id) VALUES (%s, %s)",
            (user["user_id"], author_id),
        )
    followers = _count_followers(author_id)
    following_count = _count_following(user["user_id"])
    return {
        "ok": True,
        "following": True,
        "followers": followers,
        "following_count": following_count,
    }


@app.get("/api/authors/{author_id}/follow")
def check_author_follow(author_id: int, user: dict[str, Any] = Depends(require_user)):
    _ensure_author_follows_table()
    rows = fetch_all(
        "SELECT id FROM author_follows WHERE user_id=%s AND author_id=%s",
        (user["user_id"], author_id),
    )
    return {"following": bool(rows)}


@app.delete("/api/authors/{author_id}/follow")
def unfollow_author(author_id: int, user: dict[str, Any] = Depends(require_user)):
    _ensure_author_follows_table()
    _, affected = execute_write(
        "DELETE FROM author_follows WHERE user_id=%s AND author_id=%s",
        (user["user_id"], author_id),
    )
    # Idempotent: treat missing row as already unfollowed
    followers = _count_followers(author_id)
    following_count = _count_following(user["user_id"])
    return {
        "ok": True,
        "following": False,
        "followers": followers,
        "following_count": following_count,
    }


@app.get("/api/authors/{author_id}/books")
def list_author_books(author_id: int, exclude_id: int | None = None):
    """Public list of published books by a given author (user_id)."""
    if exclude_id is not None:
        rows = fetch_all(
            """
            SELECT id, user_id, title, author, description, genre, cover_path, accent_hex,
                   status_text, rating
            FROM books
            WHERE user_id=%s AND id!=%s
              AND LOWER(COALESCE(status_text, 'draft')) NOT IN ('draft', 'unpublished', 'private')
            ORDER BY id DESC
            LIMIT 20
            """,
            (author_id, exclude_id),
        )
    else:
        rows = fetch_all(
            """
            SELECT id, user_id, title, author, description, genre, cover_path, accent_hex,
                   status_text, rating
            FROM books
            WHERE user_id=%s
              AND LOWER(COALESCE(status_text, 'draft')) NOT IN ('draft', 'unpublished', 'private')
            ORDER BY id DESC
            LIMIT 20
            """,
            (author_id,),
        )
    return {"items": [_serialize_book(row) for row in rows]}


@app.get("/api/authors/follow")
def fetch_authors_follow(
    ids: str = Query(default=""), user: dict[str, Any] = Depends(require_user)
):
    _ensure_author_follows_columns()
    # ids expected as comma-separated list of author ids, e.g. ids=1,2,3
    raw = ids or ""
    id_list = []
    for part in raw.split(","):
        part = part.strip()
        if not part:
            continue
        try:
            id_list.append(int(part))
        except ValueError:
            continue
    if not id_list:
        return {"following": {}}

    placeholders = ",".join(["%s"] * len(id_list))
    sql = f"SELECT author_id FROM author_follows WHERE user_id=%s AND author_id IN ({placeholders})"
    params: list[Any] = [user["user_id"]] + id_list
    rows = fetch_all(sql, tuple(params))
    followed = {r["author_id"] for r in rows}
    result = {str(i): (i in followed) for i in id_list}
    return {"following": result}


@app.delete("/api/write/stories/{story_id}")
def delete_writer_story(story_id: int, user: dict[str, Any] = Depends(require_user)):
    _, affected = execute_write(
        "DELETE FROM books WHERE id=%s AND (user_id=%s OR user_id IS NULL)",
        (story_id, user["user_id"]),
    )
    if affected == 0:
        raise HTTPException(status_code=404, detail="Story not found")
    bump_content_version()
    return {"ok": True}


@app.get("/api/admin/bootstrap")
def admin_bootstrap(_: dict[str, Any] = Depends(require_admin)):
    categories = fetch_all(
        "SELECT id, name, topic_count, tab_group, sort_order FROM categories ORDER BY tab_group, sort_order, id"
    )
    books = fetch_all(
        """
        SELECT id, title, author, description, cover_path, accent_hex, section_name,
               status_text, rating, genre, cta_label, sort_order
        FROM books
        ORDER BY sort_order, id
        """
    )
    notifications = fetch_all(
        "SELECT id, tab_name, title, message, created_at, sort_order FROM notifications ORDER BY sort_order, id"
    )
    menu_items = fetch_all(
        "SELECT id, section_name, section_order, label, icon_name, route_name, sort_order FROM menu_items ORDER BY section_order, sort_order, id"
    )
    write_screen_rows = fetch_all(
        "SELECT id, manage_tabs, story_tabs, filter_label, sort_label, empty_title, empty_cta FROM write_screen ORDER BY id ASC LIMIT 1"
    )
    profile_rows = fetch_all(
        "SELECT id, display_name, username, following, followers, blocked, chapters_read, social_karma, day_streak FROM profiles ORDER BY id ASC LIMIT 1"
    )
    reading_lists = fetch_all(
        "SELECT id, profile_id, name, story_count, cover_path, sort_order FROM reading_lists ORDER BY sort_order, id"
    )
    achievements = fetch_all(
        "SELECT id, group_name, group_order, title, subtitle, progress_label, badge_value, style, sort_order FROM achievements ORDER BY group_order, sort_order, id"
    )
    support_requests = fetch_all(
        "SELECT id, email, first_name, issue, subject, description, device_type, attachment_path, status, created_at FROM support_requests ORDER BY created_at DESC, id DESC"
    )

    return {
        "categories": categories,
        "books": [
            {**book, "cover_path": _normalize_cover_path(book["cover_path"])}
            for book in books
        ],
        "notifications": notifications,
        "menu_items": menu_items,
        "write_screen": write_screen_rows[0] if write_screen_rows else None,
        "profile": profile_rows[0] if profile_rows else None,
        "reading_lists": reading_lists,
        "achievements": achievements,
        "support_requests": support_requests,
        "stats": {
            "category_count": len(categories),
            "book_count": len(books),
            "notification_count": len(notifications),
            "menu_item_count": len(menu_items),
            "reading_list_count": len(reading_lists),
            "achievement_count": len(achievements),
            "support_request_count": len(support_requests),
        },
    }


@app.get("/api/admin/support-requests")
def admin_get_support_requests(_: dict[str, Any] = Depends(require_admin)):
    rows = fetch_all(
        "SELECT id, email, first_name, issue, subject, description, device_type, attachment_path, status, created_at FROM support_requests ORDER BY created_at DESC, id DESC"
    )
    return {"items": rows}


@app.put("/api/admin/support-requests/{request_id}")
def admin_update_support_request(
    request_id: int,
    payload: SupportRequestUpdateRequest,
    _: dict[str, Any] = Depends(require_admin),
):
    _, affected = execute_write(
        "UPDATE support_requests SET status=%s WHERE id=%s",
        (payload.status, request_id),
    )
    if affected == 0:
        raise HTTPException(status_code=404, detail="Support request not found")
    bump_content_version()
    return {"ok": True}


@app.post("/api/admin/categories")
def admin_create_category(
    payload: CategoryCreateRequest,
    _: dict[str, Any] = Depends(require_admin),
):
    _, affected = execute_write(
        "INSERT INTO categories (name, topic_count, tab_group, sort_order) VALUES (%s, %s, %s, %s)",
        (payload.name, payload.topic_count, payload.tab_group, payload.sort_order),
    )
    if affected == 0:
        raise HTTPException(status_code=400, detail="Failed to create category")
    bump_content_version()
    return {"ok": True}


@app.put("/api/admin/categories/{category_id}")
def admin_update_category(
    category_id: int,
    payload: CategoryUpdateRequest,
    _: dict[str, Any] = Depends(require_admin),
):
    rows = fetch_all("SELECT * FROM categories WHERE id=%s", (category_id,))
    if not rows:
        raise HTTPException(status_code=404, detail="Category not found")

    current = rows[0]
    _, affected = execute_write(
        """
        UPDATE categories
        SET name=%s, topic_count=%s, tab_group=%s, sort_order=%s
        WHERE id=%s
        """,
        (
            payload.name or current["name"],
            payload.topic_count if payload.topic_count is not None else current["topic_count"],
            payload.tab_group or current["tab_group"],
            payload.sort_order if payload.sort_order is not None else current["sort_order"],
            category_id,
        ),
    )
    if affected == 0:
        raise HTTPException(status_code=400, detail="Failed to update category")
    bump_content_version()
    return {"ok": True}


@app.delete("/api/admin/categories/{category_id}")
def admin_delete_category(
    category_id: int,
    _: dict[str, Any] = Depends(require_admin),
):
    _, affected = execute_write("DELETE FROM categories WHERE id=%s", (category_id,))
    if affected == 0:
        raise HTTPException(status_code=404, detail="Category not found")
    bump_content_version()
    return {"ok": True}


@app.post("/api/admin/books")
def admin_create_book(
    payload: AdminBookCreateRequest,
    _: dict[str, Any] = Depends(require_admin),
):
    book_id, _ = execute_write(
        """
        INSERT INTO books (
            title, author, description, cover_path, accent_hex, section_name,
            status_text, rating, genre, cta_label, sort_order
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """,
        (
            payload.title,
            payload.author,
            payload.description,
            payload.cover_path,
            payload.accent_hex,
            payload.section_name,
            payload.status_text,
            payload.rating,
            payload.genre,
            payload.cta_label,
            payload.sort_order,
        ),
    )
    bump_content_version()
    return {"ok": True, "id": book_id}


@app.put("/api/admin/books/{book_id}")
def admin_update_book(
    book_id: int,
    payload: AdminBookUpdateRequest,
    _: dict[str, Any] = Depends(require_admin),
):
    rows = fetch_all("SELECT * FROM books WHERE id=%s", (book_id,))
    if not rows:
        raise HTTPException(status_code=404, detail="Book not found")

    current = rows[0]
    _, affected = execute_write(
        """
        UPDATE books
        SET title=%s, author=%s, description=%s, cover_path=%s, accent_hex=%s,
            section_name=%s, status_text=%s, rating=%s, genre=%s, cta_label=%s, sort_order=%s
        WHERE id=%s
        """,
        (
            payload.title or current["title"],
            payload.author or current["author"],
            payload.description or current["description"],
            payload.cover_path if payload.cover_path is not None else current["cover_path"],
            payload.accent_hex or current["accent_hex"],
            payload.section_name or current["section_name"],
            payload.status_text or current["status_text"],
            payload.rating if payload.rating is not None else current["rating"],
            payload.genre or current["genre"],
            payload.cta_label or current["cta_label"],
            payload.sort_order if payload.sort_order is not None else current["sort_order"],
            book_id,
        ),
    )
    if affected == 0:
        raise HTTPException(status_code=400, detail="Failed to update book")
    bump_content_version()
    return {"ok": True}


@app.delete("/api/admin/books/{book_id}")
def admin_delete_book(
    book_id: int,
    _: dict[str, Any] = Depends(require_admin),
):
    _, affected = execute_write("DELETE FROM books WHERE id=%s", (book_id,))
    if affected == 0:
        raise HTTPException(status_code=404, detail="Book not found")
    bump_content_version()
    return {"ok": True}


@app.get("/api/admin/notifications")
def admin_get_notifications(_: dict[str, Any] = Depends(require_admin)):
    rows = fetch_all(
        "SELECT id, tab_name, title, message, created_at, sort_order FROM notifications ORDER BY sort_order, id"
    )
    return {"items": rows}


@app.post("/api/admin/notifications")
def admin_create_notification(
    payload: AdminNotificationCreateRequest,
    _: dict[str, Any] = Depends(require_admin),
):
    row_id, _ = execute_write(
        """
        INSERT INTO notifications (tab_name, title, message, created_at, sort_order)
        VALUES (%s, %s, %s, %s, %s)
        """,
        (
            payload.tab_name,
            payload.title,
            payload.message,
            payload.created_at,
            payload.sort_order,
        ),
    )
    bump_content_version()
    return {"ok": True, "id": row_id}


@app.put("/api/admin/notifications/{notification_id}")
def admin_update_notification(
    notification_id: int,
    payload: AdminNotificationUpdateRequest,
    _: dict[str, Any] = Depends(require_admin),
):
    rows = fetch_all("SELECT * FROM notifications WHERE id=%s", (notification_id,))
    if not rows:
        raise HTTPException(status_code=404, detail="Notification not found")

    current = rows[0]
    _, affected = execute_write(
        """
        UPDATE notifications
        SET tab_name=%s, title=%s, message=%s, created_at=%s, sort_order=%s
        WHERE id=%s
        """,
        (
            payload.tab_name or current["tab_name"],
            payload.title or current["title"],
            payload.message or current["message"],
            payload.created_at or current["created_at"],
            payload.sort_order if payload.sort_order is not None else current["sort_order"],
            notification_id,
        ),
    )
    if affected == 0:
        raise HTTPException(status_code=400, detail="Failed to update notification")
    bump_content_version()
    return {"ok": True}


@app.delete("/api/admin/notifications/{notification_id}")
def admin_delete_notification(
    notification_id: int,
    _: dict[str, Any] = Depends(require_admin),
):
    _, affected = execute_write("DELETE FROM notifications WHERE id=%s", (notification_id,))
    if affected == 0:
        raise HTTPException(status_code=404, detail="Notification not found")
    bump_content_version()
    return {"ok": True}


@app.get("/api/admin/menu-items")
def admin_get_menu_items(_: dict[str, Any] = Depends(require_admin)):
    rows = fetch_all(
        "SELECT id, section_name, section_order, label, icon_name, route_name, sort_order FROM menu_items ORDER BY section_order, sort_order, id"
    )
    return {"items": rows}


@app.post("/api/admin/menu-items")
def admin_create_menu_item(
    payload: AdminMenuItemCreateRequest,
    _: dict[str, Any] = Depends(require_admin),
):
    row_id, _ = execute_write(
        """
        INSERT INTO menu_items (section_name, section_order, label, icon_name, route_name, sort_order)
        VALUES (%s, %s, %s, %s, %s, %s)
        """,
        (
            payload.section_name,
            payload.section_order,
            payload.label,
            payload.icon_name,
            payload.route_name,
            payload.sort_order,
        ),
    )
    bump_content_version()
    return {"ok": True, "id": row_id}


@app.put("/api/admin/menu-items/{menu_item_id}")
def admin_update_menu_item(
    menu_item_id: int,
    payload: AdminMenuItemUpdateRequest,
    _: dict[str, Any] = Depends(require_admin),
):
    rows = fetch_all("SELECT * FROM menu_items WHERE id=%s", (menu_item_id,))
    if not rows:
        raise HTTPException(status_code=404, detail="Menu item not found")

    current = rows[0]
    _, affected = execute_write(
        """
        UPDATE menu_items
        SET section_name=%s, section_order=%s, label=%s, icon_name=%s, route_name=%s, sort_order=%s
        WHERE id=%s
        """,
        (
            payload.section_name or current["section_name"],
            payload.section_order if payload.section_order is not None else current["section_order"],
            payload.label or current["label"],
            payload.icon_name or current["icon_name"],
            payload.route_name or current["route_name"],
            payload.sort_order if payload.sort_order is not None else current["sort_order"],
            menu_item_id,
        ),
    )
    if affected == 0:
        raise HTTPException(status_code=400, detail="Failed to update menu item")
    bump_content_version()
    return {"ok": True}


@app.delete("/api/admin/menu-items/{menu_item_id}")
def admin_delete_menu_item(
    menu_item_id: int,
    _: dict[str, Any] = Depends(require_admin),
):
    _, affected = execute_write("DELETE FROM menu_items WHERE id=%s", (menu_item_id,))
    if affected == 0:
        raise HTTPException(status_code=404, detail="Menu item not found")
    bump_content_version()
    return {"ok": True}


@app.get("/api/admin/write-screen")
def admin_get_write_screen(_: dict[str, Any] = Depends(require_admin)):
    rows = fetch_all(
        "SELECT id, manage_tabs, story_tabs, filter_label, sort_label, empty_title, empty_cta FROM write_screen ORDER BY id ASC LIMIT 1"
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Write screen config not found")
    return rows[0]


@app.put("/api/admin/write-screen")
def admin_update_write_screen(
    payload: AdminWriteScreenUpdateRequest,
    _: dict[str, Any] = Depends(require_admin),
):
    rows = fetch_all("SELECT id FROM write_screen ORDER BY id ASC LIMIT 1")
    if not rows:
        execute_write(
            """
            INSERT INTO write_screen (manage_tabs, story_tabs, filter_label, sort_label, empty_title, empty_cta)
            VALUES (%s, %s, %s, %s, %s, %s)
            """,
            (
                payload.manage_tabs,
                payload.story_tabs,
                payload.filter_label,
                payload.sort_label,
                payload.empty_title,
                payload.empty_cta,
            ),
        )
        bump_content_version()
        return {"ok": True}

    _, affected = execute_write(
        """
        UPDATE write_screen
        SET manage_tabs=%s, story_tabs=%s, filter_label=%s, sort_label=%s, empty_title=%s, empty_cta=%s
        WHERE id=%s
        """,
        (
            payload.manage_tabs,
            payload.story_tabs,
            payload.filter_label,
            payload.sort_label,
            payload.empty_title,
            payload.empty_cta,
            rows[0]["id"],
        ),
    )
    if affected == 0:
        raise HTTPException(status_code=400, detail="Failed to update write screen config")
    bump_content_version()
    return {"ok": True}


@app.get("/api/admin/profile")
def admin_get_profile(_: dict[str, Any] = Depends(require_admin)):
    rows = fetch_all(
        "SELECT id, display_name, username, following, followers, blocked, chapters_read, social_karma, day_streak FROM profiles ORDER BY id ASC LIMIT 1"
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Profile not found")
    return rows[0]


@app.put("/api/admin/profile")
def admin_update_profile(
    payload: AdminProfileUpdateRequest,
    _: dict[str, Any] = Depends(require_admin),
):
    rows = fetch_all("SELECT id FROM profiles ORDER BY id ASC LIMIT 1")
    if not rows:
        execute_write(
            """
            INSERT INTO profiles (display_name, username, following, followers, blocked, chapters_read, social_karma, day_streak)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """,
            (
                payload.display_name,
                payload.username,
                payload.following,
                payload.followers,
                payload.blocked,
                payload.chapters_read,
                payload.social_karma,
                payload.day_streak,
            ),
        )
        bump_content_version()
        return {"ok": True}

    _, affected = execute_write(
        """
        UPDATE profiles
        SET display_name=%s, username=%s, following=%s, followers=%s, blocked=%s,
            chapters_read=%s, social_karma=%s, day_streak=%s
        WHERE id=%s
        """,
        (
            payload.display_name,
            payload.username,
            payload.following,
            payload.followers,
            payload.blocked,
            payload.chapters_read,
            payload.social_karma,
            payload.day_streak,
            rows[0]["id"],
        ),
    )
    if affected == 0:
        raise HTTPException(status_code=400, detail="Failed to update profile")
    bump_content_version()
    return {"ok": True}


@app.get("/api/admin/reading-lists")
def admin_get_reading_lists(_: dict[str, Any] = Depends(require_admin)):
    rows = fetch_all(
        "SELECT id, profile_id, name, story_count, cover_path, sort_order FROM reading_lists ORDER BY sort_order, id"
    )
    return {"items": rows}


@app.post("/api/admin/reading-lists")
def admin_create_reading_list(
    payload: AdminReadingListCreateRequest,
    _: dict[str, Any] = Depends(require_admin),
):
    row_id, _ = execute_write(
        """
        INSERT INTO reading_lists (profile_id, name, story_count, cover_path, sort_order)
        VALUES (%s, %s, %s, %s, %s)
        """,
        (
            payload.profile_id,
            payload.name,
            payload.story_count,
            payload.cover_path,
            payload.sort_order,
        ),
    )
    bump_content_version()
    return {"ok": True, "id": row_id}


@app.put("/api/admin/reading-lists/{list_id}")
def admin_update_reading_list(
    list_id: int,
    payload: AdminReadingListUpdateRequest,
    _: dict[str, Any] = Depends(require_admin),
):
    rows = fetch_all("SELECT * FROM reading_lists WHERE id=%s", (list_id,))
    if not rows:
        raise HTTPException(status_code=404, detail="Reading list not found")

    current = rows[0]
    _, affected = execute_write(
        """
        UPDATE reading_lists
        SET profile_id=%s, name=%s, story_count=%s, cover_path=%s, sort_order=%s
        WHERE id=%s
        """,
        (
            payload.profile_id if payload.profile_id is not None else current["profile_id"],
            payload.name or current["name"],
            payload.story_count if payload.story_count is not None else current["story_count"],
            payload.cover_path if payload.cover_path is not None else current["cover_path"],
            payload.sort_order if payload.sort_order is not None else current["sort_order"],
            list_id,
        ),
    )
    if affected == 0:
        raise HTTPException(status_code=400, detail="Failed to update reading list")
    bump_content_version()
    return {"ok": True}


@app.delete("/api/admin/reading-lists/{list_id}")
def admin_delete_reading_list(
    list_id: int,
    _: dict[str, Any] = Depends(require_admin),
):
    _, affected = execute_write("DELETE FROM reading_lists WHERE id=%s", (list_id,))
    if affected == 0:
        raise HTTPException(status_code=404, detail="Reading list not found")
    bump_content_version()
    return {"ok": True}


@app.get("/api/admin/achievements")
def admin_get_achievements(_: dict[str, Any] = Depends(require_admin)):
    rows = fetch_all(
        "SELECT id, group_name, group_order, title, subtitle, progress_label, badge_value, style, sort_order FROM achievements ORDER BY group_order, sort_order, id"
    )
    return {"items": rows}


@app.post("/api/admin/achievements")
def admin_create_achievement(
    payload: AdminAchievementCreateRequest,
    _: dict[str, Any] = Depends(require_admin),
):
    row_id, _ = execute_write(
        """
        INSERT INTO achievements (group_name, group_order, title, subtitle, progress_label, badge_value, style, sort_order)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """,
        (
            payload.group_name,
            payload.group_order,
            payload.title,
            payload.subtitle,
            payload.progress_label,
            payload.badge_value,
            payload.style,
            payload.sort_order,
        ),
    )
    bump_content_version()
    return {"ok": True, "id": row_id}


@app.put("/api/admin/achievements/{achievement_id}")
def admin_update_achievement(
    achievement_id: int,
    payload: AdminAchievementUpdateRequest,
    _: dict[str, Any] = Depends(require_admin),
):
    rows = fetch_all("SELECT * FROM achievements WHERE id=%s", (achievement_id,))
    if not rows:
        raise HTTPException(status_code=404, detail="Achievement not found")

    current = rows[0]
    _, affected = execute_write(
        """
        UPDATE achievements
        SET group_name=%s, group_order=%s, title=%s, subtitle=%s,
            progress_label=%s, badge_value=%s, style=%s, sort_order=%s
        WHERE id=%s
        """,
        (
            payload.group_name or current["group_name"],
            payload.group_order if payload.group_order is not None else current["group_order"],
            payload.title or current["title"],
            payload.subtitle or current["subtitle"],
            payload.progress_label or current["progress_label"],
            payload.badge_value or current["badge_value"],
            payload.style or current["style"],
            payload.sort_order if payload.sort_order is not None else current["sort_order"],
            achievement_id,
        ),
    )
    if affected == 0:
        raise HTTPException(status_code=400, detail="Failed to update achievement")
    bump_content_version()
    return {"ok": True}


@app.delete("/api/admin/achievements/{achievement_id}")
def admin_delete_achievement(
    achievement_id: int,
    _: dict[str, Any] = Depends(require_admin),
):
    _, affected = execute_write("DELETE FROM achievements WHERE id=%s", (achievement_id,))
    if affected == 0:
        raise HTTPException(status_code=404, detail="Achievement not found")
    bump_content_version()
    return {"ok": True}


# ----- Public profile data (wired to real tables) -----

@app.get("/api/users/{user_id}/stories")
def list_user_stories(user_id: int):
    """Public stories authored by user_id."""
    rows = fetch_all(
        """
        SELECT id, user_id, title, author, description, genre, cover_path, accent_hex,
               status_text, rating, primary_genre, secondary_genre, is_completed
        FROM books
        WHERE user_id=%s
        ORDER BY id DESC
        LIMIT 100
        """,
        (user_id,),
    )
    return {"items": [_serialize_book(row) for row in rows]}


@app.get("/api/users/{user_id}/reading-lists")
def list_user_reading_lists(user_id: int):
    """Public reading lists for a user profile."""
    rows = fetch_all(
        """
        SELECT id, name, story_count, cover_path, is_public
        FROM reading_lists
        WHERE user_id=%s AND (is_public IS NULL OR is_public=1 OR is_public=TRUE)
        ORDER BY id DESC
        LIMIT 50
        """,
        (user_id,),
    )
    items = []
    for row in rows:
        cover = _normalize_cover_path(_row_get(row, "cover_path") or "")
        # collage covers from list items if available
        covers = []
        try:
            lid = _row_get(row, "id")
            if lid is not None:
                item_rows = fetch_all(
                    """
                    SELECT b.cover_path FROM reading_list_items rli
                    JOIN books b ON b.id = rli.book_id
                    WHERE rli.reading_list_id=%s
                    LIMIT 4
                    """,
                    (lid,),
                )
                for ir in item_rows:
                    p = _normalize_cover_path(_row_get(ir, "cover_path") or "")
                    if p:
                        covers.append(p)
        except Exception:
            pass
        items.append({
            "id": _row_get(row, "id"),
            "name": _row_get(row, "name") or "List",
            "story_count": int(_row_get(row, "story_count") or 0),
            "cover_path": cover,
            "covers": covers,
        })
    return {"items": items}


@app.get("/api/users/{user_id}/reviews")
def list_user_reviews(user_id: int):
    """Reviews written by this user."""
    rows = fetch_all(
        """
        SELECT r.id, r.book_id, r.user_id, r.rating, r.comment, r.created_at,
               b.title AS book_title, b.cover_path, b.author AS book_author,
               u.display_name AS reviewer_name
        FROM book_reviews r
        LEFT JOIN books b ON b.id = r.book_id
        LEFT JOIN app_users u ON u.id = r.user_id
        WHERE r.user_id=%s
        ORDER BY r.id DESC
        LIMIT 100
        """,
        (user_id,),
    )
    items = []
    for row in rows:
        comment = _row_get(row, "comment") or ""
        rating = int(_row_get(row, "rating") or 5)
        items.append({
            "id": _row_get(row, "id"),
            "book_id": _row_get(row, "book_id"),
            "book_title": _row_get(row, "book_title") or "Story",
            "book_author": _row_get(row, "book_author") or "",
            "cover_path": _normalize_cover_path(_row_get(row, "cover_path") or ""),
            "rating": rating,
            "comment": comment,
            "title": comment.split("\n")[0][:80] if comment else "Review",
            "plot": min(5, max(1, rating)),
            "writing_style": min(5, max(1, rating)),
            "grammar": min(5, max(1, max(1, rating - 1))),
            "created_at": str(_row_get(row, "created_at") or ""),
        })
    return {"items": items}


@app.get("/api/users/{user_id}/wall")
def list_user_wall(user_id: int):
    """Profile Wall: posts on this user's wall (real data from wall_posts)."""
    _ensure_wall_posts_table()
    try:
        rows = fetch_all(
            """
            SELECT id, user_id, target_user_id, body, image_path, likes_count, created_at
            FROM wall_posts
            WHERE target_user_id=%s OR user_id=%s
            ORDER BY id DESC
            LIMIT 80
            """,
            (user_id, user_id),
        )
    except Exception:
        rows = []
    items = []
    for row in rows:
        uid = _row_get(row, "user_id")
        uname = "User"
        photo = ""
        try:
            urows = fetch_all(
                "SELECT display_name, photo_url FROM app_users WHERE id=%s LIMIT 1",
                (uid,),
            )
            if urows:
                uname = _row_get(urows[0], "display_name") or uname
                photo = _row_get(urows[0], "photo_url") or ""
        except Exception:
            pass
        items.append({
            "id": _row_get(row, "id"),
            "user_id": uid,
            "sender_name": uname,
            "display_name": uname,
            "photo_url": photo,
            "body": _row_get(row, "body") or "",
            "message": _row_get(row, "body") or "",
            "image_path": _normalize_cover_path(_row_get(row, "image_path") or ""),
            "created_at": str(_row_get(row, "created_at") or ""),
            "likes": int(_row_get(row, "likes_count") or 0),
        })
    return {"items": items}


@app.post("/api/users/{user_id}/wall")
def post_user_wall(
    user_id: int,
    payload: dict[str, Any],
    user: dict[str, Any] = Depends(require_user),
):
    """Create a wall post on target user's profile (requires login)."""
    _ensure_wall_posts_table()
    body = (payload.get("body") or payload.get("message") or "").strip()
    if not body:
        raise HTTPException(status_code=400, detail="Empty post")
    image_path = payload.get("image_path") or payload.get("image_url") or ""
    row_id, _ = execute_write(
        """
        INSERT INTO wall_posts (user_id, target_user_id, body, image_path, likes_count, created_at)
        VALUES (%s, %s, %s, %s, 0, CURRENT_TIMESTAMP)
        """,
        (user["user_id"], user_id, body, image_path),
    )
    return {"ok": True, "id": row_id}


# ----- Admin: users list + ban / unban -----

@app.get("/api/admin/users")
def admin_list_users(_: dict[str, Any] = Depends(require_admin)):
    try:
        rows = fetch_all(
            """
            SELECT id, email, display_name, photo_url, provider, bio,
                   COALESCE(is_banned, 0) AS is_banned,
                   COALESCE(is_suspended, 0) AS is_suspended,
                   COALESCE(is_deleted, 0) AS is_deleted,
                   suspended_until,
                   COALESCE(is_author, 0) AS is_author,
                   COALESCE(is_author_active, 1) AS is_author_active
            FROM app_users
            ORDER BY id DESC
            LIMIT 500
            """
        )
    except Exception:
        rows = fetch_all(
            "SELECT id, email, display_name, photo_url, provider, bio FROM app_users ORDER BY id DESC LIMIT 500"
        )
    items = []
    for row in rows:
        uid = _row_get(row, "id")
        story_c = fetch_all("SELECT COUNT(*) AS c FROM books WHERE user_id=%s", (uid,))
        fol_c = fetch_all("SELECT COUNT(*) AS c FROM author_follows WHERE author_id=%s", (uid,))
        items.append({
            "id": uid,
            "email": _row_get(row, "email") or "",
            "display_name": _row_get(row, "display_name") or "",
            "photo_url": _row_get(row, "photo_url") or "",
            "provider": _row_get(row, "provider") or "",
            "bio": _row_get(row, "bio") or "",
            "is_banned": bool(int(_row_get(row, "is_banned") or 0)),
            "is_suspended": bool(int(_row_get(row, "is_suspended") or 0)),
            "is_deleted": bool(int(_row_get(row, "is_deleted") or 0)),
            "suspended_until": str(_row_get(row, "suspended_until") or "") or None,
            "is_author": bool(int(_row_get(row, "is_author") or 0)) or int(story_c[0]["c"] if story_c else 0) > 0,
            "is_author_active": bool(int(_row_get(row, "is_author_active") if _row_get(row, "is_author_active") is not None else 1)),
            "story_count": int(story_c[0]["c"]) if story_c else 0,
            "followers": int(fol_c[0]["c"]) if fol_c else 0,
        })
    return {"items": items}


@app.post("/api/admin/users/{user_id}/ban")
def admin_ban_user(user_id: int, _: dict[str, Any] = Depends(require_admin)):
    try:
        execute_write("ALTER TABLE app_users ADD COLUMN is_banned INT NOT NULL DEFAULT 0", ())
    except Exception:
        pass
    execute_write("UPDATE app_users SET is_banned=1 WHERE id=%s", (user_id,))
    return {"ok": True, "is_banned": True}


@app.post("/api/admin/users/{user_id}/unban")
def admin_unban_user(user_id: int, _: dict[str, Any] = Depends(require_admin)):
    try:
        execute_write("UPDATE app_users SET is_banned=0 WHERE id=%s", (user_id,))
    except Exception:
        pass
    return {"ok": True, "is_banned": False}



@app.post("/api/admin/users/{user_id}/suspend")
def admin_suspend_user(
    user_id: int,
    payload: dict[str, Any] | None = None,
    _: dict[str, Any] = Depends(require_admin),
):
    """Suspend for N days (body: {"days": 7}). User cannot log in until suspended_until passes."""
    _ensure_user_moderation_columns()
    body = payload or {}
    days = int(body.get("days") or body.get("suspend_days") or 7)
    if days < 1:
        days = 1
    if days > 3650:
        days = 3650
    until = (datetime.now(timezone.utc) + timedelta(days=days)).isoformat()
    execute_write(
        "UPDATE app_users SET is_suspended=1, suspended_until=%s WHERE id=%s",
        (until, user_id),
    )
    return {"ok": True, "is_suspended": True, "suspended_until": until, "days": days}


@app.post("/api/admin/users/{user_id}/unsuspend")
def admin_unsuspend_user(user_id: int, _: dict[str, Any] = Depends(require_admin)):
    _ensure_user_moderation_columns()
    execute_write(
        "UPDATE app_users SET is_suspended=0, suspended_until=NULL WHERE id=%s",
        (user_id,),
    )
    return {"ok": True, "is_suspended": False}


@app.post("/api/admin/users/{user_id}/activate")
def admin_activate_user(user_id: int, _: dict[str, Any] = Depends(require_admin)):
    """Clear ban + suspend flags — full access restored."""
    try:
        execute_write(
            "UPDATE app_users SET is_banned=0, is_suspended=0 WHERE id=%s",
            (user_id,),
        )
    except Exception:
        try:
            execute_write("UPDATE app_users SET is_banned=0 WHERE id=%s", (user_id,))
        except Exception:
            pass
    return {"ok": True, "is_banned": False, "is_suspended": False}

@app.delete("/api/admin/users/{user_id}")
def admin_delete_user(user_id: int, _: dict[str, Any] = Depends(require_admin)):
    """Soft-delete: keep row, flag is_deleted so login is permanently blocked until restored."""
    _ensure_user_moderation_columns()
    execute_write(
        "UPDATE app_users SET is_deleted=1, is_banned=1 WHERE id=%s",
        (user_id,),
    )
    return {"ok": True, "is_deleted": True}


@app.post("/api/admin/users/{user_id}/restore")
def admin_restore_user(user_id: int, _: dict[str, Any] = Depends(require_admin)):
    _ensure_user_moderation_columns()
    execute_write(
        "UPDATE app_users SET is_deleted=0, is_banned=0, is_suspended=0, suspended_until=NULL WHERE id=%s",
        (user_id,),
    )
    return {"ok": True, "is_deleted": False}


@app.post("/api/admin/users/{user_id}/author-active")
def admin_set_author_active(
    user_id: int,
    payload: dict[str, Any] | None = None,
    _: dict[str, Any] = Depends(require_admin),
):
    _ensure_user_moderation_columns()
    body = payload or {}
    active = 1 if body.get("active", True) in (True, 1, "1", "true", "True") else 0
    execute_write("UPDATE app_users SET is_author_active=%s WHERE id=%s", (active, user_id))
    return {"ok": True, "is_author_active": bool(active)}


@app.get("/api/users/{user_id}/activity")
def list_user_activity(user_id: int):
    """Real activity feed: story updates + wall-ish posts from this user."""
    items: list[dict[str, Any]] = []
    try:
        books = fetch_all(
            """
            SELECT id, title, cover_path, status_text, updated_at, created_at
            FROM books WHERE user_id=%s
            ORDER BY COALESCE(updated_at, created_at) DESC, id DESC
            LIMIT 30
            """,
            (user_id,),
        )
        for b in books:
            when = str(_row_get(b, "updated_at") or _row_get(b, "created_at") or "")
            items.append({
                "id": f"book-{_row_get(b, 'id')}",
                "type": "story_update",
                "title": f"Updated {_row_get(b, 'title') or 'a story'}",
                "message": _row_get(b, "status_text") or "",
                "cover_path": _normalize_cover_path(_row_get(b, "cover_path") or ""),
                "book_id": _row_get(b, "id"),
                "created_at": when,
            })
    except Exception:
        pass
    try:
        posts = fetch_all(
            """
            SELECT id, body, created_at FROM chat_messages
            WHERE user_id=%s ORDER BY id DESC LIMIT 20
            """,
            (user_id,),
        )
        for p in posts:
            items.append({
                "id": f"wall-{_row_get(p, 'id')}",
                "type": "wall",
                "title": "Posted on wall",
                "message": (_row_get(p, "body") or "")[:200],
                "cover_path": "",
                "created_at": str(_row_get(p, "created_at") or ""),
            })
    except Exception:
        pass
    items.sort(key=lambda x: str(x.get("created_at") or ""), reverse=True)
    return {"items": items[:40]}

try:
    from .inkitt_routes import register_inkitt_routes

    def _fetch_one(query: str, params: tuple[Any, ...] | None = None):
        rows = fetch_all(query, params)
        return rows[0] if rows else None

    register_inkitt_routes(
        app,
        fetch_all=fetch_all,
        fetch_one=_fetch_one,
        execute_write=execute_write,
        require_user=require_user,
        require_admin=require_admin,
        bump_content_version=bump_content_version,
    )
except Exception as _inkitt_exc:
    LOGGER.warning("inkitt_routes not registered: %s", _inkitt_exc)

try:
    from .admin_tags import register_admin_tag_routes
    register_admin_tag_routes(
        app,
        require_admin=require_admin,
        fetch_all=fetch_all,
        execute_write=execute_write,
        bump_content_version=bump_content_version,
        LOGGER=LOGGER,
    )
except Exception as _admin_tags_exc:
    LOGGER.warning("admin_tags routes not registered: %s", _admin_tags_exc)

try:
    from .story_reports import register_story_report_routes
    register_story_report_routes(
        app,
        require_user=require_user,
        require_admin=require_admin,
        fetch_all=fetch_all,
        execute_write=execute_write,
        bump_content_version=bump_content_version,
        LOGGER=LOGGER,
        USE_SQLITE=USE_SQLITE,
    )
except Exception as _story_reports_exc:
    LOGGER.warning("story_reports routes not registered: %s", _story_reports_exc)

try:
    from .chapter_reactions import register_chapter_reaction_routes
    register_chapter_reaction_routes(
        app,
        require_user=require_user,
        fetch_all=fetch_all,
        execute_write=execute_write,
        LOGGER=LOGGER,
        USE_SQLITE=USE_SQLITE,
    )
except Exception as _chapter_reactions_exc:
    LOGGER.warning("chapter_reactions routes not registered: %s", _chapter_reactions_exc)

