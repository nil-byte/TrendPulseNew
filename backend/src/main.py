"""TrendPulse Backend - FastAPI Application Entry Point."""

from __future__ import annotations

import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from src.api.router import api_router
from src.config.settings import settings
from src.models.database import init_db
from src.services.scheduler_service import SchedulerService

logging.basicConfig(level=logging.INFO)

_scheduler = SchedulerService()


def get_scheduler() -> SchedulerService:
    """Return the app-wide scheduler instance (tests and diagnostics)."""
    return _scheduler


@asynccontextmanager
async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
    """Manage application startup and shutdown lifecycle."""
    await init_db()
    if settings.scheduler_enabled:
        await _scheduler.start()
    yield
    if settings.scheduler_enabled:
        await _scheduler.stop()


app = FastAPI(
    title="TrendPulse API",
    description="Multi-source sentiment analysis engine",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router)


@app.get("/health")
async def health_check() -> dict[str, str]:
    """Health check endpoint."""
    return {"status": "ok"}
