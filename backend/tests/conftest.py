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


@pytest.fixture(autouse=True)
async def setup_db(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> AsyncGenerator[None, None]:
    """Initialize an isolated temporary test database for each test."""
    db_path = tmp_path / "test_trendpulse.db"
    monkeypatch.setattr(settings, "database_url", f"sqlite+aiosqlite:///{db_path}")
    monkeypatch.setattr(settings, "scheduler_enabled", False)
    await init_db()
    yield


@pytest.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    """Async HTTP client for testing FastAPI endpoints."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
