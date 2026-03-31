"""Task creation endpoint tests."""

from __future__ import annotations

import asyncio
from pathlib import Path
from unittest.mock import AsyncMock, patch

import pytest
from httpx import AsyncClient

from src.config.settings import settings
from src.services.source_availability_service import source_availability_service


class TestTaskCreationEndpoints:
    """Tests for task creation endpoint behavior."""

    @patch("src.api.endpoints.tasks.task_service._process_task", new_callable=AsyncMock)
    async def test_create_task(
        self, mock_process: AsyncMock, client: AsyncClient
    ) -> None:
        """POST /api/v1/tasks with valid body returns 201 with task data."""
        body = {
            "keyword": "artificial intelligence",
            "content_language": "zh",
            "report_language": "en",
            "max_items": 20,
            "sources": ["reddit", "youtube"],
        }

        response = await client.post("/api/v1/tasks", json=body)

        assert response.status_code == 201
        data = response.json()
        assert data["keyword"] == "artificial intelligence"
        assert data["content_language"] == "zh"
        assert data["report_language"] == "en"
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
            "content_language": "en",
            "report_language": "en",
            "sources": ["reddit"],
        }

        response = await client.post("/api/v1/tasks", json=body)

        assert response.status_code == 422

    async def test_create_task_rejects_legacy_language_field(
        self, client: AsyncClient
    ) -> None:
        """POST should reject the removed legacy language field."""
        response = await client.post(
            "/api/v1/tasks",
            json={
                "keyword": "ai",
                "language": "zh",
                "max_items": 20,
                "sources": ["reddit"],
            },
        )

        assert response.status_code == 422

    async def test_create_task_rejects_duplicate_sources(
        self, client: AsyncClient
    ) -> None:
        """POST should reject duplicated sources to avoid duplicate collection."""
        response = await client.post(
            "/api/v1/tasks",
            json={
                "keyword": "ai",
                "content_language": "en",
                "report_language": "en",
                "max_items": 20,
                "sources": ["reddit", "reddit"],
            },
        )

        assert response.status_code == 422

    @patch("src.api.endpoints.tasks.task_service._process_task", new_callable=AsyncMock)
    async def test_create_task_filters_unavailable_sources(
        self,
        mock_process: AsyncMock,
        client: AsyncClient,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        """Task responses should reflect only the runnable source set."""
        source_availability_service.reset_runtime_state()
        monkeypatch.setattr(settings, "reddit_client_id", "reddit-id")
        monkeypatch.setattr(settings, "reddit_client_secret", "reddit-secret")
        monkeypatch.setattr(settings, "youtube_api_key", "youtube-key")
        monkeypatch.setattr(settings, "grok_api_key", "")

        response = await client.post(
            "/api/v1/tasks",
            json={
                "keyword": "ai",
                "content_language": "zh",
                "report_language": "en",
                "max_items": 20,
                "sources": ["youtube", "x"],
            },
        )

        assert response.status_code == 201
        assert response.json()["sources"] == ["youtube"]
        await asyncio.sleep(0)
        mock_process.assert_awaited_once()
        await_args = mock_process.await_args
        assert await_args.args[1].sources == ["youtube"]
        assert (
            await_args.kwargs["initial_source_errors"]["x"].reason_code
            == "grok_api_key_missing"
        )

    @patch("src.api.endpoints.tasks.task_service._process_task", new_callable=AsyncMock)
    async def test_create_task_keeps_degraded_sources_runnable(
        self,
        mock_process: AsyncMock,
        client: AsyncClient,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        """Runtime failures should warn, but still allow users to retry the source."""
        source_availability_service.reset_runtime_state()
        monkeypatch.setattr(settings, "reddit_client_id", "reddit-id")
        monkeypatch.setattr(settings, "reddit_client_secret", "reddit-secret")
        monkeypatch.setattr(settings, "youtube_api_key", "youtube-key")
        monkeypatch.setattr(settings, "grok_api_key", "grok-key")
        source_availability_service.record_failure(
            "reddit",
            "reddit_network_unreachable",
            "Reddit collection failed: error with request "
            "Cannot connect to host oauth.reddit.com:443 ssl:default [None]",
        )

        response = await client.post(
            "/api/v1/tasks",
            json={
                "keyword": "ai",
                "content_language": "zh",
                "report_language": "en",
                "max_items": 20,
                "sources": ["reddit", "youtube"],
            },
        )

        assert response.status_code == 201
        assert response.json()["sources"] == ["reddit", "youtube"]
        await asyncio.sleep(0)
        mock_process.assert_awaited_once()
        await_args = mock_process.await_args
        assert await_args.args[1].sources == ["reddit", "youtube"]
        assert await_args.kwargs["initial_source_errors"] == {}

    async def test_create_task_rejects_when_all_requested_sources_are_unavailable(
        self,
        client: AsyncClient,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        """Task creation should fail fast when no requested source can run."""
        source_availability_service.reset_runtime_state()
        monkeypatch.setattr(settings, "reddit_client_id", "")
        monkeypatch.setattr(settings, "reddit_client_secret", "")
        monkeypatch.setattr(settings, "youtube_api_key", "")
        monkeypatch.setattr(settings, "grok_api_key", "")

        response = await client.post(
            "/api/v1/tasks",
            json={
                "keyword": "ai",
                "content_language": "zh",
                "report_language": "en",
                "max_items": 20,
                "sources": ["reddit", "x"],
            },
        )

        assert response.status_code == 422
        assert response.json() == {
            "detail": {
                "code": "no_available_sources",
                "message": (
                    "No requested sources are currently available. "
                    "Unavailable sources: reddit (Reddit credentials are not "
                    "configured); x (Grok API key is not configured)."
                ),
            }
        }

    async def test_create_task_rejects_invalid_reddit_ca_before_collection(
        self,
        client: AsyncClient,
        monkeypatch: pytest.MonkeyPatch,
        tmp_path: Path,
    ) -> None:
        """Task creation should fail fast on an invalid Reddit CA file path."""
        source_availability_service.reset_runtime_state()
        monkeypatch.setattr(settings, "reddit_client_id", "reddit-id")
        monkeypatch.setattr(settings, "reddit_client_secret", "reddit-secret")
        invalid_ca = tmp_path / "invalid-reddit-ca.pem"
        invalid_ca.write_text("not a valid certificate bundle", encoding="utf-8")
        monkeypatch.setattr(
            settings,
            "reddit_ssl_ca_file",
            str(invalid_ca),
        )

        response = await client.post(
            "/api/v1/tasks",
            json={
                "keyword": "ai",
                "content_language": "zh",
                "report_language": "en",
                "max_items": 20,
                "sources": ["reddit"],
            },
        )

        assert response.status_code == 422
