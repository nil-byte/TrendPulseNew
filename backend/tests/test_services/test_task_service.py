"""Tests for TaskService background processing semantics."""

from __future__ import annotations

import asyncio
import json
import uuid
from collections.abc import Iterator
from dataclasses import dataclass
from datetime import datetime, timezone
from unittest.mock import AsyncMock

import pytest

from src.adapters.base import SourceFailure
from src.models.database import get_db
from src.models.schemas import CreateTaskRequest, KeyInsight, RawPost, TaskSourceOutcome
from src.services.analyzer_service import AnalysisResult
from src.services.app_settings_service import AppSettingsService
from src.services.source_availability_service import source_availability_service
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


def _make_failure(source: str, message: str) -> dict[str, SourceFailure]:
    """Create a structured source failure map for TaskService tests."""
    return {
        source: SourceFailure(
            reason_code=f"{source}_test_failure",
            message=message,
        )
    }


@dataclass(slots=True)
class FakeCollectionResult:
    """Minimal collector result test double for TaskService orchestration."""

    posts: list[RawPost]
    source_errors: dict[str, SourceFailure]

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
                    content_language,
                    report_language,
                    max_items,
                    status,
                    sources,
                    created_at,
                    updated_at,
                    subscription_id
                )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                task_id,
                request.keyword,
                request.content_language,
                request.report_language or "en",
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
                    content_language,
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


async def _get_task_quality(task_id: str) -> tuple[str, str | None]:
    """Return the stored task quality and quality summary."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT quality, quality_summary FROM tasks WHERE id = ?",
            (task_id,),
        )
        row = await cursor.fetchone()
        assert row is not None
        return row["quality"], row["quality_summary"]
    finally:
        await db.close()


async def _get_task_source_outcomes(task_id: str) -> list[dict[str, object]]:
    """Return the stored structured source outcomes for a task."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT source_outcomes_json FROM tasks WHERE id = ?",
            (task_id,),
        )
        row = await cursor.fetchone()
        assert row is not None
        return json.loads(row["source_outcomes_json"])
    finally:
        await db.close()


