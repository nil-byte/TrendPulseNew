"""Database connection and table definitions.

Uses aiosqlite directly (no ORM). Provides async helpers to initialise
the schema, obtain a connection, and tear it down.
"""

from __future__ import annotations

import re
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
        await db.execute(_SQL_CREATE_TASKS)
        await db.execute(_SQL_CREATE_RAW_POSTS)
        await db.execute(_SQL_CREATE_ANALYSIS_REPORTS)
        await db.execute(_SQL_CREATE_INDEX_RAW_POSTS_TASK)
        await db.execute(_SQL_CREATE_INDEX_REPORTS_TASK)
        await db.commit()
    finally:
        await close_db(db)


async def close_db(db: aiosqlite.Connection) -> None:
    """Close an aiosqlite connection safely.

    Args:
        db: The connection to close.
    """
    await db.close()
