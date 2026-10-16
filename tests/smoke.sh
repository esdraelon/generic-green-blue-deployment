#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GB="${ROOT}/bin/gb"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

cat > "${tmpdir}/.greenblue" <<'EOF'
GB_MODE="dev"
GB_PROJECT_NAME="smoke-app"
GB_CONTAINER_APP_DIR="/var/www/smoke-app"
GB_WEB_COMPOSE_PROJECT="smoke-app"
GB_STATE_DIR="${GB_ROOT}/.gb/state"
GB_DEV_STACKS="web"
EOF

out="$("$GB" "$tmpdir" config)"
echo "$out" | grep -Fq 'GB_ROOT='"${tmpdir}"
echo "$out" | grep -Fq 'GB_MODE=dev'
echo "$out" | grep -Fq 'GB_PROJECT_NAME=smoke-app'

echo "smoke: ok"
