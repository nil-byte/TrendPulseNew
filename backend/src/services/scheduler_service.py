"""Background scheduler for subscription-driven task creation."""

from __future__ import annotations

import asyncio
import json
import logging
from datetime import datetime, timedelta, timezone

from src.models.database import get_db
from src.models.schemas import CreateTaskRequest
from src.services.task_service import TaskService

logger = logging.getLogger(__name__)

_INTERVAL_DELTAS: dict[str, timedelta] = {
    "hourly": timedelta(hours=1),
    "6hours": timedelta(hours=6),
    "daily": timedelta(days=1),
    "weekly": timedelta(days=7),
}

_POLL_INTERVAL_SECONDS = 60


class SchedulerService:
    """Periodically polls for due subscriptions and spawns analysis tasks."""

    def __init__(self) -> None:
        self._task: asyncio.Task[None] | None = None
        self._task_service = TaskService()

    async def start(self) -> None:
        """Start the background scheduler loop."""
        if self._task is not None:
            return
        self._task = asyncio.create_task(self._loop())
        logger.info("Scheduler started")

    async def stop(self) -> None:
        """Cancel the background scheduler loop."""
        if self._task is None:
            return
        self._task.cancel()
        try:
            await self._task
        except asyncio.CancelledError:
            pass
        self._task = None
        logger.info("Scheduler stopped")

    async def _loop(self) -> None:
        """Main loop: sleep, then check for due subscriptions."""
        while True:
            try:
                await asyncio.sleep(_POLL_INTERVAL_SECONDS)
                await self._tick()
            except asyncio.CancelledError:
                raise
            except Exception:
                logger.exception("Scheduler tick failed — will retry next cycle")

    async def _tick(self) -> None:
        """Single scheduler tick: find due subscriptions and create tasks."""
        now = datetime.now(timezone.utc)
        now_iso = now.isoformat()

        db = await get_db()
        try:
            cursor = await db.execute(
                "SELECT * FROM subscriptions WHERE is_active = 1 AND next_run_at <= ?",
                (now_iso,),
            )
            rows = await cursor.fetchall()
        finally:
            await db.close()

        if not rows:
            return

        logger.info("Scheduler found %d due subscription(s)", len(rows))

        for row in rows:
            try:
                await self._process_subscription(row, now)
            except Exception:
                logger.exception(
                    "Failed to process subscription %s", row["id"]  # type: ignore[index]
                )

    async def _process_subscription(self, row: object, now: datetime) -> None:
        """Create a task for a single due subscription and update timestamps.

        Args:
            row: Database row for the subscription.
            now: Current UTC datetime for timestamp calculations.
        """
        sub_id: str = row["id"]  # type: ignore[index]
        keyword: str = row["keyword"]  # type: ignore[index]
        language: str = row["language"]  # type: ignore[index]
        max_items: int = row["max_items"]  # type: ignore[index]
        sources: list[str] = json.loads(row["sources"])  # type: ignore[index]
        interval: str = row["interval"]  # type: ignore[index]

        request = CreateTaskRequest(
            keyword=keyword,
            language=language,
            max_items=max_items,
            sources=sources,
        )
        await self._task_service.create_task(request, subscription_id=sub_id)
        logger.info("Scheduler created task for subscription %s (%s)", sub_id, keyword)

        delta = _INTERVAL_DELTAS.get(interval, timedelta(days=1))
        next_run = (now + delta).isoformat()
        now_iso = now.isoformat()

        db = await get_db()
        try:
            await db.execute(
                "UPDATE subscriptions SET last_run_at = ?, next_run_at = ?, updated_at = ? WHERE id = ?",
                (now_iso, next_run, now_iso, sub_id),
            )
            await db.commit()
        finally:
            await db.close()
