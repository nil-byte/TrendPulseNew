"""Tests for subscription/app-settings service edge cases."""

from __future__ import annotations

import asyncio
from datetime import datetime, timezone
from unittest.mock import AsyncMock

import pytest
from pydantic import ValidationError

from src.api.endpoints.analysis import task_service as analysis_task_service
from src.api.endpoints.tasks import task_service as tasks_task_service
from src.models.database import get_db
from src.models.schemas import (
    CreateSubscriptionRequest,
    TaskResponse,
    UpdateNotificationSettingsRequest,
    UpdateSubscriptionRequest,
)
from src.services.app_settings_service import AppSettingsService
from src.services.scheduler_service import SchedulerService
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

    async def test_get_report_language_defaults_to_english(self) -> None:
        """Fresh databases should default the app report language to English."""
        service = AppSettingsService()

        assert await service.get_report_language() == "en"

    async def test_update_report_language_persists(self) -> None:
        """Updating report_language should persist across reads."""
        service = AppSettingsService()

        assert await service.update_report_language("zh") == "zh"
        assert await service.get_report_language() == "zh"


class TestSubscriptionService:
    """Regression tests for subscription creation semantics."""

    async def test_subscription_and_scheduler_share_endpoint_task_service(self) -> None:
        """TaskService should be app-wide across endpoints and services."""
        subscription_service = SubscriptionService()
        scheduler_service = SchedulerService()

        assert subscription_service._task_service is tasks_task_service
        assert scheduler_service._task_service is tasks_task_service
        assert analysis_task_service is tasks_task_service

    def test_update_subscription_request_rejects_legacy_language_field(self) -> None:
        """UpdateSubscriptionRequest should reject the removed language field."""
        with pytest.raises(ValidationError):
            UpdateSubscriptionRequest.model_validate({"language": "zh"})

    async def test_create_subscription_omitted_notify_serializes_with_bulk_sync(
        self,
    ) -> None:
        """Bulk sync must not miss concurrent subscriptions using defaults."""
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
        real_get_default = (
            subscription_service._app_settings_service.get_default_subscription_notify
        )

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
                CreateSubscriptionRequest(
                    keyword="openai",
                    content_language="zh",
                    sources=["reddit"],
                )
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

    async def test_run_subscription_now_defers_report_language_to_task_service(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        """Manual subscription runs should let TaskService resolve report_language."""
        app_settings_service = AppSettingsService()
        subscription_service = SubscriptionService()
        subscription = await subscription_service.create_subscription(
            CreateSubscriptionRequest(
                keyword="openai",
                content_language="zh",
                sources=["reddit"],
                interval="daily",
            )
        )
        await app_settings_service.update_report_language("en")
        now = datetime.now(timezone.utc).isoformat()
        create_task_mock = AsyncMock(
            return_value=TaskResponse(
                id="task-1",
                keyword="openai",
                content_language="zh",
                report_language="en",
                max_items=50,
                status="pending",
                sources=["reddit"],
                created_at=now,
                updated_at=now,
                subscription_id=subscription.id,
                sentiment_score=None,
                post_count=None,
            )
        )
        monkeypatch.setattr(
            subscription_service._task_service,
            "create_task",
            create_task_mock,
        )

        task = await subscription_service.run_subscription_now(subscription.id)

        assert task is not None
        create_task_mock.assert_awaited_once()
        await_args = create_task_mock.await_args
        request = await_args.args[0]
        assert request.content_language == "zh"
        assert request.report_language is None
        assert await_args.kwargs["subscription_id"] == subscription.id
