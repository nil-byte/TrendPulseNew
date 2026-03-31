"""App-wide settings service."""

from __future__ import annotations

import aiosqlite

from src.common.time_utils import utc_now_iso
from src.models.database import close_db, get_db
from src.models.schemas import (
    NotificationSettingsResponse,
    UpdateNotificationSettingsRequest,
    UpdateReportLanguageRequest,
)

_APP_SETTINGS_ROW_ID = 1
_MISSING_APP_SETTINGS_ROW_MESSAGE = (
    "app_settings singleton row is missing; init_db() must seed it."
)

class AppSettingsService:
    """Manage persisted application settings."""

    async def get_notification_settings(
        self,
        db: aiosqlite.Connection | None = None,
    ) -> NotificationSettingsResponse:
        """Return the current notification settings."""
        connection = db or await get_db()
        owns_connection = db is None
        try:
            row = await self._get_settings_row(connection)
            return NotificationSettingsResponse(
                subscription_notify_default=bool(row["default_subscription_notify"])
            )
        finally:
            if owns_connection:
                await close_db(connection)

    async def get_default_subscription_notify(
        self,
        db: aiosqlite.Connection | None = None,
    ) -> bool:
        """Return the default notify flag for newly created subscriptions."""
        settings = await self.get_notification_settings(db)
        return settings.subscription_notify_default

    async def get_report_language(
        self,
        db: aiosqlite.Connection | None = None,
    ) -> str:
        """Return the app-level report language used for new task reports."""
        connection = db or await get_db()
        owns_connection = db is None
        try:
            row = await self._get_settings_row(connection)
            return str(row["report_language"])
        finally:
            if owns_connection:
                await close_db(connection)

    async def update_report_language(self, report_language: str) -> str:
        """Persist the app-level report language and return the stored value."""
        validated = UpdateReportLanguageRequest(report_language=report_language)
        db = await get_db()
        try:
            await db.execute("BEGIN IMMEDIATE")
            await self._get_settings_row(db)
            await db.execute(
                """
                UPDATE app_settings
                SET report_language = ?, updated_at = ?
                WHERE id = ?
                """,
                (validated.report_language, utc_now_iso(), _APP_SETTINGS_ROW_ID),
            )
            await db.commit()
            return validated.report_language
        except Exception:
            await db.rollback()
            raise
        finally:
            await close_db(db)

    async def update_notification_settings(
        self, request: UpdateNotificationSettingsRequest
    ) -> NotificationSettingsResponse:
        """Persist notification settings and optionally sync subscriptions."""
        now = utc_now_iso()
        notify_value = int(request.subscription_notify_default)
        db = await get_db()
        try:
            await db.execute("BEGIN IMMEDIATE")
            await self._get_settings_row(db)
            await db.execute(
                """
                UPDATE app_settings
                SET default_subscription_notify = ?, updated_at = ?
                WHERE id = ?
                """,
                (notify_value, now, _APP_SETTINGS_ROW_ID),
            )
            if request.apply_to_existing:
                await db.execute(
                    """
                    UPDATE subscriptions
                    SET notify = ?, updated_at = ?
                    """,
                    (notify_value, now),
                )
            await db.commit()
            return NotificationSettingsResponse(
                subscription_notify_default=request.subscription_notify_default
            )
        except Exception:
            await db.rollback()
            raise
        finally:
            await close_db(db)

    async def _get_settings_row(self, db: aiosqlite.Connection) -> aiosqlite.Row:
        """Load the singleton app-settings row or raise when it is missing."""
        cursor = await db.execute(
            """
            SELECT
                id,
                default_subscription_notify,
                report_language,
                created_at,
                updated_at
            FROM app_settings
            WHERE id = ?
            """,
            (_APP_SETTINGS_ROW_ID,),
        )
        row = await cursor.fetchone()
        if row is None:
            raise RuntimeError(_MISSING_APP_SETTINGS_ROW_MESSAGE)
        return row
