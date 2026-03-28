"""Tests for data collection adapters."""

from __future__ import annotations

import json
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from src.adapters.reddit_adapter import RedditAdapter
from src.adapters.x_adapter import XAdapter
from src.adapters.youtube_adapter import YouTubeAdapter
from src.models.schemas import RawPost


class TestRedditAdapter:
    """Tests for RedditAdapter.collect()."""

    @patch("src.adapters.reddit_adapter.settings")
    @patch("src.adapters.reddit_adapter.asyncpraw")
    async def test_reddit_adapter_returns_raw_posts(
        self, mock_asyncpraw: MagicMock, mock_settings: MagicMock
    ) -> None:
        """Mock asyncpraw to return fake submissions and verify RawPost list."""
        mock_settings.reddit_client_id = "test_id"
        mock_settings.reddit_client_secret = "test_secret"
        mock_settings.reddit_user_agent = "test_agent"

        fake_submission = SimpleNamespace(
            id="abc123",
            title="Test Title",
            selftext="Test body content here",
            author="test_user",
            score=42,
            created_utc=1700000000.0,
            permalink="/r/test/comments/abc123/test/",
        )

        mock_subreddit = AsyncMock()
        mock_subreddit.search = MagicMock(return_value=_async_iter([fake_submission]))

        mock_reddit_instance = AsyncMock()
        mock_reddit_instance.subreddit = AsyncMock(return_value=mock_subreddit)
        mock_reddit_instance.__aenter__ = AsyncMock(return_value=mock_reddit_instance)
        mock_reddit_instance.__aexit__ = AsyncMock(return_value=False)

        mock_asyncpraw.Reddit.return_value = mock_reddit_instance

        adapter = RedditAdapter()
        posts = await adapter.collect("test", "en", 10)

        assert len(posts) == 1
        assert posts[0].source == "reddit"
        assert posts[0].source_id == "abc123"
        assert "Test Title" in posts[0].content
        assert posts[0].engagement == 42

    @patch("src.adapters.reddit_adapter.settings")
    async def test_reddit_handles_empty_credentials(
        self, mock_settings: MagicMock
    ) -> None:
        """Verify adapter returns empty list when API keys are empty."""
        mock_settings.reddit_client_id = ""
        mock_settings.reddit_client_secret = ""

        adapter = RedditAdapter()
        posts = await adapter.collect("test", "en", 10)

        assert posts == []


class TestYouTubeAdapter:
    """Tests for YouTubeAdapter.collect()."""

    @patch("src.adapters.youtube_adapter.YouTubeTranscriptApi")
    @patch("src.adapters.youtube_adapter.build")
    @patch("src.adapters.youtube_adapter.settings")
    async def test_youtube_adapter_returns_raw_posts(
        self,
        mock_settings: MagicMock,
        mock_build: MagicMock,
        mock_transcript_api: MagicMock,
    ) -> None:
        """Mock Google API client and transcript API, verify posts with transcript."""
        mock_settings.youtube_api_key = "test_key"

        search_response = {
            "items": [
                {
                    "id": {"videoId": "vid001"},
                    "snippet": {
                        "title": "Test Video",
                        "channelTitle": "TestChannel",
                        "publishedAt": "2024-01-01T00:00:00Z",
                    },
                }
            ]
        }
        stats_response = {
            "items": [
                {
                    "id": "vid001",
                    "statistics": {"viewCount": "1000"},
                }
            ]
        }

        mock_youtube = MagicMock()
        mock_youtube.search().list().execute.return_value = search_response
        mock_youtube.videos().list().execute.return_value = stats_response
        mock_build.return_value = mock_youtube

        mock_transcript_api.get_transcript.return_value = [
            {"text": "Hello world this is a transcript"}
        ]

        adapter = YouTubeAdapter()
        posts = await adapter.collect("test", "en", 5)

        assert len(posts) == 1
        assert posts[0].source == "youtube"
        assert posts[0].source_id == "vid001"
        assert "Test Video" in posts[0].content
        assert "Hello world" in posts[0].content
        assert posts[0].engagement == 1000

    @patch("src.adapters.youtube_adapter.settings")
    async def test_youtube_handles_empty_credentials(
        self, mock_settings: MagicMock
    ) -> None:
        """Verify adapter returns empty list when API key is empty."""
        mock_settings.youtube_api_key = ""

        adapter = YouTubeAdapter()
        posts = await adapter.collect("test", "en", 10)

        assert posts == []


class TestXAdapter:
    """Tests for XAdapter.collect()."""

    @patch("src.adapters.x_adapter.settings")
    @patch("src.adapters.x_adapter.AsyncOpenAI")
    async def test_x_adapter_returns_raw_posts(
        self, mock_openai_cls: MagicMock, mock_settings: MagicMock
    ) -> None:
        """Mock AsyncOpenAI to return fake JSON, verify deduplicated posts."""
        mock_settings.grok_api_key = "test_key"
        mock_settings.grok_base_url = "https://test.api/v1"
        mock_settings.grok_model = "test-model"

        tweets = [
            {
                "id": "t1",
                "username": "user1",
                "content": "Great product launch",
                "perspective": "Bullish",
                "created_at": "2024-01-01T00:00:00Z",
                "engagement": 100,
                "url": "https://x.com/user1/status/t1",
            },
            {
                "id": "t2",
                "username": "user2",
                "content": "Not impressed at all",
                "perspective": "Skeptical",
                "created_at": "2024-01-01T01:00:00Z",
                "engagement": 50,
                "url": "https://x.com/user2/status/t2",
            },
        ]

        mock_response = MagicMock()
        mock_response.choices = [
            MagicMock(message=MagicMock(content=json.dumps(tweets)))
        ]

        mock_client = AsyncMock()
        mock_client.chat.completions.create = AsyncMock(return_value=mock_response)
        mock_openai_cls.return_value = mock_client

        adapter = XAdapter()
        posts = await adapter.collect("test", "en", 10)

        assert len(posts) > 0
        sources = {p.source for p in posts}
        assert sources == {"x"}
        ids = [p.source_id for p in posts]
        assert len(ids) == len(set(ids))

    @patch("src.adapters.x_adapter.settings")
    async def test_x_handles_empty_credentials(
        self, mock_settings: MagicMock
    ) -> None:
        """Verify adapter returns empty list when Grok API key is empty."""
        mock_settings.grok_api_key = ""

        adapter = XAdapter()
        posts = await adapter.collect("test", "en", 10)

        assert posts == []

    async def test_x_adapter_handles_think_tags(self) -> None:
        """Verify <think> tag stripping works in _parse_response."""
        adapter = XAdapter()
        raw_text = (
            '<think>Let me analyze this...</think>'
            '[{"id": "t1", "username": "u1", "content": "hello world", '
            '"perspective": "Neutral", "created_at": "2024-01-01T00:00:00Z", '
            '"engagement": 10, "url": "https://x.com/u1/status/t1"}]'
        )

        posts = adapter._parse_response(raw_text, "test_shard")

        assert len(posts) == 1
        assert posts[0].source_id == "t1"
        assert posts[0].content == "hello world"


class _AsyncIterator:
    """Helper to create an async iterator from a list."""

    def __init__(self, items: list) -> None:
        self._items = iter(items)

    def __aiter__(self):
        return self

    async def __anext__(self):
        try:
            return next(self._items)
        except StopIteration:
            raise StopAsyncIteration


def _async_iter(items: list) -> _AsyncIterator:
    return _AsyncIterator(items)
