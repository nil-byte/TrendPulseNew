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
MAIN_LOG_FILE="$RUN_DIR/dev-android.log"
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
# adb 目标：模拟器或 USB 真机（变量名历史原因保留为 EMULATOR_SERIAL）
USE_USB_DEVICE=0
DEVICE_SERIAL_OVERRIDE=""
VERBOSE_LOGS=0

usage() {
  cat <<'EOF'
用法:
  scripts/dev-android.sh [选项]

说明:
  - 清理前后端缓存与构建产物
  - 默认：启动或复用 Android 模拟器，拉起后端与本机 Flutter
  - USB 真机：使用 --usb，手机需开启 USB 调试并连接电脑；仍通过 adb reverse
    将手机上的 localhost:8000 转到本机后端（应用内默认 http://localhost:8000 即可）
  - 脚本会持续前台运行
  - 按 Ctrl+C 后，自动停止 Flutter、后端、App 进程；仅当模拟器由本脚本启动时才会关闭模拟器

选项:
  --purge-data              额外删除 backend/trendpulse.db
  --emulator-id <id>        指定 Flutter emulator id，默认 Pixel_8_M4（与 --usb 互斥）
  --usb                     使用已通过 USB 连接的真机（adb 状态为 device 的非 emulator）
  --device-serial <serial>  指定 adb 设备序列号（可选，多设备时建议指定）
  --verbose                 后端 uvicorn --log-level debug；flutter run 增加 -v（日志量很大）

日志文件（均在 .run/ 下）:
  dev-android.log  本脚本步骤与时间戳
  backend.log      后端标准输出/错误
  flutter.log      flutter run 输出
EOF
}

log() {
  local line="[dev-android] $*"
  printf '%s\n' "$line"
  if [[ -n "${MAIN_LOG_FILE:-}" ]]; then
    printf '%s %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$line" >>"$MAIN_LOG_FILE" || true
  fi
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
      --usb)
        USE_USB_DEVICE=1
        shift
        ;;
      --device-serial)
        [[ $# -ge 2 ]] || fail "--device-serial 需要一个值"
        DEVICE_SERIAL_OVERRIDE="$2"
        USE_USB_DEVICE=1
        shift 2
        ;;
      --verbose)
        VERBOSE_LOGS=1
        shift
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

  # stdout/stderr 重定向到文件时常为全缓冲，flutter_tools 的 “Flutter run key commands.”
  # 可能长期不写入 .run/flutter.log；stdbuf（GNU coreutils）在可用时改为行缓冲。
  local -a cmd=( "$@" )
  if command -v stdbuf >/dev/null 2>&1; then
    cmd=( stdbuf -oL -eL "${cmd[@]}" )
  fi

  if command -v setsid >/dev/null 2>&1; then
    setsid nohup "${cmd[@]}" >"$log_file" 2>&1 < /dev/null &
  else
    nohup "${cmd[@]}" >"$log_file" 2>&1 < /dev/null &
  fi
}

# flutter run 输出重定向到文件时 stdout 常全缓冲，可能长时间不出现
# “Flutter run key commands.”；同时用 DevTools / VM Service / 设备 I/flutter 日志判断已就绪。
flutter_run_log_indicates_resident_ready() {
  local log_file="$1"
  [[ -f "$log_file" ]] || return 1
  grep -q "Flutter run key commands\\." "$log_file" 2>/dev/null && return 0
  grep -q "The Flutter DevTools debugger" "$log_file" 2>/dev/null && return 0
  grep -q "A Dart VM Service on" "$log_file" 2>/dev/null && return 0
  grep -q "Dart VM Service" "$log_file" 2>/dev/null && return 0
  grep -q "I/flutter (" "$log_file" 2>/dev/null && return 0
  return 1
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
  local reverse_out=""
  local rc=0
  reverse_out="$(
    adb -s "$EMULATOR_SERIAL" reverse "tcp:$BACKEND_PORT" "tcp:$BACKEND_PORT" 2>&1
  )" || rc=$?
  if [[ "$rc" -eq 0 ]]; then
    BACKEND_REVERSE_ENABLED=1
  fi

  if [[ "$BACKEND_REVERSE_ENABLED" -ne 1 ]]; then
    if [[ -n "$reverse_out" ]]; then
      log "adb reverse 失败输出: $reverse_out"
    fi
    fail "无法建立 Android localhost:$BACKEND_PORT 到宿主机后端的 adb reverse 映射（请确认 USB 调试已授权）"
  fi

  if [[ "$VERBOSE_LOGS" -eq 1 ]]; then
    [[ -n "$reverse_out" ]] && log "adb reverse: $reverse_out" || log "adb reverse: 成功"
  fi

  local reverse_list=""
  reverse_list="$(
    adb -s "$EMULATOR_SERIAL" reverse --list 2>/dev/null | tr '\n' ';'
  )"

  if [[ "$reverse_list" != *"tcp:$BACKEND_PORT tcp:$BACKEND_PORT"* ]]; then
    fail "adb reverse 状态异常：未找到 localhost:$BACKEND_PORT 的映射"
  fi

  if [[ "$VERBOSE_LOGS" -eq 1 ]]; then
    log "adb reverse --list: $reverse_list"
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

count_usb_devices() {
  adb devices | awk 'NR > 1 && $2 == "device" && $1 !~ /^emulator-/ {c++} END {print c+0}'
}

