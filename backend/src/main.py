"""TrendPulse Backend - FastAPI Application Entry Point."""

from __future__ import annotations

import logging
import os
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

# Load settings before any import that pulls in asyncpraw/asyncprawcore: those
# libraries read ``PRAWCORE_TIMEOUT`` from os.environ once at import time.
from src.config.settings import settings

os.environ["PRAWCORE_TIMEOUT"] = str(float(settings.reddit_http_timeout_seconds))

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from src.api.router import api_router
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


def create_app() -> FastAPI:
    """Build the FastAPI application with runtime configuration applied."""
    logging.getLogger().setLevel(logging.DEBUG if settings.debug else logging.INFO)
    app = FastAPI(
        title="TrendPulse API",
        description="Multi-source sentiment analysis engine",
        version="0.1.0",
        debug=settings.debug,
        lifespan=lifespan,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.parsed_cors_allowed_origins,
        allow_origin_regex=settings.cors_allowed_origin_regex or None,
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(api_router)

    @app.get("/health")
    async def health_check() -> dict[str, str]:
        """Health check endpoint."""
        return {"status": "ok"}

    return app


app = create_app()
