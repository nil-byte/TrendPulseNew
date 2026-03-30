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
from urllib.parse import urlparse

from openai import AsyncOpenAI

from src.adapters.base import BaseAdapter, PartialSourceCollectionError, SourceCollectionError
from src.config.settings import settings
from src.models.schemas import RawPost

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Prompt templates for triple-helix sampling
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


def _compute_shard_limit(limit: int) -> int:
    """Round up shard size so total shard budget can satisfy the requested limit."""
    shard_count = len(_SHARDS)
    return max(1, (limit + shard_count - 1) // shard_count)


def _message_content_to_str(content: object) -> str:
    """Normalize OpenAI ``message.content`` (str or multi-part list) to plain text."""
    if content is None:
        return ""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts: list[str] = []
        for block in content:
            if isinstance(block, dict):
                if block.get("type") == "text" and "text" in block:
                    parts.append(str(block.get("text", "")))
                elif "text" in block:
                    parts.append(str(block["text"]))
            elif isinstance(block, str):
                parts.append(block)
        return "\n".join(parts).strip()
    return str(content)


_INCOMPATIBLE_MESSAGE = (
    "Grok provider returned a non-standard chat completion payload (missing or empty "
    "`choices`). For New API and other relays, confirm the channel returns OpenAI "
    "`/v1/chat/completions` JSON and that `GROK_BASE_URL` ends with `/v1`."
)


def _coerce_completion_dict(payload: object) -> dict[str, Any] | None:
    """Best-effort: turn an SDK model, plain dict, or JSON string into a dict."""
    if isinstance(payload, dict):
        return payload
    if isinstance(payload, str):
        text = payload.strip()
        if text.startswith("{") and text.endswith("}"):
            try:
                parsed = json.loads(text)
            except json.JSONDecodeError:
                return None
            return parsed if isinstance(parsed, dict) else None
        return None
    model_dump = getattr(payload, "model_dump", None)
    if callable(model_dump):
        try:
            dumped = model_dump()
            if isinstance(dumped, dict):
                return dumped
        except Exception:
            return None
    return None


def _unwrap_relay_envelope(data: dict[str, Any]) -> dict[str, Any]:
    """If a gateway wraps the OpenAI body, peel one common layer."""
    for key in ("data", "result", "response"):
        inner = data.get(key)
        if isinstance(inner, dict) and ("choices" in inner or "error" in inner):
            return inner
    return data


def _choice_to_dict(choice: object) -> dict[str, Any]:
    """Normalize one `choices[]` entry to a dict."""
    coerced = _coerce_completion_dict(choice)
    if coerced is not None:
        return coerced
    out: dict[str, Any] = {}
    for attr in ("message", "text", "index", "finish_reason"):
        if hasattr(choice, attr):
            val = getattr(choice, attr)
            out[attr] = val
    return out


def _message_dict_from_choice(choice_dict: dict[str, Any]) -> dict[str, Any]:
    """Return the assistant message object from a choice dict."""
    msg = choice_dict.get("message")
    if isinstance(msg, dict):
        return msg
    if msg is not None:
        md = _coerce_completion_dict(msg)
        if isinstance(md, dict):
            return md
    return {}


def _text_from_message_dict(msg: dict[str, Any]) -> str:
    """Read content, then reasoning fields used by some Grok or relay channels."""
    text = _message_content_to_str(msg.get("content"))
    if text.strip():
        return text
    for key in ("reasoning_content", "reasoning"):
        text = _message_content_to_str(msg.get(key))
        if text.strip():
            return text
    return ""


def _extract_completion_text_from_chat_response(response: object) -> str:
    """Extract assistant text from an OpenAI-compatible completion."""
    data = _coerce_completion_dict(response)
    if data is not None:
        data = _unwrap_relay_envelope(data)
        err = data.get("error")
        if err is not None:
            if isinstance(err, str):
                msg = err
            elif isinstance(err, dict):
                msg = str(
                    err.get("message") or err.get("msg") or err.get("code") or err
                )
            else:
                msg = str(err)
            raise SourceCollectionError("grok_provider_error", msg)

        choices = data.get("choices")
        if not choices:
            raise SourceCollectionError(
                "grok_provider_incompatible",
                _INCOMPATIBLE_MESSAGE,
            )
        choice0 = _choice_to_dict(choices[0])
        msg = _message_dict_from_choice(choice0)
        text = _text_from_message_dict(msg)
        if text.strip():
            return text
        legacy = choice0.get("text") if isinstance(choice0, dict) else None
        if legacy:
            return str(legacy)
        return ""

    # Legacy: SDK objects (and unittest.mock.MagicMock) without a real model_dump dict.
    choices = getattr(response, "choices", None)
    if not choices:
        raise SourceCollectionError("grok_provider_incompatible", _INCOMPATIBLE_MESSAGE)

    choice0 = choices[0]
    message = getattr(choice0, "message", None)
    if message is not None:
        content = getattr(message, "content", None)
        text = _message_content_to_str(content)
        if text.strip():
            return text
        for attr in ("reasoning_content", "reasoning"):
            if hasattr(message, attr):
                text = _message_content_to_str(getattr(message, attr))
                if text.strip():
                    return text

    choice_dict = _choice_to_dict(choice0)
    msg = _message_dict_from_choice(choice_dict)
    text = _text_from_message_dict(msg)
    if text.strip():
        return text

    text_attr = getattr(choice0, "text", None)
    if isinstance(text_attr, str) and text_attr:
        return text_attr
    td = choice_dict.get("text")
    if td:
        return str(td)
    return ""


class XAdapter(BaseAdapter):
    """Collect posts from X via Grok API using Triple-Helix Sampling."""

    _MISSING_API_KEY_CODE = "grok_api_key_missing"
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
            raise SourceCollectionError(
                self._MISSING_API_KEY_CODE,
                self._MISSING_API_KEY_MESSAGE,
            )

        client = self._build_grok_client()
        try:
            shard_limit = _compute_shard_limit(limit)
            parsed = urlparse(settings.grok_base_url)
            endpoint_host = parsed.netloc or settings.grok_base_url
            logger.info(
                "X collection starting keyword=%r limit=%d shard_limit=%d "
                "provider_mode=%s endpoint=%s model=%s timeout=%ss",
                keyword,
                limit,
                shard_limit,
                settings.grok_provider_mode,
                endpoint_host,
                settings.grok_model,
                settings.grok_http_timeout_seconds,
            )

            tasks = [
                self._query_shard(client, keyword, language, name, focus, shard_limit)
                for name, focus in _SHARDS
            ]
            shard_results: list[list[RawPost] | BaseException] = await asyncio.gather(
                *tasks,
                return_exceptions=True,
            )

            shard_errors: dict[str, SourceCollectionError] = {}
            seen: dict[str | None, RawPost] = {}
            for (dimension_name, _), shard in zip(_SHARDS, shard_results, strict=True):
                if isinstance(shard, BaseException):
                    source_error = self._normalize_error(shard)
                    logger.warning(
                        "Grok shard failed keyword=%r shard=%r reason_code=%s reason=%s",
                        keyword,
                        dimension_name,
                        source_error.reason_code,
                        source_error.message,
                    )
                    shard_errors[dimension_name] = source_error
                    continue

                for post in shard:
                    if post.source_id and post.source_id in seen:
                        continue
                    seen[post.source_id] = post

            posts = list(seen.values())[:limit]
            if shard_errors and posts:
                raise PartialSourceCollectionError(
                    self._aggregate_shard_reason_code(shard_errors),
                    f"X collection partially failed: {self._format_shard_errors(shard_errors)}",
                    partial_posts=posts,
                )

            if not posts and shard_errors:
                raise SourceCollectionError(
                    self._aggregate_shard_reason_code(shard_errors),
                    f"X collection failed: {self._format_shard_errors(shard_errors)}",
                )

            logger.info("X collected %d unique posts for keyword=%r", len(posts), keyword)
            return posts
        finally:
            await client.close()

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    def _build_grok_client(self) -> AsyncOpenAI:
        """Create the OpenAI-compatible client for the active Grok endpoint."""
        return AsyncOpenAI(
            api_key=settings.grok_api_key,
            base_url=settings.grok_base_url,
            timeout=settings.grok_http_timeout_seconds,
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

        # New API (and some relays) default to SSE streaming when `stream` is omitted;
        # the SDK then yields a malformed non-stream parse. Force JSON completions.
        response = await client.chat.completions.create(
            model=self._resolve_grok_model(),
            temperature=0.2,
            stream=False,
            messages=[
                {"role": "system", "content": _SYSTEM_PROMPT},
                {"role": "user", "content": user_prompt},
            ],
        )

        raw_text = _extract_completion_text_from_chat_response(response)
        if not raw_text.strip():
            raise SourceCollectionError(
                "grok_empty_response",
                f"Grok returned an empty completion for shard {dimension_name}",
            )
        try:
            return self._parse_response(raw_text, dimension_name)
        except ValueError as exc:
            raise SourceCollectionError(
                "grok_invalid_payload",
                str(exc),
            ) from exc

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
    def _normalize_error(error: BaseException) -> SourceCollectionError:
        """Convert arbitrary shard exceptions into typed source failures."""
        if isinstance(error, SourceCollectionError):
            return error
        message = str(error).strip() or error.__class__.__name__
        return SourceCollectionError("grok_collection_failed", message)

    @staticmethod
    def _format_shard_errors(shard_errors: dict[str, SourceCollectionError]) -> str:
        """Render shard failures into a readable summary string."""
        return "; ".join(
            f"{shard_name}: {error.reason_code} ({error.message})"
            for shard_name, error in shard_errors.items()
        )

    @staticmethod
    def _aggregate_shard_reason_code(
        shard_errors: dict[str, SourceCollectionError],
    ) -> str:
        """Return a source-level code for all shard failures."""
        reason_codes = {error.reason_code for error in shard_errors.values()}
        if len(reason_codes) == 1:
            return reason_codes.pop()
        return "grok_shards_failed"
