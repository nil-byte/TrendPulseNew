"""Multi-source data collection orchestration service."""

from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass, field

from src.adapters.base import BaseAdapter
from src.adapters.reddit_adapter import RedditAdapter
from src.adapters.x_adapter import XAdapter
from src.adapters.youtube_adapter import YouTubeAdapter
from src.models.schemas import RawPost

logger = logging.getLogger(__name__)


@dataclass(slots=True)
class CollectionResult:
    """Structured collection output with successful posts and source failures."""

    posts: list[RawPost]
    source_errors: dict[str, str] = field(default_factory=dict)

    @property
    def failed_sources(self) -> list[str]:
        """Return failed source names in deterministic iteration order."""
        return list(self.source_errors)


class CollectorService:
    """Orchestrates data collection from multiple sources concurrently."""

    def __init__(self) -> None:
        self._adapters: dict[str, BaseAdapter] = {
            "reddit": RedditAdapter(),
            "youtube": YouTubeAdapter(),
            "x": XAdapter(),
        }

    async def collect(
        self,
        keyword: str,
        language: str,
        limit: int,
        sources: list[str],
    ) -> CollectionResult:
        """Collect data from specified sources concurrently.

        Args:
            keyword: Search keyword.
            language: Language code.
            limit: Max items per source.
            sources: List of source names to collect from.

        Returns:
            Structured posts plus per-source failure metadata.
        """
        source_errors: dict[str, str] = {}
        valid_sources: list[tuple[str, BaseAdapter]] = []

        for source_name in sources:
            adapter = self._adapters.get(source_name)
            if adapter is None:
                error_message = f"Unsupported source: {source_name}"
                logger.warning(error_message)
                source_errors[source_name] = error_message
                continue
            valid_sources.append((source_name, adapter))

        if not valid_sources:
            logger.info("Collected 0 total posts from 0 sources")
            return CollectionResult(posts=[], source_errors=source_errors)

        per_source_limit = max(1, limit // len(valid_sources))
        tasks: list[asyncio.Task[list[RawPost]]] = []
        for _, adapter in valid_sources:
            tasks.append(
                asyncio.create_task(
                    self._collect_from_source(
                        adapter,
                        keyword,
                        language,
                        per_source_limit,
                    )
                )
            )

        results = await asyncio.gather(*tasks, return_exceptions=True)

        all_posts: list[RawPost] = []
        for i, result in enumerate(results):
            if isinstance(result, BaseException):
                source_name = valid_sources[i][0]
                error_message = self._stringify_error(result)
                logger.error(
                    "Collection failed for source %s: %s",
                    source_name,
                    error_message,
                )
                source_errors[source_name] = error_message
                continue
            all_posts.extend(result)

        logger.info(
            "Collected %d total posts from %d sources",
            len(all_posts),
            len(valid_sources),
        )
        return CollectionResult(posts=all_posts, source_errors=source_errors)

    @staticmethod
    def _stringify_error(error: BaseException) -> str:
        """Convert an exception into a readable error summary."""
        message = str(error).strip()
        return message or error.__class__.__name__

    async def _collect_from_source(
        self, adapter: BaseAdapter, keyword: str, language: str, limit: int
    ) -> list[RawPost]:
        """Collect from a single source and bubble adapter failures upward."""
        return await adapter.collect(keyword, language, limit)
