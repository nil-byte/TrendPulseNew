"""AI-powered sentiment analysis service."""

from __future__ import annotations

import json
import logging
import re
from typing import Any

from pydantic import BaseModel, Field, ValidationError, field_validator

from src.adapters.llm_adapter import LLMAdapter
from src.models.schemas import KeyInsight, RawPost

logger = logging.getLogger(__name__)

_MIN_CONTENT_LEN = 10
_MAX_CONTENT_LEN = 500
_REDUCE_MAX_TOKENS = 1200
_MERMAID_MAX_LABEL_LENGTH = 120
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

    def has_analyzable_content(self) -> bool:
        """Return True when the analysis represents at least one cleaned post."""
        if self.raw_analysis is None:
            return False

        total_posts = self.raw_analysis.get("total_posts_analyzed", 0)
        try:
            return int(total_posts) > 0
        except (TypeError, ValueError):
            return False


class _ReduceInsightPayload(BaseModel):
    """Validated reduce-stage key insight payload."""

    text: str = Field(..., min_length=1)
    sentiment: str = Field(default="neutral")
    source_count: int = Field(default=1, ge=1)


class _ReduceOutput(BaseModel):
    """Validated reduce-stage output payload."""

    summary: str = Field(..., min_length=1)
    key_insights: list[_ReduceInsightPayload] = Field(default_factory=list)

    @field_validator("key_insights")
    @classmethod
    def limit_key_insights(
        cls, value: list[_ReduceInsightPayload]
    ) -> list[_ReduceInsightPayload]:
        """Keep reduce insights within the product limit."""
        return value[:3]


def _sanitize_mermaid_label(text: str, *, fallback: str = "") -> str:
    """Normalize free text into a Mermaid-safe single-line label."""
    collapsed = " ".join(text.split())
    normalized = re.sub(r"[\[\]\{\}\(\)\"`]", "", collapsed)
    normalized = normalized.replace(":::", " ")
    normalized = normalized.strip()
    if len(normalized) > _MERMAID_MAX_LABEL_LENGTH:
        normalized = normalized[: _MERMAID_MAX_LABEL_LENGTH - 3].rstrip() + "..."
    return normalized or fallback


def _mindmap_heading(language: str, english: str, chinese: str) -> str:
    """Return a localized branch label for Mermaid mindmaps."""
    return chinese if language == "zh" else english


def _insight_sentiment_label(sentiment: str, language: str) -> str:
    """Return a human-readable sentiment branch label."""
    normalized = sentiment.strip().lower()
    if language == "zh":
        return {
            "positive": "正面观点",
            "negative": "负面观点",
            "neutral": "中性观点",
        }.get(normalized, "中性观点")
    return {
        "positive": "Positive view",
        "negative": "Negative view",
        "neutral": "Neutral view",
    }.get(normalized, "Neutral view")


def build_mermaid_mindmap(
    *,
    keyword: str,
    summary: str,
    insights: list[KeyInsight],
    language: str,
) -> str | None:
    """Build a Mermaid mindmap string from the analysis summary and insights."""
    root_label = _sanitize_mermaid_label(
        keyword,
        fallback=_mindmap_heading(language, "TrendPulse Report", "TrendPulse 报告"),
    )
    summary_label = _sanitize_mermaid_label(summary)
    if not summary_label and not insights:
        return None

    lines = ["mindmap", f"  root(({root_label}))"]

    if summary_label:
        lines.extend(
            [
                f"    {_mindmap_heading(language, 'Summary', '摘要')}",
                f"      {summary_label}",
            ]
        )

    if insights:
        lines.append(f"    {_mindmap_heading(language, 'Viewpoints', '观点脉络')}")
        for index, insight in enumerate(insights[:3], start=1):
            insight_label = _sanitize_mermaid_label(
                insight.text,
                fallback=_mindmap_heading(language, "Key takeaway", "关键结论"),
            )
            lines.extend(
                [
                    "      "
                    + _mindmap_heading(
                        language,
                        f"Insight {index}",
                        f"洞察 {index}",
                    ),
                    f"        {insight_label}",
                    f"        {_insight_sentiment_label(insight.sentiment, language)}",
                    "        "
                    + _mindmap_heading(
                        language,
                        f"{insight.source_count} sources",
                        f"{insight.source_count} 条来源",
                    ),
                ]
            )

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# System prompt template
# ---------------------------------------------------------------------------

