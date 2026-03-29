"""Tests for subscription/app-settings service edge cases."""

from __future__ import annotations

import asyncio

import pytest

from src.models.database import get_db
from src.models.schemas import CreateSubscriptionRequest, UpdateNotificationSettingsRequest
from src.services.app_settings_service import AppSettingsService
from src.services.subscription_service import SubscriptionService


async def _fetch_subscription_notify(subscription_id: str) -> bool:
    """Return the persisted notify flag for a subscription."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT notify FROM subscriptions WHERE id = ?",
            (subscription_id,),
        )
        row = await cursor.fetchone()
        assert row is not None
        return bool(row["notify"])
    finally:
        await db.close()


class TestAppSettingsService:
    """Regression tests for app-settings persistence."""

    async def test_get_notification_settings_raises_when_singleton_row_missing(
        self,
    ) -> None:
        """Missing app_settings row must be treated as a real error."""
        db = await get_db()
        try:
            await db.execute("DELETE FROM app_settings")
            await db.commit()
        finally:
            await db.close()

        service = AppSettingsService()

        with pytest.raises(RuntimeError, match="app_settings"):
            await service.get_notification_settings()


class TestSubscriptionService:
    """Regression tests for subscription creation semantics."""

    async def test_create_subscription_omitted_notify_serializes_with_bulk_sync(
        self,
    ) -> None:
        """Bulk sync must not miss a concurrent subscription using the default notify."""
        settings_service = AppSettingsService()
        subscription_service = SubscriptionService()
        await settings_service.update_notification_settings(
            UpdateNotificationSettingsRequest(
                subscription_notify_default=False,
                apply_to_existing=False,
            )
        )

        default_read = asyncio.Event()
        allow_insert = asyncio.Event()
        real_get_default = subscription_service._app_settings_service.get_default_subscription_notify

        async def blocked_get_default(*args: object, **kwargs: object) -> bool:
            value = await real_get_default(*args, **kwargs)
            default_read.set()
            await allow_insert.wait()
            return value

        subscription_service._app_settings_service.get_default_subscription_notify = (  # type: ignore[method-assign]
            blocked_get_default
        )

        create_task = asyncio.create_task(
            subscription_service.create_subscription(
                CreateSubscriptionRequest(keyword="openai", sources=["reddit"])
            )
        )
        await default_read.wait()

        update_task = asyncio.create_task(
            settings_service.update_notification_settings(
                UpdateNotificationSettingsRequest(
                    subscription_notify_default=True,
                    apply_to_existing=True,
                )
            )
        )

        update_finished_before_insert = False
        try:
            await asyncio.wait_for(asyncio.shield(update_task), timeout=0.05)
            update_finished_before_insert = True
        except asyncio.TimeoutError:
            update_finished_before_insert = False
        finally:
            allow_insert.set()

        created_subscription = await create_task
        await update_task

        assert update_finished_before_insert is False
        assert await _fetch_subscription_notify(created_subscription.id) is True