async def _get_task_sources(task_id: str) -> list[str]:
    """Return the stored source list for a task."""
    db = await get_db()
    try:
        cursor = await db.execute("SELECT sources FROM tasks WHERE id = ?", (task_id,))
        row = await cursor.fetchone()
        assert row is not None
        return json.loads(row["sources"])
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

    async def test_create_task_defaults_report_language_from_app_settings(
        self,
    ) -> None:
        """Omitted report_language should resolve from app settings."""
        await AppSettingsService().update_report_language("zh")
        request = CreateTaskRequest(
            keyword="openai",
            content_language="en",
            sources=["reddit"],
        )
        service = TaskService()
        service._process_task = AsyncMock()  # type: ignore[method-assign]

        response = await service.create_task(request)
        await asyncio.sleep(0)

        assert response.report_language == "zh"
        service._process_task.assert_awaited_once()
        await_args = service._process_task.await_args
        assert await_args.args[1].report_language == "zh"

    async def test_create_task_persists_only_runnable_sources(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        """Task rows and responses should reflect the runnable source set only."""
        source_availability_service.reset_runtime_state()
        monkeypatch.setattr(
            "src.config.settings.settings.youtube_api_key",
            "youtube-key",
        )
        monkeypatch.setattr("src.config.settings.settings.grok_api_key", "")

        request = CreateTaskRequest(
            keyword="openai",
            content_language="zh",
            report_language="en",
            max_items=20,
            sources=["youtube", "x"],
        )
        service = TaskService()
        service._process_task = AsyncMock()  # type: ignore[method-assign]

        response = await service.create_task(request)
        await asyncio.sleep(0)

        assert response.sources == ["youtube"]
        assert response.content_language == "zh"
        assert response.report_language == "en"
        assert await _get_task_sources(response.id) == ["youtube"]
        service._process_task.assert_awaited_once()
        await_args = service._process_task.await_args
        assert await_args.args[1].sources == ["youtube"]
        assert await_args.args[1].content_language == "zh"
        assert await_args.args[1].report_language == "en"
        initial_source_errors = await_args.kwargs["initial_source_errors"]
        assert initial_source_errors["x"].reason_code == "grok_api_key_missing"

    async def test_create_task_keeps_quality_summary_empty_while_pending(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        """Pending tasks must not expose completed-style degraded summaries."""
        source_availability_service.reset_runtime_state()
        monkeypatch.setattr(
            "src.config.settings.settings.youtube_api_key",
            "youtube-key",
        )
        monkeypatch.setattr("src.config.settings.settings.grok_api_key", "")

        request = CreateTaskRequest(
            keyword="openai",
            content_language="zh",
            report_language="en",
            sources=["youtube", "x"],
        )
        service = TaskService()
        service._process_task = AsyncMock()  # type: ignore[method-assign]

        response = await service.create_task(request)
        quality, quality_summary = await _get_task_quality(response.id)

        assert response.status == "pending"
        assert response.quality == "degraded"
        assert response.quality_summary is None
        assert quality == "degraded"
        assert quality_summary is None

    async def test_process_task_marks_degraded_quality_for_preflight_source_failures(
        self,
    ) -> None:
        """Preflight source failures should degrade quality only."""
        stored_request = CreateTaskRequest(
            keyword="openai",
            content_language="zh",
            report_language="en",
            sources=["youtube", "x"],
        )
        runnable_request = stored_request.model_copy(update={"sources": ["youtube"]})
        task_id = str(uuid.uuid4())
        await _insert_task(task_id, stored_request)

        collected_posts = [
            _make_post(
                "youtube",
                "A real transcript-backed post with enough text to analyze",
            )
        ]
        service = TaskService()
        service._collector.collect = AsyncMock(  # type: ignore[method-assign]
            return_value=FakeCollectionResult(posts=collected_posts, source_errors={})
        )
        service._analyzer.analyze = AsyncMock(  # type: ignore[method-assign]
            return_value=_make_analysis_result()
        )

        await service._process_task(
            task_id,
            runnable_request,
            initial_source_errors={
                "x": SourceFailure(
                    reason_code="grok_api_key_missing",
                    message="Grok API key is not configured",
                )
            },
        )

        status, error_message = await _get_task_state(task_id)
        quality, quality_summary = await _get_task_quality(task_id)
        assert status == "completed"
        assert error_message is None
        assert quality == "degraded"
        assert (
            quality_summary
            == "Completed with source issues: x (Grok API key is not configured)."
        )
        assert await _get_task_sources(task_id) == ["youtube", "x"]
        assert await _count_raw_posts(task_id) == 1
        assert await _count_reports(task_id) == 1

    async def test_process_task_fails_when_collection_returns_no_posts(self) -> None:
        """No collected posts must fail instead of reporting success."""
        request = CreateTaskRequest(
            keyword="openai",
            report_language="en",
            sources=["reddit"],
        )
        task_id = str(uuid.uuid4())
        await _insert_task(task_id, request)

        service = TaskService()
        service._collector.collect = AsyncMock(  # type: ignore[method-assign]
            return_value=FakeCollectionResult(
                posts=[],
                source_errors=_make_failure("reddit", "API down"),
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

    async def test_process_task_fails_when_no_posts_and_no_source_errors(
        self,
    ) -> None:
        """Zero posts from all sources should fail even when no source failed."""
        request = CreateTaskRequest(
            keyword="openai",
            report_language="en",
            sources=["reddit", "youtube"],
        )
        task_id = str(uuid.uuid4())
        await _insert_task(task_id, request)

        service = TaskService()
        service._collector.collect = AsyncMock(  # type: ignore[method-assign]
            return_value=FakeCollectionResult(
                posts=[],
                source_errors={},
            )
        )
        service._analyzer.analyze = AsyncMock(  # type: ignore[method-assign]
            return_value=_make_analysis_result()
        )

        await service._process_task(task_id, request)

        status, error_message = await _get_task_state(task_id)
        assert status == "failed"
        assert error_message == "No posts were collected from the requested sources."
        assert await _count_raw_posts(task_id) == 0
        assert await _count_reports(task_id) == 0
        service._analyzer.analyze.assert_not_awaited()

    async def test_process_task_marks_degraded_quality_when_some_sources_fail(
        self,
    ) -> None:
        """Source failures should surface as degraded quality on a completed task."""
        request = CreateTaskRequest(
            keyword="openai",
            content_language="zh",
            report_language="en",
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
                source_errors=_make_failure("youtube", "API down"),
            )
        )
        service._analyzer.analyze = AsyncMock(  # type: ignore[method-assign]
            return_value=_make_analysis_result()
        )

        await service._process_task(task_id, request)

        status, error_message = await _get_task_state(task_id)
        quality, quality_summary = await _get_task_quality(task_id)
        assert status == "completed"
        assert error_message is None
        assert quality == "degraded"
        assert quality_summary == "Completed with source issues: youtube (API down)."
        assert await _count_raw_posts(task_id) == 1
        assert await _count_reports(task_id) == 1
        service._collector.collect.assert_awaited_once_with(
            keyword=request.keyword,
            language="zh",
            limit=request.max_items,
            sources=request.sources,
        )
        service._analyzer.analyze.assert_awaited_once_with(
            collected_posts,
            request.keyword,
            language="en",
        )

    async def test_process_task_completes_with_degraded_quality_when_sources_fail(
        self,
    ) -> None:
        """Report-ready tasks should finish completed and carry degraded quality."""
        request = CreateTaskRequest(
            keyword="openai",
            content_language="zh",
            report_language="en",
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
                source_errors=_make_failure("youtube", "API down"),
            )
        )
        service._analyzer.analyze = AsyncMock(  # type: ignore[method-assign]
            return_value=_make_analysis_result()
        )

        await service._process_task(task_id, request)

        status, error_message = await _get_task_state(task_id)
        quality, quality_summary = await _get_task_quality(task_id)
        source_outcomes = await _get_task_source_outcomes(task_id)

        assert status == "completed"
        assert error_message is None
        assert quality == "degraded"
        assert quality_summary == "Completed with source issues: youtube (API down)."
        assert source_outcomes == [
            {
                "source": "reddit",
                "status": "success",
                "post_count": 1,
                "reason": None,
                "reason_code": None,
            },
            {
                "source": "youtube",
                "status": "failed",
                "post_count": 0,
                "reason": "API down",
                "reason_code": "youtube_test_failure",
            },
        ]

    async def test_process_task_completes_when_only_some_sources_return_zero_posts(
        self,
    ) -> None:
        """Zero-result sources without source_errors must not force partial status."""
        request = CreateTaskRequest(
            keyword="openai",
            content_language="zh",
            report_language="en",
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
                source_errors={},
            )
        )
        service._analyzer.analyze = AsyncMock(  # type: ignore[method-assign]
            return_value=_make_analysis_result()
        )

        await service._process_task(task_id, request)

        status, error_message = await _get_task_state(task_id)
        assert status == "completed"
        assert error_message is None
        assert await _count_raw_posts(task_id) == 1
        assert await _count_reports(task_id) == 1

    async def test_process_task_completes_with_degraded_quality_for_preflight_source(
        self,
    ) -> None:
        """Preflight-unavailable sources should degrade quality, not lifecycle."""
        stored_request = CreateTaskRequest(
            keyword="openai",
            content_language="zh",
            report_language="en",
            sources=["youtube", "x"],
        )
        runnable_request = stored_request.model_copy(update={"sources": ["youtube"]})
        task_id = str(uuid.uuid4())
        await _insert_task(task_id, stored_request)

        collected_posts = [
            _make_post(
                "youtube",
                "A real transcript-backed post with enough text to analyze",
            )
        ]
        service = TaskService()
        service._collector.collect = AsyncMock(  # type: ignore[method-assign]
            return_value=FakeCollectionResult(posts=collected_posts, source_errors={})
        )
        service._analyzer.analyze = AsyncMock(  # type: ignore[method-assign]
            return_value=_make_analysis_result()
        )

        await service._process_task(
            task_id,
            runnable_request,
            initial_source_errors={
                "x": SourceFailure(
                    reason_code="grok_api_key_missing",
                    message="Grok API key is not configured",
                )
            },
        )

        status, error_message = await _get_task_state(task_id)
        quality, quality_summary = await _get_task_quality(task_id)
        source_outcomes = await _get_task_source_outcomes(task_id)

        assert status == "completed"
        assert error_message is None
        assert quality == "degraded"
        assert (
            quality_summary
            == "Completed with source issues: x (Grok API key is not configured)."
        )
        assert source_outcomes == [
            {
                "source": "youtube",
                "status": "success",
                "post_count": 1,
                "reason": None,
                "reason_code": None,
            },
            {
                "source": "x",
                "status": "unavailable",
                "post_count": 0,
                "reason": "Grok API key is not configured",
                "reason_code": "grok_api_key_missing",
            },
        ]

    async def test_process_task_fails_when_analysis_has_no_valid_content(self) -> None:
        """Empty analysis after cleaning must fail instead of saving a report."""
        request = CreateTaskRequest(
            keyword="openai",
            report_language="en",
            sources=["reddit"],
        )
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
        ("source_errors", "expected_quality"),
        [
            ({}, "clean"),
            (_make_failure("youtube", "API down"), "degraded"),
        ],
        ids=["clean", "degraded"],
    )
    async def test_process_task_creates_unread_alert_for_low_score_subscription_task(
        self,
        source_errors: dict[str, SourceFailure],
        expected_quality: str,
    ) -> None:
        """Low-score subscription runs must create a new unread alert."""
        request = CreateTaskRequest(
            keyword="openai",
            report_language="en",
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
        quality, _ = await _get_task_quality(task_id)
        alert_rows = await _get_alert_rows(task_id)

        assert status == "completed"
        assert quality == expected_quality
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
        request = CreateTaskRequest(
            keyword="openai",
            report_language="en",
            sources=["reddit"],
        )
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
        request = CreateTaskRequest(
            keyword="openai",
            report_language="en",
            sources=["reddit"],
        )
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

    async def test_process_task_clears_completed_style_quality_summary_on_failure(
        self,
    ) -> None:
        """Unhandled failures must not retain completed-style degraded summaries."""
        request = CreateTaskRequest(
            keyword="openai",
            report_language="en",
            sources=["youtube"],
        )
        task_id = str(uuid.uuid4())
        await _insert_task(task_id, request)

        db = await get_db()
        try:
            await db.execute(
                """
                UPDATE tasks
                SET quality = ?, quality_summary = ?
                WHERE id = ?
                """,
                (
                    "degraded",
                    "Completed with source issues: x (Grok API key is not configured).",
                    task_id,
                ),
            )
            await db.commit()
        finally:
            await db.close()

        service = TaskService()
        service._collector.collect = AsyncMock(  # type: ignore[method-assign]
            side_effect=RuntimeError("collector boom")
        )

        await service._process_task(
            task_id,
            request,
            initial_source_errors={
                "x": SourceFailure(
                    reason_code="grok_api_key_missing",
                    message="Grok API key is not configured",
                )
            },
        )

        status, error_message = await _get_task_state(task_id)
        quality, quality_summary = await _get_task_quality(task_id)

        assert status == "failed"
        assert error_message == "collector boom"
        assert quality == "degraded"
        assert quality_summary is None

    def test_build_quality_summary_falls_back_to_status_without_reason(self) -> None:
        """Degraded summaries should remain readable even without source reasons."""
        summary = TaskService._build_quality_summary([
            TaskSourceOutcome(
                source="x",
                status="failed",
                post_count=0,
            ),
        ])

        assert summary == "Completed with source issues: x (failed)."
