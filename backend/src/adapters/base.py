"""Base adapter abstract class for data collection."""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Any

from src.models.schemas import RawPost


@dataclass(slots=True, frozen=True)
class SourceFailure:
    """Stable source failure payload used across collection and availability."""

    reason_code: str
    message: str


class SourceCollectionError(RuntimeError):
    """Typed adapter failure with a stable reason code for logs and UI."""

    def __init__(
        self,
        reason_code: str,
        message: str,
        *,
        details: dict[str, Any] | None = None,
    ) -> None:
        super().__init__(message)
        self.reason_code = reason_code
        self.message = message
        self.details = details or {}


class PartialSourceCollectionError(SourceCollectionError):
    """Typed adapter error that still carries partial posts for degraded results."""

    def __init__(
        self,
        reason_code: str,
        message: str,
        *,
        partial_posts: list[RawPost],
        details: dict[str, Any] | None = None,
    ) -> None:
        super().__init__(reason_code, message, details=details)
        self.partial_posts = partial_posts


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
