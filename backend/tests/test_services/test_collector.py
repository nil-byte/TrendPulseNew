"""Tests for CollectorService."""

from __future__ import annotations

import logging
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

import pytest

from src.adapters.base import (
    PartialSourceCollectionError,
    SourceCollectionError,
    SourceFailure,
)
from src.models.schemas import RawPost
from src.services.collector_service import CollectorService
from src.services.source_availability_service import source_availability_service


def _make_post(source: str, content: str) -> RawPost:
    """Create a RawPost for testing."""
    return RawPost(source=source, content=content, engagement=10)


class TestCollectorService:
    """Tests for CollectorService concurrent collection."""

    async def test_collect_uses_localized_search_query_for_adapters(self) -> None:
        """Collector should localize once, then pass the rewritten query to adapters."""
        source_availability_service.reset_runtime_state()
        mock_reddit = AsyncMock()
        mock_reddit.collect = AsyncMock(
            return_value=[_make_post("reddit", "Reddit post about AI trends")]
        )
        mock_reddit.source_name = "reddit"

        mock_youtube = AsyncMock()
        mock_youtube.collect = AsyncMock(
            return_value=[_make_post("youtube", "YouTube video about AI trends")]
        )
        mock_youtube.source_name = "youtube"

        mock_x = AsyncMock()
        mock_x.collect = AsyncMock(
            return_value=[_make_post("x", "Tweet about AI trends")]
        )
        mock_x.source_name = "x"

        mock_search_query_service = AsyncMock()
        mock_search_query_service.build_search_query = AsyncMock(
            return_value=SimpleNamespace(
                query="artificial intelligence",
                status="localized",
                reason=None,
            )
        )

        service = CollectorService(
            adapters={
                "reddit": mock_reddit,
                "youtube": mock_youtube,
                "x": mock_x,
            },
            search_query_service=mock_search_query_service,
        )
        result = await service.collect("人工智能", "en", 30, ["reddit", "youtube", "x"])

        assert len(result.posts) == 3
        assert result.source_errors == {}
        mock_search_query_service.build_search_query.assert_awaited_once_with(
            "人工智能",
            "en",
        )
        mock_reddit.collect.assert_awaited_once_with(
            "artificial intelligence",
            "en",
            30,
        )
        mock_youtube.collect.assert_awaited_once_with(
            "artificial intelligence",
            "en",
            30,
        )
        mock_x.collect.assert_awaited_once_with("artificial intelligence", "en", 30)
        source_availability_service.reset_runtime_state()

    async def test_collect_logs_search_query_fallback_status_and_reason(
        self,
        caplog: pytest.LogCaptureFixture,
    ) -> None:
        """Collector should log localization fallback metadata for observability."""
        source_availability_service.reset_runtime_state()
        mock_x = AsyncMock()
        mock_x.collect = AsyncMock(return_value=[_make_post("x", "Tweet content here")])
        mock_x.source_name = "x"

        mock_search_query_service = AsyncMock()
        mock_search_query_service.build_search_query = AsyncMock(
            return_value=SimpleNamespace(
                query='"exact phrase"',
                status="fallback",
                reason="llm_call_failed",
            )
        )

        service = CollectorService(
            adapters={"x": mock_x},
            search_query_service=mock_search_query_service,
        )

        with caplog.at_level(logging.INFO, logger="src.services.collector_service"):
            result = await service.collect('"exact phrase"', "en", 10, ["x"])

        assert len(result.posts) == 1
        mock_x.collect.assert_awaited_once_with('"exact phrase"', "en", 10)
        assert "Collector starting" in caplog.text
        assert 'search_query=\'"exact phrase"\'' in caplog.text
        assert "search_query_status=fallback" in caplog.text
        assert "search_query_reason='llm_call_failed'" in caplog.text
        source_availability_service.reset_runtime_state()

    async def test_collect_logs_zero_post_success_with_posts_count(
        self,
        caplog: pytest.LogCaptureFixture,
    ) -> None:
        """Successful zero-post collections should still log posts=0."""
        source_availability_service.reset_runtime_state()
        mock_youtube = AsyncMock()
        mock_youtube.collect = AsyncMock(return_value=[])
        mock_youtube.source_name = "youtube"

        mock_search_query_service = AsyncMock()
        mock_search_query_service.build_search_query = AsyncMock(
            return_value=SimpleNamespace(
                query="AI",
                status="localized",
                reason=None,
            )
        )

        service = CollectorService(
            adapters={"youtube": mock_youtube},
            search_query_service=mock_search_query_service,
        )

        with caplog.at_level(logging.INFO, logger="src.services.collector_service"):
            result = await service.collect("AI", "en", 10, ["youtube"])

        assert result.posts == []
        assert result.source_errors == {}
        assert "Collection succeeded source=youtube posts=0" in caplog.text
        source_availability_service.reset_runtime_state()

    async def test_collect_logs_source_and_reason_code_when_source_fails(
        self,
        caplog: pytest.LogCaptureFixture,
    ) -> None:
        """Failed collections should log both source and stable reason_code."""
        source_availability_service.reset_runtime_state()
        mock_youtube = AsyncMock()
        mock_youtube.collect = AsyncMock(
            side_effect=SourceCollectionError(
                "youtube_rate_limited",
                "YouTube API rate limit exceeded",
            )
        )
        mock_youtube.source_name = "youtube"

        mock_search_query_service = AsyncMock()
        mock_search_query_service.build_search_query = AsyncMock(
            return_value=SimpleNamespace(
                query="AI",
                status="localized",
                reason=None,
            )
        )

        service = CollectorService(
            adapters={"youtube": mock_youtube},
            search_query_service=mock_search_query_service,
        )

        with caplog.at_level(logging.ERROR, logger="src.services.collector_service"):
            result = await service.collect("AI", "en", 10, ["youtube"])

        assert result.posts == []
        assert result.source_errors == {
            "youtube": SourceFailure(
                reason_code="youtube_rate_limited",
                message="YouTube API rate limit exceeded",
            )
        }
        assert (
            "Collection failed source=youtube reason_code=youtube_rate_limited"
            in caplog.text
        )
        source_availability_service.reset_runtime_state()

    @patch("src.services.collector_service.XAdapter")
    @patch("src.services.collector_service.YouTubeAdapter")
    @patch("src.services.collector_service.RedditAdapter")
    async def test_collect_from_multiple_sources(
        self,
        mock_reddit_cls: type,
        mock_youtube_cls: type,
        mock_x_cls: type,
    ) -> None:
        """Mock all adapters, verify concurrent collection works."""
        source_availability_service.reset_runtime_state()
        mock_reddit = AsyncMock()
        mock_reddit.collect = AsyncMock(
            return_value=[_make_post("reddit", "Reddit post about AI trends")]
        )
        mock_reddit.source_name = "reddit"
        mock_reddit_cls.return_value = mock_reddit

        mock_youtube = AsyncMock()
        mock_youtube.collect = AsyncMock(
            return_value=[_make_post("youtube", "YouTube video about AI trends")]
        )
        mock_youtube.source_name = "youtube"
        mock_youtube_cls.return_value = mock_youtube

        mock_x = AsyncMock()
        mock_x.collect = AsyncMock(
            return_value=[_make_post("x", "Tweet about AI trends")]
        )
        mock_x.source_name = "x"
        mock_x_cls.return_value = mock_x

        service = CollectorService()
        result = await service.collect("AI", "en", 30, ["reddit", "youtube", "x"])

        assert len(result.posts) == 3
        sources = {p.source for p in result.posts}
        assert sources == {"reddit", "youtube", "x"}
        assert result.source_errors == {}
        assert result.failed_sources == []
        mock_reddit.collect.assert_awaited_once_with("AI", "en", 30)
        mock_youtube.collect.assert_awaited_once_with("AI", "en", 30)
        mock_x.collect.assert_awaited_once_with("AI", "en", 30)
        availability = {
            item.source: item
            for item in source_availability_service.list_availability(
                ["reddit", "youtube", "x"]
            )
        }
        assert availability["reddit"].status == "available"
        assert availability["youtube"].status == "available"
        assert availability["x"].status == "available"
        assert availability["reddit"].checked_at is not None
        assert availability["youtube"].checked_at is not None
        assert availability["x"].checked_at is not None
        source_availability_service.reset_runtime_state()

    @patch("src.services.collector_service.XAdapter")
    @patch("src.services.collector_service.YouTubeAdapter")
    @patch("src.services.collector_service.RedditAdapter")
    async def test_collect_handles_adapter_failure(
        self,
        mock_reddit_cls: type,
        mock_youtube_cls: type,
        mock_x_cls: type,
    ) -> None:
        """Mock one adapter to raise exception, verify others still return data."""
        source_availability_service.reset_runtime_state()
        mock_reddit = AsyncMock()
        mock_reddit.collect = AsyncMock(
            return_value=[_make_post("reddit", "Reddit post content here")]
        )
        mock_reddit.source_name = "reddit"
        mock_reddit_cls.return_value = mock_reddit

        mock_youtube = AsyncMock()
        mock_youtube.collect = AsyncMock(side_effect=RuntimeError("API down"))
        mock_youtube.source_name = "youtube"
        mock_youtube_cls.return_value = mock_youtube

        mock_x = AsyncMock()
        mock_x.collect = AsyncMock(
            return_value=[_make_post("x", "Tweet content here")]
        )
        mock_x.source_name = "x"
        mock_x_cls.return_value = mock_x

        service = CollectorService()
        result = await service.collect("AI", "en", 30, ["reddit", "youtube", "x"])

        assert len(result.posts) == 2
        sources = {p.source for p in result.posts}
        assert "youtube" not in sources
        assert result.source_errors == {
            "youtube": SourceFailure(
                reason_code="unknown_collection_error",
                message="API down",
            )
        }
        assert result.failed_sources == ["youtube"]
        mock_reddit.collect.assert_awaited_once_with("AI", "en", 30)
        mock_youtube.collect.assert_awaited_once_with("AI", "en", 30)
        mock_x.collect.assert_awaited_once_with("AI", "en", 30)
        availability = {
            item.source: item
            for item in source_availability_service.list_availability(
                ["reddit", "youtube", "x"]
            )
        }
        assert availability["reddit"].status == "available"
        assert availability["x"].status == "available"
        assert availability["youtube"].status == "degraded"
        assert availability["youtube"].is_available is True
        assert availability["youtube"].reason_code == "unknown_collection_error"
        assert availability["youtube"].checked_at is not None
        source_availability_service.reset_runtime_state()

    async def test_collect_unknown_source(self) -> None:
        """Verify unknown source name is skipped with warning."""
        service = CollectorService()
        result = await service.collect("AI", "en", 10, ["nonexistent_source"])

        assert result.posts == []
        assert result.source_errors == {
            "nonexistent_source": SourceFailure(
                reason_code="unsupported_source",
                message="Unsupported source: nonexistent_source",
            )
        }
        assert result.failed_sources == ["nonexistent_source"]

    @patch("src.services.collector_service.XAdapter")
    @patch("src.services.collector_service.YouTubeAdapter")
    @patch("src.services.collector_service.RedditAdapter")
    async def test_collect_keeps_partial_posts_when_source_degrades(
        self,
        mock_reddit_cls: type,
        mock_youtube_cls: type,
        mock_x_cls: type,
    ) -> None:
        """Adapters may return partial posts via typed degraded errors."""
        source_availability_service.reset_runtime_state()
        mock_reddit = AsyncMock()
        mock_reddit.collect = AsyncMock(
            return_value=[_make_post("reddit", "Reddit post content here")]
        )
        mock_reddit.source_name = "reddit"
        mock_reddit_cls.return_value = mock_reddit

        mock_youtube = AsyncMock()
        mock_youtube.collect = AsyncMock(return_value=[])
        mock_youtube.source_name = "youtube"
        mock_youtube_cls.return_value = mock_youtube

        mock_x = AsyncMock()
        mock_x.collect = AsyncMock(
            side_effect=PartialSourceCollectionError(
                "grok_collection_failed",
                "X collection partially failed: shard down",
                partial_posts=[_make_post("x", "Partial X post still usable")],
            )
        )
        mock_x.source_name = "x"
        mock_x_cls.return_value = mock_x

        service = CollectorService()
        result = await service.collect("AI", "en", 30, ["reddit", "x"])

        assert len(result.posts) == 2
        assert {post.source for post in result.posts} == {"reddit", "x"}
        assert result.source_errors == {
            "x": SourceFailure(
                reason_code="grok_collection_failed",
                message="X collection partially failed: shard down",
            )
        }
        availability = {
            item.source: item
            for item in source_availability_service.list_availability(["reddit", "x"])
        }
        assert availability["reddit"].status == "available"
        assert availability["x"].status == "degraded"
        assert availability["x"].reason_code == "grok_collection_failed"
        source_availability_service.reset_runtime_state()

    @patch("src.adapters.reddit_adapter.settings")
    async def test_collect_records_real_adapter_configuration_failure(
        self, mock_settings: type
    ) -> None:
        """Collector must capture source errors raised by a real adapter."""
        mock_settings.reddit_client_id = ""
        mock_settings.reddit_client_secret = ""
        mock_settings.reddit_user_agent = "test-agent"

        service = CollectorService()
        result = await service.collect("AI", "en", 10, ["reddit"])

        assert result.posts == []
        assert result.source_errors == {
            "reddit": SourceFailure(
                reason_code="reddit_credentials_missing",
                message="Reddit credentials are not configured",
            )
        }
        assert result.failed_sources == ["reddit"]
