"""Tests for API endpoints."""

from __future__ import annotations

import asyncio
import json
from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, patch

from httpx import AsyncClient

from src.models.database import get_db
from src.services.scheduler_service import SchedulerService


async def _insert_subscription_alert(
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


async def _insert_subscription_task(
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
                    language,
                    max_items,
                    status,
                    sources,
                    created_at,
                    updated_at,
                    subscription_id
                )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                task_id,
                "openai",
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


async def _fetch_subscription_notify(subscription_id: str) -> bool:
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


async def _fetch_app_settings_rows() -> list[object]:
    """Return all persisted app settings rows."""
    db = await get_db()
    try:
        cursor = await db.execute(
            """
            SELECT id, default_subscription_notify, created_at, updated_at
            FROM app_settings
            ORDER BY id
            """
        )
        return await cursor.fetchall()
    finally:
        await db.close()


class TestHealthCheck:
    """Tests for the health check endpoint."""

    async def test_health_check(self, client: AsyncClient) -> None:
        """GET /health returns 200 with status ok."""
        response = await client.get("/health")

        assert response.status_code == 200
        assert response.json() == {"status": "ok"}


class TestTaskEndpoints:
    """Tests for task CRUD endpoints."""

    @patch("src.api.endpoints.tasks.task_service._process_task", new_callable=AsyncMock)
    async def test_create_task(
        self, mock_process: AsyncMock, client: AsyncClient
    ) -> None:
        """POST /api/v1/tasks with valid body returns 201 with task data."""
        body = {
            "keyword": "artificial intelligence",
            "language": "en",
            "max_items": 20,
            "sources": ["reddit", "youtube"],
        }

        response = await client.post("/api/v1/tasks", json=body)

        assert response.status_code == 201
        data = response.json()
        assert data["keyword"] == "artificial intelligence"
        assert data["language"] == "en"
        assert data["max_items"] == 20
        assert data["status"] == "pending"
        assert "sentiment_score" in data
        assert data["sentiment_score"] is None
        assert "post_count" in data
        assert data["post_count"] is None
        assert "id" in data
        assert "created_at" in data

    async def test_create_task_invalid_keyword(self, client: AsyncClient) -> None:
        """POST with empty keyword returns 422."""
        body = {
            "keyword": "",
            "language": "en",
            "sources": ["reddit"],
        }

        response = await client.post("/api/v1/tasks", json=body)

        assert response.status_code == 422

    @patch("src.api.endpoints.tasks.task_service._process_task", new_callable=AsyncMock)
    async def test_list_tasks(
        self, mock_process: AsyncMock, client: AsyncClient
    ) -> None:
        """GET /api/v1/tasks returns task list."""
        create_body = {
            "keyword": "test keyword",
            "sources": ["reddit"],
        }
        await client.post("/api/v1/tasks", json=create_body)

        response = await client.get("/api/v1/tasks")

        assert response.status_code == 200
        data = response.json()
        assert "tasks" in data
        assert "total" in data
        assert data["total"] >= 1

    @patch("src.api.endpoints.tasks.task_service._process_task", new_callable=AsyncMock)
    async def test_get_task(self, mock_process: AsyncMock, client: AsyncClient) -> None:
        """GET /api/v1/tasks/{id} returns task."""
        create_resp = await client.post(
            "/api/v1/tasks",
            json={"keyword": "test", "sources": ["reddit"]},
        )
        task_id = create_resp.json()["id"]

        response = await client.get(f"/api/v1/tasks/{task_id}")

        assert response.status_code == 200
        assert response.json()["id"] == task_id

    @patch(
        "src.services.task_service.TaskService._process_task", new_callable=AsyncMock
    )
    async def test_task_endpoints_include_partial_report_fields(
        self, mock_process: AsyncMock, client: AsyncClient
    ) -> None:
        """Task detail/list endpoints must expose partial report fields."""
        create_subscription_body = {
            "keyword": "openai",
            "language": "en",
            "max_items": 25,
            "sources": ["reddit", "youtube"],
            "interval": "daily",
            "notify": True,
        }
        create_subscription_response = await client.post(
            "/api/v1/subscriptions", json=create_subscription_body
        )
        subscription_id = create_subscription_response.json()["id"]

        create_task_response = await client.post(
            f"/api/v1/subscriptions/{subscription_id}/tasks"
        )
        task_id = create_task_response.json()["id"]
        await asyncio.sleep(0)
        mock_process.assert_awaited_once()

        db = await get_db()
        try:
            await db.execute(
                "UPDATE tasks SET status = ?, error_message = ?, updated_at = ? "
                "WHERE id = ?",
                (
                    "partial",
                    "Completed with source failures: youtube (API down).",
                    "2026-03-29T00:05:00Z",
                    task_id,
                ),
            )
            await db.executemany(
                """
                INSERT INTO raw_posts
                    (id, task_id, source, content, collected_at)
                VALUES (?, ?, ?, ?, ?)
                """,
                [
                    (
                        "post-1",
                        task_id,
                        "reddit",
                        "First collected post",
                        "2026-03-29T00:03:00Z",
                    ),
                    (
                        "post-2",
                        task_id,
                        "reddit",
                        "Second collected post",
                        "2026-03-29T00:04:00Z",
                    ),
                ],
            )
            await db.execute(
                """
                INSERT INTO analysis_reports
                    (
                        id,
                        task_id,
                        sentiment_score,
                        positive_ratio,
                        negative_ratio,
                        neutral_ratio,
                        heat_index,
                        key_insights,
                        summary,
                        raw_analysis_json,
                        created_at
                    )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    "report-1",
                    task_id,
                    72.5,
                    0.6,
                    0.1,
                    0.3,
                    80.0,
                    json.dumps(
                        [
                            {
                                "text": "Reddit sentiment stayed positive.",
                                "sentiment": "positive",
                                "source_count": 2,
                            }
                        ]
                    ),
                    "Completed with partial source coverage.",
                    None,
                    "2026-03-29T00:05:00Z",
                ),
            )
            await db.commit()
        finally:
            await db.close()

        detail_response = await client.get(f"/api/v1/tasks/{task_id}")
        list_response = await client.get("/api/v1/tasks")
        subscription_tasks_response = await client.get(
            f"/api/v1/subscriptions/{subscription_id}/tasks"
        )

        assert detail_response.status_code == 200
        assert list_response.status_code == 200
        assert subscription_tasks_response.status_code == 200

        detail_data = detail_response.json()
        list_task = next(
            item for item in list_response.json()["tasks"] if item["id"] == task_id
        )
        subscription_task = subscription_tasks_response.json()["tasks"][0]

        for payload in (detail_data, list_task, subscription_task):
            assert payload["status"] == "partial"
            assert payload["sentiment_score"] == 72.5
            assert payload["post_count"] == 2
            assert (
                payload["error_message"]
                == "Completed with source failures: youtube (API down)."
            )

    @patch("src.api.endpoints.tasks.task_service._process_task", new_callable=AsyncMock)
    async def test_get_task_report_includes_mermaid_mindmap(
        self, mock_process: AsyncMock, client: AsyncClient
    ) -> None:
        """Task report endpoint must expose Mermaid mindmap output."""
        create_response = await client.post(
            "/api/v1/tasks",
            json={
                "keyword": "openai",
                "language": "en",
                "max_items": 20,
                "sources": ["reddit"],
            },
        )
        task_id = create_response.json()["id"]

        db = await get_db()
        try:
            await db.execute(
                """
                INSERT INTO analysis_reports
                    (
                        id,
                        task_id,
                        sentiment_score,
                        positive_ratio,
                        negative_ratio,
                        neutral_ratio,
                        heat_index,
                        key_insights,
                        summary,
                        raw_analysis_json,
                        created_at
                    )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    "report-mermaid-1",
                    task_id,
                    28.0,
                    0.2,
                    0.6,
                    0.2,
                    51.0,
                    json.dumps(
                        [
                            {
                                "text": "Support quality dropped",
                                "sentiment": "negative",
                                "source_count": 6,
                            }
                        ]
                    ),
                    "Support conversations are trending negative.",
                    json.dumps(
                        {
                            "mermaid_mindmap": (
                                "mindmap\n"
                                "  root((openai))\n"
                                "    Summary\n"
                                "      Support conversations are trending negative.\n"
                                "    Insight 1\n"
                                "      Support quality dropped\n"
                            )
                        }
                    ),
                    "2026-03-29T00:05:00Z",
                ),
            )
            await db.commit()
        finally:
            await db.close()

        response = await client.get(f"/api/v1/tasks/{task_id}/report")

        assert response.status_code == 200
        payload = response.json()
        assert payload["task_id"] == task_id
        assert payload["summary"] == "Support conversations are trending negative."
        assert payload["mermaid_mindmap"].startswith("mindmap\n")
        assert "root((openai))" in payload["mermaid_mindmap"]

    @patch("src.api.endpoints.tasks.task_service._process_task", new_callable=AsyncMock)
    async def test_get_task_report_rebuilds_mermaid_mindmap_when_raw_payload_missing(
        self, mock_process: AsyncMock, client: AsyncClient
    ) -> None:
        """Task report endpoint should rebuild Mermaid from the canonical contract."""
        create_response = await client.post(
            "/api/v1/tasks",
            json={
                "keyword": "openai",
                "language": "en",
                "max_items": 20,
                "sources": ["reddit"],
            },
        )
        task_id = create_response.json()["id"]

        db = await get_db()
        try:
            await db.execute(
                """
                INSERT INTO analysis_reports
                    (
                        id,
                        task_id,
                        sentiment_score,
                        positive_ratio,
                        negative_ratio,
                        neutral_ratio,
                        heat_index,
                        key_insights,
                        summary,
                        raw_analysis_json,
                        created_at
                    )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    "report-mermaid-2",
                    task_id,
                    41.0,
                    0.3,
                    0.4,
                    0.3,
                    49.0,
                    json.dumps(
                        [
                            {
                                "text": "Support quality dropped",
                                "sentiment": "negative",
                                "source_count": 6,
                            }
                        ]
                    ),
                    "Support conversations are trending negative.",
                    None,
                    "2026-03-29T00:06:00Z",
                ),
            )
            await db.commit()
        finally:
            await db.close()

        response = await client.get(f"/api/v1/tasks/{task_id}/report")

        assert response.status_code == 200
        payload = response.json()
        assert payload["task_id"] == task_id
        assert payload["mermaid_mindmap"].startswith("mindmap\n")
        assert "root((openai))" in payload["mermaid_mindmap"]
        assert "Viewpoints" in payload["mermaid_mindmap"]
        assert "Support quality dropped" in payload["mermaid_mindmap"]

    async def test_get_task_not_found(self, client: AsyncClient) -> None:
        """GET /api/v1/tasks/nonexistent returns 404."""
        response = await client.get("/api/v1/tasks/nonexistent-id-12345")

        assert response.status_code == 404

    @patch("src.api.endpoints.tasks.task_service._process_task", new_callable=AsyncMock)
    async def test_delete_task(
        self, mock_process: AsyncMock, client: AsyncClient
    ) -> None:
        """DELETE /api/v1/tasks/{id} returns 204."""
        create_resp = await client.post(
            "/api/v1/tasks",
            json={"keyword": "to delete", "sources": ["reddit"]},
        )
        task_id = create_resp.json()["id"]

        response = await client.delete(f"/api/v1/tasks/{task_id}")

        assert response.status_code == 204

        get_resp = await client.get(f"/api/v1/tasks/{task_id}")
        assert get_resp.status_code == 404


class TestNotificationSettingsEndpoints:
    """Tests for notification settings endpoints."""

    async def test_init_db_seeds_single_app_settings_row(self) -> None:
        """Database init must seed exactly one default app-settings row."""
        rows = await _fetch_app_settings_rows()

        assert len(rows) == 1
        assert rows[0]["id"] == 1
        assert bool(rows[0]["default_subscription_notify"]) is True
        assert rows[0]["created_at"]
        assert rows[0]["updated_at"]

    async def test_get_notification_settings_defaults_to_enabled(
        self, client: AsyncClient
    ) -> None:
        """GET returns the default subscription notification setting."""
        response = await client.get("/api/v1/settings/notifications")

        assert response.status_code == 200
        assert response.json() == {"subscription_notify_default": True}

    async def test_update_notification_settings_applies_to_existing_subscriptions(
        self, client: AsyncClient
    ) -> None:
        """PUT can update the global default and sync existing subscriptions."""
        first_response = await client.post(
            "/api/v1/subscriptions",
            json={
                "keyword": "openai",
                "language": "en",
                "max_items": 25,
                "sources": ["reddit", "x"],
                "interval": "daily",
                "notify": True,
            },
        )
        second_response = await client.post(
            "/api/v1/subscriptions",
            json={
                "keyword": "cursor",
                "language": "en",
                "max_items": 25,
                "sources": ["reddit", "youtube"],
                "interval": "daily",
                "notify": False,
            },
        )

        response = await client.put(
            "/api/v1/settings/notifications",
            json={
                "subscription_notify_default": False,
                "apply_to_existing": True,
            },
        )

        assert response.status_code == 200
        assert response.json() == {"subscription_notify_default": False}

        get_response = await client.get("/api/v1/settings/notifications")
        assert get_response.status_code == 200
        assert get_response.json() == {"subscription_notify_default": False}

        first_subscription_id = first_response.json()["id"]
        second_subscription_id = second_response.json()["id"]
        assert await _fetch_subscription_notify(first_subscription_id) is False
        assert await _fetch_subscription_notify(second_subscription_id) is False

    async def test_update_notification_settings_without_apply_keeps_existing_notify(
        self, client: AsyncClient
    ) -> None:
        """PUT with apply_to_existing=false must not rewrite current subscriptions."""
        first_response = await client.post(
            "/api/v1/subscriptions",
            json={
                "keyword": "openai",
                "language": "en",
                "max_items": 25,
                "sources": ["reddit", "x"],
                "interval": "daily",
                "notify": True,
            },
        )
        second_response = await client.post(
            "/api/v1/subscriptions",
            json={
                "keyword": "cursor",
                "language": "en",
                "max_items": 25,
                "sources": ["reddit", "youtube"],
                "interval": "daily",
                "notify": False,
            },
        )

        response = await client.put(
            "/api/v1/settings/notifications",
            json={
                "subscription_notify_default": False,
                "apply_to_existing": False,
            },
        )

        assert response.status_code == 200
        first_subscription_id = first_response.json()["id"]
        second_subscription_id = second_response.json()["id"]
        assert await _fetch_subscription_notify(first_subscription_id) is True
        assert await _fetch_subscription_notify(second_subscription_id) is False

    async def test_create_subscription_without_notify_uses_backend_default(
        self, client: AsyncClient
    ) -> None:
        """Omitted notify should use the persisted backend default."""
        update_response = await client.put(
            "/api/v1/settings/notifications",
            json={
                "subscription_notify_default": False,
                "apply_to_existing": False,
            },
        )
        assert update_response.status_code == 200

        response = await client.post(
            "/api/v1/subscriptions",
            json={
                "keyword": "openai",
                "language": "en",
                "max_items": 25,
                "sources": ["reddit", "x"],
                "interval": "daily",
            },
        )

        assert response.status_code == 201
        assert response.json()["notify"] is False
        assert await _fetch_subscription_notify(response.json()["id"]) is False

    async def test_create_subscription_explicit_notify_overrides_backend_default(
        self, client: AsyncClient
    ) -> None:
        """Explicit notify should override the persisted backend default."""
        update_response = await client.put(
            "/api/v1/settings/notifications",
            json={
                "subscription_notify_default": False,
                "apply_to_existing": False,
            },
        )
        assert update_response.status_code == 200

        response = await client.post(
            "/api/v1/subscriptions",
            json={
                "keyword": "openai",
                "language": "en",
                "max_items": 25,
                "sources": ["reddit", "x"],
                "interval": "daily",
                "notify": True,
            },
        )

        assert response.status_code == 201
        assert response.json()["notify"] is True
        assert await _fetch_subscription_notify(response.json()["id"]) is True

    async def test_create_subscription_rejects_null_notify(
        self, client: AsyncClient
    ) -> None:
        """Explicit null notify must fail validation."""
        response = await client.post(
            "/api/v1/subscriptions",
            json={
                "keyword": "openai",
                "language": "en",
                "max_items": 25,
                "sources": ["reddit", "x"],
                "interval": "daily",
                "notify": None,
            },
        )

        assert response.status_code == 422


class TestSubscriptionEndpoints:
    """Tests for subscription CRUD and execution endpoints."""

    @patch(
        "src.services.task_service.TaskService._process_task",
        new_callable=AsyncMock,
    )
    async def test_run_subscription_now_creates_linked_task(
        self, mock_process: AsyncMock, client: AsyncClient
    ) -> None:
        """POST /api/v1/subscriptions/{id}/tasks creates a linked task."""
        create_subscription_body = {
            "keyword": "openai",
            "language": "en",
            "max_items": 25,
            "sources": ["reddit", "x"],
            "interval": "daily",
            "notify": True,
        }

        create_subscription_response = await client.post(
            "/api/v1/subscriptions", json=create_subscription_body
        )
        subscription_id = create_subscription_response.json()["id"]

        response = await client.post(f"/api/v1/subscriptions/{subscription_id}/tasks")

        assert response.status_code == 201
        data = response.json()
        assert data["keyword"] == create_subscription_body["keyword"]
        assert data["language"] == create_subscription_body["language"]
        assert data["max_items"] == create_subscription_body["max_items"]
        assert data["sources"] == create_subscription_body["sources"]
        assert data["subscription_id"] == subscription_id
        assert data["status"] == "pending"
        assert "sentiment_score" in data
        assert data["sentiment_score"] is None
        assert "post_count" in data
        assert data["post_count"] is None

        task_list_response = await client.get(
            f"/api/v1/subscriptions/{subscription_id}/tasks"
        )

        assert task_list_response.status_code == 200
        task_list_data = task_list_response.json()
        assert task_list_data["total"] == 1
        assert task_list_data["tasks"][0]["id"] == data["id"]

        subscription_detail_response = await client.get(
            f"/api/v1/subscriptions/{subscription_id}"
        )
        subscription_detail_data = subscription_detail_response.json()
        assert subscription_detail_data["last_run_at"] is not None

    async def test_run_subscription_now_not_found(self, client: AsyncClient) -> None:
        """POST /api/v1/subscriptions/{id}/tasks returns 404 when missing."""
        response = await client.post("/api/v1/subscriptions/missing-subscription/tasks")

        assert response.status_code == 404

    async def test_subscription_endpoints_include_unread_alert_summary_fields(
        self, client: AsyncClient
    ) -> None:
        """List/detail subscription endpoints must expose unread alert summary data."""
        create_subscription_response = await client.post(
            "/api/v1/subscriptions",
            json={
                "keyword": "openai",
                "language": "en",
                "max_items": 25,
                "sources": ["reddit", "x"],
                "interval": "daily",
                "notify": True,
            },
        )
        subscription_id = create_subscription_response.json()["id"]
        first_task_id = "task-alert-1"
        latest_task_id = "task-alert-2"
        await _insert_subscription_task(
            task_id=first_task_id,
            subscription_id=subscription_id,
            created_at="2026-03-29T00:01:00Z",
        )
        await _insert_subscription_task(
            task_id=latest_task_id,
            subscription_id=subscription_id,
            created_at="2026-03-29T00:02:00Z",
        )

        await _insert_subscription_alert(
            alert_id="alert-1",
            subscription_id=subscription_id,
            task_id=first_task_id,
            sentiment_score=24.0,
            created_at="2026-03-29T00:01:00Z",
        )
        await _insert_subscription_alert(
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
                "language": "en",
                "max_items": 25,
                "sources": ["reddit", "youtube"],
                "interval": "daily",
                "notify": True,
            },
        )
        subscription_id = create_subscription_response.json()["id"]
        first_task_id = "task-read-1"
        second_task_id = "task-read-2"
        await _insert_subscription_task(
            task_id=first_task_id,
            subscription_id=subscription_id,
            created_at="2026-03-29T00:01:00Z",
        )
        await _insert_subscription_task(
            task_id=second_task_id,
            subscription_id=subscription_id,
            created_at="2026-03-29T00:02:00Z",
        )

        await _insert_subscription_alert(
            alert_id="alert-read-1",
            subscription_id=subscription_id,
            task_id=first_task_id,
            sentiment_score=19.0,
            created_at="2026-03-29T00:01:00Z",
        )
        await _insert_subscription_alert(
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
            "language": "en",
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
