"""Task lifecycle management service."""

from __future__ import annotations

import asyncio
import json
import logging
import uuid

from src.adapters.base import SourceFailure
from src.common.time_utils import utc_now_iso
from src.models.database import get_db
from src.models.schemas import (
    AnalysisReportResponse,
    CreateTaskRequest,
    KeyInsight,
    PostListResponse,
    RawPost,
    RawPostResponse,
    TaskListResponse,
    TaskResponse,
)
from src.services.analyzer_service import (
    AnalysisResult,
    AnalyzerService,
    build_mermaid_mindmap,
)
from src.services.app_settings_service import AppSettingsService
from src.services.collector_service import CollectionResult, CollectorService
from src.services.source_availability_service import source_availability_service

logger = logging.getLogger(__name__)

_FAILED_STATUS = "failed"
_PARTIAL_STATUS = "partial"
_COMPLETED_STATUS = "completed"
_LOW_SENTIMENT_ALERT_THRESHOLD = 30.0
_EMPTY_COLLECTION_ERROR = "No posts were collected from the requested sources."
_EMPTY_ANALYSIS_ERROR = (
    "Collected posts did not contain analyzable content after cleaning."
)
_TASK_SELECT_WITH_METRICS = """
SELECT
    tasks.id,
    tasks.keyword,
    tasks.content_language,
    tasks.report_language,
    tasks.max_items,
    tasks.status,
    tasks.sources,
    tasks.created_at,
    tasks.updated_at,
    tasks.error_message,
    tasks.subscription_id,
    analysis_reports.sentiment_score AS sentiment_score,
    post_counts.post_count AS post_count
FROM tasks
LEFT JOIN analysis_reports
    ON analysis_reports.task_id = tasks.id
LEFT JOIN (
    SELECT task_id, COUNT(*) AS post_count
    FROM raw_posts
    GROUP BY task_id
) AS post_counts
    ON post_counts.task_id = tasks.id
"""


class NoAvailableSourcesError(RuntimeError):
    """Raised when a task request contains no runnable sources."""

    code = "no_available_sources"

    def as_detail(self) -> dict[str, str]:
        """Return a structured API-safe error payload."""
        return {"code": self.code, "message": str(self)}

def build_task_query(*, where_clause: str = "", order_clause: str = "") -> str:
    """Build a task query that includes derived list/detail metrics."""
    parts = [_TASK_SELECT_WITH_METRICS.strip()]
    if where_clause:
        parts.append(where_clause)
    if order_clause:
        parts.append(order_clause)
    return "\n".join(parts)


def row_to_task_response(row: object) -> TaskResponse:
    """Convert a task query row with optional metrics into a response model."""
    sentiment_score = row["sentiment_score"]  # type: ignore[index]
    post_count = row["post_count"]  # type: ignore[index]
    return TaskResponse(
        id=row["id"],  # type: ignore[index]
        keyword=row["keyword"],  # type: ignore[index]
        content_language=row["content_language"],  # type: ignore[index]
        report_language=row["report_language"],  # type: ignore[index]
        max_items=row["max_items"],  # type: ignore[index]
        status=row["status"],  # type: ignore[index]
        sources=json.loads(row["sources"]),  # type: ignore[index]
        created_at=row["created_at"],  # type: ignore[index]
        updated_at=row["updated_at"],  # type: ignore[index]
        error_message=row["error_message"],  # type: ignore[index]
        subscription_id=row["subscription_id"],  # type: ignore[index]
        sentiment_score=float(sentiment_score) if sentiment_score is not None else None,
        post_count=int(post_count) if post_count is not None else None,
    )


