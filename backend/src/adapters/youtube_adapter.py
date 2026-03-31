"""YouTube data collection adapter using Google API client + transcript API."""

from __future__ import annotations

import asyncio
import logging
from collections import Counter
from dataclasses import dataclass
from typing import Any

from googleapiclient.discovery import build  # type: ignore[import-untyped]
from youtube_transcript_api import (  # type: ignore[import-untyped]
    AgeRestricted,
    CouldNotRetrieveTranscript,
    InvalidVideoId,
    IpBlocked,
    NoTranscriptFound,
    RequestBlocked,
    TranscriptsDisabled,
    VideoUnavailable,
    VideoUnplayable,
    YouTubeTranscriptApi,
)

from src.adapters.base import BaseAdapter, SourceCollectionError
from src.config.settings import settings
from src.models.schemas import RawPost

logger = logging.getLogger(__name__)

_TRANSCRIPT_MAX_CHARS = 2000


@dataclass(slots=True)
class _TranscriptResult:
    text: str | None
    status: str
    error_code: str | None = None
    language: str | None = None
    language_code: str | None = None
    is_generated: bool | None = None


class YouTubeAdapter(BaseAdapter):
    """Collect videos (with transcripts) from YouTube."""

    _MISSING_API_KEY_CODE = "youtube_api_key_missing"
    _MISSING_API_KEY_MESSAGE = "YouTube API key is not configured"

    @property
    def source_name(self) -> str:
        return "youtube"

    async def collect(
        self, keyword: str, language: str, limit: int
    ) -> list[RawPost]:
        """Search YouTube and fetch transcripts for matching videos.

        Args:
            keyword: Search keyword.
            language: Language code (en/zh) — used to prefer transcript language.
            limit: Maximum number of posts to collect.

        Returns:
            List of collected raw posts.
        """
        if not settings.youtube_api_key:
            logger.warning(self._MISSING_API_KEY_MESSAGE)
            raise SourceCollectionError(
                self._MISSING_API_KEY_CODE,
                self._MISSING_API_KEY_MESSAGE,
            )

        posts: list[RawPost] = []
        transcript_status_counts: Counter[str] = Counter()
        try:
            videos = await asyncio.to_thread(
                self._search_videos,
                keyword,
                language,
                limit,
            )
            for video in videos:
                post, transcript_result = await asyncio.to_thread(
                    self._process_video,
                    video,
                    language,
                )
                transcript_status_counts[transcript_result.status] += 1
                logger.info(
                    "YouTube transcript result "
                    "video_id=%s status=%s error_code=%s language_code=%s "
                    "is_generated=%s",
                    video["video_id"],
                    transcript_result.status,
                    transcript_result.error_code,
                    transcript_result.language_code,
                    transcript_result.is_generated,
                )
                if post is not None:
                    posts.append(post)
        except SourceCollectionError:
            raise
        except Exception as exc:
            logger.exception("YouTube collection failed for keyword=%r", keyword)
            raise SourceCollectionError(
                "youtube_collection_failed",
                f"YouTube collection failed: {exc}",
            ) from exc

        logger.info(
            "YouTube collected %d posts for keyword=%r transcript_summary=%s",
            len(posts),
            keyword,
            dict(transcript_status_counts),
        )
        return posts

    # ------------------------------------------------------------------
    # Private helpers (synchronous — YouTube client lib is sync)
    # ------------------------------------------------------------------

    def _search_videos(
        self, keyword: str, language: str, limit: int
    ) -> list[dict[str, Any]]:
        """Call YouTube Data API v3 search + videos.list for statistics."""
        youtube = build("youtube", "v3", developerKey=settings.youtube_api_key)
        search_kwargs: dict[str, Any] = {
            "q": keyword,
            "part": "snippet",
            "type": "video",
            "maxResults": limit,
        }
        relevance_language = self._map_relevance_language(language)
        if relevance_language is not None:
            search_kwargs["relevanceLanguage"] = relevance_language

        search_resp = (
            youtube.search()
            .list(**search_kwargs)
            .execute()
        )
        items: list[dict[str, Any]] = search_resp.get("items", [])
        if not items:
            return []

        video_ids = [it["id"]["videoId"] for it in items]
        stats_resp = (
            youtube.videos()
            .list(id=",".join(video_ids), part="statistics")
            .execute()
        )
        stats_map: dict[str, dict[str, Any]] = {
            v["id"]: v["statistics"] for v in stats_resp.get("items", [])
        }

        results: list[dict[str, Any]] = []
        for item in items:
            vid = item["id"]["videoId"]
            snippet = item["snippet"]
            stats = stats_map.get(vid, {})
            results.append(
                {
                    "video_id": vid,
                    "title": snippet.get("title", ""),
                    "channel": snippet.get("channelTitle", ""),
                    "published_at": snippet.get("publishedAt", ""),
                    "view_count": int(stats.get("viewCount", 0)),
                }
            )
        return results

    @staticmethod
    def _map_relevance_language(language: str) -> str | None:
        """Map supported content languages to YouTube search.list values."""
        if language == "zh":
            return "zh-Hans"
        if language == "en":
            return "en"
        return None

    @staticmethod
    def _preferred_transcript_language_codes(language: str) -> list[str]:
        """Return transcript language candidates ordered by product preference."""
        if language == "zh":
            return [
                "zh-Hans",
                "zh-CN",
                "zh-SG",
                "zh",
                "zh-Hant",
                "zh-TW",
                "zh-HK",
            ]
        if language == "en":
            return ["en"]
        return [language, "en"]

    def _fetch_transcript(self, video_id: str, language: str) -> _TranscriptResult:
        """Attempt to fetch and classify a video transcript result."""
        try:
            transcript_api = YouTubeTranscriptApi()
            transcript_list = transcript_api.list(video_id)
            transcript = transcript_list.find_transcript(
                self._preferred_transcript_language_codes(language)
            )
            fetched = transcript.fetch()
            full_text = " ".join(snippet.text for snippet in fetched)
            return _TranscriptResult(
                text=full_text[:_TRANSCRIPT_MAX_CHARS],
                status="fetched",
                language=transcript.language,
                language_code=transcript.language_code,
                is_generated=transcript.is_generated,
            )
        except TranscriptsDisabled:
            return _TranscriptResult(
                text=None,
                status="unavailable",
                error_code="youtube_transcripts_disabled",
            )
        except NoTranscriptFound:
            return _TranscriptResult(
                text=None,
                status="unavailable",
                error_code="youtube_transcript_not_found",
            )
        except VideoUnavailable:
            return _TranscriptResult(
                text=None,
                status="unavailable",
                error_code="youtube_video_unavailable",
            )
        except VideoUnplayable:
            return _TranscriptResult(
                text=None,
                status="unavailable",
                error_code="youtube_video_unplayable",
            )
        except InvalidVideoId:
            return _TranscriptResult(
                text=None,
                status="unavailable",
                error_code="youtube_invalid_video_id",
            )
        except AgeRestricted:
            return _TranscriptResult(
                text=None,
                status="unavailable",
                error_code="youtube_age_restricted",
            )
        except (IpBlocked, RequestBlocked):
            return _TranscriptResult(
                text=None,
                status="blocked",
                error_code="youtube_transcript_request_blocked",
            )
        except CouldNotRetrieveTranscript:
            return _TranscriptResult(
                text=None,
                status="unavailable",
                error_code="youtube_transcript_unavailable",
            )
        except Exception:
            logger.exception("Unexpected transcript error for video_id=%s", video_id)
            return _TranscriptResult(
                text=None,
                status="error",
                error_code="youtube_transcript_error",
            )

    def _process_video(
        self, video: dict[str, Any], language: str
    ) -> tuple[RawPost | None, _TranscriptResult]:
        """Build a RawPost from video metadata + optional transcript."""
        title = video["title"]
        transcript_result = self._fetch_transcript(video["video_id"], language)

        content_parts = [title]
        if transcript_result.text:
            content_parts.append(transcript_result.text)
        content = "\n\n".join(content_parts).strip()
        if not content:
            return None, transcript_result

        return (
            RawPost(
                source="youtube",
                source_id=video["video_id"],
                author=video.get("channel"),
                content=content,
                url=f"https://www.youtube.com/watch?v={video['video_id']}",
                engagement=video.get("view_count", 0),
                published_at=video.get("published_at"),
                metadata_extra={
                    "has_transcript": transcript_result.text is not None,
                    "transcript_status": transcript_result.status,
                    "transcript_error_code": transcript_result.error_code,
                    "transcript_language": transcript_result.language,
                    "transcript_language_code": transcript_result.language_code,
                    "transcript_is_generated": transcript_result.is_generated,
                },
            ),
            transcript_result,
        )
