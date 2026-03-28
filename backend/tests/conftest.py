"""Shared test fixtures."""

from __future__ import annotations

import os
from collections.abc import AsyncGenerator

import pytest
from httpx import ASGITransport, AsyncClient

os.environ["DATABASE_URL"] = "sqlite+aiosqlite:///./test_trendpulse.db"
os.environ["SCHEDULER_ENABLED"] = "false"

from src.main import app
from src.models.database import close_db, get_db, init_db


@pytest.fixture(autouse=True)
async def setup_db() -> AsyncGenerator[None, None]:
    """Initialize fresh test database for each test."""
    await init_db()
    yield
    db = await get_db()
    await db.execute("DELETE FROM analysis_reports")
    await db.execute("DELETE FROM raw_posts")
    await db.execute("DELETE FROM tasks")
    await db.execute("DELETE FROM subscriptions")
    await db.commit()
    await close_db(db)


@pytest.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    """Async HTTP client for testing FastAPI endpoints."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
