"""Multi-source data collection orchestration service."""

from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass, field

from src.adapters.base import (
    BaseAdapter,
    PartialSourceCollectionError,
    SourceCollectionError,
    SourceFailure,
)
from src.adapters.reddit_adapter import RedditAdapter
from src.adapters.x_adapter import XAdapter
from src.adapters.youtube_adapter import YouTubeAdapter
from src.models.schemas import RawPost
from src.services.search_query_service import SearchQueryService
from src.services.source_availability_service import source_availability_service

logger = logging.getLogger(__name__)


@dataclass(slots=True)
class CollectionResult:
    """Structured collection output with successful posts and source failures."""

    posts: list[RawPost]
    source_errors: dict[str, SourceFailure] = field(default_factory=dict)

    @property
    def failed_sources(self) -> list[str]:
        """Return failed source names in deterministic iteration order."""
        return list(self.source_errors)


class CollectorService:
    """Orchestrates data collection from multiple sources concurrently."""

    def __init__(
        self,
        *,
        adapters: dict[str, BaseAdapter] | None = None,
        search_query_service: SearchQueryService | None = None,
    ) -> None:
        self._adapters = adapters or {
            "reddit": RedditAdapter(),
            "youtube": YouTubeAdapter(),
            "x": XAdapter(),
        }
        self._search_query_service = search_query_service or SearchQueryService()

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
        source_errors: dict[str, SourceFailure] = {}
        valid_sources: list[tuple[str, BaseAdapter]] = []

        for source_name in sources:
            adapter = self._adapters.get(source_name)
            if adapter is None:
                error_message = f"Unsupported source: {source_name}"
                logger.warning(error_message)
                source_errors[source_name] = SourceFailure(
                    reason_code="unsupported_source",
                    message=error_message,
                )
                continue
            valid_sources.append((source_name, adapter))

        if not valid_sources:
            logger.info("Collected 0 total posts from 0 sources")
            return CollectionResult(posts=[], source_errors=source_errors)

        per_source_limit = limit
        search_query_result = await self._search_query_service.build_search_query(
            keyword,
            language,
        )
        search_query = search_query_result.query
        logger.info(
            "Collector starting keyword=%r search_query=%r search_query_status=%s "
            "search_query_reason=%r sources=%s max_items_per_source=%d",
            keyword,
            search_query,
            search_query_result.status,
            search_query_result.reason,
            [source_name for source_name, _ in valid_sources],
            per_source_limit,
        )
        tasks: list[asyncio.Task[list[RawPost]]] = []
        for _, adapter in valid_sources:
            tasks.append(
                asyncio.create_task(
                    self._collect_from_source(
                        adapter,
                        search_query,
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
                source_error = self._normalize_error(result)
                partial_posts = self._extract_partial_posts(result)
                logger.error(
                    "Collection failed source=%s reason_code=%s reason=%s partial_posts=%d",
                    source_name,
                    source_error.reason_code,
                    source_error.message,
                    len(partial_posts),
                )
                all_posts.extend(partial_posts)
                source_errors[source_name] = source_error
                source_availability_service.record_failure(
                    source_name,
                    source_error.reason_code,
                    source_error.message,
                )
                continue
            source_name = valid_sources[i][0]
            source_availability_service.record_success(source_name)
            logger.info(
                "Collection succeeded source=%s posts=%d",
                source_name,
                len(result),
            )
            all_posts.extend(result)

        logger.info(
            "Collected %d total posts from %d sources failed_sources=%s",
            len(all_posts),
            len(valid_sources),
            {
                source: failure.reason_code
                for source, failure in sorted(source_errors.items())
            },
        )
        return CollectionResult(posts=all_posts, source_errors=source_errors)

    @staticmethod
    def _normalize_error(error: BaseException) -> SourceFailure:
        """Convert arbitrary adapter failures into stable source error payloads."""
        if isinstance(error, SourceCollectionError):
            return SourceFailure(
                reason_code=error.reason_code,
                message=error.message,
            )
        message = str(error).strip() or error.__class__.__name__
        return SourceFailure(
            reason_code="unknown_collection_error",
            message=message,
        )

    @staticmethod
    def _extract_partial_posts(error: BaseException) -> list[RawPost]:
        """Return partial posts carried by adapters that degraded mid-collection."""
        if isinstance(error, PartialSourceCollectionError):
            return error.partial_posts
        return []

    async def _collect_from_source(
        self, adapter: BaseAdapter, keyword: str, language: str, limit: int
    ) -> list[RawPost]:
        """Collect from a single source and bubble adapter failures upward."""
        return await adapter.collect(keyword, language, limit)
