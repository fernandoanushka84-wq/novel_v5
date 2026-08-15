from __future__ import annotations

import os
import sqlite3
from pathlib import Path
from uuid import uuid4

try:
    import mysql.connector as mysql_connector
except ModuleNotFoundError:
    mysql_connector = None

try:
    from dotenv import load_dotenv
except ModuleNotFoundError:
    load_dotenv = lambda *args, **kwargs: None

# Load .env.local first (local dev environment), then fall back to .env
_BACKEND_ROOT = Path(__file__).resolve().parents[1]
load_dotenv(_BACKEND_ROOT / ".env.local", override=False)
load_dotenv(_BACKEND_ROOT / ".env", override=False)

DB_TYPE_ENV = os.getenv("DB_TYPE")
if DB_TYPE_ENV:
    DB_TYPE = DB_TYPE_ENV.strip().lower()
elif mysql_connector is None:
    DB_TYPE = "sqlite"
else:
    DB_TYPE = "mysql"

USE_SQLITE = DB_TYPE == "sqlite"
SQLITE_FILE = Path(os.getenv("SQLITE_FILE", str(_BACKEND_ROOT / "novel_app.db"))).resolve()

MYSQL_ERROR = mysql_connector.Error if mysql_connector is not None else Exception

REQUIRED_TABLES = {
    "categories",
    "books",
    "chapters",
    "library_entries",
    "write_screen",
    "notifications",
    "menu_items",
    "profiles",
    "reading_lists",
    "achievements",
}

SEED_CATEGORIES = [
    ("New", 0, "discover", 1),
    ("Popular", 0, "discover", 2),
    ("Fanfiction", 0, "discover", 3),
    ("Newsfeed", 0, "discover", 4),
    ("Editor's Picks", 0, "discover", 5),
    ("Rising", 0, "discover", 6),
    ("Fanfiction", 100, "explore", 1),
    ("Fantasy", 31, "explore", 2),
    ("Poetry", 14, "explore", 3),
    ("Adventure", 35, "explore", 4),
    ("Horror", 29, "explore", 5),
    ("Thriller", 35, "explore", 6),
    ("Young Adult", 0, "explore", 7),
    ("LGBTQ+", 0, "explore", 8),
    ("Literary Fiction", 0, "explore", 9),
    ("Historical Fiction", 0, "explore", 10),
    ("Erotica", 32, "explore", 11),
    ("Mystery", 32, "explore", 12),
    ("SciFi", 31, "explore", 13),
    ("Humor", 24, "explore", 14),
    ("Drama", 28, "explore", 15),
    ("Romance", 41, "explore", 16),
    ("Paranormal", 19, "explore", 17),
]

SEED_BOOKS = [
    (
        "River (Revised version)",
        "Lola Grant",
        "A revised edition prepared for publication with deeper character arcs.",
        "story_card_images/c1a4b2d2-7ba9-44ea-9ea9-81873119a8ec.jpg",
        "#8DB7C8",
        "recently_updated",
        "2hr ago",
        4.5,
        "Historical Fiction",
        "Drama",
        "Read now",
        20,
        0,
    ),
    (
        "Misery's Chosen",
        "I. Falon",
        "Mico faces a shadowed figure with glowing eyes on a stormy night.",
        "story_card_images/cf12c459-4fe5-4725-8ca0-01f42b898d21.jpg",
        "#4A4A62",
        "recently_completed",
        "Completed",
        4.8,
        "Horror",
        "Mystery",
        "Read now",
        21,
        1,
    ),
    (
        "Goddess Tamer",
        "Ari Nova",
        "A reborn hero must tame a dangerous goddess and survive a hostile realm.",
        "story_card_images/d1a0655f-892d-4603-919f-92cdf779dae7.jpg",
        "#7F74C1",
        "recently_completed",
        "Completed",
        4.9,
        "Adventure",
        "Fantasy",
        "Read now",
        22,
        1,
    ),
    (
        "Avengard: The Fall of Senvia",
        "R. Den",
        "Two survivors chase a stolen voice across a drowned empire.",
        "story_card_images/d7728b65-7fcc-45cc-bfb2-38a47dfea216.jpg",
        "#6A8DB5",
        "recently_updated",
        "1yr ago",
        4.3,
        "Fantasy",
        "Romance",
        "Read now",
        23,
        0,
    ),
    (
        "Diary Of Nobody",
        "K. Haze",
        "A quiet diary that reveals pages no one was meant to read.",
        "story_card_images/d55997d3-bc48-43a1-a42e-d004598104d0.jpg",
        "#7D6A5A",
        "recently_updated",
        "1m ago",
        4.1,
        "Poetry",
        "Drama",
        "Read now",
        24,
        0,
    ),
    (
        "Demon King Leveling System",
        "J. Ard",
        "A trapped student awakens a leveling system to survive the abyss.",
        "story_card_images/dc335f4a-9cf3-498d-8c27-5addd0cb15cf.jpg",
        "#3F6FA0",
        "recently_updated",
        "5m ago",
        4.7,
        "Fantasy",
        "Action",
        "Read now",
        25,
        0,
    ),
    (
        "The Boy with the Checkered Scarf",
        "M. Wren",
        "A mythic tale where one scarf links three broken timelines.",
        "story_card_images/dc499710-91bd-4dae-8d0c-145faa5345e2.jpg",
        "#7C6D6A",
        "recently_updated",
        "10m ago",
        4.4,
        "Poetry",
        "Literary Fiction",
        "Read now",
        26,
        0,
    ),
    (
        "The Mnemonivores",
        "Liora Fane",
        "Creatures that feed on memories stalk a city after sunset.",
        "story_card_images/de52e8d5-1a1c-43b2-8752-70582d3e6c94.jpg",
        "#51406A",
        "recently_updated",
        "7m ago",
        4.6,
        "Paranormal",
        "Urban Fantasy",
        "Read now",
        27,
        0,
    ),
    (
        "Gaming Cube Adventures",
        "E. Barrett",
        "A failed streamer logs into a game that refuses to let him leave.",
        "story_card_images/e65f5659-9564-4623-b4c6-a5c37cb4aa5e.jpg",
        "#5875A3",
        "recently_updated",
        "2wk ago",
        4.2,
        "Action",
        "Fantasy",
        "Read now",
        28,
        0,
    ),
    (
        "The Apex Transfer",
        "Elena Torres",
        "An invisible outlier discovers she carries royal wolf blood.",
        "story_card_images/fdc309b2-20b4-4966-8293-9db4532dd8e3.jpg",
        "#7B5D56",
        "recently_completed",
        "Completed",
        5.0,
        "Fantasy",
        "Paranormal",
        "Read now",
        29,
        1,
    ),
]

