"""Tests for SchedulerService due-subscription processing."""

from __future__ import annotations

import json
import uuid
from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock

import pytest

from src.config.settings import settings
from src.models.database import get_db
from src.services.scheduler_service import SchedulerService


async def _insert_due_subscription(
    subscription_id: str,
    *,
    sources: list[str],
    interval: str = "daily",
    content_language: str = "en",
) -> str:
    """Insert an active subscription that is already due to run."""
    now = datetime.now(timezone.utc)
    overdue_at = (now - timedelta(minutes=5)).isoformat()
    db = await get_db()
    try:
        await db.execute(
            """
            INSERT INTO subscriptions
                (
                    id,
                    keyword,
                    content_language,
                    max_items,
                    sources,
                    interval,
                    is_active,
                    notify,
                    created_at,
                    updated_at,
                    next_run_at
                )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                subscription_id,
                "openai",
                content_language,
                25,
                json.dumps(sources),
                interval,
                1,
                1,
                now.isoformat(),
                now.isoformat(),
                overdue_at,
            ),
        )
        await db.commit()
    finally:
        await db.close()
    return overdue_at


async def _update_report_language(report_language: str) -> None:
    """Persist a specific app-level report language for scheduler tests."""
    db = await get_db()
    try:
        await db.execute(
            "UPDATE app_settings SET report_language = ?, updated_at = ? WHERE id = 1",
            (report_language, datetime.now(timezone.utc).isoformat()),
        )
        await db.commit()
    finally:
        await db.close()


async def _fetch_subscription_schedule(subscription_id: str) -> tuple[str | None, str]:
    """Return last_run_at and next_run_at for assertions."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT last_run_at, next_run_at FROM subscriptions WHERE id = ?",
            (subscription_id,),
        )
        row = await cursor.fetchone()
        assert row is not None
        return row["last_run_at"], row["next_run_at"]
    finally:
        await db.close()


async def _count_subscription_tasks(subscription_id: str) -> int:
    """Count tasks linked to a subscription."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT COUNT(*) AS count FROM tasks WHERE subscription_id = ?",
            (subscription_id,),
        )
        row = await cursor.fetchone()
        assert row is not None
        return int(row["count"])
    finally:
        await db.close()


@pytest.mark.asyncio
async def test_tick_reschedules_due_subscription_when_sources_are_unavailable(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Unavailable sources should not stay overdue forever and re-run every tick."""
    subscription_id = str(uuid.uuid4())
    overdue_at = await _insert_due_subscription(subscription_id, sources=["reddit"])
    monkeypatch.setattr(settings, "reddit_client_id", "")
    monkeypatch.setattr(settings, "reddit_client_secret", "")

    scheduler = SchedulerService()

    await scheduler._tick()

    last_run_at, next_run_at = await _fetch_subscription_schedule(subscription_id)
    await scheduler._tick()
    last_run_at_after_second_tick, next_run_at_after_second_tick = (
        await _fetch_subscription_schedule(subscription_id)
    )

    assert await _count_subscription_tasks(subscription_id) == 0
    assert last_run_at is None
    assert next_run_at > overdue_at
    assert last_run_at_after_second_tick is None
    assert next_run_at_after_second_tick == next_run_at


@pytest.mark.asyncio
async def test_tick_defers_report_language_resolution_to_task_service(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Scheduler-created tasks should let TaskService resolve report_language."""
    subscription_id = str(uuid.uuid4())
    await _insert_due_subscription(
        subscription_id,
        sources=["reddit"],
        content_language="en",
    )
    await _update_report_language("zh")

    scheduler = SchedulerService()
    create_task_mock = AsyncMock()
    monkeypatch.setattr(scheduler._task_service, "create_task", create_task_mock)

    await scheduler._tick()

    create_task_mock.assert_awaited_once()
    await_args = create_task_mock.await_args
    request = await_args.args[0]
    assert request.keyword == "openai"
    assert request.content_language == "en"
    assert request.report_language is None
    assert await_args.kwargs["subscription_id"] == subscription_id
