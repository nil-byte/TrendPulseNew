"""LLM API adapter for AI analysis."""

from __future__ import annotations

import logging
from typing import Any

from openai import AsyncOpenAI

from src.config.settings import settings

logger = logging.getLogger(__name__)


class LLMAdapter:
    """Adapter for LLM API calls using OpenAI SDK compatible interface."""

    def __init__(self) -> None:
        self._client: AsyncOpenAI | None = None

    @property
    def client(self) -> AsyncOpenAI:
        """Lazy-initialise the async OpenAI client."""
        if self._client is None:
            self._client = AsyncOpenAI(
                api_key=settings.llm_api_key,
                base_url=settings.llm_base_url or None,
            )
        return self._client

    async def chat_completion(
        self,
        system_prompt: str,
        user_prompt: str,
        temperature: float = 0.3,
        max_tokens: int = 4096,
    ) -> str:
        """Send a chat completion request to the LLM.

        Args:
            system_prompt: System message for the LLM.
            user_prompt: User message content.
            temperature: Sampling temperature.
            max_tokens: Maximum tokens in response.

        Returns:
            The LLM's response text.

        Raises:
            RuntimeError: If the API call fails.
        """
        try:
            response = await self.client.chat.completions.create(
                model=settings.llm_model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
                temperature=temperature,
                max_tokens=max_tokens,
            )
            content = response.choices[0].message.content or ""
            if "</think>" in content:
                content = content.split("</think>")[-1].strip()
            return content
        except Exception as e:
            logger.error("LLM API call failed: %s", e)
            raise RuntimeError(f"LLM API call failed: {e}") from e
