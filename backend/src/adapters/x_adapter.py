"""X (Twitter) data collection adapter via Grok API.

Splits the requested ``limit`` into one or more chat completion calls capped by
``X_BATCH_SIZE`` (default 20). A single batch uses a balanced profile; multiple
batches rotate **Balanced Mix / Authority / Dissent / Latest** dimensions.
Results merge and deduplicate by ``source_id``. Concurrency and backoff align
with ``source_runtime_control`` and settings (``X_PARALLEL_BATCHES``, retries).
"""

from __future__ import annotations

import asyncio
import json
import logging
import random
import re
from datetime import datetime
from typing import Any
from urllib.parse import urlparse

from openai import APIConnectionError, APIStatusError, APITimeoutError, AsyncOpenAI

from src.adapters.base import (
    BaseAdapter,
    PartialSourceCollectionError,
    SourceCollectionError,
)
from src.common.language_utils import target_language_name
from src.common.time_utils import (
    format_rfc3339,
    is_timestamp_in_recency_window,
    recency_window_start,
    resolve_recency_hours,
    utc_now,
)
from src.config.settings import settings
from src.models.schemas import RawPost
from src.services.source_runtime_control import (
    RECOVERABLE_X_GATEWAY_REASON_CODES,
    source_runtime_control,
)

logger = logging.getLogger(__name__)
_CJK_RE = re.compile(r"[\u3400-\u4DBF\u4E00-\u9FFF]")
_ASCII_ALPHA_RE = re.compile(r"[A-Za-z]")

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
Target language: {target_language}
Target: {shard_limit} items
Dimension: {dimension_name}
Search Focus: {dimension_focus}
Current UTC time: {current_utc}
Allowed post window: {window_start} to {current_utc}
</context>

<task>
Analyze the X search space for the above keyword.
Identify {shard_limit} unique, high-signal tweets that best represent the \
assigned 'Dimension'.
Prioritize variety in authors and specific, detailed content over generic reactions.
</task>

<language_requirement>
Tweets must be primarily written in {target_language}.
Discard tweets whose main content is clearly in another language.
</language_requirement>

<time_requirement>
Only return tweets whose created_at falls within this window.
If created_at is missing, invalid, ambiguous, or older than the last {recency_hours} \
hours, exclude that tweet.
Do not use older tweets to fill the quota.
</time_requirement>

