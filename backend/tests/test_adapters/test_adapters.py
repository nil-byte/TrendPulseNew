"""Tests for data collection adapters."""

from __future__ import annotations

import json
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from src.adapters.base import PartialSourceCollectionError, SourceCollectionError
from src.adapters.reddit_adapter import RedditAdapter
from src.adapters.x_adapter import XAdapter
from src.adapters.youtube_adapter import YouTubeAdapter


class TestRedditAdapter:
    """Tests for RedditAdapter.collect()."""

    @patch("src.adapters.reddit_adapter.utc_now")
    @patch("src.adapters.reddit_adapter.settings")
    @patch("src.adapters.reddit_adapter.asyncpraw")
    async def test_reddit_adapter_returns_raw_posts(
        self,
        mock_asyncpraw: MagicMock,
        mock_settings: MagicMock,
        mock_utc_now: MagicMock,
    ) -> None:
        """Mock asyncpraw to return fake submissions and verify RawPost list."""
        fixed_now = datetime(2026, 4, 1, 12, 0, tzinfo=timezone.utc)
        mock_utc_now.return_value = fixed_now
        mock_settings.reddit_client_id = "test_id"
        mock_settings.reddit_client_secret = "test_secret"
        mock_settings.reddit_user_agent = "test_agent"
        mock_settings.reddit_https_proxy = ""
        mock_settings.reddit_ssl_ca_file = ""
        mock_settings.collection_recency_hours = 24

        fake_submission = SimpleNamespace(
            id="abc123",
            title="Test Title",
            selftext="Test body content here",
            author="test_user",
            score=42,
            created_utc=(fixed_now - timedelta(hours=2)).timestamp(),
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

    @patch("src.adapters.reddit_adapter.utc_now")
    @patch("src.adapters.reddit_adapter.settings")
    @patch("src.adapters.reddit_adapter.asyncpraw")
    async def test_reddit_adapter_filters_obvious_language_mismatches(
        self,
        mock_asyncpraw: MagicMock,
        mock_settings: MagicMock,
        mock_utc_now: MagicMock,
    ) -> None:
        """Reddit should drop obviously non-English posts when content_language=en."""
        fixed_now = datetime(2026, 4, 1, 12, 0, tzinfo=timezone.utc)
        mock_utc_now.return_value = fixed_now
        mock_settings.reddit_client_id = "test_id"
        mock_settings.reddit_client_secret = "test_secret"
        mock_settings.reddit_user_agent = "test_agent"
        mock_settings.reddit_https_proxy = ""
        mock_settings.reddit_ssl_ca_file = ""
        mock_settings.collection_recency_hours = 24

        english_submission = SimpleNamespace(
            id="en123",
            title="AI launch discussion",
            selftext="Users are debating the new roadmap in detail.",
            author="english_user",
            score=42,
            created_utc=(fixed_now - timedelta(hours=3)).timestamp(),
            permalink="/r/test/comments/en123/test/",
        )
        chinese_submission = SimpleNamespace(
            id="zh123",
            title="人工智能趋势",
            selftext="这个话题在中文社区非常热门。",
            author="chinese_user",
            score=30,
            created_utc=(fixed_now - timedelta(hours=1)).timestamp(),
            permalink="/r/test/comments/zh123/test/",
        )

        mock_subreddit = AsyncMock()
        mock_subreddit.search = MagicMock(
            return_value=_async_iter([english_submission, chinese_submission])
        )

        mock_reddit_instance = AsyncMock()
        mock_reddit_instance.subreddit = AsyncMock(return_value=mock_subreddit)
        mock_reddit_instance.__aenter__ = AsyncMock(return_value=mock_reddit_instance)
        mock_reddit_instance.__aexit__ = AsyncMock(return_value=False)

        mock_asyncpraw.Reddit.return_value = mock_reddit_instance

        adapter = RedditAdapter()
        posts = await adapter.collect("artificial intelligence", "en", 10)

        assert [post.source_id for post in posts] == ["en123"]

    @patch("src.adapters.reddit_adapter.utc_now")
    @patch("src.adapters.reddit_adapter.settings")
    @patch("src.adapters.reddit_adapter.asyncpraw")
    async def test_reddit_adapter_uses_day_new_and_filters_to_recent_window(
        self,
        mock_asyncpraw: MagicMock,
        mock_settings: MagicMock,
        mock_utc_now: MagicMock,
    ) -> None:
        """Reddit should narrow to `day/new`, then hard-filter to the last 24 hours."""
        fixed_now = datetime(2026, 4, 1, 12, 0, tzinfo=timezone.utc)
        mock_utc_now.return_value = fixed_now
        mock_settings.reddit_client_id = "test_id"
        mock_settings.reddit_client_secret = "test_secret"
        mock_settings.reddit_user_agent = "test_agent"
        mock_settings.reddit_https_proxy = ""
        mock_settings.reddit_ssl_ca_file = ""
        mock_settings.collection_recency_hours = 24

        recent_submission = SimpleNamespace(
            id="recent123",
            title="Recent launch notes",
            selftext="Fresh product chatter from today.",
            author="recent_user",
            score=52,
            created_utc=(fixed_now - timedelta(hours=2)).timestamp(),
            permalink="/r/test/comments/recent123/test/",
        )
        stale_submission = SimpleNamespace(
            id="stale123",
            title="Last week's recap",
            selftext="This should be discarded as too old.",
            author="stale_user",
            score=31,
            created_utc=(fixed_now - timedelta(hours=30)).timestamp(),
            permalink="/r/test/comments/stale123/test/",
        )
        another_recent_submission = SimpleNamespace(
            id="recent456",
            title="Another current discussion",
            selftext="Still inside the last day window.",
            author="recent_user_2",
            score=44,
            created_utc=(fixed_now - timedelta(hours=6)).timestamp(),
            permalink="/r/test/comments/recent456/test/",
        )

        mock_subreddit = AsyncMock()
        mock_subreddit.search = MagicMock(
            return_value=_async_iter(
                [recent_submission, stale_submission, another_recent_submission]
            )
        )

        mock_reddit_instance = AsyncMock()
        mock_reddit_instance.subreddit = AsyncMock(return_value=mock_subreddit)
        mock_reddit_instance.__aenter__ = AsyncMock(return_value=mock_reddit_instance)
        mock_reddit_instance.__aexit__ = AsyncMock(return_value=False)
        mock_asyncpraw.Reddit.return_value = mock_reddit_instance

        adapter = RedditAdapter()
        posts = await adapter.collect("test", "en", 1)

        assert [post.source_id for post in posts] == ["recent123"]
        mock_subreddit.search.assert_called_once_with(
            "test",
            sort="new",
            time_filter="day",
            limit=3,
        )

    @patch("src.adapters.reddit_adapter.settings")
    @patch("src.adapters.reddit_adapter.aiohttp.ClientSession")
    def test_reddit_build_client_session_applies_https_proxy_from_settings(
        self,
        mock_client_session: MagicMock,
        mock_settings: MagicMock,
    ) -> None:
        """Configured proxy should stay scoped to the Reddit aiohttp session."""
        mock_settings.reddit_https_proxy = "http://proxy.internal:3128"
        mock_settings.reddit_ssl_ca_file = ""
        mock_settings.reddit_http_timeout_seconds = 45.0

        with patch.dict(os.environ, {}, clear=True):
            adapter = RedditAdapter()
            adapter._build_client_session()
            assert "HTTPS_PROXY" not in os.environ
            assert "https_proxy" not in os.environ
            assert "HTTP_PROXY" not in os.environ
            assert "http_proxy" not in os.environ

        mock_client_session.assert_called_once()
        kwargs = mock_client_session.call_args.kwargs
        assert kwargs["proxy"] == "http://proxy.internal:3128"
        assert kwargs["trust_env"] is False

    @patch("src.adapters.reddit_adapter.settings")
    async def test_reddit_raises_typed_error_when_ssl_ca_file_is_missing(
        self, mock_settings: MagicMock
    ) -> None:
        """A missing CA file should surface as a typed collection error."""
        mock_settings.reddit_client_id = "test_id"
        mock_settings.reddit_client_secret = "test_secret"
        mock_settings.reddit_user_agent = "test_agent"
        mock_settings.reddit_https_proxy = ""
        mock_settings.reddit_ssl_ca_file = "/tmp/does-not-exist-ca.pem"
        mock_settings.reddit_http_timeout_seconds = 45.0

        adapter = RedditAdapter()
        with pytest.raises(SourceCollectionError) as exc_info:
            await adapter.collect("test", "en", 10)

        assert exc_info.value.reason_code == "reddit_ssl_error"

    @patch("src.adapters.reddit_adapter.settings")
    async def test_reddit_raises_typed_error_when_ssl_ca_file_is_invalid(
        self,
        mock_settings: MagicMock,
        tmp_path: Path,
    ) -> None:
        """A malformed CA file should be rejected before the session is created."""
        invalid_ca = tmp_path / "invalid-ca.pem"
        invalid_ca.write_text("not a valid certificate bundle", encoding="utf-8")

        mock_settings.reddit_client_id = "test_id"
        mock_settings.reddit_client_secret = "test_secret"
        mock_settings.reddit_user_agent = "test_agent"
        mock_settings.reddit_https_proxy = ""
        mock_settings.reddit_ssl_ca_file = str(invalid_ca)
        mock_settings.reddit_http_timeout_seconds = 45.0

        adapter = RedditAdapter()
        with pytest.raises(SourceCollectionError) as exc_info:
            await adapter.collect("test", "en", 10)

        assert exc_info.value.reason_code == "reddit_ssl_error"

    @patch("src.adapters.reddit_adapter.settings")
    def test_reddit_prefers_proxy_error_code_for_proxy_host(
        self, mock_settings: MagicMock
    ) -> None:
        """Proxy failures should not be misclassified as generic network."""
        mock_settings.reddit_https_proxy = "http://proxy.internal:3128"

        error = RedditAdapter._map_collection_error(
            RuntimeError(
                "Cannot connect to host proxy.internal:3128 "
                "ssl:default [Connect call failed]"
            )
        )

        assert error.reason_code == "reddit_proxy_required"

    @patch("src.adapters.reddit_adapter.settings")
    async def test_reddit_raises_typed_error_when_proxy_url_is_invalid(
        self, mock_settings: MagicMock
    ) -> None:
        """Malformed proxy URLs should be rejected before aiohttp session creation."""
        mock_settings.reddit_client_id = "test_id"
        mock_settings.reddit_client_secret = "test_secret"
        mock_settings.reddit_user_agent = "test_agent"
        mock_settings.reddit_https_proxy = "http://proxy.internal:badport"
        mock_settings.reddit_ssl_ca_file = ""
        mock_settings.reddit_http_timeout_seconds = 45.0

        adapter = RedditAdapter()
        with pytest.raises(SourceCollectionError) as exc_info:
            await adapter.collect("test", "en", 10)

        assert exc_info.value.reason_code == "reddit_proxy_required"

    @patch("src.adapters.reddit_adapter.settings")
    async def test_reddit_raises_when_credentials_missing(
        self, mock_settings: MagicMock
    ) -> None:
        """Missing Reddit credentials must raise instead of silently returning []."""
        mock_settings.reddit_client_id = ""
        mock_settings.reddit_client_secret = ""

        adapter = RedditAdapter()
        with pytest.raises(RuntimeError, match="Reddit credentials"):
            await adapter.collect("test", "en", 10)

    @patch("src.adapters.reddit_adapter.settings")
    @patch("src.adapters.reddit_adapter.asyncpraw")
    async def test_reddit_raises_on_top_level_collection_failure(
        self, mock_asyncpraw: MagicMock, mock_settings: MagicMock
    ) -> None:
        """Top-level Reddit failures must bubble up to CollectorService."""
        mock_settings.reddit_client_id = "test_id"
        mock_settings.reddit_client_secret = "test_secret"
        mock_settings.reddit_user_agent = "test_agent"
        mock_settings.reddit_https_proxy = ""
        mock_settings.reddit_ssl_ca_file = ""
        mock_asyncpraw.Reddit.side_effect = RuntimeError("auth failed")

        adapter = RedditAdapter()
        with pytest.raises(RuntimeError, match="auth failed"):
            await adapter.collect("test", "en", 10)


class TestYouTubeAdapter:
    """Tests for YouTubeAdapter.collect()."""

    @patch("src.adapters.youtube_adapter.YouTubeTranscriptApi")
    def test_youtube_fetch_transcript_uses_prioritized_chinese_language_codes(
        self,
        mock_transcript_api: MagicMock,
    ) -> None:
        """Chinese transcript lookup should only try zh transcript variants."""
        mock_transcript = MagicMock()
        mock_transcript.language = "Chinese (Simplified)"
        mock_transcript.language_code = "zh-Hans"
        mock_transcript.is_generated = False
        mock_transcript.fetch.return_value = [SimpleNamespace(text="中文字幕")]
        transcript_list = mock_transcript_api.return_value.list.return_value
        transcript_list.find_transcript.return_value = mock_transcript

        adapter = YouTubeAdapter()
        result = adapter._fetch_transcript("vid001", "zh")

        assert result.status == "fetched"
        mock_transcript_api.return_value.list.return_value.find_transcript.assert_called_once_with(
            ["zh-Hans", "zh-CN", "zh-SG", "zh", "zh-Hant", "zh-TW", "zh-HK"]
        )

    @patch("src.adapters.youtube_adapter.utc_now")
    @patch("src.adapters.youtube_adapter.YouTubeTranscriptApi")
    @patch("src.adapters.youtube_adapter.build")
    @patch("src.adapters.youtube_adapter.asyncio.to_thread")
    @patch("src.adapters.youtube_adapter.settings")
    async def test_youtube_adapter_returns_raw_posts(
        self,
        mock_settings: MagicMock,
        mock_to_thread: AsyncMock,
        mock_build: MagicMock,
        mock_transcript_api: MagicMock,
        mock_utc_now: MagicMock,
    ) -> None:
        """Mock Google API client and transcript API, verify posts with transcript."""
        fixed_now = datetime(2026, 4, 1, 12, 0, tzinfo=timezone.utc)
        mock_utc_now.return_value = fixed_now
        mock_settings.youtube_api_key = "test_key"
        mock_settings.collection_recency_hours = 24
        mock_to_thread.side_effect = lambda func, *args: func(*args)

        search_response = {
            "items": [
                {
                    "id": {"videoId": "vid001"},
                    "snippet": {
                        "title": "Test Video",
                        "channelTitle": "TestChannel",
                        "publishedAt": "2026-04-01T08:00:00Z",
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

        mock_transcript = MagicMock()
        mock_transcript.language = "English"
        mock_transcript.language_code = "en"
        mock_transcript.is_generated = False
        mock_transcript.fetch.return_value = [
            SimpleNamespace(text="Hello world this is a transcript")
        ]
        transcript_list = mock_transcript_api.return_value.list.return_value
        transcript_list.find_transcript.return_value = mock_transcript

        adapter = YouTubeAdapter()
        posts = await adapter.collect("test", "en", 5)

        assert len(posts) == 1
        assert posts[0].source == "youtube"
        assert posts[0].source_id == "vid001"
        assert "Test Video" in posts[0].content
        assert "Hello world" in posts[0].content
        assert posts[0].engagement == 1000
        assert posts[0].metadata_extra == {
            "has_transcript": True,
            "transcript_status": "fetched",
            "transcript_error_code": None,
            "transcript_language": "English",
            "transcript_language_code": "en",
            "transcript_is_generated": False,
        }
        assert mock_to_thread.await_count == 2
        assert (
            mock_youtube.search().list.call_args.kwargs.get("relevanceLanguage") == "en"
        )

    @patch("src.adapters.youtube_adapter.build")
    @patch("src.adapters.youtube_adapter.asyncio.to_thread")
    @patch("src.adapters.youtube_adapter.settings")
    async def test_youtube_search_uses_simplified_chinese_relevance_language(
        self,
        mock_settings: MagicMock,
        mock_to_thread: AsyncMock,
        mock_build: MagicMock,
    ) -> None:
        """Chinese collection should ask YouTube search.list for zh-Hans relevance."""
        mock_settings.youtube_api_key = "test_key"
        mock_to_thread.side_effect = lambda func, *args: func(*args)

        mock_youtube = MagicMock()
        mock_youtube.search().list().execute.return_value = {"items": []}
        mock_build.return_value = mock_youtube

        adapter = YouTubeAdapter()
        posts = await adapter.collect("人工智能", "zh", 5)

        assert posts == []
        assert (
            mock_youtube.search().list.call_args.kwargs.get("relevanceLanguage")
            == "zh-Hans"
        )

    @patch("src.adapters.youtube_adapter.utc_now")
    @patch("src.adapters.youtube_adapter.build")
    @patch("src.adapters.youtube_adapter.asyncio.to_thread")
    @patch("src.adapters.youtube_adapter.settings")
    async def test_youtube_search_uses_recent_window_parameters(
        self,
        mock_settings: MagicMock,
        mock_to_thread: AsyncMock,
        mock_build: MagicMock,
        mock_utc_now: MagicMock,
    ) -> None:
        """YouTube search.list should request only the last 24 hours ordered by date."""
        fixed_now = datetime(2026, 4, 1, 12, 0, tzinfo=timezone.utc)
        mock_utc_now.return_value = fixed_now
        mock_settings.youtube_api_key = "test_key"
        mock_settings.collection_recency_hours = 24
        mock_to_thread.side_effect = lambda func, *args: func(*args)

        mock_youtube = MagicMock()
        mock_youtube.search().list().execute.return_value = {"items": []}
        mock_build.return_value = mock_youtube

        adapter = YouTubeAdapter()
        posts = await adapter.collect("test", "en", 5)

        assert posts == []
        assert mock_youtube.search().list.call_args.kwargs == {
            "q": "test",
            "part": "snippet",
            "type": "video",
            "maxResults": 5,
            "relevanceLanguage": "en",
            "order": "date",
            "publishedAfter": "2026-03-31T12:00:00Z",
            "publishedBefore": "2026-04-01T12:00:00Z",
        }

    @patch("src.adapters.youtube_adapter.utc_now")
    @patch("src.adapters.youtube_adapter.build")
    @patch("src.adapters.youtube_adapter.settings")
    def test_youtube_search_filters_results_outside_recent_window(
        self,
        mock_settings: MagicMock,
        mock_build: MagicMock,
        mock_utc_now: MagicMock,
    ) -> None:
        """YouTube should still hard-filter out videos outside the recent window."""
        fixed_now = datetime(2026, 4, 1, 12, 0, tzinfo=timezone.utc)
        mock_utc_now.return_value = fixed_now
        mock_settings.youtube_api_key = "test_key"
        mock_settings.collection_recency_hours = 24

        mock_youtube = MagicMock()
        mock_youtube.search().list().execute.return_value = {
            "items": [
                {
                    "id": {"videoId": "recent001"},
                    "snippet": {
                        "title": "Recent video",
                        "channelTitle": "CurrentChannel",
                        "publishedAt": "2026-04-01T08:00:00Z",
                    },
                },
                {
                    "id": {"videoId": "stale001"},
                    "snippet": {
                        "title": "Old video",
                        "channelTitle": "ArchiveChannel",
                        "publishedAt": "2026-03-30T11:59:59Z",
                    },
                },
            ]
        }
        mock_youtube.videos().list().execute.return_value = {
            "items": [
                {"id": "recent001", "statistics": {"viewCount": "100"}},
                {"id": "stale001", "statistics": {"viewCount": "200"}},
            ]
        }
        mock_build.return_value = mock_youtube

        adapter = YouTubeAdapter()
        videos = adapter._search_videos("test", "en", 5)

        assert [video["video_id"] for video in videos] == ["recent001"]

    @patch("src.adapters.youtube_adapter.settings")
    async def test_youtube_raises_when_api_key_missing(
        self, mock_settings: MagicMock
    ) -> None:
        """Missing YouTube API key must raise instead of silently returning []."""
        mock_settings.youtube_api_key = ""

        adapter = YouTubeAdapter()
        with pytest.raises(RuntimeError, match="YouTube API key"):
            await adapter.collect("test", "en", 10)

    @patch("src.adapters.youtube_adapter.build")
    @patch("src.adapters.youtube_adapter.settings")
    async def test_youtube_raises_on_top_level_collection_failure(
        self, mock_settings: MagicMock, mock_build: MagicMock
    ) -> None:
        """Top-level YouTube search failures must bubble up to CollectorService."""
        mock_settings.youtube_api_key = "test_key"
        mock_build.side_effect = RuntimeError("quota exceeded")

        adapter = YouTubeAdapter()
        with pytest.raises(RuntimeError, match="quota exceeded"):
            await adapter.collect("test", "en", 10)


class TestXAdapter:
    """Tests for XAdapter.collect()."""

    @patch("src.adapters.x_adapter.settings")
    @patch("src.adapters.x_adapter.AsyncOpenAI")
    async def test_x_collect_uses_settings_base_url_for_client(
        self, mock_openai_cls: MagicMock, mock_settings: MagicMock
    ) -> None:
        """`collect()` must construct the client with `settings.grok_base_url`."""
        mock_settings.grok_provider_mode = "openai_compatible"
        mock_settings.grok_api_key = "test_key"
        mock_settings.grok_base_url = "https://configured.example/v1"
        mock_settings.grok_model = "test-model"
        mock_settings.grok_http_timeout_seconds = 45.0

        mock_openai_cls.return_value = AsyncMock()
        adapter = XAdapter()

        with patch.object(adapter, "_query_shard", AsyncMock(return_value=[])):
            posts = await adapter.collect("test", "en", 3)

        assert posts == []
        kwargs = mock_openai_cls.call_args.kwargs
        assert kwargs["api_key"] == mock_settings.grok_api_key
        assert kwargs["base_url"] == mock_settings.grok_base_url
        assert kwargs["timeout"] == mock_settings.grok_http_timeout_seconds

    @patch("src.adapters.x_adapter.settings")
    @patch("src.adapters.x_adapter.AsyncOpenAI")
    def test_x_build_grok_client_uses_compatible_endpoint(
        self, mock_openai_cls: MagicMock, mock_settings: MagicMock
    ) -> None:
        """Compatible mode should build the client from the configured endpoint."""
        mock_settings.grok_provider_mode = "openai_compatible"
        mock_settings.grok_api_key = "test_key"
        mock_settings.grok_base_url = "https://compatible.example/v1"
        mock_settings.grok_http_timeout_seconds = 45.0

        adapter = XAdapter()
        client = adapter._build_grok_client()

        assert client is mock_openai_cls.return_value
        kwargs = mock_openai_cls.call_args.kwargs
        assert kwargs["api_key"] == mock_settings.grok_api_key
        assert kwargs["base_url"] == mock_settings.grok_base_url
        assert kwargs["timeout"] == mock_settings.grok_http_timeout_seconds

    @patch("src.adapters.x_adapter.settings")
    def test_x_resolve_grok_model_returns_configured_model(
        self, mock_settings: MagicMock
    ) -> None:
        """Model resolution should centralize the configured Grok model."""
        mock_settings.grok_provider_mode = "openai_compatible"
        mock_settings.grok_model = "grok-compat"

        adapter = XAdapter()

        assert adapter._resolve_grok_model() == "grok-compat"

    @patch("src.adapters.x_adapter.settings")
    async def test_x_query_shard_uses_settings_model(
        self, mock_settings: MagicMock
    ) -> None:
        """`_query_shard()` must send `settings.grok_model` to Grok completions."""
        mock_settings.grok_provider_mode = "openai_compatible"
        mock_settings.grok_model = "configured-model"

        mock_response = MagicMock()
        mock_response.choices = [MagicMock(message=MagicMock(content="[]"))]

        mock_client = AsyncMock()
        mock_client.chat.completions.create = AsyncMock(return_value=mock_response)

        adapter = XAdapter()
        posts = await adapter._query_shard(
            mock_client,
            keyword="test",
            language="en",
            dimension_name="The Pulse",
            dimension_focus="Latest original posts",
            shard_limit=1,
        )

        assert posts == []
        mock_client.chat.completions.create.assert_awaited_once()
        kwargs = mock_client.chat.completions.create.await_args.kwargs
        assert kwargs["model"] == mock_settings.grok_model
        assert kwargs.get("stream") is False

    @patch("src.adapters.x_adapter.settings")
    async def test_x_query_shard_includes_target_language_requirement_in_messages(
        self, mock_settings: MagicMock
    ) -> None:
        """Grok prompts should explicitly require the requested content language."""
        mock_settings.grok_provider_mode = "openai_compatible"
        mock_settings.grok_model = "configured-model"
        mock_settings.collection_recency_hours = 24

        mock_response = MagicMock()
        mock_response.choices = [MagicMock(message=MagicMock(content="[]"))]

        mock_client = AsyncMock()
        mock_client.chat.completions.create = AsyncMock(return_value=mock_response)

        adapter = XAdapter()
        await adapter._query_shard(
            mock_client,
            keyword="人工智能",
            language="zh",
            dimension_name="The Pulse",
            dimension_focus="Latest original posts",
            shard_limit=1,
        )

        kwargs = mock_client.chat.completions.create.await_args.kwargs
        joined_messages = "\n".join(
            str(message["content"]) for message in kwargs["messages"]
        )
        assert "Simplified Chinese" in joined_messages
        assert (
            "Tweets must be primarily written in Simplified Chinese."
            in joined_messages
        )

    @patch("src.adapters.x_adapter.utc_now")
    @patch("src.adapters.x_adapter.settings")
    async def test_x_query_shard_includes_recent_window_boundaries_in_messages(
        self,
        mock_settings: MagicMock,
        mock_utc_now: MagicMock,
    ) -> None:
        """Grok prompts should include 24h window boundaries and current UTC time."""
        fixed_now = datetime(2026, 4, 1, 12, 0, tzinfo=timezone.utc)
        mock_utc_now.return_value = fixed_now
        mock_settings.grok_provider_mode = "openai_compatible"
        mock_settings.grok_model = "configured-model"
        mock_settings.collection_recency_hours = 24

        mock_response = MagicMock()
        mock_response.choices = [MagicMock(message=MagicMock(content="[]"))]

        mock_client = AsyncMock()
        mock_client.chat.completions.create = AsyncMock(return_value=mock_response)

        adapter = XAdapter()
        await adapter._query_shard(
            mock_client,
            keyword="AI",
            language="en",
            dimension_name="The Pulse",
            dimension_focus="Latest original posts",
            shard_limit=1,
        )

        kwargs = mock_client.chat.completions.create.await_args.kwargs
        joined_messages = "\n".join(
            str(message["content"]) for message in kwargs["messages"]
        )
        assert "Current UTC time: 2026-04-01T12:00:00Z" in joined_messages
        assert (
            "Allowed post window: 2026-03-31T12:00:00Z to 2026-04-01T12:00:00Z"
            in joined_messages
        )
        snippet = "Only return tweets whose created_at falls within this window."
        assert snippet in joined_messages

    @patch("src.adapters.x_adapter.utc_now")
    @patch("src.adapters.x_adapter.settings")
    async def test_x_query_shard_filters_obvious_language_mismatches_from_results(
        self,
        mock_settings: MagicMock,
        mock_utc_now: MagicMock,
    ) -> None:
        """Result parsing should drop obviously wrong-language tweets."""
        mock_utc_now.return_value = datetime(2026, 4, 1, 12, 0, tzinfo=timezone.utc)
        mock_settings.grok_provider_mode = "openai_compatible"
        mock_settings.grok_model = "configured-model"
        mock_settings.collection_recency_hours = 24

        tweets = [
            {
                "id": "t1",
                "username": "user1",
                "content": "Detailed product feedback from English users",
                "perspective": "Bullish",
                "created_at": "2026-04-01T10:00:00Z",
                "engagement": 100,
                "url": "https://x.com/user1/status/t1",
            },
            {
                "id": "t2",
                "username": "user2",
                "content": "这个产品在中文社区讨论很多",
                "perspective": "Neutral",
                "created_at": "2026-04-01T09:00:00Z",
                "engagement": 20,
                "url": "https://x.com/user2/status/t2",
            },
        ]

        mock_response = MagicMock()
        mock_response.choices = [
            MagicMock(message=MagicMock(content=json.dumps(tweets))),
        ]

        mock_client = AsyncMock()
        mock_client.chat.completions.create = AsyncMock(return_value=mock_response)

        adapter = XAdapter()
        posts = await adapter._query_shard(
            mock_client,
            keyword="product feedback",
            language="en",
            dimension_name="The Pulse",
            dimension_focus="Latest original posts",
            shard_limit=2,
        )

        assert [post.source_id for post in posts] == ["t1"]

    @patch("src.adapters.x_adapter.utc_now")
    @patch("src.adapters.x_adapter.settings")
    async def test_x_shard_drops_stale_or_missing_created_at(
        self,
        mock_settings: MagicMock,
        mock_utc_now: MagicMock,
    ) -> None:
        """X should hard-filter when created_at is stale, missing, or invalid."""
        fixed_now = datetime(2026, 4, 1, 12, 0, tzinfo=timezone.utc)
        mock_utc_now.return_value = fixed_now
        mock_settings.grok_provider_mode = "openai_compatible"
        mock_settings.grok_model = "configured-model"
        mock_settings.collection_recency_hours = 24

        tweets = [
            {
                "id": "recent",
                "username": "user1",
                "content": "Fresh commentary from today",
                "perspective": "Neutral",
                "created_at": "2026-04-01T09:30:00Z",
                "engagement": 100,
                "url": "https://x.com/user1/status/recent",
            },
            {
                "id": "stale",
                "username": "user2",
                "content": "This one is too old",
                "perspective": "Neutral",
                "created_at": "2026-03-30T09:29:59Z",
                "engagement": 50,
                "url": "https://x.com/user2/status/stale",
            },
            {
                "id": "missing",
                "username": "user3",
                "content": "Missing time metadata",
                "perspective": "Neutral",
                "created_at": "",
                "engagement": 10,
                "url": "https://x.com/user3/status/missing",
            },
            {
                "id": "invalid",
                "username": "user4",
                "content": "Invalid time metadata",
                "perspective": "Neutral",
                "created_at": "not-a-timestamp",
                "engagement": 5,
                "url": "https://x.com/user4/status/invalid",
            },
            {
                "id": "ambiguous",
                "username": "user5",
                "content": "Ambiguous timestamp metadata",
                "perspective": "Neutral",
                "created_at": "2026-04-01T08:45:00",
                "engagement": 15,
                "url": "https://x.com/user5/status/ambiguous",
            },
        ]

        mock_response = MagicMock()
        mock_response.choices = [
            MagicMock(message=MagicMock(content=json.dumps(tweets))),
        ]

        mock_client = AsyncMock()
        mock_client.chat.completions.create = AsyncMock(return_value=mock_response)

        adapter = XAdapter()
        posts = await adapter._query_shard(
            mock_client,
            keyword="test",
            language="en",
            dimension_name="The Pulse",
            dimension_focus="Latest original posts",
            shard_limit=4,
        )

        assert [post.source_id for post in posts] == ["recent"]

    @patch("src.adapters.x_adapter.settings")
    async def test_x_query_shard_rejects_empty_choices_json_string(
        self, mock_settings: MagicMock
    ) -> None:
        """Empty `choices` in a JSON string body must not be treated as success."""
        mock_settings.grok_provider_mode = "openai_compatible"
        mock_settings.grok_model = "configured-model"

        mock_client = AsyncMock()
        mock_client.chat.completions.create = AsyncMock(return_value='{"choices":[]}')

        adapter = XAdapter()
        with pytest.raises(SourceCollectionError) as exc_info:
            await adapter._query_shard(
                mock_client,
                keyword="test",
                language="en",
                dimension_name="The Pulse",
                dimension_focus="Latest original posts",
                shard_limit=1,
            )

        assert exc_info.value.reason_code == "grok_provider_incompatible"

    @patch("src.adapters.x_adapter.settings")
    async def test_x_query_shard_accepts_json_string_completion(
        self, mock_settings: MagicMock
    ) -> None:
        """If the client returns a JSON string, parse it like a raw OpenAI body."""
        mock_settings.grok_provider_mode = "openai_compatible"
        mock_settings.grok_model = "configured-model"

        payload = json.dumps({"choices": [{"message": {"content": "[]"}}]})
        mock_client = AsyncMock()
        mock_client.chat.completions.create = AsyncMock(return_value=payload)

        adapter = XAdapter()
        posts = await adapter._query_shard(
            mock_client,
            keyword="test",
            language="en",
            dimension_name="The Pulse",
            dimension_focus="Latest original posts",
            shard_limit=1,
        )

        assert posts == []

    @patch("src.adapters.x_adapter.settings")
    async def test_x_query_shard_accepts_openai_shaped_dict_response(
        self, mock_settings: MagicMock
    ) -> None:
        """New API / relays may deserialize to plain dict; shape must still work."""
        mock_settings.grok_provider_mode = "openai_compatible"
        mock_settings.grok_model = "configured-model"

        mock_client = AsyncMock()
        mock_client.chat.completions.create = AsyncMock(
            return_value={"choices": [{"message": {"content": "[]"}}]}
        )

        adapter = XAdapter()
        posts = await adapter._query_shard(
            mock_client,
            keyword="test",
            language="en",
            dimension_name="The Pulse",
            dimension_focus="Latest original posts",
            shard_limit=1,
        )

        assert posts == []

    @patch("src.adapters.x_adapter.settings")
    async def test_x_query_shard_accepts_wrapped_data_envelope(
        self, mock_settings: MagicMock
    ) -> None:
        """Some gateways wrap the OpenAI body under `data` or `result`."""
        mock_settings.grok_provider_mode = "openai_compatible"
        mock_settings.grok_model = "configured-model"

        body = {"choices": [{"message": {"content": "[]"}}]}
        mock_client = AsyncMock()
        mock_client.chat.completions.create = AsyncMock(
            return_value={"data": body}
        )

        adapter = XAdapter()
        posts = await adapter._query_shard(
            mock_client,
            keyword="test",
            language="en",
            dimension_name="The Pulse",
            dimension_focus="Latest original posts",
            shard_limit=1,
        )

        assert posts == []

    @patch("src.adapters.x_adapter.settings")
    async def test_x_query_shard_surfaces_provider_error_field(
        self, mock_settings: MagicMock
    ) -> None:
        """HTTP 200 with an `error` object should become a typed provider error."""
        mock_settings.grok_provider_mode = "openai_compatible"
        mock_settings.grok_model = "configured-model"

        mock_client = AsyncMock()
        mock_client.chat.completions.create = AsyncMock(
            return_value={
                "error": {
                    "message": "Argument not supported: stream_options",
                    "type": "invalid",
                }
            }
        )

        adapter = XAdapter()
        with pytest.raises(SourceCollectionError) as exc_info:
            await adapter._query_shard(
                mock_client,
                keyword="test",
                language="en",
                dimension_name="The Pulse",
                dimension_focus="Latest original posts",
                shard_limit=1,
            )

        assert exc_info.value.reason_code == "grok_provider_error"
        assert "stream_options" in exc_info.value.message

    @patch("src.adapters.x_adapter.utc_now")
    @patch("src.adapters.x_adapter.settings")
    @patch("src.adapters.x_adapter.AsyncOpenAI")
    async def test_x_adapter_returns_raw_posts(
        self,
        mock_openai_cls: MagicMock,
        mock_settings: MagicMock,
        mock_utc_now: MagicMock,
    ) -> None:
        """Mock AsyncOpenAI to return fake JSON, verify deduplicated posts."""
        mock_utc_now.return_value = datetime(2026, 4, 1, 12, 0, tzinfo=timezone.utc)
        mock_settings.grok_provider_mode = "openai_compatible"
        mock_settings.grok_api_key = "test_key"
        mock_settings.grok_base_url = "https://test.api/v1"
        mock_settings.grok_model = "test-model"
        mock_settings.grok_http_timeout_seconds = 45.0
        mock_settings.collection_recency_hours = 24

        tweets = [
            {
                "id": "t1",
                "username": "user1",
                "content": "Great product launch",
                "perspective": "Bullish",
                "created_at": "2026-04-01T10:30:00Z",
                "engagement": 100,
                "url": "https://x.com/user1/status/t1",
            },
            {
                "id": "t2",
                "username": "user2",
                "content": "Not impressed at all",
                "perspective": "Skeptical",
                "created_at": "2026-04-01T09:45:00Z",
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
    @patch("src.adapters.x_adapter.AsyncOpenAI")
    async def test_x_collect_uses_single_batch_when_limit_is_at_most_twenty(
        self, mock_openai_cls: MagicMock, mock_settings: MagicMock
    ) -> None:
        """Small X requests should stay in a single Grok batch."""
        mock_settings.grok_provider_mode = "openai_compatible"
        mock_settings.grok_api_key = "test_key"
        mock_settings.grok_base_url = "https://test.api/v1"
        mock_settings.grok_model = "test-model"
        mock_settings.grok_http_timeout_seconds = 45.0
        mock_settings.x_batch_size = 20

        mock_client = AsyncMock()
        mock_openai_cls.return_value = mock_client

        adapter = XAdapter()
        query_shard = AsyncMock(return_value=[])
        with patch.object(adapter, "_query_shard", query_shard):
            await adapter.collect("test", "en", 10)

        shard_limits = [call.args[-1] for call in query_shard.await_args_list]
        assert shard_limits == [10]

    @patch("src.adapters.x_adapter.settings")
    @patch("src.adapters.x_adapter.AsyncOpenAI")
    async def test_x_collect_splits_large_requests_into_twenty_item_batches(
        self, mock_openai_cls: MagicMock, mock_settings: MagicMock
    ) -> None:
        """Large X requests should be chunked into twenty-item Grok batches."""
        mock_settings.grok_provider_mode = "openai_compatible"
        mock_settings.grok_api_key = "test_key"
        mock_settings.grok_base_url = "https://test.api/v1"
        mock_settings.grok_model = "test-model"
        mock_settings.grok_http_timeout_seconds = 45.0
        mock_settings.x_batch_size = 20

        mock_client = AsyncMock()
        mock_openai_cls.return_value = mock_client

        adapter = XAdapter()
        query_shard = AsyncMock(return_value=[])
        with patch.object(adapter, "_query_shard", query_shard):
            await adapter.collect("test", "en", 100)

        shard_limits = [call.args[-1] for call in query_shard.await_args_list]
        assert shard_limits == [20, 20, 20, 20, 20]

    @patch("src.adapters.x_adapter.settings")
    async def test_x_query_shard_with_retry_retries_rate_limited_failures(
        self, mock_settings: MagicMock
    ) -> None:
        """Retryable gateway failures should be retried before surfacing."""
        mock_settings.x_retry_max_attempts = 2
        mock_settings.x_retry_base_delay_seconds = 0.0

        adapter = XAdapter()
        query_shard = AsyncMock(
            side_effect=[
                SourceCollectionError("grok_rate_limited", "No available tokens."),
                [],
            ]
        )

        with patch.object(adapter, "_query_shard", query_shard):
            posts = await adapter._query_shard_with_retry(
                AsyncMock(),
                keyword="test",
                language="en",
                dimension_name="Balanced Mix",
                dimension_focus="Return a balanced mix of X posts.",
                shard_limit=10,
            )

        assert posts == []
        assert query_shard.await_count == 2

    @patch("src.adapters.x_adapter.settings")
    @patch("src.adapters.x_adapter.AsyncOpenAI")
    async def test_x_collect_closes_client(
        self, mock_openai_cls: MagicMock, mock_settings: MagicMock
    ) -> None:
        """The Grok client should always be closed after collection."""
        mock_settings.grok_provider_mode = "openai_compatible"
        mock_settings.grok_api_key = "test_key"
        mock_settings.grok_base_url = "https://test.api/v1"
        mock_settings.grok_model = "test-model"
        mock_settings.grok_http_timeout_seconds = 45.0

        mock_client = AsyncMock()
        mock_openai_cls.return_value = mock_client

        adapter = XAdapter()
        with patch.object(adapter, "_query_shard", AsyncMock(return_value=[])):
            await adapter.collect("test", "en", 3)

        mock_client.close.assert_awaited_once()

    @patch("src.adapters.x_adapter.settings")
    @patch("src.adapters.x_adapter.AsyncOpenAI")
    async def test_x_collect_raises_partial_error_when_a_batch_fails(
        self, mock_openai_cls: MagicMock, mock_settings: MagicMock
    ) -> None:
        """Partial batch failures should be surfaced, not silently ignored."""
        mock_settings.grok_provider_mode = "openai_compatible"
        mock_settings.grok_api_key = "test_key"
        mock_settings.grok_base_url = "https://test.api/v1"
        mock_settings.grok_model = "test-model"
        mock_settings.grok_http_timeout_seconds = 45.0
        mock_settings.x_batch_size = 20

        mock_client = AsyncMock()
        mock_openai_cls.return_value = mock_client

        adapter = XAdapter()
        with patch.object(
            adapter,
            "_query_shard",
            AsyncMock(
                side_effect=[
                    [
                        adapter._parse_response(
                            json.dumps(
                                [
                                    {
                                        "id": "t1",
                                        "username": "user1",
                                        "content": "Great product launch",
                                        "perspective": "Bullish",
                                        "created_at": "2024-01-01T00:00:00Z",
                                        "engagement": 100,
                                        "url": "https://x.com/user1/status/t1",
                                    }
                                ]
                            ),
                            "Balanced Mix",
                        )[0]
                    ],
                    RuntimeError("batch down"),
                ]
            ),
        ), pytest.raises(PartialSourceCollectionError) as exc_info:
            await adapter.collect("test", "en", 35)

        assert len(exc_info.value.partial_posts) == 1
        assert exc_info.value.reason_code == "grok_collection_failed"

    @patch("src.adapters.x_adapter.settings")
    async def test_x_raises_when_api_key_missing(
        self, mock_settings: MagicMock
    ) -> None:
        """Missing Grok API key must raise instead of silently returning []."""
        mock_settings.grok_provider_mode = "official_xai"
        mock_settings.grok_api_key = ""

        adapter = XAdapter()
        with pytest.raises(RuntimeError, match="Grok API key"):
            await adapter.collect("test", "en", 10)

    @patch("src.adapters.x_adapter.settings")
    @patch("src.adapters.x_adapter.AsyncOpenAI")
    async def test_x_raises_when_all_shards_fail(
        self, mock_openai_cls: MagicMock, mock_settings: MagicMock
    ) -> None:
        """Whole-source X failures must not silently collapse into an empty list."""
        mock_settings.grok_provider_mode = "openai_compatible"
        mock_settings.grok_api_key = "test_key"
        mock_settings.grok_base_url = "https://test.api/v1"
        mock_settings.grok_model = "test-model"
        mock_settings.grok_http_timeout_seconds = 45.0

        mock_client = AsyncMock()
        mock_client.chat.completions.create = AsyncMock(
            side_effect=RuntimeError("upstream down")
        )
        mock_openai_cls.return_value = mock_client

        adapter = XAdapter()
        with pytest.raises(RuntimeError, match="upstream down"):
            await adapter.collect("test", "en", 10)

    async def test_x_adapter_handles_think_tags(self) -> None:
        """Verify <think> tag stripping works in _parse_response."""
        adapter = XAdapter()
        raw_text = (
            "<think>Let me analyze this...</think>"
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

    def __init__(self, items: list[object]) -> None:
        self._items = iter(items)

    def __aiter__(self) -> _AsyncIterator:
        return self

    async def __anext__(self) -> object:
        try:
            return next(self._items)
        except StopIteration as exc:
            raise StopAsyncIteration from exc


def _async_iter(items: list[object]) -> _AsyncIterator:
    return _AsyncIterator(items)
