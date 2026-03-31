#!/usr/bin/env bash
# Map device localhost:PORT -> host localhost:PORT (USB debugging).
# Usage:
#   scripts/adb-reverse-backend.sh [PORT]
#   scripts/adb-reverse-backend.sh -s SERIAL [PORT]
#   ANDROID_SERIAL=SERIAL scripts/adb-reverse-backend.sh [PORT]
set -euo pipefail

PORT="8000"
SERIAL=""

usage() {
  printf '%s\n' "用法: $0 [-s 设备序列号] [端口(默认8000)]" \
    "  或多设备时: export ANDROID_SERIAL=<序列号> 后再运行" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s)
      [[ $# -ge 2 ]] || {
        usage
        exit 1
      }
      SERIAL="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        PORT="$1"
        shift
      else
        printf '未知参数: %s\n' "$1" >&2
        usage
        exit 1
      fi
      ;;
  esac
done

if [[ -z "$SERIAL" ]]; then
  SERIAL="${ANDROID_SERIAL:-}"
fi

require_adb() {
  command -v adb >/dev/null 2>&1 || {
    echo "adb not found" >&2
    exit 1
  }
}

pick_serial_if_single() {
  local list_raw
  list_raw="$(adb devices | awk 'NR>1 && $2=="device" {print $1}')"
  local -a list
  mapfile -t list <<<"$list_raw"
  # trim empty lines
  local -a devs=()
  local line
  for line in "${list[@]}"; do
    [[ -z "${line// }" ]] && continue
    devs+=("$line")
  done
  if [[ ${#devs[@]} -eq 0 ]]; then
    echo "未检测到已连上的设备（adb devices 中需为 device 状态）。" >&2
    adb devices -l >&2 || true
    exit 1
  fi
  if [[ ${#devs[@]} -eq 1 ]]; then
    printf '%s' "${devs[0]}"
    return
  fi
  printf '' 
}

require_adb

if [[ -z "$SERIAL" ]]; then
  SERIAL="$(pick_serial_if_single)"
fi

if [[ -z "$SERIAL" ]]; then
  echo "adb: 当前有不止一台设备/模拟器，请指定其一：" >&2
  adb devices -l >&2
  echo >&2
  echo "任选一种方式：" >&2
  echo "  $0 -s <序列号> [端口]" >&2
  echo "  export ANDROID_SERIAL=<序列号> && $0 [端口]" >&2
  exit 1
fi

adb -s "$SERIAL" reverse "tcp:${PORT}" "tcp:${PORT}"

echo "已在设备 $SERIAL 上映射 tcp:${PORT} -> 本机 tcp:${PORT}"
adb -s "$SERIAL" reverse --list
