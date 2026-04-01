"""Database connection and table definitions.

Uses aiosqlite directly (no ORM). Provides async helpers to initialise
the schema, obtain a connection, and tear it down.
"""

from __future__ import annotations

import re
from pathlib import Path

import aiosqlite

from src.common.time_utils import utc_now_iso
from src.config.settings import settings

_SQL_CREATE_TASKS = """
CREATE TABLE IF NOT EXISTS tasks (
    id          TEXT PRIMARY KEY,
    keyword     TEXT NOT NULL,
    content_language TEXT NOT NULL DEFAULT 'en',
    report_language TEXT NOT NULL DEFAULT 'en',
    max_items   INTEGER NOT NULL DEFAULT 50,
    status      TEXT NOT NULL DEFAULT 'pending',
    quality     TEXT NOT NULL DEFAULT 'clean',
    quality_summary TEXT,
    source_outcomes_json TEXT NOT NULL DEFAULT '[]',
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
    content_language TEXT NOT NULL DEFAULT 'en',
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
    report_language               TEXT NOT NULL DEFAULT 'en',
    created_at                    TEXT NOT NULL,
    updated_at                    TEXT NOT NULL
);
"""

_SQL_INSERT_DEFAULT_APP_SETTINGS = """
INSERT OR IGNORE INTO app_settings (
    id,
    default_subscription_notify,
    report_language,
    created_at,
    updated_at
)
VALUES (1, 1, 'en', ?, ?);
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

_SQL_ADD_TASKS_QUALITY = """
ALTER TABLE tasks ADD COLUMN quality TEXT NOT NULL DEFAULT 'clean';
"""

_SQL_ADD_TASKS_QUALITY_SUMMARY = """
ALTER TABLE tasks ADD COLUMN quality_summary TEXT;
"""

_SQL_ADD_TASKS_SOURCE_OUTCOMES = """
ALTER TABLE tasks ADD COLUMN source_outcomes_json TEXT NOT NULL DEFAULT '[]';
"""

_SQL_CREATE_INDEX_SUBSCRIPTIONS_ACTIVE = """
CREATE INDEX IF NOT EXISTS idx_subscriptions_is_active ON subscriptions (is_active);
"""

_SQL_CREATE_INDEX_SUBSCRIPTION_ALERTS_UNREAD = """
CREATE INDEX IF NOT EXISTS idx_subscription_alerts_unread
ON subscription_alerts (subscription_id, is_read, created_at DESC);
"""


class DatabaseSchemaContractError(RuntimeError):
    """Raised when the on-disk SQLite schema no longer matches the backend contract."""

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
        now = utc_now_iso()
        await db.execute(_SQL_CREATE_TASKS)
        await db.execute(_SQL_CREATE_RAW_POSTS)
        await db.execute(_SQL_CREATE_ANALYSIS_REPORTS)
        await db.execute(_SQL_CREATE_APP_SETTINGS)
        await db.execute(_SQL_CREATE_SUBSCRIPTIONS)
        await db.execute(_SQL_CREATE_SUBSCRIPTION_ALERTS)
        await _ensure_language_contract(db)
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
        await _safe_add_column(
            db,
            "tasks",
            "quality",
            _SQL_ADD_TASKS_QUALITY,
        )
        await _safe_add_column(
            db,
            "tasks",
            "quality_summary",
            _SQL_ADD_TASKS_QUALITY_SUMMARY,
        )
        await _safe_add_column(
            db,
            "tasks",
            "source_outcomes_json",
            _SQL_ADD_TASKS_SOURCE_OUTCOMES,
        )
        await _backfill_partial_tasks(db)
        await db.commit()
    finally:
        await close_db(db)


async def _ensure_language_contract(db: aiosqlite.Connection) -> None:
    """Fail fast when an existing database still uses the removed language contract."""
    expected_columns_by_table = {
        "tasks": {"content_language", "report_language"},
        "subscriptions": {"content_language"},
        "app_settings": {"report_language"},
    }
    for table, required_columns in expected_columns_by_table.items():
        columns = await _get_table_columns(db, table)
        if not columns:
            continue
        has_legacy_language = "language" in columns
        missing_columns = sorted(required_columns - set(columns))
        if has_legacy_language or missing_columns:
            raise DatabaseSchemaContractError(
                _build_schema_contract_error(
                    table=table,
                    columns=columns,
                    missing_columns=missing_columns,
                    has_legacy_language=has_legacy_language,
                )
            )


def _build_schema_contract_error(
    *,
    table: str,
    columns: list[str],
    missing_columns: list[str],
    has_legacy_language: bool,
) -> str:
    """Build a clear error for unsupported legacy SQLite schemas."""
    issues: list[str] = []
    if has_legacy_language:
        issues.append("legacy language column present")
    if missing_columns:
        issues.append(f"missing columns: {', '.join(missing_columns)}")
    issue_summary = "; ".join(issues) if issues else "schema contract mismatch"
    return (
        f"legacy language schema detected in table '{table}' for database "
        f"'{_resolve_db_path()}': {issue_summary}. "
        f"found columns: {', '.join(columns)}. "
        "delete the development SQLite database and restart so the backend can "
        "initialize the current schema."
    )


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
    cols = await _get_table_columns(db, table)
    if column not in cols:
        await db.execute(ddl)


async def _backfill_partial_tasks(db: aiosqlite.Connection) -> None:
    """Normalize legacy partial tasks to completed + degraded quality."""
    await db.execute(
        """
        UPDATE tasks
        SET status = 'completed',
            quality = 'degraded',
            quality_summary = COALESCE(
                quality_summary,
                CASE
                    WHEN error_message LIKE 'Completed with source failures:%'
                    THEN REPLACE(
                        error_message,
                        'Completed with source failures:',
                        'Completed with source issues:'
                    )
                    ELSE error_message
                END
            ),
            source_outcomes_json = COALESCE(NULLIF(source_outcomes_json, ''), '[]'),
            error_message = NULL
        WHERE status = 'partial'
          AND EXISTS (
              SELECT 1
              FROM analysis_reports
              WHERE analysis_reports.task_id = tasks.id
          )
        """
    )
    await db.execute(
        """
        UPDATE tasks
        SET status = 'failed',
            quality = 'degraded',
            source_outcomes_json = COALESCE(NULLIF(source_outcomes_json, ''), '[]'),
            error_message = CASE
                WHEN error_message LIKE 'Completed with source failures:%'
                THEN REPLACE(
                    error_message,
                    'Completed with source failures:',
                    'Source failures prevented report completion:'
                )
                ELSE error_message
            END
        WHERE status = 'partial'
        """
    )


async def _get_table_columns(db: aiosqlite.Connection, table: str) -> list[str]:
    """Return column names for the given table in definition order."""
    cursor = await db.execute(f"PRAGMA table_info({table})")
    rows = await cursor.fetchall()
    return [row[1] for row in rows]


async def close_db(db: aiosqlite.Connection) -> None:
    """Close an aiosqlite connection safely.

    Args:
        db: The connection to close.
    """
    await db.close()
