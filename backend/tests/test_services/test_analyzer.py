"""Tests for AnalyzerService."""

from __future__ import annotations

import json
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from src.models.schemas import RawPost
from src.services.analyzer_service import AnalyzerService, AnalysisResult


def _make_post(content: str, source: str = "reddit", engagement: int = 10) -> RawPost:
    """Create a RawPost for testing."""
    return RawPost(source=source, content=content, engagement=engagement)


class TestCleanPosts:
    """Tests for AnalyzerService._clean_posts()."""

    def test_clean_posts_filters_short_content(self) -> None:
        """Verify posts with <10 chars are filtered out."""
        service = AnalyzerService()
        posts = [
            _make_post("short"),
            _make_post("This is a long enough post for analysis"),
        ]

        result = service._clean_posts(posts)

        assert len(result) == 1
        assert "long enough" in result[0].content

    def test_clean_posts_filters_spam(self) -> None:
        """Verify spam detection removes spammy posts."""
        service = AnalyzerService()
        posts = [
            _make_post("Check http://a.com http://b.com http://c.com buy now"),
            _make_post("THIS IS ALL CAPS SPAM MESSAGE THAT IS VERY LOUD"),
            _make_post("aaaaaaaaaaaaa repeated chars here"),
            _make_post("This is a perfectly normal post about technology"),
        ]

        result = service._clean_posts(posts)

        assert len(result) == 1
        assert "perfectly normal" in result[0].content

    def test_clean_posts_removes_duplicates(self) -> None:
        """Verify exact duplicate content is removed."""
        service = AnalyzerService()
        posts = [
            _make_post("This is a duplicate post content here"),
            _make_post("This is a duplicate post content here"),
            _make_post("This is a unique post about something else"),
        ]

        result = service._clean_posts(posts)

        assert len(result) == 2
        contents = [p.content for p in result]
        assert len(set(contents)) == 2


class TestChunkPosts:
    """Tests for AnalyzerService._chunk_posts()."""

    def test_chunk_posts(self) -> None:
        """Verify posts are split into correct chunk sizes."""
        service = AnalyzerService()
        posts = [_make_post(f"Post number {i} with enough content") for i in range(25)]

        chunks = service._chunk_posts(posts, chunk_size=10)

        assert len(chunks) == 3
        assert len(chunks[0]) == 10
        assert len(chunks[1]) == 10
        assert len(chunks[2]) == 5


class TestAnalyze:
    """Tests for AnalyzerService.analyze() pipeline."""

    async def test_analyze_empty_posts(self) -> None:
        """Verify empty input returns empty result."""
        service = AnalyzerService()
        result = await service.analyze([], "test")

        assert isinstance(result, AnalysisResult)
        assert result.sentiment_score == 0.0
        assert result.summary == "No posts available for analysis after cleaning."

    async def test_analyze_with_mocked_llm(self) -> None:
        """Mock LLMAdapter, verify full pipeline returns AnalysisResult."""
        llm_response = json.dumps(
            {
                "overall_score": 72.5,
                "sentiments": {"positive": 3, "negative": 1, "neutral": 1},
                "key_opinions": [
                    {
                        "text": "Great user experience",
                        "sentiment": "positive",
                        "frequency": 3,
                    },
                    {
                        "text": "Needs improvement",
                        "sentiment": "negative",
                        "frequency": 1,
                    },
                ],
                "post_sentiments": [
                    {"index": 1, "sentiment": "positive"},
                    {"index": 2, "sentiment": "positive"},
                    {"index": 3, "sentiment": "neutral"},
                    {"index": 4, "sentiment": "negative"},
                    {"index": 5, "sentiment": "positive"},
                ],
            }
        )

        mock_llm = AsyncMock()
        mock_llm.chat_completion = AsyncMock(return_value=llm_response)

        service = AnalyzerService(llm_adapter=mock_llm)
        posts = [
            _make_post("I really love this product, great experience!", engagement=50),
            _make_post("The interface is clean and intuitive to use", engagement=30),
            _make_post("It works okay but nothing special really", engagement=10),
            _make_post("Terrible performance, needs major improvement", engagement=20),
            _make_post("Best tool I have used in a long time overall", engagement=40),
        ]

        result = await service.analyze(posts, "test product")

        assert isinstance(result, AnalysisResult)
        assert 0 <= result.sentiment_score <= 100
        assert 0 <= result.positive_ratio <= 1
        assert 0 <= result.negative_ratio <= 1
        assert 0 <= result.neutral_ratio <= 1
        assert result.summary != ""
        assert result.key_insights is not None
        mock_llm.chat_completion.assert_called_once()
