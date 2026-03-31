"""Subscription alert summary and reschedule endpoint tests."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, patch

from httpx import AsyncClient

from src.models.database import get_db
from src.services.scheduler_service import SchedulerService
from tests.test_api.helpers import insert_subscription_alert, insert_subscription_task


class TestSubscriptionAlertEndpoints:
    """Tests for subscription alert summary and rescheduling behavior."""

    async def test_subscription_endpoints_include_unread_alert_summary_fields(
        self, client: AsyncClient
    ) -> None:
        """List/detail subscription endpoints must expose unread alert summary data."""
        create_subscription_response = await client.post(
            "/api/v1/subscriptions",
            json={
                "keyword": "openai",
                "content_language": "en",
                "max_items": 25,
                "sources": ["reddit", "x"],
                "interval": "daily",
                "notify": True,
            },
        )
        subscription_id = create_subscription_response.json()["id"]
        first_task_id = "task-alert-1"
        latest_task_id = "task-alert-2"
        await insert_subscription_task(
            task_id=first_task_id,
            subscription_id=subscription_id,
            created_at="2026-03-29T00:01:00Z",
        )
        await insert_subscription_task(
            task_id=latest_task_id,
            subscription_id=subscription_id,
            created_at="2026-03-29T00:02:00Z",
        )

        await insert_subscription_alert(
            alert_id="alert-1",
            subscription_id=subscription_id,
            task_id=first_task_id,
            sentiment_score=24.0,
            created_at="2026-03-29T00:01:00Z",
        )
        await insert_subscription_alert(
            alert_id="alert-2",
            subscription_id=subscription_id,
            task_id=latest_task_id,
            sentiment_score=12.5,
            created_at="2026-03-29T00:02:00Z",
        )

        list_response = await client.get("/api/v1/subscriptions")
        detail_response = await client.get(f"/api/v1/subscriptions/{subscription_id}")

        assert list_response.status_code == 200
        assert detail_response.status_code == 200

        list_item = next(
            item
            for item in list_response.json()["subscriptions"]
            if item["id"] == subscription_id
        )

        for payload in (list_item, detail_response.json()):
            assert payload["unread_alert_count"] == 2
            assert payload["latest_unread_alert_task_id"] == latest_task_id
            assert payload["latest_unread_alert_score"] == 12.5

    async def test_mark_subscription_alerts_read_clears_unread_summary(
        self, client: AsyncClient
    ) -> None:
        """Mark-read endpoint must clear unread alert summary data."""
        create_subscription_response = await client.post(
            "/api/v1/subscriptions",
            json={
                "keyword": "openai",
                "content_language": "en",
                "max_items": 25,
                "sources": ["reddit", "youtube"],
                "interval": "daily",
                "notify": True,
            },
        )
        subscription_id = create_subscription_response.json()["id"]
        first_task_id = "task-read-1"
        second_task_id = "task-read-2"
        await insert_subscription_task(
            task_id=first_task_id,
            subscription_id=subscription_id,
            created_at="2026-03-29T00:01:00Z",
        )
        await insert_subscription_task(
            task_id=second_task_id,
            subscription_id=subscription_id,
            created_at="2026-03-29T00:02:00Z",
        )

        await insert_subscription_alert(
            alert_id="alert-read-1",
            subscription_id=subscription_id,
            task_id=first_task_id,
            sentiment_score=19.0,
            created_at="2026-03-29T00:01:00Z",
        )
        await insert_subscription_alert(
            alert_id="alert-read-2",
            subscription_id=subscription_id,
            task_id=second_task_id,
            sentiment_score=11.0,
            created_at="2026-03-29T00:02:00Z",
        )

        response = await client.post(
            f"/api/v1/subscriptions/{subscription_id}/alerts/read"
        )

        assert response.status_code == 204

        db = await get_db()
        try:
            cursor = await db.execute(
                """
                SELECT COUNT(*) AS unread_count
                FROM subscription_alerts
                WHERE subscription_id = ? AND is_read = 0
                """,
                (subscription_id,),
            )
            row = await cursor.fetchone()
            assert row is not None
            assert int(row["unread_count"]) == 0
        finally:
            await db.close()

        list_response = await client.get("/api/v1/subscriptions")
        detail_response = await client.get(f"/api/v1/subscriptions/{subscription_id}")
        list_item = next(
            item
            for item in list_response.json()["subscriptions"]
            if item["id"] == subscription_id
        )

        for payload in (list_item, detail_response.json()):
            assert payload["unread_alert_count"] == 0
            assert payload["latest_unread_alert_task_id"] is None
            assert payload["latest_unread_alert_score"] is None

    @patch(
        "src.services.task_service.TaskService._process_task",
        new_callable=AsyncMock,
    )
    async def test_run_subscription_now_reschedules_overdue_subscription(
        self, mock_process: AsyncMock, client: AsyncClient
    ) -> None:
        """Manual runs should clear overdue state to avoid duplicate scheduler tasks."""
        create_subscription_body = {
            "keyword": "openai",
            "content_language": "en",
            "max_items": 25,
            "sources": ["reddit", "x"],
            "interval": "daily",
            "notify": True,
        }

        create_subscription_response = await client.post(
            "/api/v1/subscriptions", json=create_subscription_body
        )
        subscription_id = create_subscription_response.json()["id"]

        overdue_at = (datetime.now(timezone.utc) - timedelta(minutes=5)).isoformat()
        db = await get_db()
        try:
            await db.execute(
                "UPDATE subscriptions SET next_run_at = ? WHERE id = ?",
                (overdue_at, subscription_id),
            )
            await db.commit()
        finally:
            await db.close()

        run_now_response = await client.post(
            f"/api/v1/subscriptions/{subscription_id}/tasks"
        )

        assert run_now_response.status_code == 201

        scheduler = SchedulerService()
        await scheduler._tick()

        task_list_response = await client.get(
            f"/api/v1/subscriptions/{subscription_id}/tasks"
        )
        task_list_data = task_list_response.json()

        assert task_list_response.status_code == 200
        assert task_list_data["total"] == 1

        subscription_detail_response = await client.get(
            f"/api/v1/subscriptions/{subscription_id}"
        )
        subscription_detail_data = subscription_detail_response.json()

        assert subscription_detail_response.status_code == 200
        assert subscription_detail_data["next_run_at"] is not None
        assert subscription_detail_data["next_run_at"] > overdue_at
        assert mock_process.call_count == 1
