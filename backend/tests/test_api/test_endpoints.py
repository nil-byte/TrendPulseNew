"""Tests for API endpoints."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, patch

from httpx import AsyncClient

from src.models.database import get_db
from src.services.scheduler_service import SchedulerService


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
    async def test_get_task(
        self, mock_process: AsyncMock, client: AsyncClient
    ) -> None:
        """GET /api/v1/tasks/{id} returns task."""
        create_resp = await client.post(
            "/api/v1/tasks",
            json={"keyword": "test", "sources": ["reddit"]},
        )
        task_id = create_resp.json()["id"]

        response = await client.get(f"/api/v1/tasks/{task_id}")

        assert response.status_code == 200
        assert response.json()["id"] == task_id

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

        response = await client.post(
            f"/api/v1/subscriptions/{subscription_id}/tasks"
        )

        assert response.status_code == 201
        data = response.json()
        assert data["keyword"] == create_subscription_body["keyword"]
        assert data["language"] == create_subscription_body["language"]
        assert data["max_items"] == create_subscription_body["max_items"]
        assert data["sources"] == create_subscription_body["sources"]
        assert data["subscription_id"] == subscription_id
        assert data["status"] == "pending"

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

    async def test_run_subscription_now_not_found(
        self, client: AsyncClient
    ) -> None:
        """POST /api/v1/subscriptions/{id}/tasks returns 404 when missing."""
        response = await client.post(
            "/api/v1/subscriptions/missing-subscription/tasks"
        )

        assert response.status_code == 404

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
