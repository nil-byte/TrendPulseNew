"""Tests for API endpoints."""

from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest
from httpx import AsyncClient


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
