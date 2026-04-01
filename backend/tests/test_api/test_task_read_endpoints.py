"""Task read/report/delete endpoint tests."""

from __future__ import annotations

import asyncio
import json
from unittest.mock import AsyncMock, patch

from httpx import AsyncClient

from src.models.database import get_db


class TestTaskReadEndpoints:
    """Tests for task listing, detail, report, and deletion endpoints."""

    @patch("src.api.endpoints.tasks.task_service._process_task", new_callable=AsyncMock)
    async def test_list_tasks(
        self, mock_process: AsyncMock, client: AsyncClient
    ) -> None:
        """GET /api/v1/tasks returns task list."""
        create_body = {
            "keyword": "test keyword",
            "sources": ["reddit"],
        }
        await client.post("/api/v1/tasks", json=create_body)

        response = await client.get("/api/v1/tasks")

        assert response.status_code == 200
        data = response.json()
        assert "tasks" in data
        assert "total" in data
        assert data["total"] >= 1

    @patch("src.api.endpoints.tasks.task_service._process_task", new_callable=AsyncMock)
    async def test_get_task(self, mock_process: AsyncMock, client: AsyncClient) -> None:
        """GET /api/v1/tasks/{id} returns task."""
        create_resp = await client.post(
            "/api/v1/tasks",
            json={"keyword": "test", "sources": ["reddit"]},
        )
        task_id = create_resp.json()["id"]

        response = await client.get(f"/api/v1/tasks/{task_id}")

        assert response.status_code == 200
        assert response.json()["id"] == task_id

    @patch(
        "src.services.task_service.TaskService._process_task", new_callable=AsyncMock
    )
    async def test_task_endpoints_include_degraded_completion_fields(
        self, mock_process: AsyncMock, client: AsyncClient
    ) -> None:
        """Task endpoints must separate lifecycle from quality warnings."""
        create_subscription_body = {
            "keyword": "openai",
            "content_language": "zh",
            "max_items": 25,
            "sources": ["reddit", "youtube"],
            "interval": "daily",
            "notify": True,
        }
        create_subscription_response = await client.post(
            "/api/v1/subscriptions", json=create_subscription_body
        )
        subscription_id = create_subscription_response.json()["id"]

        create_task_response = await client.post(
            f"/api/v1/subscriptions/{subscription_id}/tasks"
        )
        task_id = create_task_response.json()["id"]
        await asyncio.sleep(0)
        mock_process.assert_awaited_once()

        db = await get_db()
        try:
            await db.execute(
                """
                UPDATE tasks
                SET status = ?,
                    quality = ?,
                    quality_summary = ?,
                    source_outcomes_json = ?,
                    error_message = ?,
                    updated_at = ?
                WHERE id = ?
                """,
                (
                    "completed",
                    "degraded",
                    "Completed with source issues: youtube (API down).",
                    json.dumps(
                        [
                            {
                                "source": "reddit",
                                "status": "success",
                                "post_count": 2,
                                "reason": None,
                                "reason_code": None,
                            },
                            {
                                "source": "youtube",
                                "status": "failed",
                                "post_count": 0,
                                "reason": "API down",
                                "reason_code": "youtube_api_down",
                            },
                        ]
                    ),
                    None,
                    "2026-03-29T00:05:00Z",
                    task_id,
                ),
            )
            await db.executemany(
                """
                INSERT INTO raw_posts
                    (id, task_id, source, content, collected_at)
                VALUES (?, ?, ?, ?, ?)
                """,
                [
                    (
                        "post-1",
                        task_id,
                        "reddit",
                        "First collected post",
                        "2026-03-29T00:03:00Z",
                    ),
                    (
                        "post-2",
                        task_id,
                        "reddit",
                        "Second collected post",
                        "2026-03-29T00:04:00Z",
                    ),
                ],
            )
            await db.execute(
                """
                INSERT INTO analysis_reports
                    (
                        id,
                        task_id,
                        sentiment_score,
                        positive_ratio,
                        negative_ratio,
                        neutral_ratio,
                        heat_index,
                        key_insights,
                        summary,
                        raw_analysis_json,
                        created_at
                    )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    "report-1",
                    task_id,
                    72.5,
                    0.6,
                    0.1,
                    0.3,
                    80.0,
                    json.dumps(
                        [
                            {
                                "text": "Reddit sentiment stayed positive.",
                                "sentiment": "positive",
                                "source_count": 2,
                            }
                        ]
                    ),
                    "Completed with partial source coverage.",
                    None,
                    "2026-03-29T00:05:00Z",
                ),
            )
            await db.commit()
        finally:
            await db.close()

        detail_response = await client.get(f"/api/v1/tasks/{task_id}")
        list_response = await client.get("/api/v1/tasks")
        subscription_tasks_response = await client.get(
            f"/api/v1/subscriptions/{subscription_id}/tasks"
        )

        assert detail_response.status_code == 200
        assert list_response.status_code == 200
        assert subscription_tasks_response.status_code == 200

        detail_data = detail_response.json()
        list_task = next(
            item for item in list_response.json()["tasks"] if item["id"] == task_id
        )
        subscription_task = subscription_tasks_response.json()["tasks"][0]

        for payload in (detail_data, list_task, subscription_task):
            assert payload["status"] == "completed"
            assert payload["quality"] == "degraded"
            assert (
                payload["quality_summary"]
                == "Completed with source issues: youtube (API down)."
            )
            assert payload["content_language"] == "zh"
            assert payload["report_language"] == "en"
            assert payload["sentiment_score"] == 72.5
            assert payload["post_count"] == 2
            assert payload["error_message"] is None
            assert payload["source_outcomes"] == [
                {
                    "source": "reddit",
                    "status": "success",
                    "post_count": 2,
                    "reason": None,
                    "reason_code": None,
                },
                {
                    "source": "youtube",
                    "status": "failed",
                    "post_count": 0,
                    "reason": "API down",
                    "reason_code": "youtube_api_down",
                },
            ]

    @patch(
        "src.services.task_service.TaskService._process_task", new_callable=AsyncMock
    )
    async def test_task_endpoints_include_quality_and_source_outcomes(
        self, mock_process: AsyncMock, client: AsyncClient
    ) -> None:
        """Task endpoints should expose lifecycle and quality as separate fields."""
        create_task_response = await client.post(
            "/api/v1/tasks",
            json={
                "keyword": "openai",
                "content_language": "zh",
                "report_language": "en",
                "max_items": 25,
                "sources": ["reddit", "youtube"],
            },
        )
        task_id = create_task_response.json()["id"]
        await asyncio.sleep(0)
        mock_process.assert_awaited_once()

        db = await get_db()
        try:
            await db.execute(
                """
                UPDATE tasks
                SET status = ?,
                    quality = ?,
                    quality_summary = ?,
                    source_outcomes_json = ?,
                    error_message = ?,
                    updated_at = ?
                WHERE id = ?
                """,
                (
                    "completed",
                    "degraded",
                    "Completed with source issues: youtube (API down).",
                    json.dumps(
                        [
                            {
                                "source": "reddit",
                                "status": "success",
                                "post_count": 2,
                                "reason": None,
                                "reason_code": None,
                            },
                            {
                                "source": "youtube",
                                "status": "failed",
                                "post_count": 0,
                                "reason": "API down",
                                "reason_code": "youtube_api_down",
                            },
                        ]
                    ),
                    None,
                    "2026-03-29T00:05:00Z",
                    task_id,
                ),
            )
            await db.executemany(
                """
                INSERT INTO raw_posts
                    (id, task_id, source, content, collected_at)
                VALUES (?, ?, ?, ?, ?)
                """,
                [
                    (
                        "post-1",
                        task_id,
                        "reddit",
                        "First collected post",
                        "2026-03-29T00:03:00Z",
                    ),
                    (
                        "post-2",
                        task_id,
                        "reddit",
                        "Second collected post",
                        "2026-03-29T00:04:00Z",
                    ),
                ],
            )
            await db.execute(
                """
                INSERT INTO analysis_reports
                    (
                        id,
                        task_id,
                        sentiment_score,
                        positive_ratio,
                        negative_ratio,
                        neutral_ratio,
                        heat_index,
                        key_insights,
                        summary,
                        raw_analysis_json,
                        created_at
                    )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    "report-quality-1",
                    task_id,
                    72.5,
                    0.6,
                    0.1,
                    0.3,
                    80.0,
                    json.dumps(
                        [
                            {
                                "text": "Reddit sentiment stayed positive.",
                                "sentiment": "positive",
                                "source_count": 2,
                            }
                        ]
                    ),
                    "Completed with partial source coverage.",
                    None,
                    "2026-03-29T00:05:00Z",
                ),
            )
            await db.commit()
        finally:
            await db.close()

        detail_response = await client.get(f"/api/v1/tasks/{task_id}")
        list_response = await client.get("/api/v1/tasks")

        assert detail_response.status_code == 200
        assert list_response.status_code == 200

        detail_data = detail_response.json()
        list_task = next(
            item for item in list_response.json()["tasks"] if item["id"] == task_id
        )

        for payload in (detail_data, list_task):
            assert payload["status"] == "completed"
            assert payload["quality"] == "degraded"
            assert (
                payload["quality_summary"]
                == "Completed with source issues: youtube (API down)."
            )
            assert payload["error_message"] is None
            assert payload["source_outcomes"] == [
                {
                    "source": "reddit",
                    "status": "success",
                    "post_count": 2,
                    "reason": None,
                    "reason_code": None,
                },
                {
                    "source": "youtube",
                    "status": "failed",
                    "post_count": 0,
                    "reason": "API down",
                    "reason_code": "youtube_api_down",
                },
            ]

    @patch("src.api.endpoints.tasks.task_service._process_task", new_callable=AsyncMock)
    async def test_get_task_report_includes_mermaid_mindmap(
        self, mock_process: AsyncMock, client: AsyncClient
    ) -> None:
        """Task report endpoint must expose Mermaid mindmap output."""
        create_response = await client.post(
            "/api/v1/tasks",
            json={
                "keyword": "openai",
                "content_language": "en",
                "report_language": "en",
                "max_items": 20,
                "sources": ["reddit"],
            },
        )
        task_id = create_response.json()["id"]

        db = await get_db()
        try:
            await db.execute(
                """
                INSERT INTO analysis_reports
                    (
                        id,
                        task_id,
                        sentiment_score,
                        positive_ratio,
                        negative_ratio,
                        neutral_ratio,
                        heat_index,
                        key_insights,
                        summary,
                        raw_analysis_json,
                        created_at
                    )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    "report-mermaid-1",
                    task_id,
                    28.0,
                    0.2,
                    0.6,
                    0.2,
                    51.0,
                    json.dumps(
                        [
                            {
                                "text": "Support quality dropped",
                                "sentiment": "negative",
                                "source_count": 6,
                            }
                        ]
                    ),
                    "Support conversations are trending negative.",
                    json.dumps(
                        {
                            "mermaid_mindmap": (
                                "mindmap\n"
                                "  root((openai))\n"
                                "    Summary\n"
                                "      Support conversations are trending negative.\n"
                                "    Insight 1\n"
                                "      Support quality dropped\n"
                            )
                        }
                    ),
                    "2026-03-29T00:05:00Z",
                ),
            )
            await db.commit()
        finally:
            await db.close()

        response = await client.get(f"/api/v1/tasks/{task_id}/report")

        assert response.status_code == 200
        payload = response.json()
        assert payload["task_id"] == task_id
        assert payload["summary"] == "Support conversations are trending negative."
        assert payload["mermaid_mindmap"].startswith("mindmap\n")
        assert "root((openai))" in payload["mermaid_mindmap"]

    @patch("src.api.endpoints.tasks.task_service._process_task", new_callable=AsyncMock)
    async def test_get_task_report_rebuilds_mermaid_mindmap_when_raw_payload_missing(
        self, mock_process: AsyncMock, client: AsyncClient
    ) -> None:
        """Task report endpoint should rebuild Mermaid from the canonical contract."""
        create_response = await client.post(
            "/api/v1/tasks",
            json={
                "keyword": "openai",
                "content_language": "en",
                "report_language": "en",
                "max_items": 20,
                "sources": ["reddit"],
            },
        )
        task_id = create_response.json()["id"]

        db = await get_db()
        try:
            await db.execute(
                """
                INSERT INTO analysis_reports
                    (
                        id,
                        task_id,
                        sentiment_score,
                        positive_ratio,
                        negative_ratio,
                        neutral_ratio,
                        heat_index,
                        key_insights,
                        summary,
                        raw_analysis_json,
                        created_at
                    )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    "report-mermaid-2",
                    task_id,
                    41.0,
                    0.3,
                    0.4,
                    0.3,
                    49.0,
                    json.dumps(
                        [
                            {
                                "text": "Support quality dropped",
                                "sentiment": "negative",
                                "source_count": 6,
                            }
                        ]
                    ),
                    "Support conversations are trending negative.",
                    None,
                    "2026-03-29T00:06:00Z",
                ),
            )
            await db.commit()
        finally:
            await db.close()

        response = await client.get(f"/api/v1/tasks/{task_id}/report")

        assert response.status_code == 200
        payload = response.json()
        assert payload["task_id"] == task_id
        assert payload["mermaid_mindmap"].startswith("mindmap\n")
        assert "root((openai))" in payload["mermaid_mindmap"]
        assert "Viewpoints" in payload["mermaid_mindmap"]
        assert "Support quality dropped" in payload["mermaid_mindmap"]

    async def test_get_task_not_found(self, client: AsyncClient) -> None:
        """GET /api/v1/tasks/nonexistent returns 404."""
        response = await client.get("/api/v1/tasks/nonexistent-id-12345")

        assert response.status_code == 404

    @patch("src.api.endpoints.tasks.task_service._process_task", new_callable=AsyncMock)
    async def test_delete_task(
        self, mock_process: AsyncMock, client: AsyncClient
    ) -> None:
        """DELETE /api/v1/tasks/{id} returns 204."""
        create_resp = await client.post(
            "/api/v1/tasks",
            json={"keyword": "to delete", "sources": ["reddit"]},
        )
        task_id = create_resp.json()["id"]

        response = await client.delete(f"/api/v1/tasks/{task_id}")

        assert response.status_code == 204

        get_resp = await client.get(f"/api/v1/tasks/{task_id}")
        assert get_resp.status_code == 404