SEED_NOTIFICATIONS = [
    ("Story", "New chapter available", "A story you follow just published a new chapter. Open Discover to read it.", "Just now", 1),
    ("Story", "Story recommendation", "Based on your library, try these trending stories this week.", "1h ago", 2),
    ("Community", "Welcome to the community", "Follow authors and join discussions to see updates here.", "Today", 1),
    ("Community", "Author reply", "An author replied to a comment on a story you liked.", "Yesterday", 2),
    ("System", "Inkitt", "Earn some karma. Help this author today by reading their story!", "Tue Apr 19:11", 1),
    ("System", "App update", "Content refreshed. Pull to refresh Discover for the latest stories.", "Now", 2),
]

SEED_MENU_ITEMS = [
    ("Profile", 1, "My Profile", "person", "profile", 1),
    ("Profile", 1, "Reading Stats", "bar_chart", "stats", 2),
    ("Community", 2, "Groups", "groups", "groups", 1),
    ("Support", 3, "Help Center", "help", "help", 1),
    ("Support", 3, "Contact Us", "chat", "contact", 2),
    ("Settings", 4, "Notifications", "notifications", "notifications", 1),
    ("Settings", 4, "App Language", "language", "language", 2),
    ("Settings", 4, "Favourite Genres", "favorite", "genres", 3),
    ("Settings", 4, "AI Content Review", "auto_awesome", "ai-review", 4),
    ("Settings", 4, "Content Warnings", "warning", "warnings", 5),
    ("Legal", 5, "Manage Cookie Preferences", "cookie", "cookies", 1),
    ("Legal", 5, "Terms of Service", "description", "terms", 2),
    ("Legal", 5, "Privacy Policy", "lock", "privacy", 3),
    ("Change Accounts", 6, "Sign Out", "logout", "logout", 1),
]

SEED_READING_LISTS = [
    (1, "Currently Reading", 2, "story_card_images/8de846ae-c1cc-4e8b-a52e-e8aa48b6abb1.jpg", 1),
    (1, "Archived / Finished Books", 0, "story_card_images/6290b4c8-83e9-4d5d-a740-06d4ec94d335.jpg", 2),
]

SEED_ACHIEVEMENTS = [
    ("Lifetime Reviews Given", 1, "Reviewer-in-Training", "0/1 Reviews Left", "0/1 Reviews Left", "1", "silver", 1),
    ("Lifetime Reviews Given", 1, "Community Voice", "0/2 Reviews Left", "0/2 Reviews Left", "2", "silver", 2),
    ("Lifetime Reviews Given", 1, "Story Critic", "0/3 Reviews Left", "0/3 Reviews Left", "3", "silver", 3),
    ("Lifetime Words Published", 2, "Ink Sprout", "0/1000 Words Published", "0/1000 Words Published", "1000", "dark", 1),
    ("Lifetime Words Published", 2, "Wordsmith", "0/5000 Words Published", "0/5000 Words Published", "5000", "dark", 2),
    ("Lifetime Words Published", 2, "Pen Prodigy", "0/10000 Words Published", "0/10000 Words Published", "10000", "dark", 3),
    ("Lifetime Reading", 3, "Page Flipper", "0/2 Chapters Read", "0/2 Chapters Read", "2", "ink", 1),
    ("Lifetime Reading", 3, "Book Explorer", "0/5 Chapters Read", "0/5 Chapters Read", "5", "ink", 2),
    ("Lifetime Reading", 3, "Reading Enthusiast", "0/10 Chapters Read", "0/10 Chapters Read", "10", "ink", 3),
]


def _to_db_query(query: str) -> str:
    return query.replace("%s", "?") if USE_SQLITE else query


def _sqlite_table_exists(cursor, table_name: str) -> bool:
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name=?", (table_name,))
    return cursor.fetchone() is not None


def _sqlite_column_exists(cursor, table_name: str, column_name: str) -> bool:
    cursor.execute(f"PRAGMA table_info({table_name})")
    return any(row[1] == column_name for row in cursor.fetchall())


def _split_sql_statements(sql_content: str) -> list[str]:
    statements: list[str] = []
    current: list[str] = []
    in_string = False
    string_char = ""

    for index, char in enumerate(sql_content):
        if char in ('"', "'") and (index == 0 or sql_content[index - 1] != "\\"):
            if not in_string:
                in_string = True
                string_char = char
            elif char == string_char:
                in_string = False

        if char == ";" and not in_string:
            statement = "".join(current).strip()
            if statement and not statement.startswith("--"):
                statements.append(statement)
            current = []
        else:
            current.append(char)

    return statements


def _ensure_database_exists() -> None:
    """Create the target database if it does not exist yet."""
    if USE_SQLITE:
        SQLITE_FILE.parent.mkdir(parents=True, exist_ok=True)
        connection = get_connection()
        connection.close()
        return

    ssl_disabled = os.getenv("MYSQL_SSL_DISABLED", "false").lower() == "true"
    db_name = os.getenv("MYSQL_DATABASE", "novel_app_db")
    if mysql_connector is None:
        raise RuntimeError("mysql.connector is not installed; install mysql-connector-python to use MySQL mode")

    try:
        connection = mysql_connector.connect(
            host=os.getenv("MYSQL_HOST", "127.0.0.1"),
            port=int(os.getenv("MYSQL_PORT", "3306")),
            user=os.getenv("MYSQL_USER", "root"),
            password=os.getenv("MYSQL_PASSWORD", ""),
            ssl_disabled=ssl_disabled,
            use_pure=True,
        )
        cursor = connection.cursor()
        cursor.execute(
            f"CREATE DATABASE IF NOT EXISTS `{db_name}` "
            "CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
        )
        connection.commit()
        cursor.close()
        connection.close()
    except MYSQL_ERROR as exc:
        # If we cannot even connect without a database, re-raise.
        raise exc


def initialize_database_if_needed() -> bool:
    """Initialize schema/seed data on startup when required tables are missing."""
    if USE_SQLITE:
        connection = get_connection()
        cursor = connection.cursor()
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
        existing_tables = {row["name"] for row in cursor.fetchall()}

        if REQUIRED_TABLES.issubset(existing_tables):
            cursor.close()
            connection.close()
            return False

        _create_sqlite_schema(connection)
        cursor.close()
        connection.close()
        return True

    init_sql = os.getenv("MYSQL_INIT_SQL", "setup_railway.sql")
    sql_path = Path(__file__).resolve().parents[1] / "sql" / init_sql

    if not sql_path.exists():
        raise FileNotFoundError(f"Init SQL file not found: {sql_path}")

    _ensure_database_exists()

    connection = get_connection()
    cursor = connection.cursor()
    cursor.execute("SHOW TABLES")
    existing_tables = {row[0] for row in cursor.fetchall()}

    if REQUIRED_TABLES.issubset(existing_tables):
        cursor.close()
        connection.close()
        return False

    sql_content = sql_path.read_text(encoding="utf-8")
    statements = _split_sql_statements(sql_content)

    cursor.execute("SET FOREIGN_KEY_CHECKS=0")

    for statement in statements:
        try:
            cursor.execute(statement)
        except MYSQL_ERROR as exc:
            # Ignore idempotent creation/seed issues to support partial environments.
            if getattr(exc, 'errno', None) not in (1050, 1062):
                cursor.execute("SET FOREIGN_KEY_CHECKS=1")
                connection.rollback()
                cursor.close()
                connection.close()
                raise

    cursor.execute("SET FOREIGN_KEY_CHECKS=1")
    connection.commit()
    cursor.close()
    connection.close()
    return True


