"""Time helpers shared across backend modules."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone


def utc_now() -> datetime:
    """Return the current timezone-aware UTC datetime."""
    return datetime.now(timezone.utc)


def utc_now_iso() -> str:
    """Return the current UTC timestamp in ISO-8601 format."""
    return utc_now().isoformat()


def resolve_recency_hours(value: object, default: int = 24) -> int:
    """Return a positive integer recency window, falling back for loose test mocks."""
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


def recency_window_start(hours: int, now: datetime | None = None) -> datetime:
    """Return the inclusive UTC start timestamp for the recency window."""
    current = _normalize_utc_datetime(now or utc_now())
    return current - timedelta(hours=hours)


def format_rfc3339(value: datetime) -> str:
    """Format a datetime as a UTC RFC3339 string without fractional seconds."""
    normalized = _normalize_utc_datetime(value).replace(microsecond=0)
    return normalized.isoformat().replace("+00:00", "Z")


def parse_iso8601_timestamp(value: str | None) -> datetime | None:
    """Parse an ISO8601/RFC3339 timestamp into a UTC datetime, or ``None``.

    Collection adapters require explicit timezone information. Naive timestamps are
    treated as ambiguous and rejected instead of guessing UTC.
    """
    if value is None:
        return None
    normalized = value.strip()
    if not normalized:
        return None
    if normalized.endswith("Z"):
        normalized = f"{normalized[:-1]}+00:00"
    try:
        parsed = datetime.fromisoformat(normalized)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        return None
    return _normalize_utc_datetime(parsed)


def is_timestamp_in_recency_window(
    value: str | None,
    hours: int,
    now: datetime | None = None,
) -> bool:
    """Return whether a timestamp falls inside the inclusive recent UTC window."""
    parsed = parse_iso8601_timestamp(value)
    if parsed is None:
        return False
    current = _normalize_utc_datetime(now or utc_now())
    window_start = recency_window_start(hours, now=current)
    return window_start <= parsed <= current


def _normalize_utc_datetime(value: datetime) -> datetime:
    """Normalize naive or aware datetimes into timezone-aware UTC values."""
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)
