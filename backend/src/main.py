"""TrendPulse Backend - FastAPI Application Entry Point."""

from __future__ import annotations

import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from src.api.router import api_router
from src.models.database import init_db

logging.basicConfig(level=logging.INFO)

app = FastAPI(
    title="TrendPulse API",
    description="Multi-source sentiment analysis engine",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router)


@app.on_event("startup")
async def startup() -> None:
    """Initialize database on startup."""
    await init_db()


@app.get("/health")
async def health_check() -> dict[str, str]:
    """Health check endpoint."""
    return {"status": "ok"}
