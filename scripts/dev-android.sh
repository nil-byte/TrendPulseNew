#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/app"
BACKEND_DIR="$ROOT_DIR/backend"
RUN_DIR="$ROOT_DIR/.run"

BACKEND_PID_FILE="$RUN_DIR/backend.pid"
FLUTTER_PID_FILE="$RUN_DIR/flutter.pid"
EMULATOR_SERIAL_FILE="$RUN_DIR/emulator.serial"
BACKEND_LOG_FILE="$RUN_DIR/backend.log"
FLUTTER_LOG_FILE="$RUN_DIR/flutter.log"
BACKEND_PORT="8000"

EMULATOR_ID="${EMULATOR_ID:-Pixel_8_M4}"
APP_PACKAGE="${APP_PACKAGE:-}"
PURGE_DATA=0
CLEANUP_DONE=0
EMULATOR_STARTED_BY_SCRIPT=0
BACKEND_REVERSE_ENABLED=0
BACKEND_PID=""
FLUTTER_PID=""
EMULATOR_SERIAL=""

usage() {
  cat <<'EOF'
用法:
  scripts/dev-android.sh [--purge-data] [--emulator-id <id>]

说明:
  - 清理前后端缓存与构建产物
  - 启动或复用 Android 模拟器
  - 拉起后端与 Flutter
  - 脚本会持续前台运行
  - 按 Ctrl+C 后，自动停止 Flutter、后端、App 进程
  - 如果模拟器是脚本本次启动的，也会一并关闭

选项:
  --purge-data         额外删除 backend/trendpulse.db
  --emulator-id <id>   指定 Flutter emulator id，默认 Pixel_8_M4
EOF
}

log() {
  printf '[dev-android] %s\n' "$*"
}

fail() {
  printf '[dev-android] 错误: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "缺少命令: $1"
}

pid_is_running() {
  local pid="$1"
  [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1
}

resolve_app_package() {
  if [[ -n "$APP_PACKAGE" ]]; then
    return
  fi

  APP_PACKAGE="$(
    awk -F'"' '/applicationId = "/ {print $2; exit}' \
      "$APP_DIR/android/app/build.gradle.kts"
  )"
  [[ -n "$APP_PACKAGE" ]] || fail "无法解析 Android applicationId"
}

ensure_run_dir() {
  mkdir -p "$RUN_DIR"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --purge-data)
        PURGE_DATA=1
        shift
        ;;
      --emulator-id)
        [[ $# -ge 2 ]] || fail "--emulator-id 需要一个值"
        EMULATOR_ID="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fail "未知参数: $1"
        ;;
    esac
  done
}

find_matching_pid() {
  local pattern="$1"
  pgrep -af "$pattern" | awk 'NR == 1 {print $1}' || true
}

spawn_background() {
  local log_file="$1"
  shift

  if command -v setsid >/dev/null 2>&1; then
    setsid nohup "$@" >"$log_file" 2>&1 < /dev/null &
  else
    nohup "$@" >"$log_file" 2>&1 < /dev/null &
  fi
}

stop_pid() {
  local pid="$1"
  local name="$2"
  if ! pid_is_running "$pid"; then
    return
  fi

  log "停止$name 进程 (PID: $pid)"
  kill "$pid" >/dev/null 2>&1 || true
  sleep 2

  if pid_is_running "$pid"; then
    log "$name 未优雅退出，执行强制终止"
    kill -9 "$pid" >/dev/null 2>&1 || true
  fi
}

configure_android_bridges() {
  if adb -s "$EMULATOR_SERIAL" reverse \
      "tcp:$BACKEND_PORT" "tcp:$BACKEND_PORT" >/dev/null 2>&1; then
    BACKEND_REVERSE_ENABLED=1
  fi

  if [[ "$BACKEND_REVERSE_ENABLED" -ne 1 ]]; then
    fail "无法建立 Android localhost:$BACKEND_PORT 到宿主机后端的 adb reverse 映射"
  fi

  local reverse_list=""
  reverse_list="$(
    adb -s "$EMULATOR_SERIAL" reverse --list 2>/dev/null | tr '\n' ';'
  )"

  if [[ "$reverse_list" != *"tcp:$BACKEND_PORT tcp:$BACKEND_PORT"* ]]; then
    fail "adb reverse 状态异常：未找到 localhost:$BACKEND_PORT 的映射"
  fi
}

