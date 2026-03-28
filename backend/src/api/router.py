"""API router registration."""

from __future__ import annotations

from fastapi import APIRouter

from src.api.endpoints import analysis, tasks

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(tasks.router)
api_router.include_router(analysis.router)
