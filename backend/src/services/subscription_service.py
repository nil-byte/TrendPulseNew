"""Subscription CRUD service."""

from __future__ import annotations

import json
import logging
import uuid
from datetime import datetime, timedelta, timezone

from src.models.database import get_db
from src.models.schemas import (
    CreateSubscriptionRequest,
    SubscriptionListResponse,
    SubscriptionResponse,
    TaskListResponse,
    TaskResponse,
    UpdateSubscriptionRequest,
)

logger = logging.getLogger(__name__)

_INTERVAL_DELTAS: dict[str, timedelta] = {
    "hourly": timedelta(hours=1),
    "6hours": timedelta(hours=6),
    "daily": timedelta(days=1),
    "weekly": timedelta(days=7),
}


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _calc_next_run(interval: str, from_dt: datetime | None = None) -> str:
    """Calculate the next run timestamp based on the interval.

    Args:
        interval: One of ``hourly``, ``6hours``, ``daily``, ``weekly``.
        from_dt: Base datetime; defaults to ``utcnow``.

    Returns:
        ISO-8601 timestamp string.
    """
    base = from_dt or datetime.now(timezone.utc)
    delta = _INTERVAL_DELTAS.get(interval, timedelta(days=1))
    return (base + delta).isoformat()


class SubscriptionService:
    """Manages subscription CRUD operations."""

    async def create_subscription(
        self, request: CreateSubscriptionRequest
    ) -> SubscriptionResponse:
        """Create a new subscription.

        Args:
            request: Validated subscription creation request.

        Returns:
            The newly created subscription.
        """
        sub_id = str(uuid.uuid4())
        now = _now_iso()
        next_run = _calc_next_run(request.interval)

        db = await get_db()
        try:
            await db.execute(
                """
                INSERT INTO subscriptions
                    (id, keyword, language, max_items, sources, interval,
                     is_active, notify, created_at, updated_at, next_run_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    sub_id,
                    request.keyword,
                    request.language,
                    request.max_items,
                    json.dumps(request.sources),
                    request.interval,
                    1,
                    int(request.notify),
                    now,
                    now,
                    next_run,
                ),
            )
            await db.commit()
        finally:
            await db.close()

        return SubscriptionResponse(
            id=sub_id,
            keyword=request.keyword,
            language=request.language,
            max_items=request.max_items,
            sources=request.sources,
            interval=request.interval,
            is_active=True,
            notify=request.notify,
            created_at=now,
            updated_at=now,
            next_run_at=next_run,
        )

    async def get_subscription(self, sub_id: str) -> SubscriptionResponse | None:
        """Get a subscription by ID.

        Args:
            sub_id: UUID of the subscription.

        Returns:
            Subscription response or ``None`` if not found.
        """
        db = await get_db()
        try:
            cursor = await db.execute(
                "SELECT * FROM subscriptions WHERE id = ?", (sub_id,)
            )
            row = await cursor.fetchone()
            if row is None:
                return None
            return self._row_to_subscription(row)
        finally:
            await db.close()

    async def get_subscription_list(self) -> SubscriptionListResponse:
        """Get all subscriptions ordered by creation date desc.

        Returns:
            List of subscriptions with total count.
        """
        db = await get_db()
        try:
            cursor = await db.execute(
                "SELECT * FROM subscriptions ORDER BY created_at DESC"
            )
            rows = await cursor.fetchall()
            subs = [self._row_to_subscription(r) for r in rows]
            return SubscriptionListResponse(subscriptions=subs, total=len(subs))
        finally:
            await db.close()

    async def update_subscription(
        self, sub_id: str, request: UpdateSubscriptionRequest
    ) -> SubscriptionResponse | None:
        """Update an existing subscription.

        Args:
            sub_id: UUID of the subscription.
            request: Fields to update (only non-None values are applied).

        Returns:
            Updated subscription or ``None`` if not found.
        """
        db = await get_db()
        try:
            cursor = await db.execute(
                "SELECT * FROM subscriptions WHERE id = ?", (sub_id,)
            )
            row = await cursor.fetchone()
            if row is None:
                return None

            updates: dict[str, object] = {}
            if request.keyword is not None:
                updates["keyword"] = request.keyword
            if request.language is not None:
                updates["language"] = request.language
            if request.max_items is not None:
                updates["max_items"] = request.max_items
            if request.sources is not None:
                updates["sources"] = json.dumps(request.sources)
            if request.interval is not None:
                updates["interval"] = request.interval
                updates["next_run_at"] = _calc_next_run(request.interval)
            if request.is_active is not None:
                updates["is_active"] = int(request.is_active)
            if request.notify is not None:
                updates["notify"] = int(request.notify)

            if updates:
                updates["updated_at"] = _now_iso()
                set_clause = ", ".join(f"{k} = ?" for k in updates)
                values = list(updates.values()) + [sub_id]
                await db.execute(
                    f"UPDATE subscriptions SET {set_clause} WHERE id = ?",  # noqa: S608
                    values,
                )
                await db.commit()

            cursor = await db.execute(
                "SELECT * FROM subscriptions WHERE id = ?", (sub_id,)
            )
            row = await cursor.fetchone()
            return self._row_to_subscription(row)  # type: ignore[arg-type]
        finally:
            await db.close()

    async def delete_subscription(self, sub_id: str) -> bool:
        """Delete a subscription.

        Tasks that referenced this subscription keep their rows (history); their
        ``subscription_id`` is cleared first so the delete does not violate the
        foreign key to ``subscriptions.id``.

        Args:
            sub_id: UUID of the subscription.

        Returns:
            ``True`` if the subscription existed and was deleted.
        """
        db = await get_db()
        try:
            cursor = await db.execute(
                "SELECT id FROM subscriptions WHERE id = ?", (sub_id,)
            )
            if await cursor.fetchone() is None:
                return False
            await db.execute(
                "UPDATE tasks SET subscription_id = NULL WHERE subscription_id = ?",
                (sub_id,),
            )
            await db.execute("DELETE FROM subscriptions WHERE id = ?", (sub_id,))
            await db.commit()
            return True
        finally:
            await db.close()

    async def get_subscription_tasks(self, sub_id: str) -> TaskListResponse:
        """Get all tasks associated with a subscription.

        Args:
            sub_id: UUID of the subscription.

        Returns:
            List of tasks with total count.
        """
        db = await get_db()
        try:
            cursor = await db.execute(
                "SELECT * FROM tasks WHERE subscription_id = ? ORDER BY created_at DESC",
                (sub_id,),
            )
            rows = await cursor.fetchall()
            tasks = [self._row_to_task(r) for r in rows]
            return TaskListResponse(tasks=tasks, total=len(tasks))
        finally:
            await db.close()

    @staticmethod
    def _row_to_subscription(row: object) -> SubscriptionResponse:
        return SubscriptionResponse(
            id=row["id"],  # type: ignore[index]
            keyword=row["keyword"],  # type: ignore[index]
            language=row["language"],  # type: ignore[index]
            max_items=row["max_items"],  # type: ignore[index]
            sources=json.loads(row["sources"]),  # type: ignore[index]
            interval=row["interval"],  # type: ignore[index]
            is_active=bool(row["is_active"]),  # type: ignore[index]
            notify=bool(row["notify"]),  # type: ignore[index]
            created_at=row["created_at"],  # type: ignore[index]
            updated_at=row["updated_at"],  # type: ignore[index]
            last_run_at=row["last_run_at"],  # type: ignore[index]
            next_run_at=row["next_run_at"],  # type: ignore[index]
        )

    @staticmethod
    def _row_to_task(row: object) -> TaskResponse:
        return TaskResponse(
            id=row["id"],  # type: ignore[index]
            keyword=row["keyword"],  # type: ignore[index]
            language=row["language"],  # type: ignore[index]
            max_items=row["max_items"],  # type: ignore[index]
            status=row["status"],  # type: ignore[index]
            sources=json.loads(row["sources"]),  # type: ignore[index]
            created_at=row["created_at"],  # type: ignore[index]
            updated_at=row["updated_at"],  # type: ignore[index]
            error_message=row["error_message"],  # type: ignore[index]
            subscription_id=row["subscription_id"],  # type: ignore[index]
        )
