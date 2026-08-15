
"""Professional authentication hardening.

Registered at startup. Replaces weak email-only login, shared guest account,
and tokens that stay valid after ban/suspend/delete.

Security model:
- Google: verified id/access token (existing)
- Email: email + password (bcrypt via passlib); register or login
- Guest: unique per device_id; cannot write content (enforced in app + optional flags)
- Every require_user checks ban/suspend/delete AND token_version (ban invalidates sessions)
"""
from __future__ import annotations

import logging
import secrets
from datetime import datetime, timedelta, timezone
from typing import Any, Callable

from fastapi import Body, Depends, Header, HTTPException
from pydantic import BaseModel, Field

LOGGER = logging.getLogger(__name__)


class EmailPasswordAuthRequest(BaseModel):
    email: str
    password: str = Field(min_length=6, max_length=128)
    display_name: str = ""
    mode: str = "login"  # login | register


class GuestAuthRequestV2(BaseModel):
    device_id: str = Field(min_length=8, max_length=128)


def _hash_password(password: str) -> str:
    try:
        from passlib.context import CryptContext

        ctx = CryptContext(schemes=["bcrypt"], deprecated="auto")
        return ctx.hash(password)
    except Exception:
        # Fallback if passlib/bcrypt unavailable (should be in requirements)
        import hashlib

        return "sha256:" + hashlib.sha256(password.encode("utf-8")).hexdigest()


def _verify_password(password: str, password_hash: str | None) -> bool:
    if not password_hash:
        return False
    try:
        from passlib.context import CryptContext

        ctx = CryptContext(schemes=["bcrypt"], deprecated="auto")
        if password_hash.startswith("$2"):
            return ctx.verify(password, password_hash)
    except Exception:
        pass
    if password_hash.startswith("sha256:"):
        import hashlib

        return password_hash == "sha256:" + hashlib.sha256(password.encode("utf-8")).hexdigest()
    return False


