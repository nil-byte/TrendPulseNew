"""Regression tests for sanitized Grok configuration artifacts."""

from __future__ import annotations

import re
from pathlib import Path

import pytest
from pydantic import ValidationError

from src.config.settings import Settings

BACKEND_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = BACKEND_DIR.parent
REPORT_PATH = REPO_ROOT / "GROK_API_INTEGRATION_REPORT.md"
README_PATH = REPO_ROOT / "README.md"
APP_README_PATH = REPO_ROOT / "app/README.md"
DEMO_RUNBOOK_PATH = REPO_ROOT / "docs/demo-acceptance-runbook.md"
DOCS_GROK_REPORT_PATH = REPO_ROOT / "docs/GROK_API_INTEGRATION_REPORT.md"
DOCS_OBJECTIVE_PATH = REPO_ROOT / "docs/Objective.md"
VERIFY_SCRIPT_PATH = REPO_ROOT / "scripts/verify-critical-paths.sh"
DEV_ANDROID_SCRIPT_PATH = REPO_ROOT / "scripts/dev-android.sh"
ENV_EXAMPLE_PATH = BACKEND_DIR / ".env.example"
SETTINGS_PATH = BACKEND_DIR / "src/config/settings.py"

OFFICIAL_GROK_BASE_URL = "https://api.x.ai/v1"
OFFICIAL_GROK_MODEL = "grok-4.20-reasoning"
OFFICIAL_GROK_API_KEY_PLACEHOLDER = "<YOUR_XAI_API_KEY_HERE>"
REAL_LOOKING_API_KEY_PATTERN = re.compile(
    r"\b(?:(?:sk|xai)-[A-Za-z0-9_-]{10,}|AIza[0-9A-Za-z_-]{35})\b"
)

VISIBLE_GROK_ARTIFACTS = (
    REPORT_PATH,
    ENV_EXAMPLE_PATH,
    SETTINGS_PATH,
)

PUBLIC_TEXT_ARTIFACT_PATTERNS = (
    "**/README.md",
    "GROK_API_INTEGRATION_REPORT.md",
    "docs/**/*.md",
    "scripts/**/*.sh",
    "backend/.env.example",
)

EXPECTED_PUBLIC_TEXT_ARTIFACTS = (
    README_PATH,
    APP_README_PATH,
    REPORT_PATH,
    DOCS_GROK_REPORT_PATH,
    DOCS_OBJECTIVE_PATH,
    ENV_EXAMPLE_PATH,
    DEMO_RUNBOOK_PATH,
    DEV_ANDROID_SCRIPT_PATH,
    VERIFY_SCRIPT_PATH,
)


def _collect_public_text_artifacts() -> tuple[Path, ...]:
    """Collect public docs, scripts, and example configs that must stay secret-free."""
    collected = {
        path
        for pattern in PUBLIC_TEXT_ARTIFACT_PATTERNS
        for path in REPO_ROOT.glob(pattern)
        if path.is_file()
        and all(
            not part.startswith(".") for part in path.relative_to(REPO_ROOT).parts[:-1]
        )
    }
    return tuple(sorted(collected, key=lambda path: str(path.relative_to(REPO_ROOT))))


PUBLIC_TEXT_ARTIFACTS_WITHOUT_SECRETS = _collect_public_text_artifacts()


def _clear_grok_env(monkeypatch: pytest.MonkeyPatch) -> None:
    """Remove Grok-related environment variables for deterministic settings tests."""
    for key in (
        "GROK_PROVIDER_MODE",
        "GROK_API_KEY",
        "GROK_BASE_URL",
        "GROK_MODEL",
    ):
        monkeypatch.delenv(key, raising=False)


def _read_text(path: Path) -> str:
    """Read a repository file as UTF-8 text."""
    return path.read_text(encoding="utf-8")


def _extract_markdown_backtick_value(path: Path, label: str) -> str:
    """Extract a backticked config value from a markdown bullet."""
    match = re.search(
        rf"\*\s+\*\*{re.escape(label)}\*\*:\s*`([^`]+)`",
        _read_text(path),
    )
    assert match is not None, f"Could not extract {label!r} from {path}."
    return match.group(1)


def _extract_env_assignment(path: Path, key: str) -> str:
    """Extract an environment variable assignment from `.env.example`."""
    match = re.search(rf"^{re.escape(key)}=(.+)$", _read_text(path), re.MULTILINE)
    assert match is not None, f"Could not extract {key!r} from {path}."
    return match.group(1)


def _extract_python_string_default(path: Path, field_name: str) -> str:
    """Extract a string default value from the settings module."""
    match = re.search(
        rf'^\s*{re.escape(field_name)}: str = "([^"]+)"$',
        _read_text(path),
        re.MULTILINE,
    )
    assert match is not None, f"Could not extract {field_name!r} from {path}."
    return match.group(1)


def _extract_documented_grok_base_url(path: Path) -> str:
    """Extract the canonical Grok base URL from a documented config file."""
    if path == REPORT_PATH:
        return _extract_markdown_backtick_value(path, "Base URL")
    if path == ENV_EXAMPLE_PATH:
        return _extract_env_assignment(path, "GROK_BASE_URL")
    if path == SETTINGS_PATH:
        return _extract_python_string_default(path, "grok_base_url")

    raise AssertionError(f"Unsupported base URL extraction target: {path}")


def _extract_documented_grok_model(path: Path) -> str:
    """Extract the canonical Grok model identifier from a documented config file."""
    if path == REPORT_PATH:
        return _extract_markdown_backtick_value(path, "Model")
    if path == ENV_EXAMPLE_PATH:
        return _extract_env_assignment(path, "GROK_MODEL")
    if path == SETTINGS_PATH:
        return _extract_python_string_default(path, "grok_model")

    raise AssertionError(f"Unsupported model extraction target: {path}")


