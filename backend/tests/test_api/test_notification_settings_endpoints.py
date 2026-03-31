"""App-level notification and report-language endpoint tests."""

from __future__ import annotations

from httpx import AsyncClient

from tests.test_api.helpers import fetch_app_settings_rows, fetch_subscription_notify


class TestNotificationSettingsEndpoints:
    """Tests for notification settings endpoints."""

    async def test_init_db_seeds_single_app_settings_row(self) -> None:
        """Database init must seed exactly one default app-settings row."""
        rows = await fetch_app_settings_rows()

        assert len(rows) == 1
        assert rows[0]["id"] == 1
        assert bool(rows[0]["default_subscription_notify"]) is True
        assert rows[0]["report_language"] == "en"
        assert rows[0]["created_at"]
        assert rows[0]["updated_at"]

    async def test_get_report_language_defaults_to_english(
        self, client: AsyncClient
    ) -> None:
        """GET returns the persisted app-level report language."""
        response = await client.get("/api/v1/settings/report-language")

        assert response.status_code == 200
        assert response.json() == {"report_language": "en"}

    async def test_update_report_language_persists(
        self, client: AsyncClient
    ) -> None:
        """PUT updates the app-level report language."""
        response = await client.put(
            "/api/v1/settings/report-language",
            json={"report_language": "zh"},
        )

        assert response.status_code == 200
        assert response.json() == {"report_language": "zh"}

        get_response = await client.get("/api/v1/settings/report-language")
        assert get_response.status_code == 200
        assert get_response.json() == {"report_language": "zh"}

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
                "content_language": "en",
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
                "content_language": "en",
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
        assert await fetch_subscription_notify(first_subscription_id) is False
        assert await fetch_subscription_notify(second_subscription_id) is False

    async def test_update_notification_settings_without_apply_keeps_existing_notify(
        self, client: AsyncClient
    ) -> None:
        """PUT with apply_to_existing=false must not rewrite current subscriptions."""
        first_response = await client.post(
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
        second_response = await client.post(
            "/api/v1/subscriptions",
            json={
                "keyword": "cursor",
                "content_language": "en",
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
        assert await fetch_subscription_notify(first_subscription_id) is True
        assert await fetch_subscription_notify(second_subscription_id) is False
