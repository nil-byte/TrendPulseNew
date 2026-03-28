"""Multi-source data collection orchestration service."""

from __future__ import annotations

import asyncio
import logging

from src.adapters.base import BaseAdapter
from src.adapters.reddit_adapter import RedditAdapter
from src.adapters.x_adapter import XAdapter
from src.adapters.youtube_adapter import YouTubeAdapter
from src.models.schemas import RawPost

logger = logging.getLogger(__name__)


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
    ) -> list[RawPost]:
        """Collect data from specified sources concurrently.

        Args:
            keyword: Search keyword.
            language: Language code.
            limit: Max items per source.
            sources: List of source names to collect from.

        Returns:
            Combined list of raw posts from all sources.
        """
        tasks: list[asyncio.Task[list[RawPost]]] = []
        valid_sources: list[str] = []
        per_source_limit = max(1, limit // len(sources)) if sources else 0

        for source_name in sources:
            adapter = self._adapters.get(source_name)
            if adapter is None:
                logger.warning("Unknown source: %s", source_name)
                continue
            valid_sources.append(source_name)
            tasks.append(
                asyncio.create_task(
                    self._collect_from_source(adapter, keyword, language, per_source_limit)
                )
            )

        results = await asyncio.gather(*tasks, return_exceptions=True)

        all_posts: list[RawPost] = []
        for i, result in enumerate(results):
            if isinstance(result, BaseException):
                logger.error("Collection failed for source %s: %s", valid_sources[i], result)
                continue
            all_posts.extend(result)

        logger.info("Collected %d total posts from %d sources", len(all_posts), len(valid_sources))
        return all_posts

    async def _collect_from_source(
        self, adapter: BaseAdapter, keyword: str, language: str, limit: int
    ) -> list[RawPost]:
        """Collect from a single source with error handling."""
        try:
            return await adapter.collect(keyword, language, limit)
        except Exception as e:
            logger.error("Adapter %s failed: %s", adapter.source_name, e)
            return []
