"""Pydantic request/response schemas.

All models use Pydantic v2 ``BaseModel`` with strict field validators
where appropriate.
"""

from __future__ import annotations

from pydantic import BaseModel, Field, field_validator


# ---------------------------------------------------------------------------
# Shared adapter model
# ---------------------------------------------------------------------------


class RawPost(BaseModel):
    """Unified raw post model returned by all adapters."""

    source: str
    source_id: str | None = None
    author: str | None = None
    content: str
    url: str | None = None
    engagement: int = 0
    published_at: str | None = None
    metadata_extra: dict | None = None  # type: ignore[type-arg]


# ---------------------------------------------------------------------------
# Request models
# ---------------------------------------------------------------------------

_VALID_SOURCES = {"reddit", "youtube", "x"}
_VALID_LANGUAGES = {"en", "zh"}


class CreateTaskRequest(BaseModel):
    """Request body for creating a new analysis task."""

    keyword: str = Field(..., min_length=1, max_length=200)
    language: str = Field(default="en")
    max_items: int = Field(default=50, ge=1, le=100)
    sources: list[str] = Field(default=["reddit", "youtube", "x"])

    @field_validator("keyword")
    @classmethod
    def keyword_not_blank(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("keyword must not be blank")
        return v.strip()

    @field_validator("language")
    @classmethod
    def language_supported(cls, v: str) -> str:
        if v not in _VALID_LANGUAGES:
            raise ValueError(f"language must be one of {sorted(_VALID_LANGUAGES)}")
        return v

    @field_validator("sources")
    @classmethod
    def sources_valid(cls, v: list[str]) -> list[str]:
        if not v:
            raise ValueError("at least one source is required")
        invalid = set(v) - _VALID_SOURCES
        if invalid:
            raise ValueError(
                f"invalid sources: {sorted(invalid)}; "
                f"allowed: {sorted(_VALID_SOURCES)}"
            )
        return v


# ---------------------------------------------------------------------------
# Response models
# ---------------------------------------------------------------------------


class TaskResponse(BaseModel):
    """Single task in API responses."""

    id: str
    keyword: str
    language: str
    max_items: int
    status: str
    sources: list[str]
    created_at: str
    updated_at: str
    error_message: str | None = None


class RawPostResponse(BaseModel):
    """Single raw post in API responses."""

    id: str
    task_id: str
    source: str
    source_id: str | None = None
    author: str | None = None
    content: str
    url: str | None = None
    engagement: int = 0
    published_at: str | None = None
    collected_at: str = ""
    metadata_json: dict | None = None  # type: ignore[type-arg]


class KeyInsight(BaseModel):
    """A single key insight extracted from analysis."""

    text: str
    sentiment: str
    source_count: int


class AnalysisReportResponse(BaseModel):
    """Analysis report in API responses."""

    id: str
    task_id: str
    sentiment_score: float = Field(..., ge=0, le=100)
    positive_ratio: float = Field(..., ge=0, le=1)
    negative_ratio: float = Field(..., ge=0, le=1)
    neutral_ratio: float = Field(..., ge=0, le=1)
    heat_index: float
    key_insights: list[KeyInsight]
    summary: str
    created_at: str


class TaskListResponse(BaseModel):
    """Paginated list of tasks."""

    tasks: list[TaskResponse]
    total: int


class PostListResponse(BaseModel):
    """Paginated list of raw posts."""

    posts: list[RawPostResponse]
    total: int