stop_stale_processes() {
  local stale_flutter_pid=""
  local stale_backend_pid=""

  stale_flutter_pid="$(find_matching_pid "flutter run -d")"
  stale_backend_pid="$(
    find_matching_pid \
      "./.venv/bin/uvicorn src.main:app --host 127.0.0.1 --port 8000"
  )"

  if [[ -n "$stale_flutter_pid" ]]; then
    stop_pid "$stale_flutter_pid" "旧 Flutter"
  fi

  if [[ -n "$stale_backend_pid" ]]; then
    stop_pid "$stale_backend_pid" "旧后端"
  fi
}

clean_caches() {
  log "清理缓存与构建产物"
  rm -rf \
    "$APP_DIR/build" \
    "$APP_DIR/.dart_tool" \
    "$APP_DIR/.flutter-plugins-dependencies" \
    "$BACKEND_DIR/.pytest_cache" \
    "$BACKEND_DIR/.ruff_cache" \
    "$BACKEND_DIR/trendpulse_backend.egg-info" \
    "$BACKEND_DIR/test_trendpulse.db" \
    "$BACKEND_DIR/uv.lock"

  if [[ "$PURGE_DATA" -eq 1 ]]; then
    log "额外删除业务数据库 backend/trendpulse.db"
    rm -f "$BACKEND_DIR/trendpulse.db"
  fi

  (
    cd "$APP_DIR"
    flutter clean >/dev/null
  )
}

find_running_emulator_serial() {
  adb devices | awk 'NR > 1 && $1 ~ /^emulator-/ && $2 == "device" {print $1; exit}'
}

wait_for_emulator_boot() {
  local serial="$1"
  local attempts=120

  for ((i = 1; i <= attempts; i++)); do
    local status
    status="$(
      adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r'
    )"
    if [[ "$status" == "1" ]]; then
      return 0
    fi
    sleep 2
  done

  return 1
}

ensure_emulator() {
  local serial=""
  serial="$(find_running_emulator_serial)"

  if [[ -z "$serial" ]]; then
    log "启动 Android 模拟器: $EMULATOR_ID"
    (
      cd "$APP_DIR"
      flutter emulators --launch "$EMULATOR_ID" >/dev/null
    )
    adb wait-for-device >/dev/null
    EMULATOR_STARTED_BY_SCRIPT=1
    serial="$(find_running_emulator_serial)"
  else
    log "复用已运行的模拟器: $serial"
  fi

  [[ -n "$serial" ]] || fail "未找到可用的 Android 模拟器"

  log "等待模拟器启动完成"
  wait_for_emulator_boot "$serial" || fail "模拟器未在预期时间内启动完成"

  EMULATOR_SERIAL="$serial"
  printf '%s\n' "$EMULATOR_SERIAL" > "$EMULATOR_SERIAL_FILE"
}

wait_for_http_ok() {
  local url="$1"
  local attempts=60

  for ((i = 1; i <= attempts; i++)); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  return 1
}

start_backend() {
  : > "$BACKEND_LOG_FILE"

  log "启动后端服务"
  (
    cd "$BACKEND_DIR"
    spawn_background \
      "$BACKEND_LOG_FILE" \
      ./.venv/bin/uvicorn src.main:app --host 127.0.0.1 --port 8000
    BACKEND_PID="$!"
    echo "$BACKEND_PID" > "$BACKEND_PID_FILE"
  )

  BACKEND_PID="$(cat "$BACKEND_PID_FILE")"

  wait_for_http_ok "http://127.0.0.1:8000/health" || {
    tail -n 50 "$BACKEND_LOG_FILE" >&2 || true
    fail "后端健康检查失败"
  }
}

