"""Tests for SearchQueryService."""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

from src.services.search_query_service import SearchQueryService


class TestSearchQueryService:
    """Contract tests for localized search query generation."""

    async def test_build_search_query_preserves_quoted_original_when_rewrite_is_skipped(
        self,
    ) -> None:
        """Fallback paths must not alter exact-phrase search semantics."""
        mock_llm = AsyncMock()
        mock_llm.chat_completion = AsyncMock(return_value="ignored")

        service = SearchQueryService(llm_adapter=mock_llm)
        result = await service.build_search_query('"exact phrase"', "en")

        assert result.query == '"exact phrase"'
        assert result.status == "unchanged"
        assert result.reason == "already_target_language"
        mock_llm.chat_completion.assert_not_awaited()

    async def test_build_search_query_returns_original_for_matching_english_keyword(
        self,
    ) -> None:
        """Obvious English keywords should skip LLM rewriting."""
        mock_llm = AsyncMock()
        mock_llm.chat_completion = AsyncMock(return_value="ignored")

        service = SearchQueryService(llm_adapter=mock_llm)
        result = await service.build_search_query("AI product launch", "en")

        assert result.query == "AI product launch"
        assert result.status == "unchanged"
        assert result.reason == "already_target_language"
        mock_llm.chat_completion.assert_not_awaited()

    async def test_build_search_query_returns_original_for_matching_chinese_keyword(
        self,
    ) -> None:
        """Obvious Chinese keywords should skip LLM rewriting."""
        mock_llm = AsyncMock()
        mock_llm.chat_completion = AsyncMock(return_value="ignored")

        service = SearchQueryService(llm_adapter=mock_llm)
        result = await service.build_search_query("人工智能趋势", "zh")

        assert result.query == "人工智能趋势"
        assert result.status == "unchanged"
        assert result.reason == "already_target_language"
        mock_llm.chat_completion.assert_not_awaited()

    @patch("src.services.search_query_service.settings")
    async def test_build_search_query_uses_llm_and_cleans_single_line_response(
        self,
        mock_settings: MagicMock,
    ) -> None:
        """Cross-language keywords should be rewritten and lightly normalized."""
        mock_settings.llm_api_key = "test-key"
        mock_settings.llm_model = "test-model"

        mock_llm = AsyncMock()
        mock_llm.chat_completion = AsyncMock(
            return_value=(
                '  "artificial intelligence"  \n'
                "extra context that should be ignored"
            )
        )

        service = SearchQueryService(llm_adapter=mock_llm)
        result = await service.build_search_query("人工智能", "en")

        assert result.query == "artificial intelligence"
        assert result.status == "localized"
        assert result.reason is None
        call = mock_llm.chat_completion.await_args.kwargs
        assert "English" in call["system_prompt"]
        assert "人工智能" in call["user_prompt"]

    @patch("src.services.search_query_service.settings")
    async def test_build_search_query_falls_back_when_llm_not_configured(
        self,
        mock_settings: MagicMock,
    ) -> None:
        """Missing LLM configuration should keep the original keyword."""
        mock_settings.llm_api_key = ""
        mock_settings.llm_model = ""

        mock_llm = AsyncMock()
        mock_llm.chat_completion = AsyncMock(return_value="ignored")

        service = SearchQueryService(llm_adapter=mock_llm)
        result = await service.build_search_query("人工智能", "en")

        assert result.query == "人工智能"
        assert result.status == "fallback"
        assert result.reason == "llm_not_configured"
        mock_llm.chat_completion.assert_not_awaited()

    @patch("src.services.search_query_service.settings")
    async def test_build_search_query_falls_back_when_llm_returns_empty_content(
        self,
        mock_settings: MagicMock,
    ) -> None:
        """Blank or quote-only LLM output should fall back to the raw keyword."""
        mock_settings.llm_api_key = "test-key"
        mock_settings.llm_model = "test-model"

        mock_llm = AsyncMock()
        mock_llm.chat_completion = AsyncMock(return_value=' "" ')

        service = SearchQueryService(llm_adapter=mock_llm)
        result = await service.build_search_query("人工智能", "en")

        assert result.query == "人工智能"
        assert result.status == "fallback"
        assert result.reason == "empty_localized_query"

    @patch("src.services.search_query_service.settings")
    async def test_build_search_query_falls_back_when_llm_call_fails(
        self,
        mock_settings: MagicMock,
    ) -> None:
        """LLM errors should not break collection-time query generation."""
        mock_settings.llm_api_key = "test-key"
        mock_settings.llm_model = "test-model"

        mock_llm = AsyncMock()
        mock_llm.chat_completion = AsyncMock(side_effect=RuntimeError("provider down"))

        service = SearchQueryService(llm_adapter=mock_llm)
        result = await service.build_search_query("人工智能", "en")

        assert result.query == "人工智能"
        assert result.status == "fallback"
        assert result.reason == "llm_call_failed"
