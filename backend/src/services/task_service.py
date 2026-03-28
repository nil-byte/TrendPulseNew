"""Task lifecycle management service."""

from __future__ import annotations

import asyncio
import json
import logging
import uuid
from datetime import datetime, timezone

from src.models.database import get_db
from src.models.schemas import (
    AnalysisReportResponse,
    CreateTaskRequest,
    PostListResponse,
    RawPost,
    RawPostResponse,
    TaskListResponse,
    TaskResponse,
)
from src.services.analyzer_service import AnalysisResult, AnalyzerService
from src.services.collector_service import CollectorService

logger = logging.getLogger(__name__)


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


class TaskService:
    """Manages the full lifecycle of analysis tasks."""

    def __init__(self) -> None:
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
        task_id = str(uuid.uuid4())
        now = _now_iso()

        db = await get_db()
        try:
            await db.execute(
                """
                INSERT INTO tasks (
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

        asyncio.create_task(self._process_task(task_id, request))

        return TaskResponse(
            id=task_id,
            keyword=request.keyword,
            language=request.language,
            max_items=request.max_items,
            status="pending",
            sources=request.sources,
            created_at=now,
            updated_at=now,
            subscription_id=subscription_id,
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
            cursor = await db.execute("SELECT * FROM tasks WHERE id = ?", (task_id,))
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
            cursor = await db.execute("SELECT * FROM tasks ORDER BY created_at DESC")
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
                "SELECT * FROM analysis_reports WHERE task_id = ?", (task_id,)
            )
            row = await cursor.fetchone()
            if row is None:
                return None
            return AnalysisReportResponse(
                id=row["id"],
                task_id=row["task_id"],
                sentiment_score=row["sentiment_score"],
                positive_ratio=row["positive_ratio"],
                negative_ratio=row["negative_ratio"],
                neutral_ratio=row["neutral_ratio"],
                heat_index=row["heat_index"],
                key_insights=json.loads(row["key_insights"]),
                summary=row["summary"],
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

    async def _process_task(self, task_id: str, request: CreateTaskRequest) -> None:
        """Background task processing: collect -> analyze -> save results.

        Args:
            task_id: UUID of the task being processed.
            request: Original creation request with parameters.
        """
        try:
            await self._update_status(task_id, "collecting")

            posts = await self._collector.collect(
                keyword=request.keyword,
                language=request.language,
                limit=request.max_items,
                sources=request.sources,
            )

            await self._save_raw_posts(task_id, posts)

            await self._update_status(task_id, "analyzing")

            result = await self._analyzer.analyze(posts, request.keyword)

            await self._save_analysis_report(task_id, result)

            await self._update_status(task_id, "completed")
            logger.info("Task %s completed successfully", task_id)

        except Exception as e:
            logger.error("Task %s failed: %s", task_id, e, exc_info=True)
            await self._update_status(task_id, "failed", error_message=str(e))

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
                (status, _now_iso(), error_message, task_id),
            )
            await db.commit()
        finally:
            await db.close()

    async def _save_raw_posts(self, task_id: str, posts: list[RawPost]) -> None:
        now = _now_iso()
        db = await get_db()
        try:
            for post in posts:
                post_id = str(uuid.uuid4())
                metadata = (
                    json.dumps(post.metadata_extra)
                    if post.metadata_extra
                    else None
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
        now = _now_iso()
        insights_json = json.dumps(
            [ins.model_dump() for ins in result.key_insights]
        )
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