def _create_sqlite_schema(connection) -> None:
    cursor = connection.cursor()
    cursor.executescript(
        """
        CREATE TABLE IF NOT EXISTS categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            topic_count INTEGER NOT NULL DEFAULT 0,
            tab_group TEXT NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS books (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            author TEXT NOT NULL,
            description TEXT NOT NULL,
            cover_path TEXT NOT NULL DEFAULT '',
            accent_hex TEXT NOT NULL DEFAULT '#808080',
            section_name TEXT NOT NULL,
            status_text TEXT NOT NULL DEFAULT '',
            rating REAL NOT NULL DEFAULT 0,
            genre TEXT NOT NULL DEFAULT '',
            primary_genre TEXT NOT NULL DEFAULT '',
            secondary_genre TEXT NOT NULL DEFAULT '',
            is_completed INTEGER NOT NULL DEFAULT 0,
            cta_label TEXT NOT NULL DEFAULT 'Read now',
            sort_order INTEGER NOT NULL DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS chapters (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            story_id INTEGER NOT NULL,
            chapter_number INTEGER NOT NULL DEFAULT 1,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (story_id) REFERENCES books(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS library_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            book_id INTEGER NOT NULL,
            reading_status TEXT NOT NULL,
            updated_text TEXT NOT NULL,
            chapters INTEGER NOT NULL DEFAULT 0,
            primary_genre TEXT NOT NULL,
            secondary_genre TEXT NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (book_id) REFERENCES books(id)
        );

        CREATE TABLE IF NOT EXISTS write_screen (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            manage_tabs TEXT NOT NULL,
            story_tabs TEXT NOT NULL,
            filter_label TEXT NOT NULL,
            sort_label TEXT NOT NULL,
            empty_title TEXT NOT NULL,
            empty_cta TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS notifications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tab_name TEXT NOT NULL,
            title TEXT NOT NULL,
            message TEXT NOT NULL,
            created_at TEXT NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS menu_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            section_name TEXT NOT NULL,
            section_order INTEGER NOT NULL DEFAULT 0,
            label TEXT NOT NULL,
            icon_name TEXT NOT NULL,
            route_name TEXT NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS profiles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            display_name TEXT NOT NULL,
            username TEXT NOT NULL,
            following INTEGER NOT NULL DEFAULT 0,
            followers INTEGER NOT NULL DEFAULT 0,
            blocked INTEGER NOT NULL DEFAULT 0,
            chapters_read INTEGER NOT NULL DEFAULT 0,
            social_karma INTEGER NOT NULL DEFAULT 0,
            day_streak INTEGER NOT NULL DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS reading_lists (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            profile_id INTEGER NOT NULL,
            user_id INTEGER,
            name TEXT NOT NULL,
            story_count INTEGER NOT NULL DEFAULT 0,
            cover_path TEXT NOT NULL DEFAULT '',
            sort_order INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (profile_id) REFERENCES profiles(id)
        );

        CREATE TABLE IF NOT EXISTS reading_list_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            reading_list_id INTEGER NOT NULL,
            book_id INTEGER NOT NULL,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (reading_list_id) REFERENCES reading_lists(id) ON DELETE CASCADE,
            FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS tags (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            created_by_admin INTEGER NOT NULL DEFAULT 1
        );

        CREATE TABLE IF NOT EXISTS book_tags (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            book_id INTEGER NOT NULL,
            tag_id INTEGER NOT NULL,
            FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE,
            FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE,
            UNIQUE (book_id, tag_id)
        );

        CREATE TABLE IF NOT EXISTS book_reviews (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            book_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            rating INTEGER NOT NULL,
            comment TEXT NOT NULL,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE,
            FOREIGN KEY (user_id) REFERENCES app_users(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS author_follows (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            author_id INTEGER NOT NULL,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES app_users(id) ON DELETE CASCADE,
            FOREIGN KEY (author_id) REFERENCES app_users(id) ON DELETE CASCADE,
            UNIQUE (user_id, author_id)
        );

        CREATE TABLE IF NOT EXISTS achievements (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            group_name TEXT NOT NULL,
            group_order INTEGER NOT NULL DEFAULT 0,
            title TEXT NOT NULL,
            subtitle TEXT NOT NULL,
            progress_label TEXT NOT NULL,
            badge_value TEXT NOT NULL,
            style TEXT NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0
        );
        """
    )
    connection.commit()
    cursor.close()


