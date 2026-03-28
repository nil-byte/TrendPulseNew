"""Reddit data collection adapter using asyncpraw."""

from __future__ import annotations

import logging
from datetime import datetime, timezone

import asyncpraw  # type: ignore[import-untyped]

from src.adapters.base import BaseAdapter
from src.config.settings import settings
from src.models.schemas import RawPost

logger = logging.getLogger(__name__)


class RedditAdapter(BaseAdapter):
    """Collect posts from Reddit via the official API (asyncpraw)."""

    @property
    def source_name(self) -> str:
        return "reddit"

    async def collect(
        self, keyword: str, language: str, limit: int
    ) -> list[RawPost]:
        """Search Reddit for posts matching *keyword*.

        Args:
            keyword: Search keyword.
            language: Language code (en/zh).
            limit: Maximum number of posts to collect.

        Returns:
            List of collected raw posts.
        """
        if not settings.reddit_client_id or not settings.reddit_client_secret:
            logger.warning("Reddit credentials not configured — skipping collection")
            return []

        posts: list[RawPost] = []
        try:
            reddit = asyncpraw.Reddit(
                client_id=settings.reddit_client_id,
                client_secret=settings.reddit_client_secret,
                user_agent=settings.reddit_user_agent,
            )

            async with reddit:
                subreddit = await reddit.subreddit("all")
                async for submission in subreddit.search(
                    keyword,
                    sort="relevance",
                    time_filter="week",
                    limit=limit,
                ):
                    content_parts = [submission.title or ""]
                    if submission.selftext:
                        content_parts.append(submission.selftext)
                    content = "\n\n".join(content_parts).strip()
                    if not content:
                        continue

                    author_name = (
                        str(submission.author) if submission.author else None
                    )
                    published_at = datetime.fromtimestamp(
                        submission.created_utc, tz=timezone.utc
                    ).isoformat()

                    posts.append(
                        RawPost(
                            source="reddit",
                            source_id=submission.id,
                            author=author_name,
                            content=content,
                            url=f"https://www.reddit.com{submission.permalink}",
                            engagement=int(submission.score),
                            published_at=published_at,
                        )
                    )

        except Exception:
            logger.exception("Reddit collection failed for keyword=%r", keyword)

        logger.info("Reddit collected %d posts for keyword=%r", len(posts), keyword)
        return posts