class TaskService:
    """Manages the full lifecycle of analysis tasks."""

    def __init__(self) -> None:
        self._app_settings_service = AppSettingsService()
        self._collector = CollectorService()
        self._analyzer = AnalyzerService()

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    async def create_task(
        self,
        request: CreateTaskRequest,
        subscription_id: str | None = None,
    ) -> TaskResponse:
        """Create a new analysis task and start background processing.

        Args:
            request: Validated task creation request.
            subscription_id: Optional owning subscription UUID.

        Returns:
            The newly created task.
        """
        availability = source_availability_service.list_availability(request.sources)
        effective_sources = [item.source for item in availability if item.is_available]
        unavailable_sources = {
            item.source: SourceFailure(
                reason_code=item.reason_code or "source_unavailable",
                message=item.reason or "Source is unavailable",
            )
            for item in availability
            if not item.is_available
        }
        degraded_sources = {
            item.source: f"{item.reason_code}: {item.reason}"
            for item in availability
            if item.status == "degraded" and item.reason and item.reason_code
        }
        logger.info(
            "Task source resolution "
            "keyword=%r requested=%s effective=%s unavailable=%s degraded=%s "
            "max_items_per_source=%d",
            request.keyword,
            request.sources,
            effective_sources,
            {
                source: failure.reason_code
                for source, failure in sorted(unavailable_sources.items())
            },
            degraded_sources,
            request.max_items,
        )
        if not effective_sources:
            source_summary = self._format_source_failures(unavailable_sources)
            raise NoAvailableSourcesError(
                "No requested sources are currently available. "
                f"Unavailable sources: {source_summary}."
            )

        report_language = request.report_language
        if report_language is None:
            report_language = await self._app_settings_service.get_report_language()

        effective_request = request.model_copy(
            update={
                "sources": effective_sources,
                "report_language": report_language,
            }
        )
        task_id = str(uuid.uuid4())
        now = utc_now_iso()

        db = await get_db()
        try:
            await db.execute(
                """
                INSERT INTO tasks (
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
                    effective_request.keyword,
                    effective_request.content_language,
                    effective_request.report_language,
                    effective_request.max_items,
                    "pending",
                    json.dumps(effective_request.sources),
                    now,
                    now,
                    subscription_id,
                ),
            )
            await db.commit()
        finally:
            await db.close()

        asyncio.create_task(
            self._process_task(
                task_id,
                effective_request,
                initial_source_errors=unavailable_sources,
            )
        )

        return TaskResponse(
            id=task_id,
            keyword=effective_request.keyword,
            content_language=effective_request.content_language,
            report_language=effective_request.report_language,
            max_items=effective_request.max_items,
            status="pending",
            sources=effective_request.sources,
            created_at=now,
            updated_at=now,
            subscription_id=subscription_id,
            sentiment_score=None,
            post_count=None,
        )

    async def get_task(self, task_id: str) -> TaskResponse | None:
        """Get task by ID.

        Args:
            task_id: UUID of the task.

        Returns:
            Task response or None if not found.
        """
        db = await get_db()
        try:
            cursor = await db.execute(
                build_task_query(where_clause="WHERE tasks.id = ?"),
                (task_id,),
            )
            row = await cursor.fetchone()
            if row is None:
                return None
            return self._row_to_task(row)
        finally:
            await db.close()

    async def get_task_list(self) -> TaskListResponse:
        """Get all tasks ordered by creation date desc.

        Returns:
            List of all tasks with total count.
        """
        db = await get_db()
        try:
            cursor = await db.execute(
                build_task_query(order_clause="ORDER BY tasks.created_at DESC")
            )
            rows = await cursor.fetchall()
            tasks = [self._row_to_task(r) for r in rows]
            return TaskListResponse(tasks=tasks, total=len(tasks))
        finally:
            await db.close()

    async def get_task_report(self, task_id: str) -> AnalysisReportResponse | None:
        """Get analysis report for a task.

        Args:
            task_id: UUID of the task.

        Returns:
            Analysis report or None if not found.
        """
        db = await get_db()
        try:
            cursor = await db.execute(
                """
                SELECT
                    analysis_reports.*,
                    tasks.keyword AS keyword,
                    tasks.report_language AS report_language
                FROM analysis_reports
                JOIN tasks
                    ON tasks.id = analysis_reports.task_id
                WHERE analysis_reports.task_id = ?
                """,
                (task_id,),
            )
            row = await cursor.fetchone()
            if row is None:
                return None
            key_insights = [
                KeyInsight.model_validate(item)
                for item in json.loads(row["key_insights"])
            ]
            raw_analysis_raw = row["raw_analysis_json"]
            loaded_raw_analysis = (
                json.loads(raw_analysis_raw) if raw_analysis_raw else None
            )
            raw_analysis = (
                loaded_raw_analysis if isinstance(loaded_raw_analysis, dict) else {}
            )
            mermaid_mindmap = raw_analysis.get("mermaid_mindmap")
            if not mermaid_mindmap:
                mermaid_mindmap = build_mermaid_mindmap(
                    keyword=row["keyword"],
                    summary=row["summary"],
                    insights=key_insights,
                    language=row["report_language"],
                )
            return AnalysisReportResponse(
                id=row["id"],
                task_id=row["task_id"],
                sentiment_score=row["sentiment_score"],
                positive_ratio=row["positive_ratio"],
                negative_ratio=row["negative_ratio"],
                neutral_ratio=row["neutral_ratio"],
                heat_index=row["heat_index"],
                key_insights=key_insights,
                summary=row["summary"],
                mermaid_mindmap=mermaid_mindmap,
                created_at=row["created_at"],
            )
        finally:
            await db.close()

    async def get_task_posts(
        self, task_id: str, source: str | None = None
    ) -> PostListResponse:
        """Get raw posts for a task, optionally filtered by source.

        Args:
            task_id: UUID of the task.
            source: Optional source name filter.

        Returns:
            List of raw posts with total count.
        """
        db = await get_db()
        try:
            if source:
                cursor = await db.execute(
                    "SELECT * FROM raw_posts "
                    "WHERE task_id = ? AND source = ? "
                    "ORDER BY engagement DESC",
                    (task_id, source),
                )
            else:
                cursor = await db.execute(
                    "SELECT * FROM raw_posts "
                    "WHERE task_id = ? "
                    "ORDER BY engagement DESC",
                    (task_id,),
                )
            rows = await cursor.fetchall()
            posts = [self._row_to_post(r) for r in rows]
            return PostListResponse(posts=posts, total=len(posts))
        finally:
            await db.close()

    async def delete_task(self, task_id: str) -> bool:
        """Delete a task and its associated data.

        Args:
            task_id: UUID of the task.

        Returns:
            True if the task existed and was deleted.
        """
        db = await get_db()
        try:
            cursor = await db.execute("SELECT id FROM tasks WHERE id = ?", (task_id,))
            if await cursor.fetchone() is None:
                return False

            await db.execute(
                "DELETE FROM analysis_reports WHERE task_id = ?",
                (task_id,),
            )
            await db.execute("DELETE FROM raw_posts WHERE task_id = ?", (task_id,))
            await db.execute("DELETE FROM tasks WHERE id = ?", (task_id,))
            await db.commit()
            return True
        finally:
            await db.close()

    # ------------------------------------------------------------------
    # Background processing
    # ------------------------------------------------------------------

    async def _process_task(
        self,
        task_id: str,
        request: CreateTaskRequest,
        *,
        initial_source_errors: dict[str, SourceFailure] | None = None,
    ) -> None:
        """Background task processing: collect -> analyze -> save results.

        Args:
            task_id: UUID of the task being processed.
            request: Runnable creation request with currently available parameters.
            initial_source_errors: Source failures known before collection begins.
        """
        try:
            await self._update_status(task_id, "collecting")

            collection_result = await self._collector.collect(
                keyword=request.keyword,
                language=request.content_language,
                limit=request.max_items,
                sources=request.sources,
            )
            source_errors = dict(initial_source_errors or {})
            source_errors.update(collection_result.source_errors)
            effective_result = CollectionResult(
                posts=collection_result.posts,
                source_errors=source_errors,
            )

            if not collection_result.posts:
                error_message = self._build_empty_collection_error(effective_result)
                await self._update_status(
                    task_id,
                    _FAILED_STATUS,
                    error_message=error_message,
                )
                logger.warning("Task %s failed: %s", task_id, error_message)
                return

            await self._save_raw_posts(task_id, collection_result.posts)

            await self._update_status(task_id, "analyzing")

            result = await self._analyzer.analyze(
                collection_result.posts,
                request.keyword,
                language=request.report_language,
            )

            if not result.has_analyzable_content():
                error_message = self._build_empty_analysis_error(effective_result)
                await self._update_status(
                    task_id,
                    _FAILED_STATUS,
                    error_message=error_message,
                )
                logger.warning("Task %s failed: %s", task_id, error_message)
                return

            await self._save_analysis_report(task_id, result)

            if effective_result.source_errors:
                error_message = self._build_partial_error(effective_result)
                await self._update_status(
                    task_id,
                    _PARTIAL_STATUS,
                    error_message=error_message,
                )
                await self._create_subscription_alert_if_needed(
                    task_id,
                    result.sentiment_score,
                )
                logger.warning(
                    "Task %s completed partially: %s",
                    task_id,
                    error_message,
                )
                return

            await self._update_status(task_id, _COMPLETED_STATUS)
            await self._create_subscription_alert_if_needed(
                task_id,
                result.sentiment_score,
            )
            logger.info("Task %s completed successfully", task_id)

        except Exception as e:
            logger.error("Task %s failed: %s", task_id, e, exc_info=True)
            await self._update_status(task_id, _FAILED_STATUS, error_message=str(e))

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    async def _update_status(
        self, task_id: str, status: str, *, error_message: str | None = None
    ) -> None:
        db = await get_db()
        try:
            await db.execute(
                "UPDATE tasks "
                "SET status = ?, updated_at = ?, error_message = ? "
                "WHERE id = ?",
                (status, utc_now_iso(), error_message, task_id),
            )
            await db.commit()
        finally:
            await db.close()

    async def _save_raw_posts(self, task_id: str, posts: list[RawPost]) -> None:
        now = utc_now_iso()
        db = await get_db()
        try:
            for post in posts:
                post_id = str(uuid.uuid4())
                metadata = (
                    json.dumps(post.metadata_extra) if post.metadata_extra else None
                )
                await db.execute(
                    """
                    INSERT INTO raw_posts
                        (id, task_id, source, source_id, author, content, url,
                         engagement, published_at, collected_at, metadata_json)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        post_id,
                        task_id,
                        post.source,
                        post.source_id,
                        post.author,
                        post.content,
                        post.url,
                        post.engagement,
                        post.published_at,
                        now,
                        metadata,
                    ),
                )
            await db.commit()
            logger.info("Saved %d raw posts for task %s", len(posts), task_id)
        finally:
            await db.close()

    async def _save_analysis_report(self, task_id: str, result: AnalysisResult) -> None:
        report_id = str(uuid.uuid4())
        now = utc_now_iso()
        insights_json = json.dumps([ins.model_dump() for ins in result.key_insights])
        raw_json = json.dumps(result.raw_analysis) if result.raw_analysis else None

        db = await get_db()
        try:
            await db.execute(
                """
                INSERT INTO analysis_reports
                    (id, task_id, sentiment_score, positive_ratio, negative_ratio,
                     neutral_ratio, heat_index, key_insights, summary,
                     raw_analysis_json, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    report_id,
                    task_id,
                    result.sentiment_score,
                    result.positive_ratio,
                    result.negative_ratio,
                    result.neutral_ratio,
                    result.heat_index,
                    insights_json,
                    result.summary,
                    raw_json,
                    now,
                ),
            )
            await db.commit()
            logger.info("Saved analysis report for task %s", task_id)
        finally:
            await db.close()

    async def _create_subscription_alert_if_needed(
        self,
        task_id: str,
        sentiment_score: float,
    ) -> None:
        """Create a subscription alert when a completed run is below threshold."""
        if sentiment_score >= _LOW_SENTIMENT_ALERT_THRESHOLD:
            return

        db = await get_db()
        try:
            await db.execute(
                """
                INSERT INTO subscription_alerts
                    (
                        id,
                        subscription_id,
                        task_id,
                        sentiment_score,
                        is_read,
                        created_at
                    )
                SELECT
                    ?,
                    tasks.subscription_id,
                    tasks.id,
                    ?,
                    0,
                    ?
                FROM tasks
                JOIN subscriptions
                    ON subscriptions.id = tasks.subscription_id
                WHERE tasks.id = ?
                  AND tasks.status IN (?, ?)
                  AND subscriptions.notify = 1
                  AND NOT EXISTS (
                      SELECT 1
                      FROM subscription_alerts
                      WHERE subscription_alerts.task_id = tasks.id
                  )
                """,
                (
                    str(uuid.uuid4()),
                    sentiment_score,
                    utc_now_iso(),
                    task_id,
                    _COMPLETED_STATUS,
                    _PARTIAL_STATUS,
                ),
            )
            await db.commit()
        finally:
            await db.close()

    @staticmethod
    def _format_source_failures(source_errors: dict[str, SourceFailure]) -> str:
        """Render source failures into a stable, readable summary."""
        return "; ".join(
            f"{source} ({failure.message})"
            for source, failure in sorted(source_errors.items())
        )

    def _build_empty_collection_error(self, result: CollectionResult) -> str:
        """Create the task error message for empty collection outcomes."""
        source_summary = self._format_source_failures(result.source_errors)
        if not source_summary:
            return _EMPTY_COLLECTION_ERROR
        return f"{_EMPTY_COLLECTION_ERROR} Source failures: {source_summary}."

    def _build_partial_error(self, result: CollectionResult) -> str:
        """Create the task error message for partial collection success."""
        source_summary = self._format_source_failures(result.source_errors)
        return f"Completed with source failures: {source_summary}."

    def _build_empty_analysis_error(self, result: CollectionResult) -> str:
        """Create the task error message for empty analysis outcomes."""
        source_summary = self._format_source_failures(result.source_errors)
        if not source_summary:
            return _EMPTY_ANALYSIS_ERROR
        return f"{_EMPTY_ANALYSIS_ERROR} Source failures: {source_summary}."

    @staticmethod
    def _row_to_task(row: object) -> TaskResponse:
        return row_to_task_response(row)

    @staticmethod
    def _row_to_post(row: object) -> RawPostResponse:
        metadata_raw = row["metadata_json"]  # type: ignore[index]
        return RawPostResponse(
            id=row["id"],  # type: ignore[index]
            task_id=row["task_id"],  # type: ignore[index]
            source=row["source"],  # type: ignore[index]
            source_id=row["source_id"],  # type: ignore[index]
            author=row["author"],  # type: ignore[index]
            content=row["content"],  # type: ignore[index]
            url=row["url"],  # type: ignore[index]
            engagement=row["engagement"],  # type: ignore[index]
            published_at=row["published_at"],  # type: ignore[index]
            collected_at=row["collected_at"],  # type: ignore[index]
            metadata_json=json.loads(metadata_raw) if metadata_raw else None,
        )


_task_service_instance: TaskService | None = None


def get_task_service() -> TaskService:
    """Return the app-wide TaskService singleton."""
    global _task_service_instance
    if _task_service_instance is None:
        _task_service_instance = TaskService()
    return _task_service_instance