@pytest.mark.parametrize(
    "token",
    (
        "sk-example-token",
        "xai-example-token",
        "AIza" + "A" * 35,
    ),
)
def test_real_looking_api_key_pattern_matches_supported_prefixes(token: str) -> None:
    """Guardrails should detect real-looking keys from supported provider prefixes."""
    assert REAL_LOOKING_API_KEY_PATTERN.search(token) is not None


def test_guardrail_targets_visible_grok_artifacts_only() -> None:
    """Repository hygiene guardrails should only scan visible docs/config artifacts."""
    assert VISIBLE_GROK_ARTIFACTS == (
        REPORT_PATH,
        ENV_EXAMPLE_PATH,
        SETTINGS_PATH,
    )


def test_target_files_do_not_contain_real_looking_api_keys() -> None:
    """Visible repository artifacts must never ship real-looking API keys."""
    for path in VISIBLE_GROK_ARTIFACTS:
        assert (
            REAL_LOOKING_API_KEY_PATTERN.search(_read_text(path)) is None
        ), f"{path} contains a real-looking API key."


def test_public_artifact_inventory_covers_docs_scripts_and_examples() -> None:
    """Secret scanning scope should cover public docs, scripts, and sample configs."""
    assert set(PUBLIC_TEXT_ARTIFACTS_WITHOUT_SECRETS) == set(
        EXPECTED_PUBLIC_TEXT_ARTIFACTS
    )


def test_public_text_artifacts_do_not_contain_real_looking_api_keys() -> None:
    """Public-facing docs, scripts, and examples must never expose provider keys."""
    for path in PUBLIC_TEXT_ARTIFACTS_WITHOUT_SECRETS:
        assert (
            REAL_LOOKING_API_KEY_PATTERN.search(_read_text(path)) is None
        ), f"{path} contains a real-looking API key."


def test_documented_grok_config_files_only_use_official_base_url() -> None:
    """Documented Grok config values should all resolve to the official base URL."""
    for path in VISIBLE_GROK_ARTIFACTS:
        assert _extract_documented_grok_base_url(path) == OFFICIAL_GROK_BASE_URL


def test_documented_grok_config_files_only_use_official_model() -> None:
    """Documented Grok config values should all resolve to the canonical model."""
    for path in VISIBLE_GROK_ARTIFACTS:
        assert _extract_documented_grok_model(path) == OFFICIAL_GROK_MODEL


def test_env_example_uses_official_grok_placeholder_and_defaults() -> None:
    """`.env.example` should document the default official Grok settings."""
    env_example = _read_text(BACKEND_DIR / ".env.example")

    assert "GROK_PROVIDER_MODE=official_xai" in env_example
    assert f"GROK_API_KEY={OFFICIAL_GROK_API_KEY_PLACEHOLDER}" in env_example
    assert f"GROK_BASE_URL={OFFICIAL_GROK_BASE_URL}" in env_example
    assert f"GROK_MODEL={OFFICIAL_GROK_MODEL}" in env_example


def test_settings_defaults_use_official_grok_defaults(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """`Settings` defaults should align with the documented official Grok config."""
    _clear_grok_env(monkeypatch)

    settings = Settings(_env_file=None)

    assert settings.grok_base_url == OFFICIAL_GROK_BASE_URL
    assert settings.grok_model == OFFICIAL_GROK_MODEL


def test_settings_default_mode_is_official_xai(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Grok should default to the official xAI provider mode."""
    _clear_grok_env(monkeypatch)

    settings = Settings(_env_file=None)

    assert settings.grok_provider_mode == "official_xai"


def test_settings_rejects_custom_base_url_without_compatible_mode(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Custom Grok endpoints must require explicit compatible-mode opt-in."""
    _clear_grok_env(monkeypatch)
    monkeypatch.setenv("GROK_BASE_URL", "https://compatible.example/v1")

    with pytest.raises(ValidationError, match="GROK_PROVIDER_MODE"):
        Settings(_env_file=None)


def test_settings_allows_custom_endpoint_in_compatible_mode(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Explicit compatible mode should allow a custom endpoint and model."""
    _clear_grok_env(monkeypatch)
    monkeypatch.setenv("GROK_PROVIDER_MODE", "openai_compatible")
    monkeypatch.setenv("GROK_BASE_URL", "https://compatible.example/v1")
    monkeypatch.setenv("GROK_MODEL", "grok-compat")

    settings = Settings(_env_file=None)

    assert settings.grok_provider_mode == "openai_compatible"
    assert settings.grok_base_url == "https://compatible.example/v1"
    assert settings.grok_model == "grok-compat"


def test_settings_official_mode_allows_official_endpoint_with_custom_model(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Official mode should still allow an official xAI endpoint with another model."""
    _clear_grok_env(monkeypatch)
    monkeypatch.setenv("GROK_PROVIDER_MODE", "official_xai")
    monkeypatch.setenv("GROK_BASE_URL", "https://api.x.ai/v1/")
    monkeypatch.setenv("GROK_MODEL", "grok-4.20-fast")

    settings = Settings(_env_file=None)

    assert settings.grok_provider_mode == "official_xai"
    assert settings.grok_base_url == OFFICIAL_GROK_BASE_URL
    assert settings.grok_model == "grok-4.20-fast"


def test_settings_rejects_invalid_compatible_base_url(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Compatible mode should validate the configured endpoint URL."""
    _clear_grok_env(monkeypatch)
    monkeypatch.setenv("GROK_PROVIDER_MODE", "openai_compatible")
    monkeypatch.setenv("GROK_BASE_URL", "not-a-url")

    with pytest.raises(ValidationError, match="GROK_BASE_URL"):
        Settings(_env_file=None)
