"""Trending keywords endpoint."""

from __future__ import annotations

from fastapi import APIRouter

from src.models.schemas import TrendingKeyword, TrendingListResponse

router = APIRouter(prefix="/trending", tags=["trending"])

_TRENDING_KEYWORDS: list[dict[str, str]] = [
    {"keyword": "AI", "icon": "trending_up", "category": "Technology"},
    {"keyword": "Bitcoin", "icon": "currency_bitcoin", "category": "Finance"},
    {"keyword": "iPhone", "icon": "phone_iphone", "category": "Technology"},
    {"keyword": "Tesla", "icon": "electric_car", "category": "Automotive"},
]


@router.get("", response_model=TrendingListResponse)
async def get_trending() -> TrendingListResponse:
    """Return the current list of trending keywords."""
    keywords = [TrendingKeyword(**kw) for kw in _TRENDING_KEYWORDS]
    return TrendingListResponse(keywords=keywords, total=len(keywords))