<instruction>
Generate the JSON array of {shard_limit} objects now.
</instruction>"""

_SINGLE_BATCH_PROFILE = (
    "Balanced Mix",
    "Return a balanced mix of latest posts, authoritative voices, and skeptical "
    "or contrarian views.",
)

_BATCH_PROFILES: list[tuple[str, str]] = [
    (
        "Balanced Mix",
        "Return a balanced mix of latest posts, authoritative voices, and "
        "skeptical or contrarian views.",
    ),
    (
        "Authority",
        "Prioritize high-engagement, expert, official, and authoritative voices.",
    ),
    (
        "Dissent",
        "Prioritize skeptical, contrarian, critical, or risk-focused discussion.",
    ),
    (
        "Latest",
        "Prioritize the freshest original posts inside the allowed time window.",
    ),
]

def _resolve_positive_int(value: object, default: int) -> int:
    """Return a positive integer config value or fall back to ``default``."""
    if isinstance(value, int) and value > 0:
        return value
    if isinstance(value, str):
        try:
            parsed = int(value)
        except ValueError:
            return default
        if parsed > 0:
            return parsed
    return default


def _resolve_non_negative_float(value: object, default: float) -> float:
    """Return a non-negative float config value or fall back to ``default``."""
    if isinstance(value, (int, float)) and float(value) >= 0:
        return float(value)
    if isinstance(value, str):
        try:
            parsed = float(value)
        except ValueError:
            return default
        if parsed >= 0:
            return parsed
    return default


def _compute_batch_sizes(limit: int, batch_size: int) -> list[int]:
    """Split the requested total into sequential batches capped at ``batch_size``."""
    remaining = limit
    batch_sizes: list[int] = []
    while remaining > 0:
        current = min(batch_size, remaining)
        batch_sizes.append(current)
        remaining -= current
    return batch_sizes

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


def _source_error_from_provider_payload(error_payload: object) -> SourceCollectionError:
    """Classify 200-level provider error payloads into stable X reason codes."""
    if isinstance(error_payload, str):
        message = error_payload
        signal = error_payload.lower()
    elif isinstance(error_payload, dict):
        message = str(
            error_payload.get("message")
            or error_payload.get("msg")
            or error_payload.get("code")
            or error_payload
        )
        signal = " ".join(
            str(error_payload.get(key, "")).lower()
            for key in ("code", "type", "message")
        )
    else:
        message = str(error_payload)
        signal = message.lower()

    if (
        "rate_limit" in signal
        or "rate limit" in signal
        or "no available tokens" in signal
    ):
        return SourceCollectionError("grok_rate_limited", message)
    return SourceCollectionError("grok_provider_error", message)


def _extract_completion_text_from_chat_response(response: object) -> str:
    """Extract assistant text from an OpenAI-compatible completion."""
    data = _coerce_completion_dict(response)
    if data is not None:
        data = _unwrap_relay_envelope(data)
        err = data.get("error")
        if err is not None:
            raise _source_error_from_provider_payload(err)

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
        """Run one or more Grok batches and deduplicate results.

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
            batch_plan = self._build_batch_plan(limit)
            batch_sizes = [batch_size for _, _, batch_size in batch_plan]
            recency_hours = resolve_recency_hours(settings.collection_recency_hours)
            window_now = utc_now()
            parsed = urlparse(settings.grok_base_url)
            endpoint_host = parsed.netloc or settings.grok_base_url
            logger.info(
                "X collection starting keyword=%r limit=%d batch_count=%d "
                "batch_sizes=%s parallel_cap=%d recency_hours=%d provider_mode=%s "
                "endpoint=%s model=%s timeout=%ss",
                keyword,
                limit,
                len(batch_plan),
                batch_sizes,
                _resolve_positive_int(settings.x_parallel_batches, 1),
                recency_hours,
                settings.grok_provider_mode,
                endpoint_host,
                settings.grok_model,
                settings.grok_http_timeout_seconds,
            )

            tasks = [
                self._query_shard_with_retry(
                    client,
                    keyword,
                    language,
                    name,
                    focus,
                    batch_limit,
                    window_now=window_now,
                    recency_hours=recency_hours,
                )
                for name, focus, batch_limit in batch_plan
            ]
            batch_results: list[list[RawPost] | BaseException] = await asyncio.gather(
                *tasks,
                return_exceptions=True,
            )

            batch_errors: dict[str, SourceCollectionError] = {}
            seen: dict[str | None, RawPost] = {}
            for (dimension_name, _, _), batch in zip(
                batch_plan, batch_results, strict=True
            ):
                if isinstance(batch, BaseException):
                    source_error = self._normalize_request_error(batch)
                    logger.warning(
                        "Grok batch failed "
                        "keyword=%r batch=%r reason_code=%s reason=%s",
                        keyword,
                        dimension_name,
                        source_error.reason_code,
                        source_error.message,
                    )
                    batch_errors[dimension_name] = source_error
                    continue

                for post in batch:
                    if post.source_id and post.source_id in seen:
                        continue
                    seen[post.source_id] = post

            posts = list(seen.values())[:limit]
            if batch_errors and posts:
                raise PartialSourceCollectionError(
                    self._aggregate_batch_reason_code(batch_errors),
                    "X collection partially failed: "
                    f"{self._format_batch_errors(batch_errors)}",
                    partial_posts=posts,
                )

            if not posts and batch_errors:
                raise SourceCollectionError(
                    self._aggregate_batch_reason_code(batch_errors),
                    "X collection failed: "
                    f"{self._format_batch_errors(batch_errors)}",
                )

            logger.info(
                "X collected %d unique posts for keyword=%r",
                len(posts),
                keyword,
            )
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

    def _build_batch_plan(self, limit: int) -> list[tuple[str, str, int]]:
        """Return the X collection batch plan for the requested limit."""
        batch_size = _resolve_positive_int(settings.x_batch_size, 20)
        batch_sizes = _compute_batch_sizes(limit, batch_size)
        if len(batch_sizes) == 1:
            name, focus = _SINGLE_BATCH_PROFILE
            return [(name, focus, batch_sizes[0])]

        batch_plan: list[tuple[str, str, int]] = []
        for index, requested_items in enumerate(batch_sizes):
            profile_name, profile_focus = _BATCH_PROFILES[index % len(_BATCH_PROFILES)]
            batch_plan.append(
                (
                    f"{profile_name} Batch {index + 1}",
                    profile_focus,
                    requested_items,
                )
            )
        return batch_plan

    async def _query_shard_with_retry(
        self,
        client: AsyncOpenAI,
        keyword: str,
        language: str,
        dimension_name: str,
        dimension_focus: str,
        shard_limit: int,
        *,
        window_now: datetime | None = None,
        recency_hours: int | None = None,
    ) -> list[RawPost]:
        """Retry recoverable X gateway failures before surfacing them upward."""
        retry_budget = _resolve_positive_int(settings.x_retry_max_attempts, 2)
        base_delay = _resolve_non_negative_float(
            settings.x_retry_base_delay_seconds,
            1.0,
        )
        attempt = 0
        while True:
            try:
                return await self._query_shard(
                    client,
                    keyword,
                    language,
                    dimension_name,
                    dimension_focus,
                    shard_limit,
                    window_now=window_now,
                    recency_hours=recency_hours,
                )
            except Exception as exc:
                source_error = self._normalize_request_error(exc)
                if (
                    source_error.reason_code
                    not in RECOVERABLE_X_GATEWAY_REASON_CODES
                    or attempt >= retry_budget
                ):
                    raise source_error from exc

                attempt += 1
                delay_seconds = self._compute_retry_delay(base_delay, attempt)
                logger.warning(
                    "Retrying X batch "
                    "keyword=%r batch=%r attempt=%d/%d reason_code=%s delay=%.2fs",
                    keyword,
                    dimension_name,
                    attempt,
                    retry_budget,
                    source_error.reason_code,
                    delay_seconds,
                )
                await asyncio.sleep(delay_seconds)

    async def _query_shard(
        self,
        client: AsyncOpenAI,
        keyword: str,
        language: str,
        dimension_name: str,
        dimension_focus: str,
        shard_limit: int,
        *,
        window_now: datetime | None = None,
        recency_hours: int | None = None,
    ) -> list[RawPost]:
        """Execute a single Grok batch request and parse the response."""
        effective_now = window_now or utc_now()
        effective_recency_hours = (
            recency_hours
            if recency_hours is not None
            else resolve_recency_hours(settings.collection_recency_hours)
        )
        window_start = recency_window_start(
            effective_recency_hours,
            now=effective_now,
        )
        user_prompt = _USER_PROMPT_TEMPLATE.format(
            keyword=keyword,
            target_language=target_language_name(language),
            shard_limit=shard_limit,
            dimension_name=dimension_name,
            dimension_focus=dimension_focus,
            current_utc=format_rfc3339(effective_now),
            window_start=format_rfc3339(window_start),
            recency_hours=effective_recency_hours,
        )

        # New API (and some relays) default to SSE streaming when `stream` is omitted;
        # the SDK then yields a malformed non-stream parse. Force JSON completions.
        async with source_runtime_control.acquire_slot(self.source_name):
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
            posts = self._parse_response(raw_text, dimension_name)
        except ValueError as exc:
            raise SourceCollectionError(
                "grok_invalid_payload",
                str(exc),
            ) from exc
        recent_posts = self._filter_posts_by_recency(
            posts,
            hours=effective_recency_hours,
            window_now=effective_now,
        )
        return self._filter_posts_by_language(recent_posts, language)

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
    def _matches_target_language(text: str, language: str) -> bool:
        """Keep mixed-language content while dropping obvious en/zh mismatches."""
        cjk_count = len(_CJK_RE.findall(text))
        ascii_count = len(_ASCII_ALPHA_RE.findall(text))

        if language == "en":
            return not (cjk_count >= 2 and ascii_count == 0)
        if language == "zh":
            return not (ascii_count >= 6 and cjk_count == 0)
        return True

    def _filter_posts_by_language(
        self, posts: list[RawPost], language: str
    ) -> list[RawPost]:
        """Drop posts that are obviously in the wrong content language."""
        filtered_posts: list[RawPost] = []
        for post in posts:
            if not self._matches_target_language(post.content, language):
                logger.debug(
                    "Skipping X post id=%s for obvious language mismatch target=%s",
                    post.source_id,
                    language,
                )
                continue
            filtered_posts.append(post)
        return filtered_posts

    def _filter_posts_by_recency(
        self,
        posts: list[RawPost],
        *,
        hours: int,
        window_now: datetime,
    ) -> list[RawPost]:
        """Drop posts whose timestamps are missing, invalid, or outside the window."""
        filtered_posts: list[RawPost] = []
        for post in posts:
            if not is_timestamp_in_recency_window(
                post.published_at,
                hours=hours,
                now=window_now,
            ):
                logger.debug(
                    "Skipping X post id=%s outside recent window "
                    "hours=%d published_at=%s",
                    post.source_id,
                    hours,
                    post.published_at,
                )
                continue
            filtered_posts.append(post)
        return filtered_posts

    @staticmethod
    def _normalize_request_error(error: BaseException) -> SourceCollectionError:
        """Convert SDK and transport errors into stable X source failures."""
        if isinstance(error, SourceCollectionError):
            return error
        if isinstance(error, APITimeoutError):
            return SourceCollectionError(
                "grok_timeout",
                "Timed out waiting for the X provider response.",
            )
        if isinstance(error, APIConnectionError):
            message = str(error).strip() or "Connection error."
            return SourceCollectionError("grok_connection_error", message)
        if isinstance(error, APIStatusError):
            message = str(error).strip() or error.__class__.__name__
            if error.status_code == 429:
                return SourceCollectionError("grok_rate_limited", message)
            if isinstance(error.status_code, int) and error.status_code >= 500:
                return SourceCollectionError("grok_upstream_unavailable", message)
            return SourceCollectionError("grok_provider_error", message)
        message = str(error).strip() or error.__class__.__name__
        return SourceCollectionError("grok_collection_failed", message)

    @staticmethod
    def _compute_retry_delay(base_delay: float, attempt: int) -> float:
        """Return exponential backoff with bounded positive jitter."""
        if base_delay <= 0:
            return 0.0
        return (base_delay * (2 ** (attempt - 1))) + random.uniform(
            0.0,
            base_delay,
        )

    @staticmethod
    def _format_batch_errors(batch_errors: dict[str, SourceCollectionError]) -> str:
        """Render batch failures into a readable summary string."""
        return "; ".join(
            f"{batch_name}: {error.reason_code} ({error.message})"
            for batch_name, error in batch_errors.items()
        )

    @staticmethod
    def _aggregate_batch_reason_code(
        batch_errors: dict[str, SourceCollectionError],
    ) -> str:
        """Return a source-level reason code for failed X batches."""
        reason_codes = {error.reason_code for error in batch_errors.values()}
        if len(reason_codes) == 1:
            return reason_codes.pop()
        return "grok_batches_failed"
