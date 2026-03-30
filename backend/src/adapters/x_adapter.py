"""X (Twitter) data collection adapter via Grok API.

Implements the Triple-Helix Sampling strategy: three parallel shards
(Pulse / Core / Noise) each request a subset of tweets through Grok's
native X search capability, then results are deduplicated by source_id.
"""

from __future__ import annotations

import asyncio
import json
import logging
import re
from typing import Any

from openai import AsyncOpenAI

from src.adapters.base import BaseAdapter
from src.config.settings import settings
from src.models.schemas import RawPost

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Prompt templates (from GROK_API_INTEGRATION_REPORT V11.0)
# ---------------------------------------------------------------------------

_SYSTEM_PROMPT = """\
<role>
You are a Social Intelligence Analyst. Your goal is to extract a high-signal \
dataset from X that accurately represents a specific dimension of public discourse.
</role>

<data_standard>
1. AUTHENTICITY: Every tweet must be a real, verifiable post from X.
2. SELECTIVITY: Filter out spam, bots, self-promotional links, and repetitive \
low-value phrases.
3. STRUCTURE: Output ONLY a valid JSON array.
</data_standard>

<schema>
[
  {
    "id": "str",
    "username": "str",
    "content": "str",
    "perspective": "Short tag: e.g., 'Technical', 'Market', 'Skeptical', 'Bullish'",
    "created_at": "ISO8601",
    "engagement": int,
    "url": "str"
  }
]
</schema>"""

_USER_PROMPT_TEMPLATE = """\
<context>
Keyword: "{keyword}"
Target: {shard_limit} items
Dimension: {dimension_name}
Search Focus: {dimension_focus}
</context>

<task>
Analyze the X search space for the above keyword.
Identify {shard_limit} unique, high-signal tweets that best represent the \
assigned 'Dimension'.
Prioritize variety in authors and specific, detailed content over generic reactions.
</task>

<instruction>
Generate the JSON array of {shard_limit} objects now.
</instruction>"""

# Shard definitions: (name, focus description)
_SHARDS: list[tuple[str, str]] = [
    (
        "The Pulse",
        "Latest original posts (time-sensitive, exclude retweets)",
    ),
    (
        "The Core",
        "High engagement/Authority content (verified accounts, high likes)",
    ),
    (
        "The Noise",
        "Dissenting/Skeptical views (contrarian opinions, criticism)",
    ),
]


class XAdapter(BaseAdapter):
    """Collect posts from X via Grok API using Triple-Helix Sampling."""

    _MISSING_API_KEY_MESSAGE = "Grok API key is not configured"

    @property
    def source_name(self) -> str:
        return "x"

    async def collect(self, keyword: str, language: str, limit: int) -> list[RawPost]:
        """Run three parallel Grok shards and deduplicate results.

        Args:
            keyword: Search keyword.
            language: Language code (en/zh).
            limit: Maximum number of posts to collect.

        Returns:
            Deduplicated list of collected raw posts.
        """
        if not settings.grok_api_key:
            logger.warning(self._MISSING_API_KEY_MESSAGE)
            raise RuntimeError(self._MISSING_API_KEY_MESSAGE)

        client = self._build_grok_client()

        shard_limit = max(1, limit // len(_SHARDS))

        tasks = [
            self._query_shard(client, keyword, language, name, focus, shard_limit)
            for name, focus in _SHARDS
        ]
        shard_results: list[list[RawPost] | BaseException] = await asyncio.gather(
            *tasks,
            return_exceptions=True,
        )

        shard_errors: dict[str, str] = {}
        seen: dict[str | None, RawPost] = {}
        for (dimension_name, _), shard in zip(_SHARDS, shard_results, strict=True):
            if isinstance(shard, BaseException):
                error_message = self._stringify_error(shard)
                logger.warning(
                    "Grok shard %r failed for keyword=%r: %s",
                    dimension_name,
                    keyword,
                    error_message,
                )
                shard_errors[dimension_name] = error_message
                continue

            for post in shard:
                if post.source_id and post.source_id in seen:
                    continue
                seen[post.source_id] = post

        posts = list(seen.values())[:limit]
        if not posts and shard_errors:
            raise RuntimeError(
                f"X collection failed: {self._format_shard_errors(shard_errors)}"
            )

        if shard_errors:
            logger.warning(
                "X collection completed with shard failures for keyword=%r: %s",
                keyword,
                self._format_shard_errors(shard_errors),
            )

        logger.info("X collected %d unique posts for keyword=%r", len(posts), keyword)
        return posts

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    def _build_grok_client(self) -> AsyncOpenAI:
        """Create the OpenAI-compatible client for the active Grok endpoint."""
        return AsyncOpenAI(
            api_key=settings.grok_api_key,
            base_url=settings.grok_base_url,
        )

    def _resolve_grok_model(self) -> str:
        """Return the configured model name for Grok shard requests."""
        return settings.grok_model

    async def _query_shard(
        self,
        client: AsyncOpenAI,
        keyword: str,
        language: str,
        dimension_name: str,
        dimension_focus: str,
        shard_limit: int,
    ) -> list[RawPost]:
        """Execute a single Grok shard request and parse the response."""
        user_prompt = _USER_PROMPT_TEMPLATE.format(
            keyword=keyword,
            shard_limit=shard_limit,
            dimension_name=dimension_name,
            dimension_focus=dimension_focus,
        )

        response = await client.chat.completions.create(
            model=self._resolve_grok_model(),
            temperature=0.2,
            messages=[
                {"role": "system", "content": _SYSTEM_PROMPT},
                {"role": "user", "content": user_prompt},
            ],
        )

        raw_text = response.choices[0].message.content or ""
        return self._parse_response(raw_text, dimension_name)

    def _parse_response(self, raw_text: str, dimension_name: str) -> list[RawPost]:
        """Strip <think> tags and parse JSON array into RawPost objects."""
        text = raw_text
        if "</think>" in text:
            text = text.split("</think>")[-1].strip()

        json_match = re.search(r"\[.*]", text, re.DOTALL)
        if not json_match:
            raise ValueError(
                f"No JSON array found in Grok response for shard {dimension_name}"
            )

        try:
            items: list[dict[str, Any]] = json.loads(json_match.group())
        except json.JSONDecodeError as exc:
            raise ValueError(
                f"Invalid JSON in Grok response for shard {dimension_name}"
            ) from exc

        posts: list[RawPost] = []
        for item in items:
            try:
                posts.append(
                    RawPost(
                        source="x",
                        source_id=str(item.get("id", "")),
                        author=item.get("username"),
                        content=item.get("content", ""),
                        url=item.get("url"),
                        engagement=int(item.get("engagement", 0)),
                        published_at=item.get("created_at"),
                        metadata_extra={"perspective": item.get("perspective")},
                    )
                )
            except (ValueError, TypeError):
                logger.debug("Skipping malformed item in shard %r", dimension_name)

        return posts

    @staticmethod
    def _stringify_error(error: BaseException) -> str:
        """Convert shard exceptions into stable human-readable messages."""
        message = str(error).strip()
        return message or error.__class__.__name__

    @staticmethod
    def _format_shard_errors(shard_errors: dict[str, str]) -> str:
        """Render shard failures into a readable summary string."""
        return "; ".join(
            f"{shard_name}: {message}" for shard_name, message in shard_errors.items()
        )
