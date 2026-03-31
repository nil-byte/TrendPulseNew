"""Shared database helpers for API endpoint tests."""

from __future__ import annotations

import json

from src.models.database import get_db


async def insert_subscription_alert(
    *,
    alert_id: str,
    subscription_id: str,
    task_id: str,
    sentiment_score: float,
    created_at: str,
    is_read: bool = False,
) -> None:
    """Insert a subscription alert row for endpoint tests."""
    db = await get_db()
    try:
        await db.execute(
            """
            INSERT INTO subscription_alerts
                (id, subscription_id, task_id, sentiment_score, is_read, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (
                alert_id,
                subscription_id,
                task_id,
                sentiment_score,
                int(is_read),
                created_at,
            ),
        )
        await db.commit()
    finally:
        await db.close()


async def insert_subscription_task(
    *,
    task_id: str,
    subscription_id: str,
    created_at: str,
) -> None:
    """Insert a linked task row for subscription endpoint tests."""
    db = await get_db()
    try:
        await db.execute(
            """
            INSERT INTO tasks
                (
                    id,
                    keyword,
                    content_language,
                    report_language,
                    max_items,
                    status,
                    sources,
                    created_at,
                    updated_at,
                    subscription_id
                )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                task_id,
                "openai",
                "en",
                "en",
                25,
                "completed",
                json.dumps(["reddit", "x"]),
                created_at,
                created_at,
                subscription_id,
            ),
        )
        await db.commit()
    finally:
        await db.close()


async def fetch_subscription_notify(subscription_id: str) -> bool:
    """Read the persisted notify flag for a subscription."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT notify FROM subscriptions WHERE id = ?",
            (subscription_id,),
        )
        row = await cursor.fetchone()
        assert row is not None
        return bool(row["notify"])
    finally:
        await db.close()


async def fetch_app_settings_rows() -> list[object]:
    """Return all persisted app settings rows."""
    db = await get_db()
    try:
        cursor = await db.execute(
            """
            SELECT
                id,
                default_subscription_notify,
                report_language,
                created_at,
                updated_at
            FROM app_settings
            ORDER BY id
            """
        )
        return await cursor.fetchall()
    finally:
        await db.close()
