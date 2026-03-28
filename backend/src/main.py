"""TrendPulse Backend - FastAPI Application Entry Point."""

from fastapi import FastAPI

app = FastAPI(
    title="TrendPulse API",
    description="Multi-source sentiment analysis engine",
    version="0.1.0",
)


@app.get("/health")
async def health_check() -> dict[str, str]:
    """Health check endpoint."""
    return {"status": "ok"}
