"""Tests for TaskService background processing semantics."""

from __future__ import annotations

import json
import uuid
from collections.abc import Iterator
from dataclasses import dataclass
from datetime import datetime, timezone
from unittest.mock import AsyncMock

import pytest

from src.models.database import get_db
from src.models.schemas import CreateTaskRequest, KeyInsight, RawPost
from src.services.analyzer_service import AnalysisResult
from src.services.task_service import TaskService


def _make_post(source: str, content: str) -> RawPost:
    """Create a RawPost for TaskService tests."""
    return RawPost(source=source, content=content, engagement=10)


def _make_analysis_result(sentiment_score: float = 72.5) -> AnalysisResult:
    """Create a non-empty analysis result for TaskService tests."""
    return AnalysisResult(
        sentiment_score=sentiment_score,
        positive_ratio=0.7,
        negative_ratio=0.1,
        neutral_ratio=0.2,
        heat_index=34.0,
        key_insights=[
            KeyInsight(
                text="Users like the release",
                sentiment="positive",
                source_count=1,
            )
        ],
        summary="Valid analysis result.",
        raw_analysis={
            "chunk_count": 1,
            "total_posts_analyzed": 1,
            "total_engagement": 10,
        },
    )


@dataclass(slots=True)
class FakeCollectionResult:
    """Minimal collector result test double for TaskService orchestration."""

    posts: list[RawPost]
    source_errors: dict[str, str]

    def __iter__(self) -> Iterator[RawPost]:
        """Support legacy list-style iteration during red phase."""
        return iter(self.posts)


async def _insert_task(
    task_id: str,
    request: CreateTaskRequest,
    *,
    subscription_id: str | None = None,
) -> None:
    """Insert a pending task row for background-processing tests."""
    now = datetime.now(timezone.utc).isoformat()
    db = await get_db()
    try:
        await db.execute(
            """
            INSERT INTO tasks
                (
                    id,
                    keyword,
                    language,
                    max_items,
                    status,
                    sources,
                    created_at,
                    updated_at,
                    subscription_id
                )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                task_id,
                request.keyword,
                request.language,
                request.max_items,
                "pending",
                json.dumps(request.sources),
                now,
                now,
                subscription_id,
            ),
        )
        await db.commit()
    finally:
        await db.close()


async def _insert_subscription(subscription_id: str, *, notify: bool) -> None:
    """Insert a subscription row for alert-related TaskService tests."""
    now = datetime.now(timezone.utc).isoformat()
    db = await get_db()
    try:
        await db.execute(
            """
            INSERT INTO subscriptions
                (
                    id,
                    keyword,
                    language,
                    max_items,
                    sources,
                    interval,
                    is_active,
                    notify,
                    created_at,
                    updated_at,
                    next_run_at
                )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                subscription_id,
                "openai",
                "en",
                50,
                json.dumps(["reddit", "youtube"]),
                "daily",
                1,
                int(notify),
                now,
                now,
                now,
            ),
        )
        await db.commit()
    finally:
        await db.close()


async def _get_task_state(task_id: str) -> tuple[str, str | None]:
    """Return the stored status and error message for a task."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT status, error_message FROM tasks WHERE id = ?",
            (task_id,),
        )
        row = await cursor.fetchone()
        assert row is not None
        return row["status"], row["error_message"]
    finally:
        await db.close()


async def _count_raw_posts(task_id: str) -> int:
    """Count raw posts saved for a task."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT COUNT(*) AS count FROM raw_posts WHERE task_id = ?",
            (task_id,),
        )
        row = await cursor.fetchone()
        assert row is not None
        return int(row["count"])
    finally:
        await db.close()