def _run_startup_migrations_sqlite(connection) -> dict[str, int]:
    cursor = connection.cursor()

    result = {
        "columns_added": 0,
        "tables_added": 0,
        "categories_added": 0,
        "books_added": 0,
        "assets_seeded": 0,
    }

    uploads_dir = Path(os.getenv("UPLOAD_DIR", "./uploads")).resolve()
    uploads_dir.mkdir(parents=True, exist_ok=True)

    if not _sqlite_table_exists(cursor, "app_metadata"):
        cursor.execute(
            """
            CREATE TABLE app_metadata (
                key_name TEXT PRIMARY KEY,
                key_value TEXT NOT NULL,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
        result["tables_added"] += 1

    cursor.execute(
        """
        INSERT INTO app_metadata (key_name, key_value)
        VALUES (?, ?)
        ON CONFLICT(key_name) DO UPDATE SET key_value = excluded.key_value
        """,
        ("content_version", str(uuid4())),
    )

    if not _sqlite_table_exists(cursor, "chapters"):
        cursor.execute(
            """
            CREATE TABLE chapters (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                story_id INTEGER NOT NULL,
                chapter_number INTEGER NOT NULL DEFAULT 1,
                title TEXT NOT NULL,
                content TEXT NOT NULL,
                sort_order INTEGER NOT NULL DEFAULT 0,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (story_id) REFERENCES books(id) ON DELETE CASCADE
            )
            """
        )
        result["tables_added"] += 1

    if not _sqlite_column_exists(cursor, "chapters", "notes"):
        cursor.execute("ALTER TABLE chapters ADD COLUMN notes TEXT")
        result["columns_added"] += 1

    if not _sqlite_column_exists(cursor, "chapters", "submission_status"):
        cursor.execute("ALTER TABLE chapters ADD COLUMN submission_status TEXT NOT NULL DEFAULT 'draft'")
        result["columns_added"] += 1

    if not _sqlite_column_exists(cursor, "chapters", "scheduled_for"):
        cursor.execute("ALTER TABLE chapters ADD COLUMN scheduled_for TEXT NULL")
        result["columns_added"] += 1

    if not _sqlite_table_exists(cursor, "chapter_revisions"):
        cursor.execute(
            """
            CREATE TABLE chapter_revisions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                chapter_id INTEGER NOT NULL,
                title TEXT NOT NULL,
                content TEXT NOT NULL,
                notes TEXT,
                submission_status TEXT NOT NULL DEFAULT 'draft',
                scheduled_for TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (chapter_id) REFERENCES chapters(id) ON DELETE CASCADE
            )
            """
        )
        result["tables_added"] += 1

    if not _sqlite_table_exists(cursor, "support_requests"):
        cursor.execute(
            """
            CREATE TABLE support_requests (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                email TEXT NOT NULL,
                first_name TEXT NOT NULL,
                issue TEXT NOT NULL,
                subject TEXT NOT NULL,
                description TEXT NOT NULL,
                device_type TEXT NOT NULL DEFAULT '',
                attachment_path TEXT,
                status TEXT NOT NULL DEFAULT 'open',
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
        result["tables_added"] += 1

    if not _sqlite_table_exists(cursor, "app_users"):
        cursor.execute(
            """
            CREATE TABLE app_users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                email TEXT NOT NULL UNIQUE,
                provider TEXT NOT NULL DEFAULT 'google',
                provider_subject TEXT,
                display_name TEXT NOT NULL,
                photo_url TEXT,
                cover_url TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
                last_login_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
        result["tables_added"] += 1

    if not _sqlite_column_exists(cursor, "app_users", "cover_url"):
        cursor.execute("ALTER TABLE app_users ADD COLUMN cover_url TEXT")
        result["columns_added"] += 1

    if not _sqlite_column_exists(cursor, "library_entries", "user_id"):
        cursor.execute("ALTER TABLE library_entries ADD COLUMN user_id INTEGER")
        result["columns_added"] += 1

    if not _sqlite_column_exists(cursor, "books", "user_id"):
        cursor.execute("ALTER TABLE books ADD COLUMN user_id INTEGER")
        result["columns_added"] += 1

    if not _sqlite_column_exists(cursor, "reading_lists", "user_id"):
        cursor.execute("ALTER TABLE reading_lists ADD COLUMN user_id INTEGER")
        result["columns_added"] += 1

    if not _sqlite_table_exists(cursor, "reading_list_items"):
        cursor.execute(
            """
            CREATE TABLE reading_list_items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                reading_list_id INTEGER NOT NULL,
                book_id INTEGER NOT NULL,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (reading_list_id) REFERENCES reading_lists(id) ON DELETE CASCADE,
                FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
            )
            """
        )
        result["tables_added"] += 1

    if not _sqlite_table_exists(cursor, "tags"):
        cursor.execute(
            """
            CREATE TABLE tags (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL UNIQUE,
                created_by_admin INTEGER NOT NULL DEFAULT 1
            )
            """
        )
        result["tables_added"] += 1

    if not _sqlite_table_exists(cursor, "book_tags"):
        cursor.execute(
            """
            CREATE TABLE book_tags (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                book_id INTEGER NOT NULL,
                tag_id INTEGER NOT NULL,
                FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE,
                FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE,
                UNIQUE (book_id, tag_id)
            )
            """
        )
        result["tables_added"] += 1

    if not _sqlite_table_exists(cursor, "book_reviews"):
        cursor.execute(
            """
            CREATE TABLE book_reviews (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                book_id INTEGER NOT NULL,
                user_id INTEGER NOT NULL,
                rating INTEGER NOT NULL,
                comment TEXT NOT NULL,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE,
                FOREIGN KEY (user_id) REFERENCES app_users(id) ON DELETE CASCADE
            )
            """
        )
        result["tables_added"] += 1

    if not _sqlite_table_exists(cursor, "chapter_comments"):
        cursor.execute(
            """
            CREATE TABLE chapter_comments (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                chapter_id INTEGER NOT NULL,
                book_id INTEGER NOT NULL,
                user_id INTEGER NOT NULL,
                body TEXT NOT NULL,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (chapter_id) REFERENCES chapters(id) ON DELETE CASCADE,
                FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE,
                FOREIGN KEY (user_id) REFERENCES app_users(id) ON DELETE CASCADE
            )
            """
        )
        result["tables_added"] += 1

    
    if not _sqlite_table_exists(cursor, "story_reports"):
        cursor.execute(
            """
            CREATE TABLE story_reports (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                book_id INTEGER NOT NULL,
                user_id INTEGER NOT NULL,
                reason TEXT NOT NULL DEFAULT '',
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(book_id, user_id),
                FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE,
                FOREIGN KEY (user_id) REFERENCES app_users(id) ON DELETE CASCADE
            )
            """
        )
        result["tables_added"] += 1

    
    if not _sqlite_table_exists(cursor, "chapter_reactions"):
        cursor.execute(
            """
            CREATE TABLE chapter_reactions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                book_id INTEGER NOT NULL,
                chapter_number INTEGER NOT NULL,
                user_id INTEGER NOT NULL,
                label TEXT NOT NULL,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(book_id, chapter_number, user_id, label)
            )
            """
        )
        result["tables_added"] += 1

    if not _sqlite_table_exists(cursor, "author_follows"):
        cursor.execute(
            """
            CREATE TABLE author_follows (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                author_id INTEGER NOT NULL,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES app_users(id) ON DELETE CASCADE,
                FOREIGN KEY (author_id) REFERENCES app_users(id) ON DELETE CASCADE,
                UNIQUE (user_id, author_id)
            )
            """
        )
        result["tables_added"] += 1

    if not _sqlite_table_exists(cursor, "chat_messages"):
        cursor.execute(
            """
            CREATE TABLE chat_messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                sender TEXT NOT NULL DEFAULT 'user',
                message TEXT NOT NULL,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES app_users(id) ON DELETE CASCADE
            )
            """
        )
        result["tables_added"] += 1

    if not _sqlite_column_exists(cursor, "support_requests", "device_type"):
        cursor.execute("ALTER TABLE support_requests ADD COLUMN device_type TEXT NOT NULL DEFAULT ''")
        result["columns_added"] += 1

    if not _sqlite_column_exists(cursor, "support_requests", "attachment_path"):
        cursor.execute("ALTER TABLE support_requests ADD COLUMN attachment_path TEXT")
        result["columns_added"] += 1

    if not _sqlite_column_exists(cursor, "books", "primary_genre"):
        cursor.execute("ALTER TABLE books ADD COLUMN primary_genre TEXT NOT NULL DEFAULT ''")
        result["columns_added"] += 1

    if not _sqlite_column_exists(cursor, "books", "secondary_genre"):
        cursor.execute("ALTER TABLE books ADD COLUMN secondary_genre TEXT NOT NULL DEFAULT ''")
        result["columns_added"] += 1

    if not _sqlite_column_exists(cursor, "books", "is_completed"):
        cursor.execute("ALTER TABLE books ADD COLUMN is_completed INTEGER NOT NULL DEFAULT 0")
        result["columns_added"] += 1

    if not _sqlite_column_exists(cursor, "books", "content_warnings"):
        cursor.execute("ALTER TABLE books ADD COLUMN content_warnings TEXT NOT NULL DEFAULT ''")
        result["columns_added"] += 1

    cursor.execute("UPDATE books SET primary_genre = genre WHERE primary_genre = '' OR primary_genre IS NULL")

    cursor.execute("SELECT id, cover_path FROM books WHERE cover_path LIKE ?", ("story_card_images/%",))
    for row in cursor.fetchall():
        book_id = row[0]
        cover_path = row[1]
        new_cover = "/uploads/" + Path(cover_path).name
        cursor.execute("UPDATE books SET cover_path = ? WHERE id = ?", (new_cover, book_id))

    for name, topic_count, tab_group, sort_order in SEED_CATEGORIES:
        cursor.execute(
            "SELECT id FROM categories WHERE name=? AND tab_group=? LIMIT 1",
            (name, tab_group),
        )
        if cursor.fetchone() is None:
            cursor.execute(
                "INSERT INTO categories (name, topic_count, tab_group, sort_order) VALUES (?, ?, ?, ?)",
                (name, topic_count, tab_group, sort_order),
            )
            result["categories_added"] += 1

    for (
        title,
        author,
        description,
        cover_path,
        accent_hex,
        section_name,
        status_text,
        rating,
        primary_genre,
        secondary_genre,
        cta_label,
        sort_order,
        is_completed,
    ) in SEED_BOOKS:
        cursor.execute("SELECT id FROM books WHERE title=? LIMIT 1", (title,))
        if cursor.fetchone() is None:
            cursor.execute(
                """
                INSERT INTO books (
                    title, author, description, cover_path, accent_hex, section_name, status_text,
                    rating, genre, primary_genre, secondary_genre, cta_label, sort_order, is_completed
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    title,
                    author,
                    description,
                    cover_path,
                    accent_hex,
                    section_name,
                    status_text,
                    rating,
                    primary_genre,
                    primary_genre,
                    secondary_genre,
                    cta_label,
                    sort_order,
                    is_completed,
                ),
            )
            result["books_added"] += 1

    # Clear broken cover paths that point to missing files (e.g. story3.jpg)
    cursor.execute(
        """
        UPDATE books SET cover_path = ''
        WHERE cover_path LIKE 'story%.jpg'
           OR cover_path LIKE '/uploads/story%.jpg'
           OR cover_path LIKE 'uploads/story%.jpg'
        """
    )

    for tab_name, title, message, created_at, sort_order in SEED_NOTIFICATIONS:
        cursor.execute(
            "SELECT id FROM notifications WHERE tab_name=? AND title=? LIMIT 1",
            (tab_name, title),
        )
        if cursor.fetchone() is None:
            cursor.execute(
                "INSERT INTO notifications (tab_name, title, message, created_at, sort_order) VALUES (?, ?, ?, ?, ?)",
                (tab_name, title, message, created_at, sort_order),
            )

    # Seed default menu items and achievements for the More/Explore UI (SQLite)
    SEED_MENU_ITEMS_SQLITE = [
        ("Profile", 1, "My Profile", "person", "profile", 1),
        ("Community", 2, "Groups", "groups", "groups", 1),
        ("Support", 3, "Help Center", "help", "help", 1),
        ("Support", 3, "Contact Us", "chat", "contact", 2),
        ("Settings", 4, "Notifications", "notifications", "notifications", 1),
    ]
    for section_name, section_order, label, icon_name, route_name, sort_order in SEED_MENU_ITEMS_SQLITE:
        cursor.execute(
            "SELECT id FROM menu_items WHERE section_name=? AND label=? LIMIT 1",
            (section_name, label),
        )
        if cursor.fetchone() is None:
            cursor.execute(
                "INSERT INTO menu_items (section_name, section_order, label, icon_name, route_name, sort_order) VALUES (?, ?, ?, ?, ?, ?)",
                (section_name, section_order, label, icon_name, route_name, sort_order),
            )

    SEED_ACHIEVEMENTS_SQLITE = [
        ("Engagement", 1, "First Read", "Read your first chapter", "1/1", "badge", 1),
        ("Milestones", 2, "10 Chapters", "Read 10 chapters", "10/10", "badge", 1),
    ]
    for group_name, group_order, title, subtitle, progress_label, style, sort_order in SEED_ACHIEVEMENTS_SQLITE:
        cursor.execute(
            "SELECT id FROM achievements WHERE group_name=? AND title=? LIMIT 1",
            (group_name, title),
        )
        if cursor.fetchone() is None:
            cursor.execute(
                "INSERT INTO achievements (group_name, group_order, title, subtitle, progress_label, badge_value, style, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                (group_name, group_order, title, subtitle, progress_label, progress_label, style, sort_order),
            )

    for section_name, section_order, label, icon_name, route_name, sort_order in SEED_MENU_ITEMS:
        cursor.execute(
            "SELECT id FROM menu_items WHERE section_name=? AND label=? LIMIT 1",
            (section_name, label),
        )
        if cursor.fetchone() is None:
            cursor.execute(
                "INSERT INTO menu_items (section_name, section_order, label, icon_name, route_name, sort_order) VALUES (?, ?, ?, ?, ?, ?)",
                (section_name, section_order, label, icon_name, route_name, sort_order),
            )

    cursor.execute("SELECT id FROM write_screen LIMIT 1")
    if cursor.fetchone() is None:
        cursor.execute(
            "INSERT INTO write_screen (manage_tabs, story_tabs, filter_label, sort_label, empty_title, empty_cta) VALUES (?, ?, ?, ?, ?, ?)",
            ("Drafts,Published", "Stories,Series", "Filter", "Sort", "Nothing here yet", "Create story"),
        )

    cursor.execute("SELECT id FROM profiles LIMIT 1")
    if cursor.fetchone() is None:
        cursor.execute(
            "INSERT INTO profiles (display_name, username, following, followers, blocked, chapters_read, social_karma, day_streak) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            ("Guest User", "guest", 0, 0, 0, 0, 0, 0),
        )

    # Ensure there's at least one sample reading list associated with the default profile (SQLite)
    cursor.execute("SELECT id FROM profiles LIMIT 1")
    profile_row = cursor.fetchone()
    profile_id = profile_row[0] if profile_row is not None else 1
    cursor.execute("SELECT id FROM reading_lists WHERE name=? LIMIT 1", ("hello",))
    if cursor.fetchone() is None:
        cursor.execute(
            "INSERT INTO reading_lists (profile_id, name, story_count, cover_path, sort_order) VALUES (?, ?, ?, ?, ?)",
            (profile_id, "hello", 0, "", 1),
        )

    for profile_id, name, story_count, cover_path, sort_order in SEED_READING_LISTS:
        cursor.execute(
            "SELECT id FROM reading_lists WHERE profile_id=? AND name=? LIMIT 1",
            (profile_id, name),
        )
        if cursor.fetchone() is None:
            cursor.execute(
                "INSERT INTO reading_lists (profile_id, name, story_count, cover_path, sort_order) VALUES (?, ?, ?, ?, ?)",
                (profile_id, name, story_count, cover_path, sort_order),
            )

    for group_name, group_order, title, subtitle, progress_label, badge_value, style, sort_order in SEED_ACHIEVEMENTS:
        cursor.execute(
            "SELECT id FROM achievements WHERE group_name=? AND title=? LIMIT 1",
            (group_name, title),
        )
        if cursor.fetchone() is None:
            cursor.execute(
                "INSERT INTO achievements (group_name, group_order, title, subtitle, progress_label, badge_value, style, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                (group_name, group_order, title, subtitle, progress_label, badge_value, style, sort_order),
            )

    static_story_dir = Path(__file__).resolve().parents[2] / "story_card_images"
    if static_story_dir.exists():
        for image_path in sorted(static_story_dir.glob("*")):
            if not image_path.is_file():
                continue
            extension = image_path.suffix.lower()
            if extension not in {".jpg", ".jpeg", ".png", ".webp"}:
                continue

            target_path = uploads_dir / image_path.name
            if target_path.exists():
                continue

            target_path.write_bytes(image_path.read_bytes())
            result["assets_seeded"] += 1

    connection.commit()
    cursor.close()
    return result


