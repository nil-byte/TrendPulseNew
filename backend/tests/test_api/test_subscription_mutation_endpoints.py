"""Subscription mutation and manual-run endpoint tests."""

from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest
from httpx import AsyncClient

from src.config.settings import settings


class TestSubscriptionMutationEndpoints:
    """Tests for subscription CRUD and manual execution endpoints."""

    @patch(
        "src.services.task_service.TaskService._process_task",
        new_callable=AsyncMock,
    )
    async def test_run_subscription_now_creates_linked_task(
        self,
        mock_process: AsyncMock,
        client: AsyncClient,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        """POST /api/v1/subscriptions/{id}/tasks creates a linked task."""
        monkeypatch.setattr(settings, "grok_api_key", "grok-key")
        create_subscription_body = {
            "keyword": "openai",
            "content_language": "zh",
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
        assert data["content_language"] == create_subscription_body["content_language"]
        assert data["report_language"] == "en"
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

    async def test_run_subscription_now_returns_422_when_all_sources_unavailable(
        self,
        client: AsyncClient,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        """Manual runs should fail fast with no runnable subscription sources."""
        monkeypatch.setattr(settings, "reddit_client_id", "")
        monkeypatch.setattr(settings, "reddit_client_secret", "")
        create_subscription_response = await client.post(
            "/api/v1/subscriptions",
            json={
                "keyword": "openai",
                "content_language": "en",
                "max_items": 25,
                "sources": ["reddit"],
                "interval": "daily",
                "notify": True,
            },
        )
        subscription_id = create_subscription_response.json()["id"]

        response = await client.post(f"/api/v1/subscriptions/{subscription_id}/tasks")

        assert response.status_code == 422
        assert response.json() == {
            "detail": {
                "code": "no_available_sources",
                "message": (
                    "No requested sources are currently available. "
                    "Unavailable sources: reddit "
                    "(Reddit credentials are not configured)."
                ),
            }
        }

    async def test_update_subscription_rejects_duplicate_sources(
        self, client: AsyncClient
    ) -> None:
        """PUT should reject duplicated sources instead of storing them."""
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

        response = await client.put(
            f"/api/v1/subscriptions/{subscription_id}",
            json={"sources": ["x", "x"]},
        )

        assert response.status_code == 422

    async def test_update_subscription_rejects_legacy_language_field(
        self, client: AsyncClient
    ) -> None:
        """PUT should reject the removed language field."""
        create_subscription_response = await client.post(
            "/api/v1/subscriptions",
            json={
                "keyword": "openai",
                "content_language": "en",
                "max_items": 25,
                "sources": ["reddit"],
                "interval": "daily",
                "notify": True,
            },
        )
        subscription_id = create_subscription_response.json()["id"]

        response = await client.put(
            f"/api/v1/subscriptions/{subscription_id}",
            json={"language": "zh"},
        )

        assert response.status_code == 422

    async def test_get_and_update_subscription_only_expose_content_language(
        self, client: AsyncClient
    ) -> None:
        """Subscription GET/PUT responses must expose content_language only."""
        create_subscription_response = await client.post(
            "/api/v1/subscriptions",
            json={
                "keyword": "openai",
                "content_language": "zh",
                "max_items": 25,
                "sources": ["reddit"],
                "interval": "daily",
                "notify": True,
            },
        )
        subscription_id = create_subscription_response.json()["id"]

        get_response = await client.get(f"/api/v1/subscriptions/{subscription_id}")
        update_response = await client.put(
            f"/api/v1/subscriptions/{subscription_id}",
            json={"content_language": "en"},
        )

        assert get_response.status_code == 200
        get_payload = get_response.json()
        assert get_payload["content_language"] == "zh"
        assert "language" not in get_payload

        assert update_response.status_code == 200
        update_payload = update_response.json()
        assert update_payload["content_language"] == "en"
        assert "language" not in update_payload
