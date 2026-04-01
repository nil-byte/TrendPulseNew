"""Tests for shared UTC recency helpers."""

from __future__ import annotations

from datetime import datetime, timezone

from src.common.time_utils import (
    format_rfc3339,
    is_timestamp_in_recency_window,
    recency_window_start,
)


def test_format_rfc3339_normalizes_utc_datetime() -> None:
    """RFC3339 formatting should use a trailing `Z` for UTC timestamps."""
    value = datetime(2026, 4, 1, 12, 0, 0, 123456, tzinfo=timezone.utc)

    assert format_rfc3339(value) == "2026-04-01T12:00:00Z"


def test_recency_window_start_subtracts_hours_from_current_utc_time() -> None:
    """Window start should be computed relative to the provided UTC clock."""
    now = datetime(2026, 4, 1, 12, 0, tzinfo=timezone.utc)

    assert recency_window_start(24, now=now) == datetime(
        2026,
        3,
        31,
        12,
        0,
        tzinfo=timezone.utc,
    )


def test_is_timestamp_in_recency_window_rejects_stale_or_invalid_values() -> None:
    """Recent `Z` timestamps pass; stale or malformed values do not."""
    now = datetime(2026, 4, 1, 12, 0, tzinfo=timezone.utc)

    assert (
        is_timestamp_in_recency_window(
            "2026-04-01T10:30:00Z",
            hours=24,
            now=now,
        )
        is True
    )
    assert (
        is_timestamp_in_recency_window(
            "2026-03-30T10:29:59Z",
            hours=24,
            now=now,
        )
        is False
    )
    assert (
        is_timestamp_in_recency_window(
            "2026-04-01T10:30:00",
            hours=24,
            now=now,
        )
        is False
    )
    assert is_timestamp_in_recency_window("2026-04-01", hours=24, now=now) is False
    assert is_timestamp_in_recency_window("not-a-timestamp", hours=24, now=now) is False
