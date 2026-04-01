"""Reddit data collection adapter using asyncpraw."""

from __future__ import annotations

import logging
import re
import ssl
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse

import aiohttp  # type: ignore[import-untyped]
import asyncpraw  # type: ignore[import-untyped]
from asyncprawcore.exceptions import RequestException as PrawRequestException

from src.adapters.base import BaseAdapter, SourceCollectionError
from src.common.time_utils import (
    is_timestamp_in_recency_window,
    resolve_recency_hours,
    utc_now,
)
from src.config.settings import settings
from src.models.schemas import RawPost

logger = logging.getLogger(__name__)

_CJK_RE = re.compile(r"[\u3400-\u4DBF\u4E00-\u9FFF]")
_ASCII_ALPHA_RE = re.compile(r"[A-Za-z]")
_SEARCH_OVERSAMPLE_FACTOR = 3
_MAX_SEARCH_CANDIDATES = 250


class RedditAdapter(BaseAdapter):
    """Collect posts from Reddit via the official API (asyncpraw)."""

    _MISSING_CREDENTIALS_CODE = "reddit_credentials_missing"
    _MISSING_CREDENTIALS_MESSAGE = "Reddit credentials are not configured"

    @property
    def source_name(self) -> str:
        return "reddit"

    async def collect(
        self, keyword: str, language: str, limit: int
    ) -> list[RawPost]:
        """Search Reddit for posts matching *keyword*.

        Args:
            keyword: Search keyword.
            language: Language code (en/zh).
            limit: Maximum number of posts to collect.

        Returns:
            List of collected raw posts.
        """
        if not settings.reddit_client_id or not settings.reddit_client_secret:
            logger.warning(self._MISSING_CREDENTIALS_MESSAGE)
            raise SourceCollectionError(
                self._MISSING_CREDENTIALS_CODE,
                self._MISSING_CREDENTIALS_MESSAGE,
            )

        posts: list[RawPost] = []
        session: aiohttp.ClientSession | None = None
        recency_hours = resolve_recency_hours(settings.collection_recency_hours)
        window_now = utc_now()
        candidate_limit = min(
            max(limit * _SEARCH_OVERSAMPLE_FACTOR, limit),
            _MAX_SEARCH_CANDIDATES,
        )
        try:
            session = self._build_client_session()
            reddit = asyncpraw.Reddit(
                client_id=settings.reddit_client_id,
                client_secret=settings.reddit_client_secret,
                user_agent=settings.reddit_user_agent,
                requestor_kwargs={"session": session},
            )
            logger.info(
                "Reddit collection starting keyword=%r limit=%d "
                "candidate_limit=%d recency_hours=%d "
                "trust_env=true custom_ca=%s proxy_configured=%s",
                keyword,
                limit,
                candidate_limit,
                recency_hours,
                bool(settings.reddit_ssl_ca_file),
                bool(settings.reddit_https_proxy),
            )

            async with reddit:
                subreddit = await reddit.subreddit("all")
                async for submission in subreddit.search(
                    keyword,
                    sort="new",
                    time_filter="day",
                    limit=candidate_limit,
                ):
                    published_at = datetime.fromtimestamp(
                        submission.created_utc, tz=timezone.utc
                    ).isoformat()
                    if not is_timestamp_in_recency_window(
                        published_at,
                        hours=recency_hours,
                        now=window_now,
                    ):
                        logger.debug(
                            "Skipping Reddit post id=%s outside recent window "
                            "hours=%d published_at=%s",
                            submission.id,
                            recency_hours,
                            published_at,
                        )
                        continue

                    content_parts = [submission.title or ""]
                    if submission.selftext:
                        content_parts.append(submission.selftext)
                    content = "\n\n".join(content_parts).strip()
                    if not content:
                        continue
                    if not self._matches_target_language(content, language):
                        logger.debug(
                            "Skipping Reddit post id=%s "
                            "for obvious language mismatch target=%s",
                            submission.id,
                            language,
                        )
                        continue

                    author_name = (
                        str(submission.author) if submission.author else None
                    )

                    posts.append(
                        RawPost(
                            source="reddit",
                            source_id=submission.id,
                            author=author_name,
                            content=content,
                            url=f"https://www.reddit.com{submission.permalink}",
                            engagement=int(submission.score),
                            published_at=published_at,
                        )
                    )
                    if len(posts) >= limit:
                        break

        except SourceCollectionError:
            raise
        except Exception as exc:
            logger.exception("Reddit collection failed for keyword=%r", keyword)
            raise self._map_collection_error(exc) from exc
        finally:
            if session is not None:
                await session.close()

        logger.info("Reddit collected %d posts for keyword=%r", len(posts), keyword)
        return posts

    def _build_client_session(self) -> aiohttp.ClientSession:
        """Create a Reddit HTTP session with isolated proxy/timeout/CA settings."""
        proxy = None
        if settings.reddit_https_proxy.strip():
            proxy = self._validate_https_proxy(settings.reddit_https_proxy)
        if proxy:
            parsed = urlparse(proxy)
            if parsed.hostname:
                port = parsed.port
                port_s = str(port) if port else ""
                host_port = parsed.hostname + (f":{port_s}" if port_s else "")
                logger.info(
                    "Reddit aiohttp session: proxy applied (%s://%s)",
                    parsed.scheme or "http",
                    host_port,
                )
            else:
                logger.info("Reddit aiohttp session: proxy URL applied")
        connector: aiohttp.TCPConnector | None = None
        if settings.reddit_ssl_ca_file:
            validated_ca_file = self._validate_ssl_ca_file(settings.reddit_ssl_ca_file)
            ssl_context = ssl.create_default_context(cafile=validated_ca_file)
            connector = aiohttp.TCPConnector(ssl=ssl_context)
        return aiohttp.ClientSession(
            trust_env=False,
            proxy=proxy,
            connector=connector,
            timeout=aiohttp.ClientTimeout(total=settings.reddit_http_timeout_seconds),
        )

    @staticmethod
    def _matches_target_language(text: str, language: str) -> bool:
        """Keep mixed-language content, filtering only obvious en/zh mismatches."""
        cjk_count = len(_CJK_RE.findall(text))
        ascii_count = len(_ASCII_ALPHA_RE.findall(text))

        if language == "en":
            return not (cjk_count >= 2 and ascii_count == 0)
        if language == "zh":
            return not (ascii_count >= 6 and cjk_count == 0)
        return True

    @staticmethod
    def _validate_ssl_ca_file(ca_file: str) -> str:
        """Return a CA file path only when it exists and can be loaded by ssl."""
        ca_path = Path(ca_file).expanduser()
        if not ca_path.is_file():
            raise SourceCollectionError(
                "reddit_ssl_error",
                "Reddit SSL CA file is missing or unreadable",
            )
        try:
            ssl.create_default_context(cafile=str(ca_path))
        except (OSError, ssl.SSLError) as exc:
            raise SourceCollectionError(
                "reddit_ssl_error",
                "Reddit SSL CA file is missing or unreadable",
            ) from exc
        return str(ca_path)

    @staticmethod
    def _validate_https_proxy(proxy_url: str) -> str:
        """Return a proxy URL only when it is syntactically valid for aiohttp."""
        normalized = proxy_url.strip()
        parsed = urlparse(normalized)
        try:
            port = parsed.port
        except ValueError as exc:
            raise SourceCollectionError(
                "reddit_proxy_required",
                "Reddit proxy URL is invalid",
            ) from exc
        if parsed.scheme not in {"http", "https"} or not parsed.hostname:
            raise SourceCollectionError(
                "reddit_proxy_required",
                "Reddit proxy URL is invalid",
            )
        if port is not None and port <= 0:
            raise SourceCollectionError(
                "reddit_proxy_required",
                "Reddit proxy URL is invalid",
            )
        return normalized

    @staticmethod
    def _exception_chain_message(exc: BaseException) -> str:
        """Short message with nested causes (asyncpraw often masks aiohttp)."""
        parts: list[str] = []
        current: BaseException | None = exc
        seen: set[int] = set()
        while current is not None and len(parts) < 5:
            ident = id(current)
            if ident in seen:
                break
            seen.add(ident)
            part = str(current).strip() or current.__class__.__name__
            if part:
                parts.append(part)
            current = current.__cause__ or current.__context__
        return "; ".join(parts)

    @staticmethod
    def _map_collection_error(exc: Exception) -> SourceCollectionError:
        """Convert asyncpraw/aiohttp failures into stable source error codes."""
        root: BaseException = exc
        if isinstance(exc, PrawRequestException):
            root = exc.original_exception
        message = RedditAdapter._exception_chain_message(root)
        lowered = message.lower()
        proxy_host = urlparse(settings.reddit_https_proxy).hostname
        if proxy_host and proxy_host.lower() in lowered or "proxy" in lowered:
            reason_code = "reddit_proxy_required"
        elif "cannot connect to host" in lowered:
            reason_code = "reddit_network_unreachable"
        elif "timeout" in lowered or "timed out" in lowered:
            reason_code = "reddit_timeout"
        elif "ssl" in lowered or "certificate" in lowered:
            reason_code = "reddit_ssl_error"
        else:
            reason_code = "reddit_collection_failed"
        return SourceCollectionError(
            reason_code,
            f"Reddit collection failed: {message}",
        )
