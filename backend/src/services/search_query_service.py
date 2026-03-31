"""Localized search query generation for source collection."""

from __future__ import annotations

import logging
import re
from dataclasses import dataclass

from src.adapters.llm_adapter import LLMAdapter
from src.config.settings import settings

logger = logging.getLogger(__name__)

_CJK_RE = re.compile(r"[\u3400-\u4DBF\u4E00-\u9FFF]")
_ASCII_ALPHA_RE = re.compile(r"[A-Za-z]")
_EDGE_QUOTES_RE = re.compile(r"^[\"'`“”‘’]+|[\"'`“”‘’]+$")

_SYSTEM_PROMPT = """\
You rewrite search keywords for social platform search.

Return exactly one concise search query in {target_language}.
Do not add explanations, lists, or surrounding quotes.
Keep product names, brands, and named entities intact when helpful.
"""

_USER_PROMPT = """\
Original keyword: {keyword}
Target content language: {target_language}

Rewrite the keyword into a natural search query for finding posts in the target \
language.
Return only the query.
"""


@dataclass(slots=True, frozen=True)
class SearchQueryResult:
    """Result of search query localization with lightweight observability data."""

    query: str
    status: str
    reason: str | None = None


class SearchQueryService:
    """Generate a localized search query for the requested content language."""

    def __init__(self, llm_adapter: LLMAdapter | None = None) -> None:
        self._llm = llm_adapter or LLMAdapter()

    async def build_search_query(
        self, keyword: str, language: str
    ) -> SearchQueryResult:
        """Return a localized search query or fall back to the original keyword."""
        original_keyword = keyword
        keyword_for_checks = keyword.strip()
        if not keyword_for_checks:
            return SearchQueryResult(
                query="",
                status="empty",
                reason="blank_keyword",
            )

        if self._is_obvious_target_language(keyword_for_checks, language):
            return SearchQueryResult(
                query=original_keyword,
                status="unchanged",
                reason="already_target_language",
            )

        if not self._llm_configured():
            logger.info(
                "Search query localization skipped because LLM is not configured"
            )
            return SearchQueryResult(
                query=original_keyword,
                status="fallback",
                reason="llm_not_configured",
            )

        try:
            localized = await self._llm.chat_completion(
                system_prompt=_SYSTEM_PROMPT.format(
                    target_language=self._target_language_name(language)
                ),
                user_prompt=_USER_PROMPT.format(
                    keyword=original_keyword,
                    target_language=self._target_language_name(language),
                ),
                temperature=0.1,
                max_tokens=64,
            )
        except Exception as exc:
            logger.warning("Search query localization failed: %s", exc)
            return SearchQueryResult(
                query=original_keyword,
                status="fallback",
                reason="llm_call_failed",
            )

        cleaned = self._normalize_query(localized)
        if not cleaned:
            return SearchQueryResult(
                query=original_keyword,
                status="fallback",
                reason="empty_localized_query",
            )

        return SearchQueryResult(
            query=cleaned,
            status="localized",
            reason=None,
        )

    @staticmethod
    def _target_language_name(language: str) -> str:
        """Return a human-readable target language label for prompts."""
        if language == "zh":
            return "Simplified Chinese"
        return "English"

    @staticmethod
    def _llm_configured() -> bool:
        """Return whether the shared LLM client has enough config to be usable."""
        return bool(settings.llm_api_key.strip() and settings.llm_model.strip())

    @classmethod
    def _is_obvious_target_language(cls, text: str, language: str) -> bool:
        """Use a simple script-level heuristic for the supported en/zh languages."""
        cjk_count = len(_CJK_RE.findall(text))
        ascii_count = len(_ASCII_ALPHA_RE.findall(text))

        if language == "zh":
            return cjk_count > 0 and cjk_count >= ascii_count
        if language == "en":
            return ascii_count > 0 and cjk_count == 0
        return True

    @staticmethod
    def _normalize_query(text: str) -> str:
        """Lightly clean an LLM output into a single-line query string."""
        lines = [line.strip() for line in text.strip().splitlines() if line.strip()]
        if not lines:
            return ""

        first_line = re.sub(r"\s+", " ", lines[0]).strip()
        cleaned = _EDGE_QUOTES_RE.sub("", first_line).strip()
        return re.sub(r"\s+", " ", cleaned)
