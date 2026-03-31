"""Application settings endpoints."""

from __future__ import annotations

from fastapi import APIRouter

from src.models.schemas import (
    NotificationSettingsResponse,
    ReportLanguageSettingsResponse,
    SourceAvailabilityListResponse,
    UpdateNotificationSettingsRequest,
    UpdateReportLanguageRequest,
)
from src.services.app_settings_service import AppSettingsService
from src.services.source_availability_service import source_availability_service

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


@router.get("/report-language", response_model=ReportLanguageSettingsResponse)
async def get_report_language() -> ReportLanguageSettingsResponse:
    """Return the app-level report language used for new task reports."""
    return ReportLanguageSettingsResponse(
        report_language=await app_settings_service.get_report_language()
    )


@router.put("/report-language", response_model=ReportLanguageSettingsResponse)
async def update_report_language(
    request: UpdateReportLanguageRequest,
) -> ReportLanguageSettingsResponse:
    """Persist the app-level report language used for new task reports."""
    return ReportLanguageSettingsResponse(
        report_language=await app_settings_service.update_report_language(
            request.report_language
        )
    )


@router.get("/sources", response_model=SourceAvailabilityListResponse)
async def get_source_availability() -> SourceAvailabilityListResponse:
    """Return current source availability for new analysis tasks."""
    return SourceAvailabilityListResponse(
        sources=source_availability_service.list_availability()
    )
