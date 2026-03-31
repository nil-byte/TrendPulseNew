"""Regression tests for the Android dev launcher script."""

from __future__ import annotations

import os
import shutil
import signal
import subprocess
import time
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT_SOURCE_PATH = REPO_ROOT / "scripts" / "dev-android.sh"


def _write_executable(path: Path, content: str) -> None:
    """Write an executable helper script."""
    path.write_text(content, encoding="utf-8")
    path.chmod(0o755)


def _prepare_fake_repo(tmp_path: Path) -> tuple[Path, Path]:
    """Create a minimal fake repo layout for exercising the launcher script."""
    repo_root = tmp_path / "repo"
    state_dir = tmp_path / "state"
    state_dir.mkdir()

    script_dir = repo_root / "scripts"
    app_android_dir = repo_root / "app" / "android" / "app"
    backend_venv_dir = repo_root / "backend" / ".venv" / "bin"

    script_dir.mkdir(parents=True)
    app_android_dir.mkdir(parents=True)
    backend_venv_dir.mkdir(parents=True)

    shutil.copy2(SCRIPT_SOURCE_PATH, script_dir / "dev-android.sh")
    (app_android_dir / "build.gradle.kts").write_text(
        (
            "android {\n"
            "    defaultConfig {\n"
            '        applicationId = "com.example.trendpulse"\n'
            "    }\n"
            "}\n"
        ),
        encoding="utf-8",
    )
    _write_executable(
        backend_venv_dir / "uvicorn",
        """#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' INT TERM
while true; do
  sleep 1
done
""",
    )
    return repo_root, state_dir


def _prepare_fake_bin(tmp_path: Path) -> Path:
    """Create fake commands consumed by the launcher script."""
    fake_bin_dir = tmp_path / "bin"
    fake_bin_dir.mkdir()

    _write_executable(
        fake_bin_dir / "adb",
        """#!/usr/bin/env bash
set -euo pipefail
state_dir="${FAKE_STATE_DIR:?}"
log_file="$state_dir/adb.log"
reverse_file="$state_dir/reverse.log"
printf '%s\\n' "$*" >> "$log_file"

if [[ "${1:-}" == "devices" ]]; then
  printf 'List of devices attached\\nemulator-5554\\tdevice\\n'
  exit 0
fi

if [[ "${1:-}" == "-s" && "${3:-}" == "shell" && "${4:-}" == "getprop" ]]; then
  printf '1\\r\\n'
  exit 0
fi

if [[ "${1:-}" == "-s" && "${3:-}" == "reverse" && "${4:-}" == "--list" ]]; then
  if [[ -f "$reverse_file" ]]; then
    cat "$reverse_file"
  fi
  exit 0
fi

if [[ "${1:-}" == "-s" && "${3:-}" == "reverse" && "${4:-}" == "--remove" ]]; then
  if [[ -f "$reverse_file" ]]; then
    tmp_file="$state_dir/reverse.tmp"
    grep -Fv "host-15 ${5} ${5}" "$reverse_file" > "$tmp_file" || true
    mv "$tmp_file" "$reverse_file"
  fi
  exit 0
fi

if [[ "${1:-}" == "-s" && "${3:-}" == "reverse" ]]; then
  printf 'host-15 %s %s\\n' "${4}" "${5}" >> "$reverse_file"
  exit 0
fi

exit 0
""",
    )
    _write_executable(
        fake_bin_dir / "curl",
        """#!/usr/bin/env bash
exit 0
""",
    )
    _write_executable(
        fake_bin_dir / "flutter",
        """#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "clean" ]]; then
  exit 0
fi
if [[ "${1:-}" == "emulators" ]]; then
  exit 0
fi
if [[ "${1:-}" == "run" ]]; then
  echo "Flutter run key commands."
  trap 'exit 0' INT TERM
  while true; do
    sleep 1
  done
fi
exit 0
""",
    )
    _write_executable(
        fake_bin_dir / "pgrep",
        """#!/usr/bin/env bash
exit 1
""",
    )
    _write_executable(
        fake_bin_dir / "setsid",
        """#!/usr/bin/env bash
exec "$@"
""",
    )

    return fake_bin_dir


def _script_env(fake_bin_dir: Path, state_dir: Path) -> dict[str, str]:
    """Build an isolated PATH for the launcher regression test."""
    env = os.environ.copy()
    env["PATH"] = f"{fake_bin_dir}:/usr/bin:/bin"
    env["FAKE_STATE_DIR"] = str(state_dir)
    return env


def _run_script_until_started(
    script_path: Path,
    repo_root: Path,
    env: dict[str, str],
) -> tuple[int, str]:
    """Run the launcher until startup completes, then interrupt it cleanly."""
    process = subprocess.Popen(
        ["/bin/bash", str(script_path)],
        cwd=repo_root,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        env=env,
        bufsize=1,
    )
    lines: list[str] = []

    try:
      deadline = time.monotonic() + 15
      started = False
      assert process.stdout is not None
      while time.monotonic() < deadline:
          line = process.stdout.readline()
          if line:
              lines.append(line)
              if "启动完成，脚本会保持前台运行。" in line:
                  started = True
                  break
          elif process.poll() is not None:
              break

      if not started:
          raise AssertionError(f"script did not reach started state:\n{''.join(lines)}")

      process.send_signal(signal.SIGINT)
      remaining_output, _ = process.communicate(timeout=10)
      lines.append(remaining_output)
      return process.returncode, "".join(lines)
    finally:
      if process.poll() is None:
          process.kill()
          process.wait(timeout=5)


def test_dev_android_script_bridges_android_localhost_to_backend(
    tmp_path: Path,
) -> None:
    """The launcher must create and clean adb reverse mappings for the API."""
    repo_root, state_dir = _prepare_fake_repo(tmp_path)
    fake_bin_dir = _prepare_fake_bin(tmp_path)

    return_code, output = _run_script_until_started(
        repo_root / "scripts" / "dev-android.sh",
        repo_root,
        _script_env(fake_bin_dir, state_dir),
    )

    adb_log = (state_dir / "adb.log").read_text(encoding="utf-8")

    assert return_code == 130, output
    assert "reverse tcp:8000 tcp:8000" in adb_log
    assert "reverse --remove tcp:8000" in adb_log