start_flutter() {
  : > "$FLUTTER_LOG_FILE"

  log "拉起 Flutter 到模拟器 $EMULATOR_SERIAL"
  (
    cd "$APP_DIR"
    spawn_background "$FLUTTER_LOG_FILE" flutter run -d "$EMULATOR_SERIAL"
    FLUTTER_PID="$!"
    echo "$FLUTTER_PID" > "$FLUTTER_PID_FILE"
  )

  FLUTTER_PID="$(cat "$FLUTTER_PID_FILE")"

  local attempts=180
  for ((i = 1; i <= attempts; i++)); do
    if grep -q "Flutter run key commands." "$FLUTTER_LOG_FILE"; then
      return 0
    fi
    if grep -q "Application finished." "$FLUTTER_LOG_FILE"; then
      tail -n 100 "$FLUTTER_LOG_FILE" >&2 || true
      fail "Flutter 启动后立即退出"
    fi
    sleep 1
  done

  tail -n 100 "$FLUTTER_LOG_FILE" >&2 || true
  fail "Flutter 未在预期时间内完成启动"
}

stop_android_app() {
  if [[ -z "$EMULATOR_SERIAL" ]] || [[ -z "$APP_PACKAGE" ]]; then
    return
  fi

  adb -s "$EMULATOR_SERIAL" shell am force-stop "$APP_PACKAGE" \
    >/dev/null 2>&1 || true
}

cleanup() {
  if [[ "$CLEANUP_DONE" -eq 1 ]]; then
    return
  fi
  CLEANUP_DONE=1

  log "开始清理运行进程"
  stop_android_app
  stop_pid "${FLUTTER_PID:-}" "Flutter"
  stop_pid "${BACKEND_PID:-}" "后端"

  if [[ "$BACKEND_REVERSE_ENABLED" -eq 1 ]] && [[ -n "$EMULATOR_SERIAL" ]]; then
    adb -s "$EMULATOR_SERIAL" reverse --remove "tcp:$BACKEND_PORT" \
      >/dev/null 2>&1 || true
  fi

  if [[ "$EMULATOR_STARTED_BY_SCRIPT" -eq 1 ]] && [[ -n "$EMULATOR_SERIAL" ]]; then
    log "关闭本次启动的模拟器 $EMULATOR_SERIAL"
    adb -s "$EMULATOR_SERIAL" emu kill >/dev/null 2>&1 || true
  fi

  rm -f \
    "$BACKEND_PID_FILE" \
    "$FLUTTER_PID_FILE" \
    "$EMULATOR_SERIAL_FILE"
}

handle_interrupt() {
  log "收到中断信号，准备停止前后端和模拟器"
  cleanup
  exit 130
}

monitor_processes() {
  while true; do
    if ! pid_is_running "$BACKEND_PID"; then
      tail -n 50 "$BACKEND_LOG_FILE" >&2 || true
      fail "后端进程意外退出"
    fi

    if ! pid_is_running "$FLUTTER_PID"; then
      tail -n 100 "$FLUTTER_LOG_FILE" >&2 || true
      fail "Flutter 进程意外退出"
    fi

    sleep 2
  done
}

print_summary() {
  cat <<EOF

启动完成，脚本会保持前台运行。
按 Ctrl+C 会自动停止本次启动的内容。

  Android 模拟器: ${EMULATOR_SERIAL}
  App 包名: ${APP_PACKAGE}
  后端健康检查: http://127.0.0.1:8000/health
  后端日志: ${BACKEND_LOG_FILE}
  Flutter 日志: ${FLUTTER_LOG_FILE}
EOF
}

main() {
  trap cleanup EXIT
  trap handle_interrupt INT TERM

  parse_args "$@"
  ensure_run_dir
  require_command adb
  require_command curl
  require_command flutter
  resolve_app_package

  stop_stale_processes
  clean_caches
  ensure_emulator
  configure_android_bridges
  stop_android_app
  start_backend
  start_flutter
  print_summary
  monitor_processes
}

main "$@"
