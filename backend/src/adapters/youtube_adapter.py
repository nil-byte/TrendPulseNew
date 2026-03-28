"""YouTube data collection adapter using Google API client + transcript API."""

from __future__ import annotations

import logging
from typing import Any

from googleapiclient.discovery import build  # type: ignore[import-untyped]
from youtube_transcript_api import YouTubeTranscriptApi  # type: ignore[import-untyped]

from src.adapters.base import BaseAdapter
from src.config.settings import settings
from src.models.schemas import RawPost

logger = logging.getLogger(__name__)

_TRANSCRIPT_MAX_CHARS = 2000


class YouTubeAdapter(BaseAdapter):
    """Collect videos (with transcripts) from YouTube."""

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
            logger.warning("YouTube API key not configured — skipping collection")
            return []

        posts: list[RawPost] = []
        try:
            videos = self._search_videos(keyword, limit)
            for video in videos:
                post = self._process_video(video, language)
                if post is not None:
                    posts.append(post)
        except Exception:
            logger.exception("YouTube collection failed for keyword=%r", keyword)

        logger.info("YouTube collected %d posts for keyword=%r", len(posts), keyword)
        return posts

    # ------------------------------------------------------------------
    # Private helpers (synchronous — YouTube client lib is sync)
    # ------------------------------------------------------------------

    def _search_videos(self, keyword: str, limit: int) -> list[dict[str, Any]]:
        """Call YouTube Data API v3 search + videos.list for statistics."""
        youtube = build("youtube", "v3", developerKey=settings.youtube_api_key)

        search_resp = (
            youtube.search()
            .list(q=keyword, part="snippet", type="video", maxResults=limit)
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

    def _fetch_transcript(self, video_id: str, language: str) -> str | None:
        """Attempt to fetch and concatenate a video transcript."""
        try:
            transcript_list = YouTubeTranscriptApi.get_transcript(
                video_id, languages=[language, "en"]
            )
            full_text = " ".join(seg["text"] for seg in transcript_list)
            return full_text[:_TRANSCRIPT_MAX_CHARS]
        except Exception:
            logger.debug("No transcript for video %s — skipping transcript", video_id)
            return None

    def _process_video(
        self, video: dict[str, Any], language: str
    ) -> RawPost | None:
        """Build a RawPost from video metadata + optional transcript."""
        title = video["title"]
        transcript = self._fetch_transcript(video["video_id"], language)

        content_parts = [title]
        if transcript:
            content_parts.append(transcript)
        content = "\n\n".join(content_parts).strip()
        if not content:
            return None

        return RawPost(
            source="youtube",
            source_id=video["video_id"],
            author=video.get("channel"),
            content=content,
            url=f"https://www.youtube.com/watch?v={video['video_id']}",
            engagement=video.get("view_count", 0),
            published_at=video.get("published_at"),
            metadata_extra={"has_transcript": transcript is not None},
        )
