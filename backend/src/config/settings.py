"""Application settings and configuration."""

from __future__ import annotations

from pathlib import Path
from typing import Literal
from urllib.parse import urlparse

from pydantic import Field, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

_BACKEND_DIR = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    """Application configuration loaded from environment variables.

    All sensitive values (API keys, secrets) are read from environment
    variables or a `.env` file — never hardcoded.
    """

    # Reddit API
    reddit_client_id: str = ""
    reddit_client_secret: str = ""
    reddit_user_agent: str = "TrendPulse/1.0"
    reddit_https_proxy: str = ""
    reddit_ssl_ca_file: str = ""
    reddit_http_timeout_seconds: float = Field(
        default=45.0,
        ge=5.0,
        le=180.0,
        description="asyncpraw/asyncprawcore per-request timeout (OAuth + API calls).",
        validation_alias="REDDIT_HTTP_TIMEOUT",
    )

    @field_validator("reddit_https_proxy", "reddit_ssl_ca_file", mode="before")
    @classmethod
    def strip_optional_url_fields(cls, value: object) -> object:
        """Trim .env padding so blank-looking proxy lines do not break matching."""
        if isinstance(value, str):
            return value.strip()
        return value

    # YouTube API
    youtube_api_key: str = ""

    # Grok API (X data collection)
    grok_provider_mode: Literal["official_xai", "openai_compatible"] = "official_xai"
    grok_api_key: str = ""
    grok_base_url: str = "https://api.x.ai/v1"
    grok_model: str = "grok-4.20-reasoning"
    grok_http_timeout_seconds: float = Field(
        default=45.0,
        ge=5.0,
        le=180.0,
        description="Per-request timeout for Grok/OpenAI-compatible collection calls.",
        validation_alias="GROK_HTTP_TIMEOUT",
    )
    x_batch_size: int = Field(
        default=20,
        ge=1,
        le=20,
        description="Maximum number of X posts requested from a single Grok call.",
        validation_alias="X_BATCH_SIZE",
    )
    x_parallel_batches: int = Field(
        default=1,
        ge=1,
        le=10,
        description="Maximum number of X Grok batches allowed to run concurrently.",
        validation_alias="X_PARALLEL_BATCHES",
    )
    x_retry_max_attempts: int = Field(
        default=2,
        ge=0,
        le=10,
        description="Retry budget for recoverable X Grok batch failures.",
        validation_alias="X_RETRY_MAX_ATTEMPTS",
    )
    x_retry_base_delay_seconds: float = Field(
        default=1.0,
        ge=0.0,
        le=30.0,
        description="Base backoff delay for recoverable X Grok batch failures.",
        validation_alias="X_RETRY_BASE_DELAY_SECONDS",
    )
    x_failure_threshold: int = Field(
        default=2,
        ge=1,
        le=10,
        description="Consecutive recoverable X failures required before cooldown.",
        validation_alias="X_FAILURE_THRESHOLD",
    )
    x_cooldown_seconds: int = Field(
        default=180,
        ge=1,
        le=3600,
        description="Cooldown duration after repeated recoverable X failures.",
        validation_alias="X_COOLDOWN_SECONDS",
    )

    # LLM Analysis API (OpenAI SDK compatible)
    llm_api_key: str = ""
    llm_base_url: str = ""
    llm_model: str = ""

    # Server
    host: str = "0.0.0.0"
    port: int = 8000
    debug: bool = False
    cors_allowed_origins: str = ""
    cors_allowed_origin_regex: str = r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"

    # Database
    database_url: str = "sqlite+aiosqlite:///./trendpulse.db"

    # Collection recency window
    collection_recency_hours: int = Field(
        default=24,
        ge=1,
        le=168,
        description="Recent-window size applied by source collectors, in hours.",
        validation_alias="COLLECTION_RECENCY_HOURS",
    )

    # Background jobs (tests set ``SCHEDULER_ENABLED=false`` to avoid real scheduler)
    scheduler_enabled: bool = True

    @model_validator(mode="after")
    def validate_grok_provider_configuration(self) -> Settings:
        """Ensure Grok provider mode and endpoint settings remain consistent."""
        base_url = self.grok_base_url.strip().rstrip("/")
        model = self.grok_model.strip()

        if not model:
            raise ValueError("GROK_MODEL must not be blank")

        if self.grok_provider_mode == "official_xai":
            if base_url != "https://api.x.ai/v1":
                raise ValueError(
                    "GROK_PROVIDER_MODE must be 'openai_compatible' when "
                    "GROK_BASE_URL is not the official xAI endpoint"
                )
            self.grok_base_url = base_url
            self.grok_model = model
            return self

        parsed = urlparse(base_url)
        if parsed.scheme not in {"http", "https"} or not parsed.netloc:
            raise ValueError(
                "GROK_BASE_URL must be a valid http:// or https:// URL when "
                "GROK_PROVIDER_MODE='openai_compatible'"
            )

        self.grok_base_url = base_url
        self.grok_model = model
        return self

    model_config = SettingsConfigDict(
        env_file=_BACKEND_DIR / ".env",
        env_file_encoding="utf-8",
    )

    @property
    def parsed_cors_allowed_origins(self) -> list[str]:
        """Return configured CORS origins as a trimmed list."""
        return [
            origin.strip()
            for origin in self.cors_allowed_origins.split(",")
            if origin.strip()
        ]


settings = Settings()
