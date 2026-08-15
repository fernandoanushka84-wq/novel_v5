"""Runtime DB mode helpers: MySQL probe + SQLite fallback for local dev."""
from __future__ import annotations

import os
from typing import Any


def apply_mysql_fallback_if_needed(db_mod: Any) -> dict[str, Any]:
    """If MySQL is configured but unreachable, switch db_mod to SQLite."""
    info: dict[str, Any] = {
        "db_mode": "sqlite" if getattr(db_mod, "USE_SQLITE", True) else "mysql",
    }
    if getattr(db_mod, "USE_SQLITE", True):
        return info

    fallback = str(os.getenv("MYSQL_FALLBACK_SQLITE", "true")).strip().lower() in {
        "1",
        "true",
        "yes",
        "on",
    }

    mysql_connector = getattr(db_mod, "mysql_connector", None)
    if mysql_connector is None:
        try:
            import mysql.connector as mysql_connector  # type: ignore
        except ModuleNotFoundError:
            mysql_connector = None

    if mysql_connector is None:
        if fallback:
            db_mod.DB_TYPE = "sqlite"
            db_mod.USE_SQLITE = True
            _sync_use_sqlite_flags()
        info["db_mode"] = "sqlite"
        info["mysql_fallback_reason"] = "mysql-connector not installed"
        return info

    ssl_disabled = os.getenv("MYSQL_SSL_DISABLED", "false").lower() == "true"
    try:
        conn = mysql_connector.connect(
            host=os.getenv("MYSQL_HOST", "127.0.0.1"),
            port=int(os.getenv("MYSQL_PORT", "3306")),
            user=os.getenv("MYSQL_USER", "root"),
            password=os.getenv("MYSQL_PASSWORD", ""),
            ssl_disabled=ssl_disabled,
            use_pure=True,
            connection_timeout=3,
        )
        conn.close()
        info["db_mode"] = "mysql"
        return info
    except Exception as exc:  # noqa: BLE001
        if not fallback:
            raise
        db_mod.DB_TYPE = "sqlite"
        db_mod.USE_SQLITE = True
        _sync_use_sqlite_flags()
        sqlite_file = getattr(db_mod, "SQLITE_FILE", "./novel_app.db")
        print(
            f"[database] MySQL unavailable ({exc}). "
            f"Falling back to SQLite at {sqlite_file}. "
            "Start MySQL or set DB_TYPE=sqlite in .env to silence this."
        )
        info["db_mode"] = "sqlite"
        info["mysql_fallback_reason"] = str(exc)
        return info


def _sync_use_sqlite_flags() -> None:
    import sys

    for mod_name in (
        "app.main",
        "app.startup_tasks",
        "backend.app.main",
        "backend.app.startup_tasks",
    ):
        mod = sys.modules.get(mod_name)
        if mod is not None and hasattr(mod, "USE_SQLITE"):
            setattr(mod, "USE_SQLITE", True)
    try:
        from . import main as main_mod

        main_mod.USE_SQLITE = True
    except Exception:
        pass