def run_startup_migrations() -> dict[str, int]:
    """Apply lightweight, idempotent migrations and baseline seed content."""
    if USE_SQLITE:
        connection = get_connection()
        result = _run_startup_migrations_sqlite(connection)
        connection.close()
        return result

    connection = get_connection()
    cursor = connection.cursor()

    result = {
        "columns_added": 0,
        "tables_added": 0,
        "categories_added": 0,
        "books_added": 0,
        "assets_seeded": 0,
    }

    uploads_dir = Path(os.getenv("UPLOAD_DIR", "./uploads")).resolve()
    uploads_dir.mkdir(parents=True, exist_ok=True)

    cursor.execute("SHOW TABLES LIKE 'app_metadata'")
    if cursor.fetchone() is None:
        cursor.execute(
            """
            CREATE TABLE app_metadata (
                key_name VARCHAR(100) PRIMARY KEY,
                key_value TEXT NOT NULL,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )
            """
        )
        result["tables_added"] += 1

    cursor.execute(
        """
        INSERT INTO app_metadata (key_name, key_value)
        VALUES ('content_version', %s)
        ON DUPLICATE KEY UPDATE key_value = key_value
        """,
        (str(uuid4()),),
    )

    cursor.execute("SHOW TABLES LIKE 'chapters'")
    if cursor.fetchone() is None:
        cursor.execute(
            """
            CREATE TABLE chapters (
                id INT AUTO_INCREMENT PRIMARY KEY,
                story_id INT NOT NULL,
                chapter_number INT NOT NULL DEFAULT 1,
                title VARCHAR(255) NOT NULL,
                content LONGTEXT NOT NULL,
                sort_order INT NOT NULL DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                CONSTRAINT fk_chapter_story FOREIGN KEY (story_id) REFERENCES books(id) ON DELETE CASCADE
            )
            """
        )
        result["tables_added"] += 1

    cursor.execute("SHOW COLUMNS FROM chapters LIKE 'notes'")
    if cursor.fetchone() is None:
        cursor.execute("ALTER TABLE chapters ADD COLUMN notes TEXT NULL AFTER content")
        result["columns_added"] += 1

    cursor.execute("SHOW COLUMNS FROM chapters LIKE 'submission_status'")
    if cursor.fetchone() is None:
        cursor.execute(
            "ALTER TABLE chapters ADD COLUMN submission_status VARCHAR(40) NOT NULL DEFAULT 'draft' AFTER notes"
        )
        result["columns_added"] += 1

    cursor.execute("SHOW COLUMNS FROM chapters LIKE 'scheduled_for'")
    if cursor.fetchone() is None:
        cursor.execute("ALTER TABLE chapters ADD COLUMN scheduled_for DATETIME NULL AFTER submission_status")
        result["columns_added"] += 1

    cursor.execute("SHOW TABLES LIKE 'chapter_revisions'")
    if cursor.fetchone() is None:
        cursor.execute(
            """
            CREATE TABLE chapter_revisions (
                id INT AUTO_INCREMENT PRIMARY KEY,
                chapter_id INT NOT NULL,
                title VARCHAR(255) NOT NULL,
                content LONGTEXT NOT NULL,
                notes TEXT NULL,
                submission_status VARCHAR(40) NOT NULL DEFAULT 'draft',
                scheduled_for DATETIME NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                CONSTRAINT fk_revision_chapter FOREIGN KEY (chapter_id) REFERENCES chapters(id) ON DELETE CASCADE
            )
            """
        )
        result["tables_added"] += 1

    cursor.execute("SHOW TABLES LIKE 'support_requests'")
    if cursor.fetchone() is None:
        cursor.execute(
            """
            CREATE TABLE support_requests (
                id INT AUTO_INCREMENT PRIMARY KEY,
                email VARCHAR(255) NOT NULL,
                first_name VARCHAR(120) NOT NULL,
                issue VARCHAR(120) NOT NULL,
                subject VARCHAR(255) NOT NULL,
                description TEXT NOT NULL,
                device_type VARCHAR(120) NOT NULL DEFAULT '',
                attachment_path TEXT NULL,
                status VARCHAR(40) NOT NULL DEFAULT 'open',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )
            """
        )
        result["tables_added"] += 1

    cursor.execute("SHOW TABLES LIKE 'app_users'")
    if cursor.fetchone() is None:
        cursor.execute(
            """
            CREATE TABLE app_users (
                id INT AUTO_INCREMENT PRIMARY KEY,
                email VARCHAR(255) NOT NULL UNIQUE,
                provider VARCHAR(40) NOT NULL DEFAULT 'google',
                provider_subject VARCHAR(255) NULL,
                display_name VARCHAR(255) NOT NULL,
                photo_url TEXT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                last_login_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
        result["tables_added"] += 1

    # Allow guest/email users without a provider subject (nullable).
    cursor.execute("SHOW COLUMNS FROM app_users LIKE 'provider_subject'")
    if cursor.fetchone() is not None:
        cursor.execute(
            "ALTER TABLE app_users MODIFY provider_subject VARCHAR(255) NULL"
        )
        result["columns_added"] += 1

    # Add user_id to library_entries so each user has their own library.
    cursor.execute("SHOW COLUMNS FROM library_entries LIKE 'user_id'")
    if cursor.fetchone() is None:
        cursor.execute(
            "ALTER TABLE library_entries ADD COLUMN user_id INT NULL AFTER id"
        )
        result["columns_added"] += 1

    # Add user_id to books so writer stories are scoped to the author.
    cursor.execute("SHOW COLUMNS FROM books LIKE 'user_id'")
    if cursor.fetchone() is None:
        cursor.execute("ALTER TABLE books ADD COLUMN user_id INT NULL AFTER id")
        result["columns_added"] += 1

    # Add user_id to reading_lists so lists are per-user.
    cursor.execute("SHOW COLUMNS FROM reading_lists LIKE 'user_id'")
    if cursor.fetchone() is None:
        cursor.execute(
            "ALTER TABLE reading_lists ADD COLUMN user_id INT NULL AFTER id"
        )
        result["columns_added"] += 1

    cursor.execute("SHOW TABLES LIKE 'chapter_comments'")
    if cursor.fetchone() is None:
        cursor.execute(
            """
            CREATE TABLE chapter_comments (
                id INT AUTO_INCREMENT PRIMARY KEY,
                chapter_id INT NOT NULL,
                book_id INT NOT NULL,
                user_id INT NOT NULL,
                body TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_cc_chapter (chapter_id),
                INDEX idx_cc_book (book_id),
                INDEX idx_cc_user (user_id)
            )
            """
        )
        result["tables_added"] += 1

    cursor.execute("SHOW TABLES LIKE 'story_reports'")
    if cursor.fetchone() is None:
        cursor.execute(
            """
            CREATE TABLE story_reports (
                id INT AUTO_INCREMENT PRIMARY KEY,
                book_id INT NOT NULL,
                user_id INT NOT NULL,
                reason TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY uq_story_report (book_id, user_id),
                INDEX (book_id),
                INDEX (user_id)
            )
            """
        )
        result["tables_added"] += 1

    cursor.execute("SHOW TABLES LIKE 'chapter_reactions'")
    if cursor.fetchone() is None:
        cursor.execute(
            """
            CREATE TABLE chapter_reactions (
                id INT AUTO_INCREMENT PRIMARY KEY,
                book_id INT NOT NULL,
                chapter_number INT NOT NULL,
                user_id INT NOT NULL,
                label VARCHAR(64) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY uq_ch_react (book_id, chapter_number, user_id, label),
                INDEX (book_id, chapter_number)
            )
            """
        )
        result["tables_added"] += 1

    # Chat history table for the in-app support/contact chat.
    cursor.execute("SHOW TABLES LIKE 'chat_messages'")
    if cursor.fetchone() is None:
        cursor.execute(
            """
            CREATE TABLE chat_messages (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id INT NOT NULL,
                sender VARCHAR(40) NOT NULL DEFAULT 'user',
                message TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                CONSTRAINT fk_chat_user FOREIGN KEY (user_id) REFERENCES app_users(id) ON DELETE CASCADE
            )
            """
        )
        result["tables_added"] += 1

    support_columns = {
        "device_type": "ALTER TABLE support_requests ADD COLUMN device_type VARCHAR(120) NOT NULL DEFAULT ''",
        "attachment_path": "ALTER TABLE support_requests ADD COLUMN attachment_path TEXT NULL",
    }

    for column, alter_sql in support_columns.items():
        cursor.execute(f"SHOW COLUMNS FROM support_requests LIKE '{column}'")
        if cursor.fetchone() is None:
            cursor.execute(alter_sql)
            result["columns_added"] += 1

    book_columns = {
        "primary_genre": "ALTER TABLE books ADD COLUMN primary_genre VARCHAR(80) NOT NULL DEFAULT ''",
        "secondary_genre": "ALTER TABLE books ADD COLUMN secondary_genre VARCHAR(80) NOT NULL DEFAULT ''",
        "is_completed": "ALTER TABLE books ADD COLUMN is_completed TINYINT(1) NOT NULL DEFAULT 0",
        "content_warnings": "ALTER TABLE books ADD COLUMN content_warnings TEXT NOT NULL DEFAULT ''",
    }

    for column, alter_sql in book_columns.items():
        cursor.execute(f"SHOW COLUMNS FROM books LIKE '{column}'")
        if cursor.fetchone() is None:
            cursor.execute(alter_sql)
            result["columns_added"] += 1

    cursor.execute(
        "UPDATE books SET primary_genre = genre WHERE (primary_genre = '' OR primary_genre IS NULL)"
    )
    cursor.execute(
        """
        UPDATE books
        SET cover_path = CONCAT('/uploads/', SUBSTRING_INDEX(cover_path, '/', -1))
        WHERE cover_path LIKE 'story_card_images/%'
        """
    )

    for name, topic_count, tab_group, sort_order in SEED_CATEGORIES:
        cursor.execute(
            "SELECT id FROM categories WHERE name=%s AND tab_group=%s LIMIT 1",
            (name, tab_group),
        )
        if cursor.fetchone() is None:
            cursor.execute(
                "INSERT INTO categories (name, topic_count, tab_group, sort_order) VALUES (%s, %s, %s, %s)",
                (name, topic_count, tab_group, sort_order),
            )
            result["categories_added"] += 1

    for (
        title,
        author,
        description,
        cover_path,
        accent_hex,
        section_name,
        status_text,
        rating,
        primary_genre,
        secondary_genre,
        cta_label,
        sort_order,
        is_completed,
    ) in SEED_BOOKS:
        cursor.execute("SELECT id FROM books WHERE title=%s LIMIT 1", (title,))
        if cursor.fetchone() is None:
            cursor.execute(
                """
                INSERT INTO books (
                    title, author, description, cover_path, accent_hex, section_name, status_text,
                    rating, genre, primary_genre, secondary_genre, cta_label, sort_order, is_completed
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    title,
                    author,
                    description,
                    cover_path,
                    accent_hex,
                    section_name,
                    status_text,
                    rating,
                    primary_genre,
                    primary_genre,
                    secondary_genre,
                    cta_label,
                    sort_order,
                    is_completed,
                ),
            )
            result["books_added"] += 1

    cursor.execute(
        """
        UPDATE books SET cover_path = ''
        WHERE cover_path LIKE 'story%.jpg'
           OR cover_path LIKE '/uploads/story%.jpg'
           OR cover_path LIKE 'uploads/story%.jpg'
        """
    )

    for tab_name, title, message, created_at, sort_order in SEED_NOTIFICATIONS:
        cursor.execute(
            "SELECT id FROM notifications WHERE tab_name=%s AND title=%s LIMIT 1",
            (tab_name, title),
        )
        if cursor.fetchone() is None:
            cursor.execute(
                "INSERT INTO notifications (tab_name, title, message, created_at, sort_order) VALUES (%s, %s, %s, %s, %s)",
                (tab_name, title, message, created_at, sort_order),
            )

    # Seed default menu items and achievements for the More/Explore UI (MySQL)
    SEED_MENU_ITEMS_MYSQL = [
        ("Profile", 1, "My Profile", "person", "profile", 1),
        ("Community", 2, "Groups", "groups", "groups", 1),
        ("Support", 3, "Help Center", "help", "help", 1),
        ("Support", 3, "Contact Us", "chat", "contact", 2),
        ("Settings", 4, "Notifications", "notifications", "notifications", 1),
    ]
    for section_name, section_order, label, icon_name, route_name, sort_order in SEED_MENU_ITEMS_MYSQL:
        cursor.execute(
            "SELECT id FROM menu_items WHERE section_name=%s AND label=%s LIMIT 1",
            (section_name, label),
        )
        if cursor.fetchone() is None:
            cursor.execute(
                "INSERT INTO menu_items (section_name, section_order, label, icon_name, route_name, sort_order) VALUES (%s, %s, %s, %s, %s, %s)",
                (section_name, section_order, label, icon_name, route_name, sort_order),
            )

    SEED_ACHIEVEMENTS_MYSQL = [
        ("Engagement", 1, "First Read", "Read your first chapter", "1/1", "badge", 1),
        ("Milestones", 2, "10 Chapters", "Read 10 chapters", "10/10", "badge", 1),
    ]
    for group_name, group_order, title, subtitle, progress_label, style, sort_order in SEED_ACHIEVEMENTS_MYSQL:
        cursor.execute(
            "SELECT id FROM achievements WHERE group_name=%s AND title=%s LIMIT 1",
            (group_name, title),
        )
        if cursor.fetchone() is None:
            cursor.execute(
                "INSERT INTO achievements (group_name, group_order, title, subtitle, progress_label, badge_value, style, sort_order) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
                (group_name, group_order, title, subtitle, progress_label, progress_label, style, sort_order),
            )

    for section_name, section_order, label, icon_name, route_name, sort_order in SEED_MENU_ITEMS:
        cursor.execute(
            "SELECT id FROM menu_items WHERE section_name=%s AND label=%s LIMIT 1",
            (section_name, label),
        )
        if cursor.fetchone() is None:
            cursor.execute(
                "INSERT INTO menu_items (section_name, section_order, label, icon_name, route_name, sort_order) VALUES (%s, %s, %s, %s, %s, %s)",
                (section_name, section_order, label, icon_name, route_name, sort_order),
            )

    cursor.execute("SELECT id FROM write_screen LIMIT 1")
    if cursor.fetchone() is None:
        cursor.execute(
            "INSERT INTO write_screen (manage_tabs, story_tabs, filter_label, sort_label, empty_title, empty_cta) VALUES (%s, %s, %s, %s, %s, %s)",
            ("Drafts,Published", "Stories,Series", "Filter", "Sort", "Nothing here yet", "Create story"),
        )

    cursor.execute("SELECT id FROM profiles LIMIT 1")
    if cursor.fetchone() is None:
        cursor.execute(
            "INSERT INTO profiles (display_name, username, following, followers, blocked, chapters_read, social_karma, day_streak) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
            ("Guest User", "guest", 0, 0, 0, 0, 0, 0),
        )

    # Ensure there's at least one sample reading list associated with the default profile (MySQL)
    cursor.execute("SELECT id FROM profiles LIMIT 1")
    profile_row = cursor.fetchone()
    profile_id = profile_row[0] if profile_row is not None else 1
    cursor.execute("SELECT id FROM reading_lists WHERE name=%s LIMIT 1", ("hello",))
    if cursor.fetchone() is None:
        cursor.execute(
            "INSERT INTO reading_lists (profile_id, name, story_count, cover_path, sort_order) VALUES (%s, %s, %s, %s, %s)",
            (profile_id, "hello", 0, "", 1),
        )

    for profile_id, name, story_count, cover_path, sort_order in SEED_READING_LISTS:
        cursor.execute(
            "SELECT id FROM reading_lists WHERE profile_id=%s AND name=%s LIMIT 1",
            (profile_id, name),
        )
        if cursor.fetchone() is None:
            cursor.execute(
                "INSERT INTO reading_lists (profile_id, name, story_count, cover_path, sort_order) VALUES (%s, %s, %s, %s, %s)",
                (profile_id, name, story_count, cover_path, sort_order),
            )

    for group_name, group_order, title, subtitle, progress_label, badge_value, style, sort_order in SEED_ACHIEVEMENTS:
        cursor.execute(
            "SELECT id FROM achievements WHERE group_name=%s AND title=%s LIMIT 1",
            (group_name, title),
        )
        if cursor.fetchone() is None:
            cursor.execute(
                "INSERT INTO achievements (group_name, group_order, title, subtitle, progress_label, badge_value, style, sort_order) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
                (group_name, group_order, title, subtitle, progress_label, badge_value, style, sort_order),
            )

    static_story_dir = Path(__file__).resolve().parents[2] / "story_card_images"
    if static_story_dir.exists():
        for image_path in sorted(static_story_dir.glob("*")):
            if not image_path.is_file():
                continue
            extension = image_path.suffix.lower()
            if extension not in {".jpg", ".jpeg", ".png", ".webp"}:
                continue

            target_path = uploads_dir / image_path.name
            if target_path.exists():
                continue

            target_path.write_bytes(image_path.read_bytes())
            result["assets_seeded"] += 1

    connection.commit()
    cursor.close()
    connection.close()
    return result


