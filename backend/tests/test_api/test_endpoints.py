"""Smoke tests for health and source-availability endpoints."""

from __future__ import annotations

from pathlib import Path

import pytest
from httpx import AsyncClient

from src.config.settings import settings
from src.main import create_app
from src.services.source_availability_service import source_availability_service


class TestHealthCheck:
    """Tests for the health check endpoint."""

    def test_create_app_respects_settings_debug_flag(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        """FastAPI debug mode should follow the configured settings flag."""
        monkeypatch.setattr(settings, "debug", True)

        debug_app = create_app()

        assert debug_app.debug is True

    async def test_health_check(self, client: AsyncClient) -> None:
        """GET /health returns 200 with status ok."""
        response = await client.get("/health")

        assert response.status_code == 200
        assert response.json() == {"status": "ok"}

    async def test_health_check_allows_local_browser_cors_preflight(
        self, client: AsyncClient
    ) -> None:
        """CORS should allow localhost preflight requests without credentials."""
        response = await client.options(
            "/health",
            headers={
                "Origin": "http://localhost:3000",
                "Access-Control-Request-Method": "GET",
            },
        )

        assert response.status_code == 200
        assert response.headers["access-control-allow-origin"] == (
            "http://localhost:3000"
        )
        assert "access-control-allow-credentials" not in response.headers


class TestSourceAvailabilityEndpoints:
    """Tests for source availability reporting."""

    async def test_get_source_availability_reports_config_and_runtime_state(
        self,
        client: AsyncClient,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        """Settings endpoint should expose unavailable sources before task creation."""
        source_availability_service.reset_runtime_state()
        monkeypatch.setattr(settings, "reddit_client_id", "reddit-id")
        monkeypatch.setattr(settings, "reddit_client_secret", "reddit-secret")
        monkeypatch.setattr(settings, "youtube_api_key", "youtube-key")
        monkeypatch.setattr(settings, "grok_api_key", "")
        source_availability_service.record_failure(
            "reddit",
            "reddit_network_unreachable",
            "Reddit collection failed: error with request "
            "Cannot connect to host www.reddit.com:443 ssl:default [None]",
        )

        response = await client.get("/api/v1/settings/sources")

        assert response.status_code == 200
        payload = response.json()
        availability_by_source = {item["source"]: item for item in payload["sources"]}

        assert availability_by_source["reddit"]["status"] == "degraded"
        assert availability_by_source["reddit"]["is_available"] is True
        assert (
            availability_by_source["reddit"]["reason"]
            == "Reddit is temporarily unreachable. Check network or proxy settings."
        )
        assert (
            availability_by_source["reddit"]["reason_code"]
            == "reddit_network_unreachable"
        )
        assert availability_by_source["reddit"]["checked_at"]

        assert availability_by_source["youtube"] == {
            "source": "youtube",
            "status": "available",
            "is_available": True,
            "reason": None,
            "reason_code": None,
            "checked_at": None,
        }
        assert availability_by_source["x"] == {
            "source": "x",
            "status": "unconfigured",
            "is_available": False,
            "reason": "Grok API key is not configured",
            "reason_code": "grok_api_key_missing",
            "checked_at": None,
        }

    async def test_get_source_availability_marks_invalid_reddit_ca_as_unavailable(
        self,
        client: AsyncClient,
        monkeypatch: pytest.MonkeyPatch,
        tmp_path: Path,
    ) -> None:
        """Settings endpoint should fail preflight when Reddit CA path is invalid."""
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

        response = await client.get("/api/v1/settings/sources")

        assert response.status_code == 200
        availability_by_source = {
            item["source"]: item for item in response.json()["sources"]
        }
        assert availability_by_source["reddit"]["is_available"] is False
        assert availability_by_source["reddit"]["reason_code"] == "reddit_ssl_error"
        assert (
            availability_by_source["reddit"]["reason"]
            == "Reddit SSL CA file is missing or unreadable"
        )

    async def test_get_source_availability_marks_invalid_reddit_proxy_as_unavailable(
        self,
        client: AsyncClient,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        """Settings endpoint should fail preflight on malformed Reddit proxy URLs."""
        source_availability_service.reset_runtime_state()
        monkeypatch.setattr(settings, "reddit_client_id", "reddit-id")
        monkeypatch.setattr(settings, "reddit_client_secret", "reddit-secret")
        monkeypatch.setattr(settings, "reddit_https_proxy", "http://proxy.internal:badport")

        response = await client.get("/api/v1/settings/sources")

        assert response.status_code == 200
        availability_by_source = {
            item["source"]: item for item in response.json()["sources"]
        }
        assert availability_by_source["reddit"]["is_available"] is False
        assert (
            availability_by_source["reddit"]["reason_code"]
            == "reddit_proxy_required"
        )
        assert (
            availability_by_source["reddit"]["reason"]
            == "Reddit proxy URL is invalid"
        )

    async def test_get_source_availability_marks_x_cooldown_as_unavailable(
        self,
        client: AsyncClient,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        """Repeated X gateway failures should surface as a temporary cooldown."""
        source_availability_service.reset_runtime_state()
        monkeypatch.setattr(settings, "grok_api_key", "grok-key")
        monkeypatch.setattr(settings, "x_failure_threshold", 2)
        monkeypatch.setattr(settings, "x_cooldown_seconds", 300)
        source_availability_service.record_failure(
            "x",
            "grok_rate_limited",
            "No available tokens. Please try again later.",
        )
        source_availability_service.record_failure(
            "x",
            "grok_connection_error",
            "Connection error.",
        )

        response = await client.get("/api/v1/settings/sources")

        assert response.status_code == 200
        availability_by_source = {
            item["source"]: item for item in response.json()["sources"]
        }
        assert availability_by_source["x"]["status"] == "cooldown"
        assert availability_by_source["x"]["is_available"] is False
        assert availability_by_source["x"]["reason_code"] == "grok_cooldown"
        assert availability_by_source["x"]["reason"]
