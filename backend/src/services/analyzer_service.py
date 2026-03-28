"""AI-powered sentiment analysis service."""

from __future__ import annotations

import json
import logging
import re
from typing import Any

from pydantic import BaseModel, Field

from src.adapters.llm_adapter import LLMAdapter
from src.models.schemas import KeyInsight, RawPost

logger = logging.getLogger(__name__)

_MIN_CONTENT_LEN = 10
_MAX_CONTENT_LEN = 500
_URL_PATTERN = re.compile(r"https?://\S+")
_REPEATED_CHAR_PATTERN = re.compile(r"(.)\1{9,}")


# ---------------------------------------------------------------------------
# Result model
# ---------------------------------------------------------------------------


class AnalysisResult(BaseModel):
    """Aggregated output of the Map-Reduce analysis pipeline."""

    sentiment_score: float = Field(0.0, ge=0, le=100)
    positive_ratio: float = Field(0.0, ge=0, le=1)
    negative_ratio: float = Field(0.0, ge=0, le=1)
    neutral_ratio: float = Field(0.0, ge=0, le=1)
    heat_index: float = 0.0
    key_insights: list[KeyInsight] = Field(default_factory=list)
    summary: str = ""
    raw_analysis: dict[str, Any] | None = None


# ---------------------------------------------------------------------------
# System prompt template
# ---------------------------------------------------------------------------

_MAP_SYSTEM_PROMPT = """\
You are a sentiment analysis expert.
Analyze the following social media posts about "{keyword}".

For each post, determine:
1. Sentiment: positive, negative, or neutral
2. Key opinion expressed (if any)

Then provide an overall assessment:
- Overall sentiment score
  (0-100, where 0=very negative, 50=neutral, 100=very positive)
- Top key opinions/viewpoints found
- Sentiment distribution counts

Respond in valid JSON format:
{{
  "overall_score": <number>,
  "sentiments": {{"positive": <count>, "negative": <count>, "neutral": <count>}},
  "key_opinions": [
    {{"text": "<opinion>", "sentiment": "<pos/neg/neutral>", "frequency": <count>}}
  ],
  "post_sentiments": [{{"index": <n>, "sentiment": "<pos/neg/neutral>"}}]
}}\
"""


# ---------------------------------------------------------------------------
# Service
# ---------------------------------------------------------------------------


