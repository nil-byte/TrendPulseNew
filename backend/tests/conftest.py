"""Shared test fixtures."""

from __future__ import annotations

import os
from collections.abc import AsyncGenerator
from pathlib import Path

import pytest
from httpx import ASGITransport, AsyncClient

os.environ["SCHEDULER_ENABLED"] = "false"

from src.config.settings import settings
from src.main import app
from src.models.database import init_db
from src.services.source_availability_service import source_availability_service


@pytest.fixture(autouse=True)
async def setup_db(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> AsyncGenerator[None, None]:
    """Initialize an isolated temporary test database for each test."""
    source_availability_service.reset_runtime_state()
    db_path = tmp_path / "test_trendpulse.db"
    monkeypatch.setattr(settings, "database_url", f"sqlite+aiosqlite:///{db_path}")
    monkeypatch.setattr(settings, "scheduler_enabled", False)
    monkeypatch.setattr(settings, "reddit_client_id", "test-reddit-id")
    monkeypatch.setattr(settings, "reddit_client_secret", "test-reddit-secret")
    monkeypatch.setattr(settings, "reddit_user_agent", "TrendPulse/Test")
    monkeypatch.setattr(settings, "reddit_https_proxy", "")
    monkeypatch.setattr(settings, "reddit_ssl_ca_file", "")
    monkeypatch.setattr(settings, "youtube_api_key", "test-youtube-key")
    monkeypatch.setattr(settings, "grok_api_key", "test-grok-key")
    monkeypatch.setattr(settings, "grok_provider_mode", "official_xai")
    monkeypatch.setattr(settings, "grok_base_url", "https://api.x.ai/v1")
    monkeypatch.setattr(settings, "grok_model", "grok-4.20-reasoning")
    await init_db()
    yield


@pytest.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    """Async HTTP client for testing FastAPI endpoints."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
