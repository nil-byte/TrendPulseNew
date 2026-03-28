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
        posts = await service.collect("AI", "en", 30, ["reddit", "youtube", "x"])

        assert len(posts) == 3
        sources = {p.source for p in posts}
        assert sources == {"reddit", "youtube", "x"}

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
        posts = await service.collect("AI", "en", 30, ["reddit", "youtube", "x"])

        assert len(posts) == 2
        sources = {p.source for p in posts}
        assert "youtube" not in sources

    async def test_collect_unknown_source(self) -> None:
        """Verify unknown source name is skipped with warning."""
        service = CollectorService()
        posts = await service.collect("AI", "en", 10, ["nonexistent_source"])

        assert posts == []
