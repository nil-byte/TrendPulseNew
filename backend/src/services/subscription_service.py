"""Subscription CRUD service."""

from __future__ import annotations

import json
import logging
import uuid
from datetime import datetime, timedelta, timezone

from src.common.time_utils import utc_now_iso
from src.models.database import get_db
from src.models.schemas import (
    CreateSubscriptionRequest,
    CreateTaskRequest,
    SubscriptionListResponse,
    SubscriptionResponse,
    TaskListResponse,
    TaskResponse,
    UpdateSubscriptionRequest,
)
from src.services.app_settings_service import AppSettingsService
from src.services.task_service import (
    TaskService,
    build_task_query,
    get_task_service,
    row_to_task_response,
)

logger = logging.getLogger(__name__)

_INTERVAL_DELTAS: dict[str, timedelta] = {
    "hourly": timedelta(hours=1),
    "6hours": timedelta(hours=6),
    "daily": timedelta(days=1),
    "weekly": timedelta(days=7),
}

_SUBSCRIPTION_SELECT_WITH_ALERT_SUMMARY = """
SELECT
    subscriptions.id,
    subscriptions.keyword,
    subscriptions.content_language,
    subscriptions.max_items,
    subscriptions.sources,
    subscriptions.interval,
    subscriptions.is_active,
    subscriptions.notify,
    subscriptions.created_at,
    subscriptions.updated_at,
    subscriptions.last_run_at,
    subscriptions.next_run_at,
    (
        SELECT COUNT(*)
        FROM subscription_alerts
        WHERE subscription_alerts.subscription_id = subscriptions.id
          AND subscription_alerts.is_read = 0
    ) AS unread_alert_count,
    (
        SELECT task_id
        FROM subscription_alerts
        WHERE subscription_alerts.subscription_id = subscriptions.id
          AND subscription_alerts.is_read = 0
        ORDER BY created_at DESC, id DESC
        LIMIT 1
    ) AS latest_unread_alert_task_id,
    (
        SELECT sentiment_score
        FROM subscription_alerts
        WHERE subscription_alerts.subscription_id = subscriptions.id
          AND subscription_alerts.is_read = 0
        ORDER BY created_at DESC, id DESC
        LIMIT 1
    ) AS latest_unread_alert_score
FROM subscriptions
"""

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


def build_subscription_query(*, where_clause: str = "", order_clause: str = "") -> str:
    """Build a subscription query that includes unread alert summary fields."""
    parts = [_SUBSCRIPTION_SELECT_WITH_ALERT_SUMMARY.strip()]
    if where_clause:
        parts.append(where_clause)
    if order_clause:
        parts.append(order_clause)
    return "\n".join(parts)


