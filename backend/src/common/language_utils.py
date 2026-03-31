"""Language helpers shared across adapters and services."""

from __future__ import annotations


def target_language_name(language: str) -> str:
    """Return a human-readable label for the supported report/search languages."""
    if language == "zh":
        return "Simplified Chinese"
    return "English"