ensure_usb_device() {
  local serial=""
  if [[ -n "$DEVICE_SERIAL_OVERRIDE" ]]; then
    serial="$DEVICE_SERIAL_OVERRIDE"
    local state=""
    state="$(adb devices | awk -v s="$serial" '$1 == s {print $2; exit}')"
    [[ "$state" == "device" ]] || fail "adb 设备 $serial 不可用（状态: ${state:-未列出}），请检查 USB 与调试授权"
    log "使用指定 USB 设备: $serial"
  else
    local n=""
    n="$(count_usb_devices)"
    [[ "$n" -ge 1 ]] || fail "未检测到已授权的 USB 真机。请连接手机、开启 USB 调试，或指定 --device-serial"
    if [[ "$n" -gt 1 ]]; then
      log "当前 adb 设备列表（请选用其一并传入 --device-serial）:"
      adb devices 2>&1 | while IFS= read -r line; do log "  $line"; done || true
      fail "连接了多台真机，请使用 --device-serial <序列号> 指定其一"
    fi
    serial="$(
      adb devices | awk 'NR > 1 && $2 == "device" && $1 !~ /^emulator-/ {print $1; exit}'
    )"
    log "使用 USB 真机: $serial"
  fi

  log "等待设备就绪（sys.boot_completed）"
  wait_for_emulator_boot "$serial" || fail "设备未在预期时间内就绪"

  EMULATOR_SERIAL="$serial"
  printf '%s\n' "$EMULATOR_SERIAL" > "$EMULATOR_SERIAL_FILE"
}

ensure_android_target() {
  if [[ "$USE_USB_DEVICE" -eq 1 ]]; then
    ensure_usb_device
  else
    ensure_emulator
  fi
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

  local -a uvicorn_args=(
    ./.venv/bin/uvicorn src.main:app --host 127.0.0.1 --port 8000
  )
  if [[ "$VERBOSE_LOGS" -eq 1 ]]; then
    uvicorn_args+=(--log-level debug)
    log "启动后端服务（uvicorn --log-level debug，详情见 ${BACKEND_LOG_FILE}）"
  else
    uvicorn_args+=(--log-level info)
    log "启动后端服务（uvicorn --log-level info，详情见 ${BACKEND_LOG_FILE}）"
  fi

  (
    cd "$BACKEND_DIR"
    spawn_background "$BACKEND_LOG_FILE" "${uvicorn_args[@]}"
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

  if [[ "$VERBOSE_LOGS" -eq 1 ]]; then
    log "拉起 Flutter 到设备 ${EMULATOR_SERIAL}（flutter run -v，详情见 ${FLUTTER_LOG_FILE}）"
  else
    log "拉起 Flutter 到设备 ${EMULATOR_SERIAL}（详情见 ${FLUTTER_LOG_FILE}）"
  fi
  (
    cd "$APP_DIR"
    if [[ "$VERBOSE_LOGS" -eq 1 ]]; then
      spawn_background "$FLUTTER_LOG_FILE" flutter run -d "$EMULATOR_SERIAL" -v
    else
      spawn_background "$FLUTTER_LOG_FILE" flutter run -d "$EMULATOR_SERIAL"
    fi
    FLUTTER_PID="$!"
    echo "$FLUTTER_PID" > "$FLUTTER_PID_FILE"
  )

  FLUTTER_PID="$(cat "$FLUTTER_PID_FILE")"

  # 每次脚本会 flutter clean，首次 Gradle 可能较慢；默认多给一些轮次。
  local attempts=420
  for ((i = 1; i <= attempts; i++)); do
    if flutter_run_log_indicates_resident_ready "$FLUTTER_LOG_FILE"; then
      return 0
    fi
    if grep -q "Application finished." "$FLUTTER_LOG_FILE"; then
      tail -n 100 "$FLUTTER_LOG_FILE" >&2 || true
      fail "Flutter 启动后立即退出"
    fi
    if ! pid_is_running "$FLUTTER_PID"; then
      tail -n 100 "$FLUTTER_LOG_FILE" >&2 || true
      fail "Flutter 工具进程在启动完成前已退出（可查看 ${FLUTTER_LOG_FILE}）"
    fi
    sleep 1
  done

  tail -n 100 "$FLUTTER_LOG_FILE" >&2 || true
  fail "Flutter 未在预期时间内完成启动（已等 ${attempts}s；若应用其实在跑，多半是日志里未出现就绪特征，请查看 ${FLUTTER_LOG_FILE}）"
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
  local target_kind="模拟器"
  if [[ "$USE_USB_DEVICE" -eq 1 ]]; then
    target_kind="USB 真机"
  fi
  cat <<EOF

启动完成，脚本会保持前台运行。
按 Ctrl+C 会自动停止本次启动的内容。

  Android 设备 (${target_kind}): ${EMULATOR_SERIAL}
  App 包名: ${APP_PACKAGE}
  后端健康检查: http://127.0.0.1:8000/health
  脚本事件日志: ${MAIN_LOG_FILE}
  后端日志: ${BACKEND_LOG_FILE}
  Flutter 日志: ${FLUTTER_LOG_FILE}
EOF
}

main() {
  trap cleanup EXIT
  trap handle_interrupt INT TERM

  parse_args "$@"
  ensure_run_dir
  : > "$MAIN_LOG_FILE"
  log "dev-android 启动: USE_USB_DEVICE=$USE_USB_DEVICE VERBOSE_LOGS=$VERBOSE_LOGS"
  require_command adb
  require_command curl
  require_command flutter
  resolve_app_package

  stop_stale_processes
  clean_caches
  ensure_android_target
  configure_android_bridges
  stop_android_app
  start_backend
  start_flutter
  print_summary
  monitor_processes
}

main "$@"
