"""Pydantic request/response schemas.

All models use Pydantic v2 ``BaseModel`` with strict field validators
where appropriate.
"""

from __future__ import annotations

from pydantic import BaseModel, Field, field_validator, model_validator

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


def _validate_sources_list(v: list[str]) -> list[str]:
    """Validate source names and reject duplicates."""
    if not v:
        raise ValueError("at least one source is required")
    invalid = set(v) - _VALID_SOURCES
    if invalid:
        raise ValueError(
            f"invalid sources: {sorted(invalid)}; "
            f"allowed: {sorted(_VALID_SOURCES)}"
        )
    if len(set(v)) != len(v):
        raise ValueError("duplicate sources are not allowed")
    return v


class CreateTaskRequest(BaseModel):
    """Request body for creating a new analysis task."""

    keyword: str = Field(..., min_length=1, max_length=200)
    language: str = Field(default="en")
    max_items: int = Field(
        default=50,
        ge=1,
        le=100,
        description="Maximum number of items to collect per selected source.",
    )
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
        return _validate_sources_list(v)


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
    subscription_id: str | None = None
    sentiment_score: float | None = Field(default=None, ge=0, le=100)
    post_count: int | None = Field(default=None, ge=0)


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
    mermaid_mindmap: str | None = None
    created_at: str


class TaskListResponse(BaseModel):
    """Paginated list of tasks."""

    tasks: list[TaskResponse]
    total: int


class PostListResponse(BaseModel):
    """Paginated list of raw posts."""

    posts: list[RawPostResponse]
    total: int


class SourceAvailability(BaseModel):
    """Availability metadata for a single collection source."""

    source: str
    status: str
    is_available: bool
    reason: str | None = None
    reason_code: str | None = None
    checked_at: str | None = None


class SourceAvailabilityListResponse(BaseModel):
    """Collection-source availability payload for API responses."""

    sources: list[SourceAvailability]


# ---------------------------------------------------------------------------
# Subscription models
# ---------------------------------------------------------------------------

_VALID_INTERVALS = {"hourly", "6hours", "daily", "weekly"}


class CreateSubscriptionRequest(BaseModel):
    """Request body for creating a subscription."""

    keyword: str = Field(..., min_length=1, max_length=200)
    language: str = Field(default="en")
    max_items: int = Field(
        default=50,
        ge=1,
        le=100,
        description="Maximum number of items to collect per selected source.",
    )
    sources: list[str] = Field(default=["reddit", "youtube", "x"])
    interval: str = Field(default="daily")
    notify: bool | None = Field(default=None)

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
        return _validate_sources_list(v)

    @field_validator("interval")
    @classmethod
    def interval_valid(cls, v: str) -> str:
        if v not in _VALID_INTERVALS:
            raise ValueError(f"interval must be one of {sorted(_VALID_INTERVALS)}")
        return v

    @model_validator(mode="after")
    def notify_must_be_boolean_when_provided(self) -> CreateSubscriptionRequest:
        """Reject explicit ``null`` so callers must send a boolean or omit it."""
        if "notify" in self.model_fields_set and self.notify is None:
            raise ValueError("notify must be a boolean")
        return self


class UpdateSubscriptionRequest(BaseModel):
    """Request body for updating a subscription. All fields optional."""

    keyword: str | None = Field(default=None, min_length=1, max_length=200)
    language: str | None = None
    max_items: int | None = Field(
        default=None,
        ge=1,
        le=100,
        description="Maximum number of items to collect per selected source.",
    )
    sources: list[str] | None = None
    interval: str | None = None
    is_active: bool | None = None
    notify: bool | None = None

    @field_validator("keyword")
    @classmethod
    def keyword_not_blank(cls, v: str | None) -> str | None:
        if v is not None and not v.strip():
            raise ValueError("keyword must not be blank")
        return v.strip() if v else v

    @field_validator("language")
    @classmethod
    def language_supported(cls, v: str | None) -> str | None:
        if v is not None and v not in _VALID_LANGUAGES:
            raise ValueError(f"language must be one of {sorted(_VALID_LANGUAGES)}")
        return v

    @field_validator("sources")
    @classmethod
    def sources_valid(cls, v: list[str] | None) -> list[str] | None:
        if v is not None:
            return _validate_sources_list(v)
        return v

    @field_validator("interval")
    @classmethod
    def interval_valid(cls, v: str | None) -> str | None:
        if v is not None and v not in _VALID_INTERVALS:
            raise ValueError(f"interval must be one of {sorted(_VALID_INTERVALS)}")
        return v


class NotificationSettingsResponse(BaseModel):
    """Notification settings exposed by the backend."""

    subscription_notify_default: bool


class UpdateNotificationSettingsRequest(BaseModel):
    """Request body for updating notification settings."""

    subscription_notify_default: bool
    apply_to_existing: bool


class SubscriptionResponse(BaseModel):
    """Single subscription in API responses."""

    id: str
    keyword: str
    language: str
    max_items: int
    sources: list[str]
    interval: str
    is_active: bool
    notify: bool
    created_at: str
    updated_at: str
    last_run_at: str | None = None
    next_run_at: str | None = None
    unread_alert_count: int = Field(default=0, ge=0)
    latest_unread_alert_task_id: str | None = None
    latest_unread_alert_score: float | None = Field(default=None, ge=0, le=100)


class SubscriptionListResponse(BaseModel):
    """List of subscriptions."""

    subscriptions: list[SubscriptionResponse]
    total: int


# ---------------------------------------------------------------------------
# Trending models
# ---------------------------------------------------------------------------


class TrendingKeyword(BaseModel):
    """A single trending keyword entry."""

    keyword: str
    icon: str
    category: str


class TrendingListResponse(BaseModel):
    """List of trending keywords."""

    keywords: list[TrendingKeyword]
    total: int