_MAP_SYSTEM_PROMPT = """\
You are a sentiment analysis expert.
Analyze the following social media posts about "{keyword}".

Return all natural-language text fields in {output_language}.
Keep the JSON keys in English.

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

_REDUCE_SYSTEM_PROMPT = """\
You are a senior analyst consolidating map-phase sentiment analysis for "{keyword}".

You will receive only condensed chunk analysis results, not raw post text.
Return all natural-language text fields in {output_language}.
Keep the JSON keys in English.

Respond in valid JSON format:
{{
  "summary": "<human-friendly summary>",
  "key_insights": [
    {{
      "text": "<debate-worthy insight>",
      "sentiment": "<positive/negative/neutral>",
      "source_count": <int>
    }}
  ]
}}

Rules:
- `summary` must be concise, human-readable, and grounded in the condensed payload.
- `key_insights` must contain at most 3 distinct viewpoints or points of debate.
- Prefer repeated or contested viewpoints over generic observations.
- Do not include markdown or any prose outside the JSON object.
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

    async def analyze(
        self, posts: list[RawPost], keyword: str, language: str
    ) -> AnalysisResult:
        """Run full analysis pipeline on collected posts.

        Args:
            posts: List of raw posts to analyze.
            keyword: The search keyword for context.
            language: Target output language for summaries and insights.

        Returns:
            Complete analysis result.
        """
        cleaned = self._clean_posts(posts)
        if not cleaned:
            return self._empty_result(language)

        chunks = self._chunk_posts(cleaned, chunk_size=20)
        chunk_results: list[dict[str, Any]] = []
        for chunk in chunks:
            result = await self._analyze_chunk(chunk, keyword, language)
            chunk_results.append(result)

        local_result = self._reduce_results(chunk_results, cleaned, language)
        if not local_result.has_analyzable_content():
            return local_result

        condensed_payload = self._build_reduce_payload(
            keyword=keyword,
            language=language,
            chunk_results=chunk_results,
            local_result=local_result,
        )
        reduce_result = await self._run_reduce_llm(
            keyword=keyword,
            language=language,
            condensed_payload=condensed_payload,
        )

        raw_analysis = dict(local_result.raw_analysis or {})
        raw_analysis.update(
            {
                "analysis_language": language,
                "reduce_attempted": True,
                "reduce_used_condensed_payload": True,
                "reduce_max_tokens": _REDUCE_MAX_TOKENS,
                "reduce_chunk_count": len(condensed_payload["chunk_analyses"]),
                "reduce_candidate_insight_count": len(
                    condensed_payload["candidate_insights"]
                ),
                "reduce_llm_succeeded": reduce_result is not None,
            }
        )

        final_summary = reduce_result.summary if reduce_result else local_result.summary
        final_insights = (
            [
                KeyInsight(
                    text=insight.text,
                    sentiment=insight.sentiment,
                    source_count=insight.source_count,
                )
                for insight in reduce_result.key_insights
            ]
            if reduce_result is not None
            else local_result.key_insights
        )
        mermaid_mindmap = build_mermaid_mindmap(
            keyword=keyword,
            summary=final_summary,
            insights=final_insights,
            language=language,
        )
        if mermaid_mindmap is not None:
            raw_analysis["mermaid_mindmap"] = mermaid_mindmap

        if reduce_result is None:
            return local_result.model_copy(update={"raw_analysis": raw_analysis})

        return local_result.model_copy(
            update={
                "summary": final_summary,
                "key_insights": final_insights,
                "raw_analysis": raw_analysis,
            }
        )

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
        self, chunk: list[RawPost], keyword: str, language: str
    ) -> dict[str, Any]:
        """Analyze a single chunk of posts via LLM.

        Args:
            chunk: A batch of posts.
            keyword: The search keyword for prompt context.
            language: Target output language for map-phase text fields.

        Returns:
            Parsed JSON dict from the LLM, or a fallback on parse error.
        """
        system_prompt = _MAP_SYSTEM_PROMPT.format(
            keyword=keyword,
            output_language=self._output_language(language),
        )

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
    def _extract_json_object(text: str) -> dict[str, Any]:
        """Extract a JSON object from raw LLM text."""
        cleaned = text.strip()
        fence_match = re.search(r"```(?:json)?\s*\n?(.*?)```", cleaned, re.DOTALL)
        if fence_match:
            cleaned = fence_match.group(1).strip()

        brace_start = cleaned.find("{")
        brace_end = cleaned.rfind("}")
        if brace_start != -1 and brace_end != -1:
            cleaned = cleaned[brace_start : brace_end + 1]

        payload = json.loads(cleaned)
        if not isinstance(payload, dict):
            raise ValueError("LLM response was not a JSON object")
        return payload

    @classmethod
    def _parse_llm_json(cls, text: str, fallback_count: int) -> dict[str, Any]:
        """Extract and parse JSON from LLM response text.

        Handles markdown code fences and stray text around the JSON object.

        Args:
            text: Raw LLM response.
            fallback_count: Number of posts in the chunk (for fallback values).

        Returns:
            Parsed dict, or a neutral fallback on failure.
        """
        try:
            return cls._extract_json_object(text)
        except (json.JSONDecodeError, ValueError) as exc:
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
        language: str = "en",
    ) -> AnalysisResult:
        """Aggregate chunk results into a local heuristic analysis result.

        Args:
            chunk_results: Parsed LLM outputs per chunk.
            all_posts: All cleaned posts (for engagement / volume stats).
            language: Target summary language for heuristic fallback.

        Returns:
            Aggregated AnalysisResult.
        """
        total_score = 0.0
        total_weight = 0
        total_positive = 0
        total_negative = 0
        total_neutral = 0
        all_opinions: list[dict[str, Any]] = []

        for chunk_result in chunk_results:
            sentiments = chunk_result.get("sentiments", {})
            positive = int(sentiments.get("positive", 0))
            negative = int(sentiments.get("negative", 0))
            neutral = int(sentiments.get("neutral", 0))
            chunk_count = positive + negative + neutral
            if chunk_count <= 0:
                continue

            total_positive += positive
            total_negative += negative
            total_neutral += neutral

            score = float(chunk_result.get("overall_score", 50.0))
            total_score += score * chunk_count
            total_weight += chunk_count

            all_opinions.extend(chunk_result.get("key_opinions", []))

        total_posts = total_positive + total_negative + total_neutral
        if total_posts <= 0 or total_weight <= 0:
            return self._empty_result(language)

        sentiment_score = total_score / max(total_weight, 1)
        positive_ratio = total_positive / total_posts
        negative_ratio = total_negative / total_posts
        neutral_ratio = total_neutral / total_posts

        key_insights = self._extract_top_insights(all_opinions, top_n=3)

        total_engagement = sum(post.engagement for post in all_posts)
        heat_index = min(
            100.0,
            (total_engagement / max(1, len(all_posts))) * 0.4
            + min(len(all_posts), 50) * 1.2,
        )

        summary = self._build_summary(
            score=sentiment_score,
            pos_ratio=positive_ratio,
            neg_ratio=negative_ratio,
            neu_ratio=neutral_ratio,
            post_count=len(all_posts),
            insights=key_insights,
            language=language,
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
                "analysis_language": language,
            },
        )

    async def _run_reduce_llm(
        self,
        keyword: str,
        language: str,
        condensed_payload: dict[str, Any],
    ) -> _ReduceOutput | None:
        """Run the reduce-stage LLM over condensed chunk outputs only."""
        system_prompt = _REDUCE_SYSTEM_PROMPT.format(
            keyword=keyword,
            output_language=self._output_language(language),
        )
        user_prompt = json.dumps(condensed_payload, ensure_ascii=False, indent=2)

        try:
            raw_text = await self._llm.chat_completion(
                system_prompt=system_prompt,
                user_prompt=user_prompt,
                temperature=0.2,
                max_tokens=_REDUCE_MAX_TOKENS,
            )
        except Exception as exc:
            logger.warning("Reduce LLM failed, falling back to heuristics: %s", exc)
            return None

        try:
            parsed = _ReduceOutput.model_validate(self._extract_json_object(raw_text))
        except (json.JSONDecodeError, ValidationError, ValueError) as exc:
            logger.warning(
                "Failed to parse reduce LLM JSON: %s — response: %.200s",
                exc,
                raw_text,
            )
            return None

        if not parsed.key_insights:
            logger.warning("Reduce LLM returned no usable key insights")
            return None

        return parsed

    def _build_reduce_payload(
        self,
        keyword: str,
        language: str,
        chunk_results: list[dict[str, Any]],
        local_result: AnalysisResult,
    ) -> dict[str, Any]:
        """Create a condensed reduce payload from chunk-level analysis only."""
        return {
            "keyword": keyword,
            "target_language": language,
            "aggregated_sentiment": {
                "sentiment_score": local_result.sentiment_score,
                "positive_ratio": local_result.positive_ratio,
                "negative_ratio": local_result.negative_ratio,
                "neutral_ratio": local_result.neutral_ratio,
            },
            "candidate_insights": [
                insight.model_dump() for insight in local_result.key_insights
            ],
            "chunk_analyses": [
                self._condense_chunk_result(chunk_result, chunk_index)
                for chunk_index, chunk_result in enumerate(chunk_results, start=1)
            ],
        }

    @staticmethod
    def _condense_chunk_result(
        chunk_result: dict[str, Any], chunk_index: int
    ) -> dict[str, Any]:
        """Compress a chunk-level result for the reduce stage."""
        sentiments = chunk_result.get("sentiments", {})
        positive = int(sentiments.get("positive", 0))
        negative = int(sentiments.get("negative", 0))
        neutral = int(sentiments.get("neutral", 0))

        key_opinions: list[dict[str, Any]] = []
        for opinion in chunk_result.get("key_opinions", []):
            text = str(opinion.get("text", "")).strip()
            if not text:
                continue
            key_opinions.append(
                {
                    "text": text,
                    "sentiment": str(opinion.get("sentiment", "neutral")),
                    "frequency": int(opinion.get("frequency", 1)),
                }
            )
            if len(key_opinions) == 5:
                break

        return {
            "chunk_index": chunk_index,
            "overall_score": float(chunk_result.get("overall_score", 50.0)),
            "classified_posts": positive + negative + neutral,
            "sentiments": {
                "positive": positive,
                "negative": negative,
                "neutral": neutral,
            },
            "key_opinions": key_opinions,
        }

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
        for opinion in opinions:
            text = str(opinion.get("text", "")).strip()
            if not text:
                continue
            key = text.lower()
            if key in merged:
                merged[key]["frequency"] += int(opinion.get("frequency", 1))
            else:
                merged[key] = {
                    "text": text,
                    "sentiment": str(opinion.get("sentiment", "neutral")),
                    "frequency": int(opinion.get("frequency", 1)),
                }

        ranked = sorted(
            merged.values(),
            key=lambda item: item["frequency"],
            reverse=True,
        )
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
        language: str = "en",
    ) -> str:
        """Generate a human-readable summary paragraph.

        Args:
            score: Overall sentiment score (0-100).
            pos_ratio: Positive ratio (0-1).
            neg_ratio: Negative ratio (0-1).
            neu_ratio: Neutral ratio (0-1).
            post_count: Number of posts analyzed.
            insights: Top key insights.
            language: Target summary language.

        Returns:
            Summary string.
        """
        if language == "zh":
            if score >= 70:
                tone = "整体偏正面"
            elif score >= 40:
                tone = "观点分化"
            else:
                tone = "整体偏负面"

            parts = [
                f"基于已分析的 {post_count} 条帖子，整体舆情{tone}"
                f"（情绪得分 {score:.1f}/100）。",
                f"情绪分布：正面 {pos_ratio:.0%}，负面 {neg_ratio:.0%}，"
                f"中性 {neu_ratio:.0%}。",
            ]

            if insights:
                insight_texts = "；".join(insight.text for insight in insights[:3])
                parts.append(f"主要争议点：{insight_texts}。")

            return "".join(parts)

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
            insight_texts = "; ".join(insight.text for insight in insights[:3])
            parts.append(f"Key viewpoints: {insight_texts}.")

        return " ".join(parts)

    # ------------------------------------------------------------------
    # Fallback
    # ------------------------------------------------------------------

    @staticmethod
    def _output_language(language: str) -> str:
        """Return a stable language hint for prompt templates."""
        if language == "zh":
            return "简体中文 (Simplified Chinese)"
        return "English"

    @staticmethod
    def _empty_result(language: str = "en") -> AnalysisResult:
        """Return an empty analysis result when no data is available."""
        summary = (
            "清洗后没有可供分析的帖子。"
            if language == "zh"
            else "No posts available for analysis after cleaning."
        )
        return AnalysisResult(summary=summary)
