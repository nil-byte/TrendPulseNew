"""Database connection and table definitions.

Uses aiosqlite directly (no ORM). Provides async helpers to initialise
the schema, obtain a connection, and tear it down.
"""

from __future__ import annotations

import re
from datetime import datetime, timezone
from pathlib import Path

import aiosqlite

from src.config.settings import settings

_SQL_CREATE_TASKS = """
CREATE TABLE IF NOT EXISTS tasks (
    id          TEXT PRIMARY KEY,
    keyword     TEXT NOT NULL,
    language    TEXT NOT NULL DEFAULT 'en',
    max_items   INTEGER NOT NULL DEFAULT 50,
    status      TEXT NOT NULL DEFAULT 'pending',
    sources     TEXT NOT NULL,
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL,
    error_message TEXT
);
"""

_SQL_CREATE_RAW_POSTS = """
CREATE TABLE IF NOT EXISTS raw_posts (
    id            TEXT PRIMARY KEY,
    task_id       TEXT NOT NULL,
    source        TEXT NOT NULL,
    source_id     TEXT,
    author        TEXT,
    content       TEXT NOT NULL,
    url           TEXT,
    engagement    INTEGER DEFAULT 0,
    published_at  TEXT,
    collected_at  TEXT NOT NULL,
    metadata_json TEXT,
    FOREIGN KEY (task_id) REFERENCES tasks (id)
);
"""

_SQL_CREATE_ANALYSIS_REPORTS = """
CREATE TABLE IF NOT EXISTS analysis_reports (
    id                TEXT PRIMARY KEY,
    task_id           TEXT NOT NULL UNIQUE,
    sentiment_score   REAL NOT NULL,
    positive_ratio    REAL NOT NULL,
    negative_ratio    REAL NOT NULL,
    neutral_ratio     REAL NOT NULL,
    heat_index        REAL NOT NULL,
    key_insights      TEXT NOT NULL,
    summary           TEXT NOT NULL,
    raw_analysis_json TEXT,
    created_at        TEXT NOT NULL,
    FOREIGN KEY (task_id) REFERENCES tasks (id)
);
"""

_SQL_CREATE_INDEX_RAW_POSTS_TASK = """
CREATE INDEX IF NOT EXISTS idx_raw_posts_task_id ON raw_posts (task_id);
"""

_SQL_CREATE_INDEX_REPORTS_TASK = """
CREATE INDEX IF NOT EXISTS idx_analysis_reports_task_id ON analysis_reports (task_id);
"""

_SQL_CREATE_SUBSCRIPTIONS = """
CREATE TABLE IF NOT EXISTS subscriptions (
    id          TEXT PRIMARY KEY,
    keyword     TEXT NOT NULL,
    language    TEXT NOT NULL DEFAULT 'en',
    max_items   INTEGER NOT NULL DEFAULT 50,
    sources     TEXT NOT NULL,
    interval    TEXT NOT NULL DEFAULT 'daily',
    is_active   INTEGER NOT NULL DEFAULT 1,
    notify      INTEGER NOT NULL DEFAULT 1,
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL,
    last_run_at TEXT,
    next_run_at TEXT
);
"""

_SQL_CREATE_APP_SETTINGS = """
CREATE TABLE IF NOT EXISTS app_settings (
    id                            INTEGER PRIMARY KEY CHECK (id = 1),
    default_subscription_notify   INTEGER NOT NULL DEFAULT 1,
    created_at                    TEXT NOT NULL,
    updated_at                    TEXT NOT NULL
);
"""

_SQL_INSERT_DEFAULT_APP_SETTINGS = """
INSERT OR IGNORE INTO app_settings (
    id,
    default_subscription_notify,
    created_at,
    updated_at
)
VALUES (1, 1, ?, ?);
"""

