"""Base adapter abstract class for data collection."""

from __future__ import annotations

from abc import ABC, abstractmethod

from src.models.schemas import RawPost


class BaseAdapter(ABC):
    """Abstract base class for all data collection adapters."""

    @abstractmethod
    async def collect(
        self, keyword: str, language: str, limit: int
    ) -> list[RawPost]:
        """Collect raw posts from a data source.

        Args:
            keyword: Search keyword.
            language: Language code (en/zh).
            limit: Maximum number of posts to collect.

        Returns:
            List of collected raw posts.
        """
        ...

    @property
    @abstractmethod
    def source_name(self) -> str:
        """Return the source platform name (reddit/youtube/x)."""
        ...