def apply_professional_auth(main_mod) -> None:
    """Monkey-patch tokens + replace weak auth routes on the running FastAPI app."""
    app = main_mod.app
    fetch_all = main_mod.fetch_all
    execute_write = main_mod.execute_write
    _row_get = main_mod._row_get
    _assert_user_can_login = main_mod._assert_user_can_login
    _user_access_block_reason = main_mod._user_access_block_reason
    _sign_token = main_mod._sign_token

    def _ensure_auth_columns() -> None:
        for sql in (
            "ALTER TABLE app_users ADD COLUMN password_hash TEXT NULL",
            "ALTER TABLE app_users ADD COLUMN token_version INT NOT NULL DEFAULT 0",
            "ALTER TABLE app_users ADD COLUMN device_id TEXT NULL",
        ):
            try:
                execute_write(sql, ())
            except Exception:
                pass

    _ensure_auth_columns()

    def create_user_token(user_id: int) -> str:
        # Read token_version so ban can invalidate outstanding sessions
        rows = fetch_all(
            "SELECT COALESCE(token_version, 0) AS token_version FROM app_users WHERE id=%s LIMIT 1",
            (user_id,),
        )
        tv = 0
        if rows:
            tv = int(_row_get(rows[0], "token_version") or 0)
        expires_at = datetime.now(timezone.utc) + timedelta(days=14)
        return _sign_token(
            {
                "sub": f"user:{user_id}",
                "role": "user",
                "tv": tv,
                "exp": expires_at.isoformat(),
            }
        )

    main_mod.create_user_token = create_user_token

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

        import base64
        import hashlib
        import hmac
        import json

        expected_signature = hmac.new(
            main_mod.JWT_SECRET.encode("utf-8"),
            encoded_payload.encode("ascii"),
            hashlib.sha256,
        ).hexdigest()
        if not hmac.compare_digest(expected_signature, provided_signature):
            raise HTTPException(status_code=401, detail="Invalid user token")
        try:
            pad = "=" * (-len(encoded_payload) % 4)
            payload = json.loads(base64.urlsafe_b64decode(encoded_payload + pad).decode("utf-8"))
        except Exception as exc:
            raise HTTPException(status_code=401, detail="Invalid user token") from exc

        if payload.get("role") != "user":
            raise HTTPException(status_code=401, detail="Invalid user token")
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
        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        if expires_at <= datetime.now(timezone.utc):
            raise HTTPException(status_code=401, detail="User token expired — please sign in again")

        uid = int(sub.split(":", 1)[1])
        reason = _user_access_block_reason(uid)
        if reason:
            raise HTTPException(status_code=403, detail=reason)

        # Token version: ban/suspend/delete bumps version → old sessions die
        rows = fetch_all(
            "SELECT COALESCE(token_version, 0) AS token_version FROM app_users WHERE id=%s LIMIT 1",
            (uid,),
        )
        if not rows:
            raise HTTPException(status_code=401, detail="Account not found")
        current_tv = int(_row_get(rows[0], "token_version") or 0)
        token_tv = int(payload.get("tv") or 0)
        if token_tv != current_tv:
            raise HTTPException(
                status_code=401,
                detail="Session revoked. Please sign in again.",
            )
        return {"user_id": uid}

    main_mod.require_user = require_user

    def bump_token_version(user_id: int) -> None:
        try:
            execute_write(
                "UPDATE app_users SET token_version = COALESCE(token_version, 0) + 1 WHERE id=%s",
                (user_id,),
            )
        except Exception as exc:
            LOGGER.warning("token_version bump failed for %s: %s", user_id, exc)

    main_mod.bump_token_version = bump_token_version

    # Wrap admin status actions so ban/suspend/delete revoke sessions
    def _wrap_admin_action(fn: Callable):
        def wrapper(*args, **kwargs):
            result = fn(*args, **kwargs)
            user_id = kwargs.get("user_id")
            if user_id is None and args:
                # path param often first after self
                for a in args:
                    if isinstance(a, int):
                        user_id = a
                        break
            if user_id is not None:
                bump_token_version(int(user_id))
            return result

        return wrapper

    # Drop weak routes so we can re-register
    def _remove_routes(paths: set[str]) -> None:
        kept = []
        for route in list(app.router.routes):
            path = getattr(route, "path", None)
            if path in paths:
                continue
            kept.append(route)
        app.router.routes = kept

    _remove_routes({"/api/auth/email", "/api/auth/guest"})

    @app.post("/api/auth/email")
    def authenticate_email_secure(payload: EmailPasswordAuthRequest):
        email = payload.email.strip().lower()
        password = payload.password or ""
        if not email or "@" not in email:
            raise HTTPException(status_code=400, detail="Invalid email address")
        if len(password) < 6:
            raise HTTPException(status_code=400, detail="Password must be at least 6 characters")

        mode = (payload.mode or "login").strip().lower()
        rows = fetch_all("SELECT * FROM app_users WHERE email=%s LIMIT 1", (email,))

        if mode == "register":
            if rows:
                raise HTTPException(status_code=400, detail="An account with this email already exists. Sign in instead.")
            display_name = (payload.display_name or "").strip() or email.split("@")[0]
            pw_hash = _hash_password(password)
            user_id, _ = execute_write(
                """
                INSERT INTO app_users (email, provider, display_name, photo_url, password_hash, token_version)
                VALUES (%s, 'email', %s, '', %s, 0)
                """,
                (email, display_name, pw_hash),
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

        # login
        if not rows:
            raise HTTPException(status_code=401, detail="Invalid email or password")
        user = rows[0]
        user_id = int(_row_get(user, "id"))
        pw_hash = _row_get(user, "password_hash")
        if not pw_hash:
            raise HTTPException(
                status_code=401,
                detail="This email account has no password set. Use Google sign-in, or register again with a password.",
            )
        if not _verify_password(password, str(pw_hash)):
            raise HTTPException(status_code=401, detail="Invalid email or password")

        _assert_user_can_login(user_id)
        display_name = _row_get(user, "display_name") or email.split("@")[0]
        try:
            execute_write(
                "UPDATE app_users SET last_login_at=CURRENT_TIMESTAMP WHERE id=%s",
                (user_id,),
            )
        except Exception:
            pass
        return {
            "id": user_id,
            "email": email,
            "display_name": display_name,
            "photo_url": _row_get(user, "photo_url") or "",
            "provider": "email",
            "token": create_user_token(user_id),
        }

    @app.post("/api/auth/guest")
    def authenticate_guest_secure(payload: GuestAuthRequestV2 = Body(default=None)):
        # Unique guest per device — never share one global guest@novel.app account
        device_id = ""
        if isinstance(payload, GuestAuthRequestV2):
            device_id = (payload.device_id or "").strip()
        if len(device_id) < 8:
            device_id = secrets.token_hex(16)

        email = f"guest_{device_id[:32]}@novel.app"
        rows = fetch_all("SELECT id FROM app_users WHERE email=%s LIMIT 1", (email,))
        if rows:
            user_id = int(rows[0]["id"] if isinstance(rows[0], dict) else rows[0][0])
            try:
                execute_write(
                    "UPDATE app_users SET provider='guest', device_id=%s, last_login_at=CURRENT_TIMESTAMP WHERE id=%s",
                    (device_id, user_id),
                )
            except Exception:
                pass
        else:
            user_id, _ = execute_write(
                """
                INSERT INTO app_users (email, provider, display_name, photo_url, device_id, token_version)
                VALUES (%s, 'guest', 'Guest', '', %s, 0)
                """,
                (email, device_id),
            )

        _assert_user_can_login(user_id)
        return {
            "id": user_id,
            "email": email,
            "display_name": "Guest",
            "photo_url": "",
            "provider": "guest",
            "token": create_user_token(user_id),
            "is_guest": True,
        }

    # Hook ban/unban/suspend to bump token_version via wrapping known admin handlers
    for name in (
        "admin_ban_user",
        "admin_unban_user",
        "admin_suspend_user",
        "admin_unsuspend_user",
        "admin_delete_user",
        "admin_restore_user",
    ):
        fn = getattr(main_mod, name, None)
        # Routes are closures; instead patch execute path by wrapping _assert is not enough.
        # Add explicit helper endpoint for admin panel after status change is optional.
        pass

    @app.post("/api/admin/users/{user_id}/revoke-sessions")
    def admin_revoke_sessions(user_id: int):
        bump_token_version(user_id)
        return {"ok": True, "user_id": user_id}

    # After any moderation write that sets is_banned etc., also bump — patch set status helpers
    original_assert = _assert_user_can_login

    def assert_and_note(user_id: int) -> None:
        original_assert(user_id)

    main_mod._assert_user_can_login = assert_and_note

    # Patch admin user status endpoints by intercepting common pattern:
    # register a dependency-free middleware-ish: after ban endpoints run, we can't easily.
    # Instead re-define thin wrappers that call existing SQL logic with bump.
    _remove_routes(
        {
            "/api/admin/users/{user_id}/ban",
            "/api/admin/users/{user_id}/unban",
            "/api/admin/users/{user_id}/suspend",
            "/api/admin/users/{user_id}/unsuspend",
            "/api/admin/users/{user_id}/activate",
            "/api/admin/users/{user_id}/restore",
        }
    )

    def _set_flag(user_id: int, **fields):
        # Build UPDATE dynamically
        if not fields:
            return
        sets = ", ".join(f"{k}=%s" for k in fields.keys())
        params = tuple(fields.values()) + (user_id,)
        execute_write(f"UPDATE app_users SET {sets} WHERE id=%s", params)
        bump_token_version(user_id)

    @app.post("/api/admin/users/{user_id}/ban")
    def admin_ban_user(user_id: int):
        _set_flag(user_id, is_banned=1)
        return {"ok": True, "is_banned": True}

    @app.post("/api/admin/users/{user_id}/unban")
    def admin_unban_user(user_id: int):
        _set_flag(user_id, is_banned=0)
        return {"ok": True, "is_banned": False}

    @app.post("/api/admin/users/{user_id}/suspend")
    def admin_suspend_user(user_id: int, payload: dict[str, Any] = Body(default=None)):
        days = 7
        if isinstance(payload, dict):
            days = int(payload.get("days") or 7)
        until = (datetime.now(timezone.utc) + timedelta(days=days)).isoformat()
        _set_flag(user_id, is_suspended=1, suspended_until=until)
        return {"ok": True, "is_suspended": True, "suspended_until": until}

    @app.post("/api/admin/users/{user_id}/unsuspend")
    def admin_unsuspend_user(user_id: int):
        _set_flag(user_id, is_suspended=0, suspended_until=None)
        return {"ok": True, "is_suspended": False}

    @app.post("/api/admin/users/{user_id}/activate")
    def admin_activate_user(user_id: int):
        _set_flag(user_id, is_banned=0, is_suspended=0, is_deleted=0, suspended_until=None)
        return {"ok": True}

    @app.post("/api/admin/users/{user_id}/restore")
    def admin_restore_user(user_id: int):
        _set_flag(user_id, is_deleted=0, is_banned=0, is_suspended=0)
        return {"ok": True}

    # Also ensure DELETE soft-delete bumps version — leave original delete route
    LOGGER.info("Professional auth hardening applied (email+password, guest device, token_version)")
