"""Runtime controls for unstable collection sources like X/Grok."""

from __future__ import annotations

import asyncio
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from dataclasses import dataclass
from datetime import datetime, timedelta
from threading import Lock

from src.common.time_utils import utc_now
from src.config.settings import settings

RECOVERABLE_X_GATEWAY_REASON_CODES = frozenset(
    {
        "grok_rate_limited",
        "grok_connection_error",
        "grok_timeout",
        "grok_upstream_unavailable",
    }
)
_COOLDOWN_X_REASON_CODES = RECOVERABLE_X_GATEWAY_REASON_CODES | frozenset(
    {"grok_batches_failed"}
)


def _resolve_positive_int(value: object, default: int) -> int:
    """Return a positive integer config value or fall back to ``default``."""
    if isinstance(value, int) and value > 0:
        return value
    if isinstance(value, str):
        try:
            parsed = int(value)
        except ValueError:
            return default
        if parsed > 0:
            return parsed
    return default


@dataclass(slots=True)
class _RuntimeControlState:
    """Mutable runtime control state for one source."""

    semaphore: asyncio.Semaphore
    parallel_limit: int
    consecutive_failures: int = 0
    cooldown_until: datetime | None = None


class SourceRuntimeControlService:
    """Manage per-source concurrency and cooldown windows."""

    def __init__(self) -> None:
        self._lock = Lock()
        self._states: dict[str, _RuntimeControlState] = {}

    @asynccontextmanager
    async def acquire_slot(self, source: str) -> AsyncIterator[None]:
        """Acquire one runtime slot for a source collection request."""
        state = self._get_or_create_state(source)
        await state.semaphore.acquire()
        try:
            yield
        finally:
            state.semaphore.release()

    def record_success(self, source: str) -> None:
        """Clear transient failure tracking after a successful collection."""
        with self._lock:
            state = self._states.get(source)
            if state is None:
                return
            state.consecutive_failures = 0
            state.cooldown_until = None

    def record_failure(
        self,
        source: str,
        *,
        reason_code: str,
        now: datetime | None = None,
    ) -> bool:
        """Record a recoverable failure and return whether cooldown is active."""
        current = now or utc_now()
        with self._lock:
            state = self._get_or_create_state_locked(source)
            self._clear_expired_cooldown_locked(state, current)
            if not self._counts_toward_cooldown(source, reason_code):
                return state.cooldown_until is not None

            state.consecutive_failures += 1
            if state.consecutive_failures >= self._failure_threshold(source):
                state.cooldown_until = current + timedelta(
                    seconds=self._cooldown_seconds(source)
                )
                state.consecutive_failures = 0
            return state.cooldown_until is not None

    def is_in_cooldown(self, source: str, *, now: datetime | None = None) -> bool:
        """Return whether a source is currently inside its cooldown window."""
        current = now or utc_now()
        with self._lock:
            state = self._states.get(source)
            if state is None:
                return False
            self._clear_expired_cooldown_locked(state, current)
            return state.cooldown_until is not None

    def get_cooldown_until(
        self,
        source: str,
        *,
        now: datetime | None = None,
    ) -> datetime | None:
        """Return the active cooldown deadline, if any."""
        current = now or utc_now()
        with self._lock:
            state = self._states.get(source)
            if state is None:
                return None
            self._clear_expired_cooldown_locked(state, current)
            return state.cooldown_until

    def reset(self) -> None:
        """Clear all runtime control state for deterministic tests."""
        with self._lock:
            self._states.clear()

    def _get_or_create_state(self, source: str) -> _RuntimeControlState:
        with self._lock:
            return self._get_or_create_state_locked(source)

    def _get_or_create_state_locked(self, source: str) -> _RuntimeControlState:
        state = self._states.get(source)
        if state is None:
            parallel_limit = self._parallel_limit(source)
            state = _RuntimeControlState(
                semaphore=asyncio.Semaphore(parallel_limit),
                parallel_limit=parallel_limit,
            )
            self._states[source] = state
        return state

    @staticmethod
    def _clear_expired_cooldown_locked(
        state: _RuntimeControlState,
        current: datetime,
    ) -> None:
        if state.cooldown_until is None:
            return
        if current >= state.cooldown_until:
            state.cooldown_until = None
            state.consecutive_failures = 0

    @staticmethod
    def _counts_toward_cooldown(source: str, reason_code: str) -> bool:
        if source != "x":
            return False
        return reason_code in _COOLDOWN_X_REASON_CODES

    @staticmethod
    def _parallel_limit(source: str) -> int:
        if source == "x":
            return _resolve_positive_int(settings.x_parallel_batches, 1)
        return 1

    @staticmethod
    def _failure_threshold(source: str) -> int:
        if source == "x":
            return _resolve_positive_int(settings.x_failure_threshold, 2)
        return 1

    @staticmethod
    def _cooldown_seconds(source: str) -> int:
        if source == "x":
            return _resolve_positive_int(settings.x_cooldown_seconds, 180)
        return 60


source_runtime_control = SourceRuntimeControlService()
