"""Shared test fixtures."""

from __future__ import annotations

import os
from typing import AsyncGenerator

import pytest
import aiosqlite
from httpx import ASGITransport, AsyncClient

os.environ["DATABASE_URL"] = "sqlite+aiosqlite:///./test_trendpulse.db"

from src.main import app
from src.models.database import init_db, get_db, close_db


@pytest.fixture(autouse=True)
async def setup_db():
    """Initialize fresh test database for each test."""
    await init_db()
    yield
    db = await get_db()
    await db.execute("DELETE FROM analysis_reports")
    await db.execute("DELETE FROM raw_posts")
    await db.execute("DELETE FROM tasks")
    await db.commit()
    await close_db(db)


@pytest.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    """Async HTTP client for testing FastAPI endpoints."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
