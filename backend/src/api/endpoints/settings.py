"""Application settings endpoints."""

from __future__ import annotations

from fastapi import APIRouter

from src.models.schemas import (
    NotificationSettingsResponse,
    UpdateNotificationSettingsRequest,
)
from src.services.app_settings_service import AppSettingsService

router = APIRouter(prefix="/settings", tags=["settings"])
app_settings_service = AppSettingsService()


@router.get("/notifications", response_model=NotificationSettingsResponse)
async def get_notification_settings() -> NotificationSettingsResponse:
    """Return the notification settings used by the backend."""
    return await app_settings_service.get_notification_settings()


@router.put("/notifications", response_model=NotificationSettingsResponse)
async def update_notification_settings(
    request: UpdateNotificationSettingsRequest,
) -> NotificationSettingsResponse:
    """Update notification settings and optionally sync subscriptions."""
    return await app_settings_service.update_notification_settings(request)
