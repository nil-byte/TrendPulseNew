"""Runtime-aware source availability service."""

from __future__ import annotations

import logging
from dataclasses import dataclass
from threading import Lock

from src.adapters.base import SourceCollectionError
from src.adapters.reddit_adapter import RedditAdapter
from src.adapters.x_adapter import XAdapter
from src.adapters.youtube_adapter import YouTubeAdapter
from src.common.time_utils import utc_now_iso
from src.config.settings import settings
from src.models.schemas import SourceAvailability
from src.services.source_runtime_control import source_runtime_control

_SUPPORTED_SOURCES = ("reddit", "youtube", "x")
logger = logging.getLogger(__name__)

@dataclass(slots=True)
class _RuntimeAvailabilityState:
    status: str
    is_available: bool
    reason_code: str | None
    reason: str | None
    checked_at: str


class SourceAvailabilityService:
    """Resolve which collection sources are safe to use right now."""

    def __init__(self) -> None:
        self._lock = Lock()
        self._runtime_state: dict[str, _RuntimeAvailabilityState] = {}

    def list_availability(
        self,
        requested_sources: list[str] | None = None,
    ) -> list[SourceAvailability]:
        """Return availability metadata for the requested or supported sources."""
        target_sources = requested_sources or list(_SUPPORTED_SOURCES)
        availability: list[SourceAvailability] = []
        for source in target_sources:
            configured, config_reason_code, config_reason = self._resolve_configuration(
                source
            )
            if not configured:
                availability.append(
                    SourceAvailability(
                        source=source,
                        status="unconfigured",
                        is_available=False,
                        reason_code=config_reason_code,
                        reason=config_reason,
                        checked_at=None,
                    )
                )
                continue

            runtime_state = self._get_runtime_state(source)
            if source_runtime_control.is_in_cooldown(source):
                availability.append(
                    SourceAvailability(
                        source=source,
                        status="cooldown",
                        is_available=False,
                        reason_code="grok_cooldown",
                        reason=self._cooldown_reason(source),
                        checked_at=runtime_state.checked_at if runtime_state else None,
                    )
                )
                continue
            if runtime_state is not None:
                availability.append(
                    SourceAvailability(
                        source=source,
                        status=runtime_state.status,
                        is_available=runtime_state.is_available,
                        reason_code=runtime_state.reason_code,
                        reason=runtime_state.reason,
                        checked_at=runtime_state.checked_at,
                    )
                )
                continue

            availability.append(
                SourceAvailability(
                    source=source,
                    status="available",
                    is_available=True,
                    checked_at=None,
                )
            )

        return availability

    def resolve_requested_sources(
        self,
        requested_sources: list[str],
    ) -> tuple[list[str], dict[str, str]]:
        """Split requested sources into runnable and unavailable groups."""
        availability = self.list_availability(requested_sources)
        effective_sources = [item.source for item in availability if item.is_available]
        unavailable_sources = {
            item.source: item.reason or "Source is unavailable"
            for item in availability
            if not item.is_available
        }
        return effective_sources, unavailable_sources

    def record_success(self, source: str) -> None:
        """Mark a source as healthy after a successful collection attempt."""
        source_runtime_control.record_success(source)
        checked_at = utc_now_iso()
        self._set_runtime_state(
            source,
            _RuntimeAvailabilityState(
                status="available",
                is_available=True,
                reason_code=None,
                reason=None,
                checked_at=checked_at,
            ),
        )
        logger.info(
            "Source availability updated source=%s status=available checked_at=%s",
            source,
            checked_at,
        )

    def record_failure(self, source: str, reason_code: str, reason: str) -> None:
        """Mark a source as degraded after a failed collection attempt."""
        cooldown_active = source_runtime_control.record_failure(
            source,
            reason_code=reason_code,
        )
        checked_at = utc_now_iso()
        public_reason = self._public_runtime_reason(source, reason_code)
        self._set_runtime_state(
            source,
            _RuntimeAvailabilityState(
                status="degraded",
                is_available=True,
                reason_code=reason_code,
                reason=public_reason,
                checked_at=checked_at,
            ),
        )
        logger.warning(
            "Source availability updated "
            "source=%s status=%s reason_code=%s checked_at=%s reason=%s",
            source,
            "cooldown" if cooldown_active else "degraded",
            reason_code,
            checked_at,
            reason,
        )

    def reset_runtime_state(self) -> None:
        """Clear runtime health memory for deterministic tests/debugging."""
        with self._lock:
            self._runtime_state.clear()
        source_runtime_control.reset()

    def _get_runtime_state(self, source: str) -> _RuntimeAvailabilityState | None:
        with self._lock:
            return self._runtime_state.get(source)

    def _set_runtime_state(self, source: str, state: _RuntimeAvailabilityState) -> None:
        with self._lock:
            self._runtime_state[source] = state

    @staticmethod
    def _resolve_configuration(source: str) -> tuple[bool, str | None, str | None]:
        """Return whether a source is configured for collection."""
        if source == "reddit":
            configured = bool(
                settings.reddit_client_id and settings.reddit_client_secret,
            )
            if configured and settings.reddit_https_proxy:
                try:
                    RedditAdapter._validate_https_proxy(settings.reddit_https_proxy)
                except SourceCollectionError as exc:
                    return (
                        False,
                        exc.reason_code,
                        exc.message,
                    )
            if configured and settings.reddit_ssl_ca_file:
                try:
                    RedditAdapter._validate_ssl_ca_file(settings.reddit_ssl_ca_file)
                except SourceCollectionError as exc:
                    return (
                        False,
                        exc.reason_code,
                        exc.message,
                    )
            return (
                configured,
                None if configured else RedditAdapter._MISSING_CREDENTIALS_CODE,
                None if configured else RedditAdapter._MISSING_CREDENTIALS_MESSAGE,
            )
        if source == "youtube":
            configured = bool(settings.youtube_api_key)
            return (
                configured,
                None if configured else YouTubeAdapter._MISSING_API_KEY_CODE,
                None if configured else YouTubeAdapter._MISSING_API_KEY_MESSAGE,
            )
        if source == "x":
            configured = bool(settings.grok_api_key)
            return (
                configured,
                None if configured else XAdapter._MISSING_API_KEY_CODE,
                None if configured else XAdapter._MISSING_API_KEY_MESSAGE,
            )
        return False, "unsupported_source", f"Unsupported source: {source}"

    @staticmethod
    def _public_runtime_reason(source: str, reason_code: str) -> str:
        """Return a user-safe runtime reason without leaking low-level details."""
        known_reasons = {
            "reddit_network_unreachable": (
                "Reddit is temporarily unreachable. Check network or proxy settings."
            ),
            "reddit_timeout": "Reddit timed out during the last collection attempt.",
            "reddit_ssl_error": (
                "Reddit connection failed because of an SSL or certificate issue."
            ),
            "reddit_proxy_required": (
                "Reddit connection failed because the configured proxy is unavailable."
            ),
            "youtube_transcript_request_blocked": (
                "YouTube transcript requests are temporarily blocked."
            ),
            "youtube_transcript_unavailable": (
                "YouTube transcripts are temporarily unavailable."
            ),
            "youtube_transcript_error": (
                "YouTube transcript retrieval failed during the last attempt."
            ),
            "grok_rate_limited": (
                "X is temporarily rate limited by the configured provider."
            ),
            "grok_connection_error": (
                "The configured X provider connection failed during the last attempt."
            ),
            "grok_timeout": (
                "The configured X provider timed out during the last attempt."
            ),
            "grok_upstream_unavailable": (
                "The configured X provider was unavailable during the last attempt."
            ),
            "grok_provider_error": "X data collection failed during the last attempt.",
            "grok_provider_incompatible": (
                "The configured X provider returned an incompatible response."
            ),
            "grok_empty_response": (
                "X returned an empty result during the last attempt."
            ),
            "grok_invalid_payload": (
                "X returned an invalid payload during the last attempt."
            ),
            "grok_batches_failed": "X data collection failed during the last attempt.",
            "grok_shards_failed": "X data collection failed during the last attempt.",
            "grok_collection_failed": (
                "X data collection failed during the last attempt."
            ),
            "unknown_collection_error": (
                f"{SourceAvailabilityService._source_label(source)} failed during the "
                "last attempt."
            ),
        }
        return known_reasons.get(
            reason_code,
            (
                f"{SourceAvailabilityService._source_label(source)} "
                "is temporarily degraded."
            ),
        )

    @staticmethod
    def _source_label(source: str) -> str:
        """Return a user-facing source label."""
        if source == "x":
            return "X"
        if source == "youtube":
            return "YouTube"
        if source == "reddit":
            return "Reddit"
        return source.capitalize()

    @staticmethod
    def _cooldown_reason(source: str) -> str:
        """Return a user-facing cooldown message for temporarily disabled sources."""
        return (
            f"{SourceAvailabilityService._source_label(source)} is temporarily "
            "cooling down after repeated upstream failures."
        )


source_availability_service = SourceAvailabilityService()
