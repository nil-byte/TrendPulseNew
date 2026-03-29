"""Tests for AnalyzerService."""

from __future__ import annotations

import json
from unittest.mock import AsyncMock

from src.models.schemas import KeyInsight, RawPost
from src.services.analyzer_service import (
    AnalysisResult,
    AnalyzerService,
    build_mermaid_mindmap,
)


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
        result = await service.analyze([], "test", language="en")

        assert isinstance(result, AnalysisResult)
        assert result.sentiment_score == 0.0
        assert result.summary == "No posts available for analysis after cleaning."

    async def test_analyze_with_mocked_llm(self) -> None:
        """Mock LLMAdapter, verify full pipeline returns AnalysisResult."""
        map_response = json.dumps(
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
        reduce_response = json.dumps(
            {
                "summary": "Users generally like the product, but performance concerns remain.",
                "key_insights": [
                    {
                        "text": "Great user experience",
                        "sentiment": "positive",
                        "source_count": 3,
                    },
                    {
                        "text": "Needs improvement",
                        "sentiment": "negative",
                        "source_count": 1,
                    },
                ],
            }
        )

        mock_llm = AsyncMock()
        mock_llm.chat_completion = AsyncMock(
            side_effect=[map_response, reduce_response]
        )

        service = AnalyzerService(llm_adapter=mock_llm)
        posts = [
            _make_post("I really love this product, great experience!", engagement=50),
            _make_post("The interface is clean and intuitive to use", engagement=30),
            _make_post("It works okay but nothing special really", engagement=10),
            _make_post("Terrible performance, needs major improvement", engagement=20),
            _make_post("Best tool I have used in a long time overall", engagement=40),
        ]

        result = await service.analyze(posts, "test product", language="en")

        assert isinstance(result, AnalysisResult)
        assert 0 <= result.sentiment_score <= 100
        assert 0 <= result.positive_ratio <= 1
        assert 0 <= result.negative_ratio <= 1
        assert 0 <= result.neutral_ratio <= 1
        assert (
            result.summary
            == "Users generally like the product, but performance concerns remain."
        )
        assert result.key_insights is not None
        assert len(result.key_insights) == 2
        assert result.key_insights[0].text == "Great user experience"
        assert result.key_insights[0].source_count == 3
        assert mock_llm.chat_completion.await_count == 2

    async def test_analyze_generates_mermaid_mindmap_in_raw_analysis(self) -> None:
        """Successful analysis should attach a Mermaid mindmap payload."""
        map_response = json.dumps(
            {
                "overall_score": 24.0,
                "sentiments": {"positive": 0, "negative": 3, "neutral": 1},
                "key_opinions": [
                    {
                        "text": "Support quality dropped",
                        "sentiment": "negative",
                        "frequency": 3,
                    },
                    {
                        "text": "Updates feel rushed",
                        "sentiment": "negative",
                        "frequency": 2,
                    },
                ],
                "post_sentiments": [],
            }
        )
        reduce_response = json.dumps(
            {
                "summary": "Support sentiment is deteriorating and users distrust recent updates.",
                "key_insights": [
                    {
                        "text": "Support quality dropped",
                        "sentiment": "negative",
                        "source_count": 3,
                    },
                    {
                        "text": "Updates feel rushed",
                        "sentiment": "negative",
                        "source_count": 2,
                    },
                ],
            }
        )
        mock_llm = AsyncMock()
        mock_llm.chat_completion = AsyncMock(
            side_effect=[map_response, reduce_response]
        )
        service = AnalyzerService(llm_adapter=mock_llm)

        result = await service.analyze(
            [
                _make_post("Support quality dropped sharply this week."),
                _make_post("Recent updates feel rushed and under-tested."),
                _make_post("Trust has fallen after the last release."),
                _make_post("Neutral observers are still waiting for fixes."),
            ],
            "openai",
            language="en",
        )

        assert result.raw_analysis is not None
        mermaid_mindmap = result.raw_analysis.get("mermaid_mindmap")
        assert isinstance(mermaid_mindmap, str)
        assert mermaid_mindmap.startswith("mindmap\n")
        assert "root((openai))" in mermaid_mindmap
        assert "Support quality dropped" in mermaid_mindmap
        assert "Updates feel rushed" in mermaid_mindmap

    async def test_analyze_zh_prompts_include_simplified_chinese_requirements(
        self,
    ) -> None:
        """Map and reduce prompts must explicitly request Simplified Chinese."""
        map_response = json.dumps(
            {
                "overall_score": 65.0,
                "sentiments": {"positive": 1, "negative": 0, "neutral": 1},
                "key_opinions": [
                    {
                        "text": "界面更顺手",
                        "sentiment": "positive",
                        "frequency": 1,
                    }
                ],
                "post_sentiments": [
                    {"index": 1, "sentiment": "positive"},
                    {"index": 2, "sentiment": "neutral"},
                ],
            }
        )
        reduce_response = json.dumps(
            {
                "summary": "整体讨论偏正面，但仍有一些保留意见。",
                "key_insights": [
                    {
                        "text": "支持者认为界面更顺手",
                        "sentiment": "positive",
                        "source_count": 1,
                    }
                ],
            }
        )
        mock_llm = AsyncMock()
        mock_llm.chat_completion = AsyncMock(
            side_effect=[map_response, reduce_response]
        )
        service = AnalyzerService(llm_adapter=mock_llm)

        await service.analyze(
            [
                _make_post("这个产品的界面更顺手了，体验明显更好了"),
                _make_post("功能不少，但还需要继续观察稳定性表现"),
            ],
            "趋势脉搏",
            language="zh",
        )

        map_call = mock_llm.chat_completion.await_args_list[0].kwargs
        reduce_call = mock_llm.chat_completion.await_args_list[1].kwargs

        assert "简体中文" in map_call["system_prompt"]
        assert "简体中文" in reduce_call["system_prompt"]

    async def test_analyze_reduce_prompt_uses_condensed_chunk_payload(
        self,
    ) -> None:
        """Reduce stage must receive condensed chunk analysis, not raw posts."""
        raw_post_text = (
            "RAW POST CONTENT SHOULD NOT REACH REDUCE PROMPT even when it is very long."
        )
        map_response = json.dumps(
            {
                "overall_score": 41.0,
                "sentiments": {"positive": 0, "negative": 1, "neutral": 0},
                "key_opinions": [
                    {
                        "text": "Pricing feels too high",
                        "sentiment": "negative",
                        "frequency": 1,
                    }
                ],
                "post_sentiments": [{"index": 1, "sentiment": "negative"}],
            }
        )
        reduce_response = json.dumps(
            {
                "summary": "Pricing concerns dominate the discussion.",
                "key_insights": [
                    {
                        "text": "Pricing feels too high",
                        "sentiment": "negative",
                        "source_count": 1,
                    }
                ],
            }
        )
        mock_llm = AsyncMock()
        mock_llm.chat_completion = AsyncMock(
            side_effect=[map_response, reduce_response]
        )
        service = AnalyzerService(llm_adapter=mock_llm)

        await service.analyze([_make_post(raw_post_text)], "pricing", language="en")

        reduce_call = mock_llm.chat_completion.await_args_list[1].kwargs
        assert "Pricing feels too high" in reduce_call["user_prompt"]
        assert raw_post_text not in reduce_call["user_prompt"]

    async def test_analyze_prefers_reduce_summary_and_key_insights_when_valid(
        self,
    ) -> None:
        """Valid reduce JSON must override heuristic summary and insights."""
        map_response = json.dumps(
            {
                "overall_score": 58.0,
                "sentiments": {"positive": 2, "negative": 1, "neutral": 0},
                "key_opinions": [
                    {
                        "text": "Setup is easier now",
                        "sentiment": "positive",
                        "frequency": 2,
                    },
                    {
                        "text": "Export still feels slow",
                        "sentiment": "negative",
                        "frequency": 1,
                    },
                ],
                "post_sentiments": [
                    {"index": 1, "sentiment": "positive"},
                    {"index": 2, "sentiment": "positive"},
                    {"index": 3, "sentiment": "negative"},
                ],
            }
        )
        reduce_response = json.dumps(
            {
                "summary": "The launch is landing well overall, but export latency is the main complaint.",
                "key_insights": [
                    {
                        "text": "Faster setup is the clearest win",
                        "sentiment": "positive",
                        "source_count": 2,
                    },
                    {
                        "text": "Export latency is still frustrating",
                        "sentiment": "negative",
                        "source_count": 1,
                    },
                ],
            }
        )
        mock_llm = AsyncMock()
        mock_llm.chat_completion = AsyncMock(
            side_effect=[map_response, reduce_response]
        )
        service = AnalyzerService(llm_adapter=mock_llm)

        result = await service.analyze(
            [
                _make_post("Setup is much easier than before."),
                _make_post("The onboarding is finally straightforward."),
                _make_post("Export still feels slow on my side."),
            ],
            "launch",
            language="en",
        )

        assert (
            result.summary
            == "The launch is landing well overall, but export latency is the main complaint."
        )
        assert [insight.text for insight in result.key_insights] == [
            "Faster setup is the clearest win",
            "Export latency is still frustrating",
        ]

    async def test_analyze_falls_back_to_local_summary_when_reduce_json_is_invalid(
        self,
    ) -> None:
        """Invalid reduce JSON must keep the pipeline successful via heuristics."""
        map_response = json.dumps(
            {
                "overall_score": 35.0,
                "sentiments": {"positive": 0, "negative": 2, "neutral": 1},
                "key_opinions": [
                    {
                        "text": "广告太多",
                        "sentiment": "negative",
                        "frequency": 2,
                    },
                    {
                        "text": "价格上涨太快",
                        "sentiment": "negative",
                        "frequency": 1,
                    },
                ],
                "post_sentiments": [
                    {"index": 1, "sentiment": "negative"},
                    {"index": 2, "sentiment": "negative"},
                    {"index": 3, "sentiment": "neutral"},
                ],
            }
        )
        mock_llm = AsyncMock()
        mock_llm.chat_completion = AsyncMock(
            side_effect=[map_response, "definitely not json"]
        )
        service = AnalyzerService(llm_adapter=mock_llm)

        result = await service.analyze(
            [
                _make_post("广告真的太多了，阅读体验很差。"),
                _make_post("价格上涨太快，让人不太能接受。"),
                _make_post("功能一般，没有特别惊喜。"),
            ],
            "订阅服务",
            language="zh",
        )

        assert "基于" in result.summary
        assert "广告太多" in [insight.text for insight in result.key_insights]
        assert result.has_analyzable_content() is True

    async def test_analyze_reduce_prompt_contains_multiple_chunk_analyses(
        self,
    ) -> None:
        """More than 20 posts must produce a multi-chunk condensed reduce payload."""
        first_chunk_response = json.dumps(
            {
                "overall_score": 32.0,
                "sentiments": {"positive": 4, "negative": 14, "neutral": 2},
                "key_opinions": [
                    {
                        "text": "Battery life drains too fast",
                        "sentiment": "negative",
                        "frequency": 9,
                    },
                    {
                        "text": "Charging is inconsistent",
                        "sentiment": "negative",
                        "frequency": 4,
                    },
                ],
                "post_sentiments": [],
            }
        )
        second_chunk_response = json.dumps(
            {
                "overall_score": 40.0,
                "sentiments": {"positive": 0, "negative": 1, "neutral": 0},
                "key_opinions": [
                    {
                        "text": "Battery life drains too fast",
                        "sentiment": "negative",
                        "frequency": 3,
                    }
                ],
                "post_sentiments": [],
            }
        )
        reduce_response = json.dumps(
            {
                "summary": "Battery life complaints dominate the discussion.",
                "key_insights": [
                    {
                        "text": "Battery life drains too fast",
                        "sentiment": "negative",
                        "source_count": 12,
                    }
                ],
            }
        )
        mock_llm = AsyncMock()
        mock_llm.chat_completion = AsyncMock(
            side_effect=[
                first_chunk_response,
                second_chunk_response,
                reduce_response,
            ]
        )
        service = AnalyzerService(llm_adapter=mock_llm)
        posts = [
            _make_post(f"Battery report {index} has enough detail for analysis.")
            for index in range(21)
        ]

        await service.analyze(posts, "battery", language="en")

        assert mock_llm.chat_completion.await_count == 3
        reduce_call = mock_llm.chat_completion.await_args_list[2].kwargs
        reduce_payload = json.loads(reduce_call["user_prompt"])

        assert len(reduce_payload["chunk_analyses"]) == 2
        assert {item["chunk_index"] for item in reduce_payload["chunk_analyses"]} == {
            1,
            2,
        }
        battery_candidate = next(
            item
            for item in reduce_payload["candidate_insights"]
            if item["text"] == "Battery life drains too fast"
        )
        assert battery_candidate["source_count"] == 12

    async def test_analyze_falls_back_when_reduce_call_raises_exception(
        self,
    ) -> None:
        """Reduce call exceptions must not break analyzer fallback semantics."""
        map_response = json.dumps(
            {
                "overall_score": 28.0,
                "sentiments": {"positive": 0, "negative": 2, "neutral": 1},
                "key_opinions": [
                    {
                        "text": "Support quality dropped",
                        "sentiment": "negative",
                        "frequency": 2,
                    },
                    {
                        "text": "Updates feel rushed",
                        "sentiment": "negative",
                        "frequency": 1,
                    },
                ],
                "post_sentiments": [],
            }
        )
        mock_llm = AsyncMock()
        mock_llm.chat_completion = AsyncMock(
            side_effect=[map_response, RuntimeError("reduce unavailable")]
        )
        service = AnalyzerService(llm_adapter=mock_llm)

        result = await service.analyze(
            [
                _make_post("Support quality dropped a lot this month."),
                _make_post("The latest updates feel rushed and under-tested."),
                _make_post("I am neutral overall but still cautious."),
            ],
            "product support",
            language="en",
        )

        assert result.summary.startswith("Based on 3 posts analyzed")
        assert [insight.text for insight in result.key_insights] == [
            "Support quality dropped",
            "Updates feel rushed",
        ]
        assert result.raw_analysis is not None
        assert result.raw_analysis["reduce_llm_succeeded"] is False
        assert result.has_analyzable_content() is True


class TestBuildMermaidMindmap:
    """Contract tests for Mermaid mindmap generation."""

    def test_build_mermaid_mindmap_uses_supported_subset_contract(self) -> None:
        """Mindmap output should stay within the supported subset contract."""
        mermaid = build_mermaid_mindmap(
            keyword="AI [Pulse]",
            summary="Market demand is stabilizing.",
            insights=[
                KeyInsight(
                    text="Demand is broadening",
                    sentiment="positive",
                    source_count=4,
                ),
                KeyInsight(
                    text="Pricing pressure remains",
                    sentiment="negative",
                    source_count=2,
                ),
                KeyInsight(
                    text="Buyers are waiting",
                    sentiment="neutral",
                    source_count=1,
                ),
                KeyInsight(
                    text="Fourth insight should be trimmed",
                    sentiment="positive",
                    source_count=9,
                ),
            ],
            language="en",
        )

        assert mermaid == (
            "mindmap\n"
            "  root((AI Pulse))\n"
            "    Summary\n"
            "      Market demand is stabilizing.\n"
            "    Viewpoints\n"
            "      Insight 1\n"
            "        Demand is broadening\n"
            "        Positive view\n"
            "        4 sources\n"
            "      Insight 2\n"
            "        Pricing pressure remains\n"
            "        Negative view\n"
            "        2 sources\n"
            "      Insight 3\n"
            "        Buyers are waiting\n"
            "        Neutral view\n"
            "        1 sources"
        )


class TestReduceResults:
    """Tests for AnalyzerService._reduce_results()."""

    def test_reduce_results_returns_empty_result_for_zero_classified_posts(
        self,
    ) -> None:
        """Zero classified samples must map back to empty-result semantics."""
        service = AnalyzerService()

        result = service._reduce_results(
            chunk_results=[
                {
                    "overall_score": 88.0,
                    "sentiments": {"positive": 0, "negative": 0, "neutral": 0},
                    "key_opinions": [
                        {
                            "text": "Looks positive",
                            "sentiment": "positive",
                            "frequency": 1,
                        }
                    ],
                }
            ],
            all_posts=[_make_post("This post is long enough for analysis")],
        )

        assert result.sentiment_score == 0.0
        assert result.summary == "No posts available for analysis after cleaning."
        assert result.raw_analysis is None
        assert result.has_analyzable_content() is False