async def _count_reports(task_id: str) -> int:
    """Count saved analysis reports for a task."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT COUNT(*) AS count FROM analysis_reports WHERE task_id = ?",
            (task_id,),
        )
        row = await cursor.fetchone()
        assert row is not None
        return int(row["count"])
    finally:
        await db.close()


async def _get_alert_rows(task_id: str) -> list[object]:
    """Return stored alert rows for a task."""
    db = await get_db()
    try:
        cursor = await db.execute(
            """
            SELECT task_id, sentiment_score, is_read
            FROM subscription_alerts
            WHERE task_id = ?
            ORDER BY created_at DESC
            """,
            (task_id,),
        )
        return await cursor.fetchall()
    finally:
        await db.close()


class TestTaskServiceProcessTask:
    """Regression tests for task completion semantics."""

    async def test_process_task_fails_when_collection_returns_no_posts(self) -> None:
        """No collected posts must fail instead of reporting success."""
        request = CreateTaskRequest(keyword="openai", sources=["reddit"])
        task_id = str(uuid.uuid4())
        await _insert_task(task_id, request)

        service = TaskService()
        service._collector.collect = AsyncMock(  # type: ignore[method-assign]
            return_value=FakeCollectionResult(
                posts=[],
                source_errors={"reddit": "API down"},
            )
        )
        service._analyzer.analyze = AsyncMock(  # type: ignore[method-assign]
            return_value=_make_analysis_result()
        )

        await service._process_task(task_id, request)

        status, error_message = await _get_task_state(task_id)
        assert status == "failed"
        assert (
            error_message
            == "No posts were collected from the requested sources. "
            "Source failures: reddit (API down)."
        )
        assert await _count_raw_posts(task_id) == 0
        assert await _count_reports(task_id) == 0
        service._analyzer.analyze.assert_not_awaited()

    async def test_process_task_marks_partial_when_some_sources_fail(self) -> None:
        """Partial source failures must surface as partial, not completed."""
        request = CreateTaskRequest(
            keyword="openai",
            language="zh",
            sources=["reddit", "youtube"],
        )
        task_id = str(uuid.uuid4())
        await _insert_task(task_id, request)

        collected_posts = [
            _make_post(
                "reddit",
                "A real post with enough text to analyze",
            )
        ]
        service = TaskService()
        service._collector.collect = AsyncMock(  # type: ignore[method-assign]
            return_value=FakeCollectionResult(
                posts=collected_posts,
                source_errors={"youtube": "API down"},
            )
        )
        service._analyzer.analyze = AsyncMock(  # type: ignore[method-assign]
            return_value=_make_analysis_result()
        )

        await service._process_task(task_id, request)

        status, error_message = await _get_task_state(task_id)
        assert status == "partial"
        assert error_message == "Completed with source failures: youtube (API down)."
        assert await _count_raw_posts(task_id) == 1
        assert await _count_reports(task_id) == 1
        service._analyzer.analyze.assert_awaited_once_with(
            collected_posts,
            request.keyword,
            language="zh",
        )

    async def test_process_task_fails_when_analysis_has_no_valid_content(self) -> None:
        """Empty analysis after cleaning must fail instead of saving a report."""
        request = CreateTaskRequest(keyword="openai", sources=["reddit"])
        task_id = str(uuid.uuid4())
        await _insert_task(task_id, request)

        service = TaskService()
        service._collector.collect = AsyncMock(  # type: ignore[method-assign]
            return_value=FakeCollectionResult(
                posts=[_make_post("reddit", "A real post with enough text to analyze")],
                source_errors={},
            )
        )
        service._analyzer.analyze = AsyncMock(  # type: ignore[method-assign]
            return_value=AnalysisResult(
                summary="No posts available for analysis after cleaning."
            )
        )

        await service._process_task(task_id, request)

        status, error_message = await _get_task_state(task_id)
        assert status == "failed"
        assert (
            error_message
            == "Collected posts did not contain analyzable content after cleaning."
        )
        assert await _count_raw_posts(task_id) == 1
        assert await _count_reports(task_id) == 0

    @pytest.mark.parametrize(
        ("source_errors", "expected_status"),
        [
            ({}, "completed"),
            ({"youtube": "API down"}, "partial"),
        ],
        ids=["completed", "partial"],
    )
    async def test_process_task_creates_unread_alert_for_low_score_subscription_task(
        self,
        source_errors: dict[str, str],
        expected_status: str,
    ) -> None:
        """Low-score subscription runs must create a new unread alert."""
        request = CreateTaskRequest(
            keyword="openai",
            sources=["reddit", "youtube"],
        )
        task_id = str(uuid.uuid4())
        subscription_id = str(uuid.uuid4())
        await _insert_subscription(subscription_id, notify=True)
        await _insert_task(task_id, request, subscription_id=subscription_id)

        service = TaskService()
        service._collector.collect = AsyncMock(  # type: ignore[method-assign]
            return_value=FakeCollectionResult(
                posts=[_make_post("reddit", "A real post with enough text to analyze")],
                source_errors=source_errors,
            )
        )
        service._analyzer.analyze = AsyncMock(  # type: ignore[method-assign]
            return_value=_make_analysis_result(sentiment_score=18.0)
        )

        await service._process_task(task_id, request)

        status, _ = await _get_task_state(task_id)
        alert_rows = await _get_alert_rows(task_id)

        assert status == expected_status
        assert len(alert_rows) == 1
        assert alert_rows[0]["task_id"] == task_id  # type: ignore[index]
        assert float(alert_rows[0]["sentiment_score"]) == 18.0  # type: ignore[index]
        assert int(alert_rows[0]["is_read"]) == 0  # type: ignore[index]

    @pytest.mark.parametrize(
        ("has_subscription", "notify"),
        [
            (False, True),
            (True, False),
        ],
        ids=["non-subscription-task", "notify-disabled-subscription"],
    )
    async def test_process_task_skips_alert_for_non_subscription_or_notify_disabled(
        self,
        has_subscription: bool,
        notify: bool,
    ) -> None:
        """Alerts must not be created when the task is not an opted-in subscription."""
        request = CreateTaskRequest(keyword="openai", sources=["reddit"])
        task_id = str(uuid.uuid4())
        subscription_id = str(uuid.uuid4()) if has_subscription else None
        if subscription_id is not None:
            await _insert_subscription(subscription_id, notify=notify)
        await _insert_task(task_id, request, subscription_id=subscription_id)

        service = TaskService()
        service._collector.collect = AsyncMock(  # type: ignore[method-assign]
            return_value=FakeCollectionResult(
                posts=[_make_post("reddit", "A real post with enough text to analyze")],
                source_errors={},
            )
        )
        service._analyzer.analyze = AsyncMock(  # type: ignore[method-assign]
            return_value=_make_analysis_result(sentiment_score=12.0)
        )

        await service._process_task(task_id, request)

        status, _ = await _get_task_state(task_id)

        assert status == "completed"
        assert await _get_alert_rows(task_id) == []

    @pytest.mark.parametrize(
        "sentiment_score",
        [30.0, 42.0],
        ids=["threshold-score", "above-threshold-score"],
    )
    async def test_process_task_skips_alert_for_scores_at_or_above_threshold(
        self,
        sentiment_score: float,
    ) -> None:
        """Scores at or above threshold must not create subscription alerts."""
        request = CreateTaskRequest(keyword="openai", sources=["reddit"])
        task_id = str(uuid.uuid4())
        subscription_id = str(uuid.uuid4())
        await _insert_subscription(subscription_id, notify=True)
        await _insert_task(task_id, request, subscription_id=subscription_id)

        service = TaskService()
        service._collector.collect = AsyncMock(  # type: ignore[method-assign]
            return_value=FakeCollectionResult(
                posts=[
                    _make_post(
                        "reddit",
                        "A real post with enough text to analyze",
                    )
                ],
                source_errors={},
            )
        )
        service._analyzer.analyze = AsyncMock(  # type: ignore[method-assign]
            return_value=_make_analysis_result(sentiment_score=sentiment_score)
        )

        await service._process_task(task_id, request)

        status, _ = await _get_task_state(task_id)

        assert status == "completed"
        assert await _get_alert_rows(task_id) == []