class SubscriptionService:
    """Manages subscription CRUD operations."""

    def __init__(self, task_service: TaskService | None = None) -> None:
        self._app_settings_service = AppSettingsService()
        self._task_service = task_service or get_task_service()

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
        now = utc_now_iso()
        next_run = _calc_next_run(request.interval)
        db = await get_db()
        try:
            await db.execute("BEGIN IMMEDIATE")
            notify_value = request.notify
            if notify_value is None:
                notify_value = (
                    await self._app_settings_service.get_default_subscription_notify(db)
                )
            await db.execute(
                """
                INSERT INTO subscriptions
                    (id, keyword, content_language, max_items, sources, interval,
                     is_active, notify, created_at, updated_at, next_run_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    sub_id,
                    request.keyword,
                    request.content_language,
                    request.max_items,
                    json.dumps(request.sources),
                    request.interval,
                    1,
                    int(notify_value),
                    now,
                    now,
                    next_run,
                ),
            )
            await db.commit()
        except Exception:
            await db.rollback()
            raise
        finally:
            await db.close()

        return SubscriptionResponse(
            id=sub_id,
            keyword=request.keyword,
            content_language=request.content_language,
            max_items=request.max_items,
            sources=request.sources,
            interval=request.interval,
            is_active=True,
            notify=notify_value,
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
                build_subscription_query(where_clause="WHERE subscriptions.id = ?"),
                (sub_id,),
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
                build_subscription_query(
                    order_clause="ORDER BY subscriptions.created_at DESC"
                )
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
            if request.content_language is not None:
                updates["content_language"] = request.content_language
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
                updates["updated_at"] = utc_now_iso()
                set_clause = ", ".join(f"{k} = ?" for k in updates)
                values = list(updates.values()) + [sub_id]
                await db.execute(
                    f"UPDATE subscriptions SET {set_clause} WHERE id = ?",  # noqa: S608
                    values,
                )
                await db.commit()

            cursor = await db.execute(
                build_subscription_query(where_clause="WHERE subscriptions.id = ?"),
                (sub_id,),
            )
            row = await cursor.fetchone()
            return self._row_to_subscription(row)
        finally:
            await db.close()

    async def mark_alerts_read(self, sub_id: str) -> bool:
        """Mark all unread alerts for a subscription as read."""
        db = await get_db()
        try:
            cursor = await db.execute(
                "SELECT id FROM subscriptions WHERE id = ?",
                (sub_id,),
            )
            if await cursor.fetchone() is None:
                return False

            await db.execute(
                """
                UPDATE subscription_alerts
                SET is_read = 1
                WHERE subscription_id = ? AND is_read = 0
                """,
                (sub_id,),
            )
            await db.commit()
            return True
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
                build_task_query(
                    where_clause="WHERE tasks.subscription_id = ?",
                    order_clause="ORDER BY tasks.created_at DESC",
                ),
                (sub_id,),
            )
            rows = await cursor.fetchall()
            tasks = [self._row_to_task(r) for r in rows]
            return TaskListResponse(tasks=tasks, total=len(tasks))
        finally:
            await db.close()

    async def run_subscription_now(self, sub_id: str) -> TaskResponse | None:
        """Trigger a task immediately using the persisted subscription config.

        Args:
            sub_id: UUID of the subscription.

        Returns:
            The newly created task, or ``None`` when the subscription does not
            exist.
        """
        subscription = await self.get_subscription(sub_id)
        if subscription is None:
            return None

        request = CreateTaskRequest(
            keyword=subscription.keyword,
            content_language=subscription.content_language,
            max_items=subscription.max_items,
            sources=subscription.sources,
        )
        task = await self._task_service.create_task(request, subscription_id=sub_id)
        run_at = datetime.fromisoformat(task.created_at)
        next_run_at = _calc_next_run(subscription.interval, run_at)

        db = await get_db()
        try:
            await db.execute(
                "UPDATE subscriptions "
                "SET last_run_at = ?, next_run_at = ?, updated_at = ? "
                "WHERE id = ?",
                (task.created_at, next_run_at, task.created_at, sub_id),
            )
            await db.commit()
        finally:
            await db.close()

        return task

    @staticmethod
    def _row_to_subscription(row: object) -> SubscriptionResponse:
        latest_unread_alert_score = row["latest_unread_alert_score"]  # type: ignore[index]
        return SubscriptionResponse(
            id=row["id"],  # type: ignore[index]
            keyword=row["keyword"],  # type: ignore[index]
            content_language=row["content_language"],  # type: ignore[index]
            max_items=row["max_items"],  # type: ignore[index]
            sources=json.loads(row["sources"]),  # type: ignore[index]
            interval=row["interval"],  # type: ignore[index]
            is_active=bool(row["is_active"]),  # type: ignore[index]
            notify=bool(row["notify"]),  # type: ignore[index]
            created_at=row["created_at"],  # type: ignore[index]
            updated_at=row["updated_at"],  # type: ignore[index]
            last_run_at=row["last_run_at"],  # type: ignore[index]
            next_run_at=row["next_run_at"],  # type: ignore[index]
            unread_alert_count=int(row["unread_alert_count"] or 0),  # type: ignore[index]
            latest_unread_alert_task_id=row["latest_unread_alert_task_id"],  # type: ignore[index]
            latest_unread_alert_score=(
                float(latest_unread_alert_score)
                if latest_unread_alert_score is not None
                else None
            ),
        )

    @staticmethod
    def _row_to_task(row: object) -> TaskResponse:
        return row_to_task_response(row)
