"""Subscription creation/default-setting endpoint tests."""

from __future__ import annotations

from httpx import AsyncClient

from tests.test_api.helpers import fetch_subscription_notify


class TestSubscriptionDefaultEndpoints:
    """Tests for subscription creation defaults and validation."""

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
                "content_language": "en",
                "max_items": 25,
                "sources": ["reddit", "x"],
                "interval": "daily",
            },
        )

        assert response.status_code == 201
        assert response.json()["notify"] is False
        assert await fetch_subscription_notify(response.json()["id"]) is False

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
                "content_language": "en",
                "max_items": 25,
                "sources": ["reddit", "x"],
                "interval": "daily",
                "notify": True,
            },
        )

        assert response.status_code == 201
        assert response.json()["notify"] is True
        assert await fetch_subscription_notify(response.json()["id"]) is True

    async def test_create_subscription_rejects_null_notify(
        self, client: AsyncClient
    ) -> None:
        """Explicit null notify must fail validation."""
        response = await client.post(
            "/api/v1/subscriptions",
            json={
                "keyword": "openai",
                "content_language": "en",
                "max_items": 25,
                "sources": ["reddit", "x"],
                "interval": "daily",
                "notify": None,
            },
        )

        assert response.status_code == 422

    async def test_create_subscription_rejects_duplicate_sources(
        self, client: AsyncClient
    ) -> None:
        """Subscriptions should reject duplicated sources up front."""
        response = await client.post(
            "/api/v1/subscriptions",
            json={
                "keyword": "openai",
                "content_language": "en",
                "max_items": 25,
                "sources": ["reddit", "reddit"],
                "interval": "daily",
            },
        )

        assert response.status_code == 422

    async def test_create_subscription_rejects_legacy_language_field(
        self, client: AsyncClient
    ) -> None:
        """Subscriptions should reject the removed legacy language field."""
        response = await client.post(
            "/api/v1/subscriptions",
            json={
                "keyword": "openai",
                "language": "zh",
                "max_items": 25,
                "sources": ["reddit"],
                "interval": "daily",
            },
        )

        assert response.status_code == 422