class AnalyzerService:
    """Orchestrates the Map-Reduce sentiment analysis pipeline."""

    def __init__(self, llm_adapter: LLMAdapter | None = None) -> None:
        self._llm = llm_adapter or LLMAdapter()

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    async def analyze(self, posts: list[RawPost], keyword: str) -> AnalysisResult:
        """Run full analysis pipeline on collected posts.

        Args:
            posts: List of raw posts to analyze.
            keyword: The search keyword for context.

        Returns:
            Complete analysis result.
        """
        cleaned = self._clean_posts(posts)
        if not cleaned:
            return self._empty_result()

        chunks = self._chunk_posts(cleaned, chunk_size=20)
        chunk_results: list[dict[str, Any]] = []
        for chunk in chunks:
            result = await self._analyze_chunk(chunk, keyword)
            chunk_results.append(result)

        return self._reduce_results(chunk_results, cleaned)

    # ------------------------------------------------------------------
    # Step 1 — Clean
    # ------------------------------------------------------------------

    def _clean_posts(self, posts: list[RawPost]) -> list[RawPost]:
        """Filter spam, duplicates, and truncate long content.

        Args:
            posts: Raw posts from collection adapters.

        Returns:
            Cleaned and de-duplicated posts.
        """
        seen_contents: set[str] = set()
        cleaned: list[RawPost] = []

        for post in posts:
            text = post.content.strip()
            if len(text) < _MIN_CONTENT_LEN:
                continue
            if self._is_spam(text):
                continue
            if text in seen_contents:
                continue

            seen_contents.add(text)
            truncated = text[:_MAX_CONTENT_LEN]
            cleaned.append(post.model_copy(update={"content": truncated}))

        logger.info(
            "Cleaned posts: %d -> %d (removed %d)",
            len(posts),
            len(cleaned),
            len(posts) - len(cleaned),
        )
        return cleaned

    @staticmethod
    def _is_spam(text: str) -> bool:
        """Heuristic spam detection.

        Args:
            text: Post content to check.

        Returns:
            True if the text looks like spam.
        """
        url_count = len(_URL_PATTERN.findall(text))
        if url_count >= 3:
            return True
        alpha_chars = [c for c in text if c.isalpha()]
        uppercase_ratio = (
            sum(1 for c in alpha_chars if c.isupper()) / len(alpha_chars)
            if alpha_chars
            else 0
        )
        if uppercase_ratio > 0.8:
            return True
        return bool(_REPEATED_CHAR_PATTERN.search(text))

    # ------------------------------------------------------------------
    # Step 2 — Map
    # ------------------------------------------------------------------

    def _chunk_posts(
        self, posts: list[RawPost], chunk_size: int = 20
    ) -> list[list[RawPost]]:
        """Split posts into chunks for map-phase processing.

        Args:
            posts: Cleaned posts.
            chunk_size: Maximum posts per chunk.

        Returns:
            List of post chunks.
        """
        return [
            posts[i : i + chunk_size] for i in range(0, len(posts), chunk_size)
        ]

    async def _analyze_chunk(
        self, chunk: list[RawPost], keyword: str
    ) -> dict[str, Any]:
        """Analyze a single chunk of posts via LLM.

        Args:
            chunk: A batch of posts.
            keyword: The search keyword for prompt context.

        Returns:
            Parsed JSON dict from the LLM, or a fallback on parse error.
        """
        system_prompt = _MAP_SYSTEM_PROMPT.format(keyword=keyword)

        lines: list[str] = []
        for idx, post in enumerate(chunk, start=1):
            source_tag = f"[{post.source}]"
            lines.append(f"{idx}. {source_tag} {post.content}")
        user_prompt = "\n".join(lines)

        raw_text = await self._llm.chat_completion(
            system_prompt=system_prompt,
            user_prompt=user_prompt,
        )

        return self._parse_llm_json(raw_text, fallback_count=len(chunk))

    @staticmethod
    def _parse_llm_json(text: str, fallback_count: int) -> dict[str, Any]:
        """Extract and parse JSON from LLM response text.

        Handles markdown code fences and stray text around the JSON object.

        Args:
            text: Raw LLM response.
            fallback_count: Number of posts in the chunk (for fallback values).

        Returns:
            Parsed dict, or a neutral fallback on failure.
        """
        cleaned = text.strip()
        fence_match = re.search(r"```(?:json)?\s*\n?(.*?)```", cleaned, re.DOTALL)
        if fence_match:
            cleaned = fence_match.group(1).strip()

        brace_start = cleaned.find("{")
        brace_end = cleaned.rfind("}")
        if brace_start != -1 and brace_end != -1:
            cleaned = cleaned[brace_start : brace_end + 1]

        try:
            return json.loads(cleaned)  # type: ignore[no-any-return]
        except json.JSONDecodeError as exc:
            logger.warning("Failed to parse LLM JSON: %s — response: %.200s", exc, text)
            return {
                "overall_score": 50.0,
                "sentiments": {
                    "positive": 0,
                    "negative": 0,
                    "neutral": fallback_count,
                },
                "key_opinions": [],
                "post_sentiments": [],
            }

    # ------------------------------------------------------------------
    # Step 3 — Reduce
    # ------------------------------------------------------------------

    def _reduce_results(
        self,
        chunk_results: list[dict[str, Any]],
        all_posts: list[RawPost],
    ) -> AnalysisResult:
        """Aggregate chunk results into a final analysis.

        Args:
            chunk_results: Parsed LLM outputs per chunk.
            all_posts: All cleaned posts (for engagement / volume stats).

        Returns:
            Aggregated AnalysisResult.
        """
        total_score = 0.0
        total_weight = 0
        total_positive = 0
        total_negative = 0
        total_neutral = 0
        all_opinions: list[dict[str, Any]] = []

        for cr in chunk_results:
            sentiments = cr.get("sentiments", {})
            pos = int(sentiments.get("positive", 0))
            neg = int(sentiments.get("negative", 0))
            neu = int(sentiments.get("neutral", 0))
            chunk_count = pos + neg + neu or 1

            total_positive += pos
            total_negative += neg
            total_neutral += neu

            score = float(cr.get("overall_score", 50.0))
            total_score += score * chunk_count
            total_weight += chunk_count

            all_opinions.extend(cr.get("key_opinions", []))

        total_posts = total_positive + total_negative + total_neutral or 1
        sentiment_score = total_score / max(total_weight, 1)
        positive_ratio = total_positive / total_posts
        negative_ratio = total_negative / total_posts
        neutral_ratio = total_neutral / total_posts

        key_insights = self._extract_top_insights(all_opinions, top_n=3)

        total_engagement = sum(p.engagement for p in all_posts)
        heat_index = min(
            100.0,
            (total_engagement / max(1, len(all_posts))) * 0.4
            + min(len(all_posts), 50) * 1.2,
        )

        summary = self._build_summary(
            sentiment_score, positive_ratio, negative_ratio, neutral_ratio,
            len(all_posts), key_insights,
        )

        return AnalysisResult(
            sentiment_score=round(sentiment_score, 2),
            positive_ratio=round(positive_ratio, 4),
            negative_ratio=round(negative_ratio, 4),
            neutral_ratio=round(neutral_ratio, 4),
            heat_index=round(heat_index, 2),
            key_insights=key_insights,
            summary=summary,
            raw_analysis={
                "chunk_count": len(chunk_results),
                "total_posts_analyzed": total_posts,
                "total_engagement": total_engagement,
            },
        )

    @staticmethod
    def _extract_top_insights(
        opinions: list[dict[str, Any]], top_n: int = 3
    ) -> list[KeyInsight]:
        """Merge and rank opinions, returning the top-N as KeyInsight objects.

        Args:
            opinions: Raw opinion dicts from all chunks.
            top_n: How many insights to keep.

        Returns:
            Top insights sorted by frequency descending.
        """
        merged: dict[str, dict[str, Any]] = {}
        for op in opinions:
            text = str(op.get("text", "")).strip()
            if not text:
                continue
            key = text.lower()
            if key in merged:
                merged[key]["frequency"] += int(op.get("frequency", 1))
            else:
                merged[key] = {
                    "text": text,
                    "sentiment": str(op.get("sentiment", "neutral")),
                    "frequency": int(op.get("frequency", 1)),
                }

        ranked = sorted(merged.values(), key=lambda x: x["frequency"], reverse=True)
        return [
            KeyInsight(
                text=item["text"],
                sentiment=item["sentiment"],
                source_count=item["frequency"],
            )
            for item in ranked[:top_n]
        ]

    @staticmethod
    def _build_summary(
        score: float,
        pos_ratio: float,
        neg_ratio: float,
        neu_ratio: float,
        post_count: int,
        insights: list[KeyInsight],
    ) -> str:
        """Generate a human-readable summary paragraph.

        Args:
            score: Overall sentiment score (0-100).
            pos_ratio: Positive ratio (0-1).
            neg_ratio: Negative ratio (0-1).
            neu_ratio: Neutral ratio (0-1).
            post_count: Number of posts analyzed.
            insights: Top key insights.

        Returns:
            Summary string.
        """
        if score >= 70:
            tone = "predominantly positive"
        elif score >= 40:
            tone = "mixed"
        else:
            tone = "predominantly negative"

        parts = [
            f"Based on {post_count} posts analyzed, the overall sentiment is {tone} "
            f"(score: {score:.1f}/100).",
            f"Sentiment breakdown: {pos_ratio:.0%} positive, "
            f"{neg_ratio:.0%} negative, {neu_ratio:.0%} neutral.",
        ]

        if insights:
            insight_texts = "; ".join(i.text for i in insights[:3])
            parts.append(f"Key viewpoints: {insight_texts}.")

        return " ".join(parts)

    # ------------------------------------------------------------------
    # Fallback
    # ------------------------------------------------------------------

    @staticmethod
    def _empty_result() -> AnalysisResult:
        """Return an empty analysis result when no data is available."""
        return AnalysisResult(
            summary="No posts available for analysis after cleaning.",
        )
