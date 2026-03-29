"""Regression tests for the critical-path verification script."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = REPO_ROOT / "scripts" / "verify-critical-paths.sh"


def _write_fake_command(directory: Path, name: str, exit_code: int) -> None:
    """Create a fake executable command for script tests."""
    command_path = directory / name
    command_path.write_text(
        "#!/usr/bin/env bash\n"
        f"exit {exit_code}\n",
        encoding="utf-8",
    )
    command_path.chmod(0o755)


def _script_env(fake_bin_dir: Path) -> dict[str, str]:
    """Build a minimal PATH that only exposes fake commands and core shells."""
    env = os.environ.copy()
    env["PATH"] = f"{fake_bin_dir}:/usr/bin:/bin"
    return env


def test_verify_script_backend_only_skips_flutter_precheck(tmp_path: Path) -> None:
    """`--backend-only` should not require or execute Flutter checks."""
    fake_bin_dir = tmp_path / "bin"
    fake_bin_dir.mkdir()
    _write_fake_command(fake_bin_dir, "python", exit_code=0)

    result = subprocess.run(
        ["/bin/bash", str(SCRIPT_PATH), "--backend-only"],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        env=_script_env(fake_bin_dir),
        check=False,
    )

    assert result.returncode == 0
    assert "运行后端关键链路测试" in result.stdout
    assert "运行 Flutter 关键链路测试" not in result.stdout


def test_verify_script_flutter_only_skips_backend_checks(tmp_path: Path) -> None:
    """`--flutter-only` should not invoke backend validation."""
    fake_bin_dir = tmp_path / "bin"
    fake_bin_dir.mkdir()
    _write_fake_command(fake_bin_dir, "python", exit_code=41)
    _write_fake_command(fake_bin_dir, "flutter", exit_code=0)

    result = subprocess.run(
        ["/bin/bash", str(SCRIPT_PATH), "--flutter-only"],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        env=_script_env(fake_bin_dir),
        check=False,
    )

    assert result.returncode == 0
    assert "运行后端关键链路测试" not in result.stdout
    assert "运行 Flutter 关键链路测试" in result.stdout


def test_verify_script_reports_actionable_message_when_flutter_missing(
    tmp_path: Path,
) -> None:
    """Full verification should fail with a clear hint when Flutter is missing."""
    fake_bin_dir = tmp_path / "bin"
    fake_bin_dir.mkdir()
    _write_fake_command(fake_bin_dir, "python", exit_code=0)

    result = subprocess.run(
        ["/bin/bash", str(SCRIPT_PATH)],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        env=_script_env(fake_bin_dir),
        check=False,
    )

    combined_output = f"{result.stdout}\n{result.stderr}"
    assert result.returncode != 0
    assert "缺少必需命令: flutter" in combined_output
    assert "--backend-only" in combined_output
