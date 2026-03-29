#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
APP_DIR="$ROOT_DIR/app"
PYTHON_BIN="${PYTHON_BIN:-python}"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
RUN_BACKEND=true
RUN_FLUTTER=true

log() {
  printf '[verify-critical-paths] %s\n' "$*"
}

fail() {
  log "错误: $*"
  exit 1
}

usage() {
  cat <<'EOF'
用法:
  scripts/verify-critical-paths.sh [--backend-only | --flutter-only]

选项:
  --backend-only   仅运行后端关键链路验证
  --flutter-only   仅运行 Flutter 关键链路验证
  -h, --help       显示帮助
EOF
}

require_directory() {
  local path="$1"
  local hint="$2"
  if [[ ! -d "$path" ]]; then
    fail "缺少目录: ${path}。${hint}"
  fi
}

require_command() {
  local command_name="$1"
  local hint="$2"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    fail "缺少必需命令: ${command_name}。${hint}"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --backend-only)
        RUN_BACKEND=true
        RUN_FLUTTER=false
        ;;
      --flutter-only)
        RUN_BACKEND=false
        RUN_FLUTTER=true
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        usage
        fail "未知参数: $1"
        ;;
    esac
    shift
  done
}

ensure_prerequisites() {
  require_directory "$BACKEND_DIR" "请确认脚本位于仓库根目录下执行。"
  require_directory "$APP_DIR" "请确认脚本位于仓库根目录下执行。"

  if [[ "$RUN_BACKEND" == true ]]; then
    require_command \
      "$PYTHON_BIN" \
      "请先安装可用的 Python，或使用 --flutter-only 仅运行 Flutter 验证。"
  fi

  if [[ "$RUN_FLUTTER" == true ]]; then
    require_command \
      "$FLUTTER_BIN" \
      "请先安装 Flutter，或使用 --backend-only 仅运行后端验证。"
  fi
}

run_backend_checks() {
  log "运行后端关键链路测试"
  (
    cd "$BACKEND_DIR"
    "$PYTHON_BIN" -m pytest \
      tests/test_grok_config_guardrails.py \
      tests/test_verify_critical_paths_script.py \
      tests/test_services/test_task_service.py \
      tests/test_services/test_analyzer.py \
      tests/test_api/test_endpoints.py
  )
}

run_flutter_checks() {
  log "运行 Flutter 关键链路测试"
  (
    cd "$APP_DIR"
    "$FLUTTER_BIN" test \
      test/features/subscription/pages/subscription_page_test.dart \
      test/features/subscription/pages/subscription_tasks_page_test.dart \
      test/features/detail/widgets/report_tab_test.dart
  )
}

main() {
  parse_args "$@"
  ensure_prerequisites

  if [[ "$RUN_BACKEND" == true ]]; then
    run_backend_checks
  fi

  if [[ "$RUN_FLUTTER" == true ]]; then
    run_flutter_checks
  fi

  log "关键链路验证完成"
}

main "$@"
