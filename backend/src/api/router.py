"""API router registration."""

from __future__ import annotations

from fastapi import APIRouter

from src.api.endpoints import analysis, subscriptions, tasks

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(tasks.router)
api_router.include_router(analysis.router)
api_router.include_router(subscriptions.router)
