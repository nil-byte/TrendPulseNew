#!/usr/bin/env bash
# Lightweight README / docs drift checks: public Markdown inventory, API route count.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCS_DIR="$ROOT_DIR/docs"
BACKEND_ENDPOINTS="$ROOT_DIR/backend/src/api/endpoints"
MAIN_PY="$ROOT_DIR/backend/src/main.py"

fail() {
  printf 'verify-readme-docs: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "missing command: $1"
}

require_command rg

# docs/ — README 约定至少包含这三份（可无其他 md）
for f in \
  "$DOCS_DIR/Objective.md" \
  "$DOCS_DIR/GROK_API_INTEGRATION_REPORT.md" \
  "$DOCS_DIR/技术说明-采集策略与AI-Prompt.md"; do
  [[ -f "$f" ]] || fail "missing required doc: $f"
done

# 手写业务路由：19 条 /api/v1 + main.py 中 GET /health
route_count="$(rg -c '@router\.(get|post|put|delete)' "$BACKEND_ENDPOINTS"/*.py 2>/dev/null | awk -F: '{sum+=$2} END {print sum+0}')"
[[ "$route_count" -eq 19 ]] || fail "expected 19 @router.* lines under api/endpoints, got $route_count"

rg -q '@app\.get\("/health"\)' "$MAIN_PY" || fail 'expected @app.get("/health") in main.py'

printf 'verify-readme-docs: OK (docs present, %s API routes + /health)\n' "$route_count"
