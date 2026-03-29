"""Tests for CollectorService."""

from __future__ import annotations

from unittest.mock import AsyncMock, patch

from src.models.schemas import RawPost
from src.services.collector_service import CollectorService


def _make_post(source: str, content: str) -> RawPost:
    """Create a RawPost for testing."""
    return RawPost(source=source, content=content, engagement=10)


class TestCollectorService:
    """Tests for CollectorService concurrent collection."""

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
        assert result.source_errors == {"youtube": "API down"}
        assert result.failed_sources == ["youtube"]

    async def test_collect_unknown_source(self) -> None:
        """Verify unknown source name is skipped with warning."""
        service = CollectorService()
        result = await service.collect("AI", "en", 10, ["nonexistent_source"])

        assert result.posts == []
        assert result.source_errors == {
            "nonexistent_source": "Unsupported source: nonexistent_source"
        }
        assert result.failed_sources == ["nonexistent_source"]

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
            "reddit": "Reddit credentials are not configured"
        }
        assert result.failed_sources == ["reddit"]
