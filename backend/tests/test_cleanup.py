"""Tests for subscription FK cleanup and scheduler test configuration."""

from __future__ import annotations

import json
import uuid
from datetime import datetime, timezone
from pathlib import Path

import pytest

from src import main as main_module
from src.models.database import _resolve_db_path, get_db, init_db
from src.services.subscription_service import SubscriptionService


@pytest.mark.asyncio
async def test_delete_subscription_nulls_task_fk_preserves_task() -> None:
    """Deleting a subscription clears task.subscription_id; task row remains."""
    sub_id = str(uuid.uuid4())
    task_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc).isoformat()
    sources = json.dumps(["reddit"])

    db = await get_db()
    try:
        await db.execute(
            """
            INSERT INTO subscriptions
                (id, keyword, content_language, max_items, sources, interval,
                 is_active, notify, created_at, updated_at, next_run_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                sub_id,
                "k",
                "en",
                10,
                sources,
                "daily",
                1,
                1,
                now,
                now,
                now,
            ),
        )
        await db.execute(
            """
            INSERT INTO tasks
                (id, keyword, content_language, report_language, max_items, status, sources,
                 created_at, updated_at, subscription_id)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (task_id, "k", "en", "en", 10, "completed", sources, now, now, sub_id),
        )
        await db.commit()
    finally:
        await db.close()

    svc = SubscriptionService()
    assert await svc.delete_subscription(sub_id) is True

    db = await get_db()
    try:
        cur = await db.execute(
            "SELECT subscription_id, keyword FROM tasks WHERE id = ?", (task_id,)
        )
        row = await cur.fetchone()
        assert row is not None
        assert row["subscription_id"] is None
        assert row["keyword"] == "k"
        cur = await db.execute("SELECT id FROM subscriptions WHERE id = ?", (sub_id,))
        assert await cur.fetchone() is None
    finally:
        await db.close()


@pytest.mark.asyncio
async def test_scheduler_not_started_when_disabled_via_env() -> None:
    """When SCHEDULER_ENABLED is false, lifespan does not start the scheduler."""
    async with main_module.app.router.lifespan_context(main_module.app):
        assert main_module.get_scheduler().is_running is False


@pytest.mark.asyncio
async def test_each_test_uses_an_isolated_temp_database(tmp_path: Path) -> None:
    """The test DB should live under pytest's per-test temp directory."""
    assert Path(_resolve_db_path()).parent == tmp_path


@pytest.mark.asyncio
async def test_init_db_raises_clear_error_for_legacy_language_schema() -> None:
    """Legacy language-schema tables should raise a clear contract error."""
    db = await get_db()
    try:
        for table in (
            "subscription_alerts",
            "analysis_reports",
            "raw_posts",
            "tasks",
            "subscriptions",
            "app_settings",
        ):
            await db.execute(f"DROP TABLE IF EXISTS {table}")
        await db.execute(
            """
            CREATE TABLE tasks (
                id TEXT PRIMARY KEY,
                keyword TEXT NOT NULL,
                language TEXT NOT NULL DEFAULT 'en',
                max_items INTEGER NOT NULL DEFAULT 50,
                status TEXT NOT NULL DEFAULT 'pending',
                sources TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                error_message TEXT
            )
            """
        )
        await db.execute(
            """
            CREATE TABLE subscriptions (
                id TEXT PRIMARY KEY,
                keyword TEXT NOT NULL,
                language TEXT NOT NULL DEFAULT 'en',
                max_items INTEGER NOT NULL DEFAULT 50,
                sources TEXT NOT NULL,
                interval TEXT NOT NULL DEFAULT 'daily',
                is_active INTEGER NOT NULL DEFAULT 1,
                notify INTEGER NOT NULL DEFAULT 1,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                last_run_at TEXT,
                next_run_at TEXT
            )
            """
        )
        await db.execute(
            """
            CREATE TABLE app_settings (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                default_subscription_notify INTEGER NOT NULL DEFAULT 1,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        await db.commit()
    finally:
        await db.close()

    with pytest.raises(RuntimeError, match="legacy.+language.+delete.+database"):
        await init_db()