_SQL_CREATE_SUBSCRIPTION_ALERTS = """
CREATE TABLE IF NOT EXISTS subscription_alerts (
    id              TEXT PRIMARY KEY,
    subscription_id TEXT NOT NULL,
    task_id         TEXT NOT NULL UNIQUE,
    sentiment_score REAL NOT NULL,
    is_read         INTEGER NOT NULL DEFAULT 0,
    created_at      TEXT NOT NULL,
    FOREIGN KEY (subscription_id) REFERENCES subscriptions (id) ON DELETE CASCADE,
    FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
);
"""

_SQL_ADD_TASKS_SUBSCRIPTION_ID = """
ALTER TABLE tasks ADD COLUMN subscription_id TEXT REFERENCES subscriptions(id);
"""

_SQL_CREATE_INDEX_SUBSCRIPTIONS_ACTIVE = """
CREATE INDEX IF NOT EXISTS idx_subscriptions_is_active ON subscriptions (is_active);
"""

_SQL_CREATE_INDEX_SUBSCRIPTION_ALERTS_UNREAD = """
CREATE INDEX IF NOT EXISTS idx_subscription_alerts_unread
ON subscription_alerts (subscription_id, is_read, created_at DESC);
"""


def _now_iso() -> str:
    """Return the current UTC timestamp in ISO-8601 format."""
    return datetime.now(timezone.utc).isoformat()


def _resolve_db_path() -> str:
    """Extract the SQLite file path from the database URL.

    Supports formats like ``sqlite+aiosqlite:///./trendpulse.db``
    and plain file paths.

    Returns:
        Resolved absolute path string for the database file.
    """
    url = settings.database_url
    match = re.search(r"///(.+)$", url)
    path_str = match.group(1) if match else url
    return str(Path(path_str).resolve())


async def get_db() -> aiosqlite.Connection:
    """Open and return an aiosqlite connection.

    The caller is responsible for closing the connection when done,
    preferably via :func:`close_db` or an ``async with`` block.

    Returns:
        An open ``aiosqlite.Connection`` with foreign-key enforcement.
    """
    db_path = _resolve_db_path()
    db = await aiosqlite.connect(db_path)
    db.row_factory = aiosqlite.Row
    await db.execute("PRAGMA foreign_keys = ON;")
    return db


async def init_db() -> None:
    """Create all tables and indexes if they do not already exist."""
    db = await get_db()
    try:
        now = _now_iso()
        await db.execute(_SQL_CREATE_TASKS)
        await db.execute(_SQL_CREATE_RAW_POSTS)
        await db.execute(_SQL_CREATE_ANALYSIS_REPORTS)
        await db.execute(_SQL_CREATE_APP_SETTINGS)
        await db.execute(_SQL_CREATE_SUBSCRIPTIONS)
        await db.execute(_SQL_CREATE_SUBSCRIPTION_ALERTS)
        await db.execute(_SQL_INSERT_DEFAULT_APP_SETTINGS, (now, now))
        await db.execute(_SQL_CREATE_INDEX_RAW_POSTS_TASK)
        await db.execute(_SQL_CREATE_INDEX_REPORTS_TASK)
        await db.execute(_SQL_CREATE_INDEX_SUBSCRIPTIONS_ACTIVE)
        await db.execute(_SQL_CREATE_INDEX_SUBSCRIPTION_ALERTS_UNREAD)
        await _safe_add_column(
            db,
            "tasks",
            "subscription_id",
            _SQL_ADD_TASKS_SUBSCRIPTION_ID,
        )
        await db.commit()
    finally:
        await close_db(db)


async def _safe_add_column(
    db: aiosqlite.Connection, table: str, column: str, ddl: str
) -> None:
    """Execute an ALTER TABLE only when the column does not yet exist.

    Args:
        db: Open aiosqlite connection.
        table: Table name to inspect.
        column: Column name to check for.
        ddl: The ALTER TABLE DDL to run if the column is missing.
    """
    cursor = await db.execute(f"PRAGMA table_info({table})")
    cols = [row[1] for row in await cursor.fetchall()]
    if column not in cols:
        await db.execute(ddl)


async def close_db(db: aiosqlite.Connection) -> None:
    """Close an aiosqlite connection safely.

    Args:
        db: The connection to close.
    """
    await db.close()
