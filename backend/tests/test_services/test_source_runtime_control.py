"""Tests for X runtime control primitives."""

from __future__ import annotations

import asyncio
from datetime import datetime, timedelta, timezone

import pytest

from src.config.settings import settings
from src.services.source_runtime_control import SourceRuntimeControlService


class TestSourceRuntimeControlService:
    """Regression tests for runtime gating and cooldown behavior."""

    async def test_acquire_slot_honors_parallel_limit(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        """Only the configured number of X batches may run concurrently."""
        monkeypatch.setattr(settings, "x_parallel_batches", 1)
        service = SourceRuntimeControlService()
        first_entered = asyncio.Event()
        release_first = asyncio.Event()
        order: list[str] = []

        async def first_batch() -> None:
            async with service.acquire_slot("x"):
                order.append("first-enter")
                first_entered.set()
                await release_first.wait()
                order.append("first-exit")

        async def second_batch() -> None:
            await first_entered.wait()
            async with service.acquire_slot("x"):
                order.append("second-enter")

        first_task = asyncio.create_task(first_batch())
        second_task = asyncio.create_task(second_batch())

        await first_entered.wait()
        await asyncio.sleep(0)
        assert order == ["first-enter"]

        release_first.set()
        await asyncio.gather(first_task, second_task)

        assert order == ["first-enter", "first-exit", "second-enter"]

    def test_record_failure_enters_cooldown_after_threshold(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        """Repeated recoverable X failures should open a cooldown window."""
        monkeypatch.setattr(settings, "x_failure_threshold", 2)
        monkeypatch.setattr(settings, "x_cooldown_seconds", 300)
        service = SourceRuntimeControlService()
        now = datetime(2026, 4, 1, 12, 0, tzinfo=timezone.utc)

        assert service.record_failure(
            "x",
            reason_code="grok_rate_limited",
            now=now,
        ) is False
        assert service.record_failure(
            "x",
            reason_code="grok_connection_error",
            now=now + timedelta(seconds=1),
        ) is True

        assert service.is_in_cooldown("x", now=now + timedelta(seconds=1)) is True
        assert service.get_cooldown_until("x") == now + timedelta(seconds=301)

    def test_non_retryable_failures_do_not_trigger_cooldown(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        """Payload or parsing failures should not count toward gateway cooldown."""
        monkeypatch.setattr(settings, "x_failure_threshold", 2)
        monkeypatch.setattr(settings, "x_cooldown_seconds", 300)
        service = SourceRuntimeControlService()
        now = datetime(2026, 4, 1, 12, 0, tzinfo=timezone.utc)

        assert service.record_failure(
            "x",
            reason_code="grok_invalid_payload",
            now=now,
        ) is False
        assert service.record_failure(
            "x",
            reason_code="grok_provider_error",
            now=now + timedelta(seconds=1),
        ) is False

        assert service.is_in_cooldown("x", now=now + timedelta(seconds=1)) is False
        assert service.get_cooldown_until("x") is None

    def test_record_success_clears_failures_and_cooldown(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        """A healthy X collection should reset cooldown tracking."""
        monkeypatch.setattr(settings, "x_failure_threshold", 1)
        monkeypatch.setattr(settings, "x_cooldown_seconds", 300)
        service = SourceRuntimeControlService()
        now = datetime(2026, 4, 1, 12, 0, tzinfo=timezone.utc)

        assert service.record_failure("x", reason_code="grok_timeout", now=now) is True
        assert service.is_in_cooldown("x", now=now) is True

        service.record_success("x")

        assert service.is_in_cooldown("x", now=now) is False
        assert service.get_cooldown_until("x") is None

    def test_expired_cooldown_self_clears(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        """Cooldown windows should expire without requiring a success event."""
        monkeypatch.setattr(settings, "x_failure_threshold", 1)
        monkeypatch.setattr(settings, "x_cooldown_seconds", 60)
        service = SourceRuntimeControlService()
        now = datetime(2026, 4, 1, 12, 0, tzinfo=timezone.utc)

        assert service.record_failure("x", reason_code="grok_timeout", now=now) is True
        assert service.is_in_cooldown("x", now=now + timedelta(seconds=30)) is True
        assert service.is_in_cooldown("x", now=now + timedelta(seconds=61)) is False
        assert service.get_cooldown_until("x", now=now + timedelta(seconds=61)) is None
