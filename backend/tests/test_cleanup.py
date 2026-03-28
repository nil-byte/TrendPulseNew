"""Tests for subscription FK cleanup and scheduler test configuration."""

from __future__ import annotations

import json
import uuid
from datetime import datetime, timezone

import pytest
from httpx import ASGITransport, AsyncClient

from src import main as main_module
from src.models.database import get_db
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
                (id, keyword, language, max_items, sources, interval,
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
                (id, keyword, language, max_items, status, sources,
                 created_at, updated_at, subscription_id)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (task_id, "k", "en", 10, "completed", sources, now, now, sub_id),
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
    transport = ASGITransport(app=main_module.app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/health")
        assert response.status_code == 200
    assert main_module.get_scheduler().is_running is False