def get_connection():
    if USE_SQLITE:
        SQLITE_FILE.parent.mkdir(parents=True, exist_ok=True)
        connection = sqlite3.connect(
            str(SQLITE_FILE),
            detect_types=sqlite3.PARSE_DECLTYPES | sqlite3.PARSE_COLNAMES,
        )
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys = ON")
        return connection

    # Use SSL by default for cloud MySQL (Railway uses caching_sha2_password over secure transport).
    # Set MYSQL_SSL_DISABLED=true only for local/non-SSL setups.
    ssl_disabled = os.getenv("MYSQL_SSL_DISABLED", "false").lower() == "true"
    if mysql_connector is None:
        raise RuntimeError("mysql.connector is not installed; install mysql-connector-python to use MySQL mode")

    return mysql_connector.connect(
        host=os.getenv("MYSQL_HOST", "127.0.0.1"),
        port=int(os.getenv("MYSQL_PORT", "3306")),
        user=os.getenv("MYSQL_USER", "root"),
        password=os.getenv("MYSQL_PASSWORD", ""),
        database=os.getenv("MYSQL_DATABASE", "novel_app_db"),
        ssl_disabled=ssl_disabled,
        # Use the pure-Python implementation. The bundled C extension
        # (_mysql_connector.cp313-win_amd64.pyd) crashes with an access
        # violation (0xC0000005) on this machine.
        use_pure=True,
    )
