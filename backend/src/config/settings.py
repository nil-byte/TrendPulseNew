"""Application settings and configuration."""

from __future__ import annotations

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application configuration loaded from environment variables.

    All sensitive values (API keys, secrets) are read from environment
    variables or a `.env` file — never hardcoded.
    """

    # Reddit API
    reddit_client_id: str = ""
    reddit_client_secret: str = ""
    reddit_user_agent: str = "TrendPulse/1.0"

    # YouTube API
    youtube_api_key: str = ""

    # Grok API (X data collection)
    grok_api_key: str = ""
    grok_base_url: str = "https://wududu.edu.kg/v1"
    grok_model: str = "grok-4.20-beta"

    # LLM Analysis API (OpenAI SDK compatible)
    llm_api_key: str = ""
    llm_base_url: str = ""
    llm_model: str = ""

    # Server
    host: str = "0.0.0.0"
    port: int = 8000
    debug: bool = True

    # Database
    database_url: str = "sqlite+aiosqlite:///./trendpulse.db"

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


settings = Settings()
