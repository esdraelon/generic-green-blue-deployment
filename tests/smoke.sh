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

# shellcheck source=../lib/util.sh
source "${ROOT}/lib/util.sh"
# shellcheck source=../lib/slots.sh
source "${ROOT}/lib/slots.sh"
# shellcheck source=../lib/install-app.sh
source "${ROOT}/lib/install-app.sh"
# shellcheck source=../cmd/revert.sh
source "${ROOT}/cmd/revert.sh"
# shellcheck source=../lib/hev.sh
source "${ROOT}/lib/hev.sh"

hev_tmp="$(mktemp -d)"
trap 'rm -rf "$tmpdir" "$hev_tmp"' EXIT

export GB_ROOT="$hev_tmp"
export GB_HEV_RENDER_ROOT="${hev_tmp}/render"
export GB_HEV_MOUNT_MAP="app-web:HEV_APP_WEB_SECRETS app-worker:HEV_APP_WORKER_SECRETS:/run/secrets"
mkdir -p "${GB_HEV_RENDER_ROOT}/app-web/current"
mkdir -p "${GB_HEV_RENDER_ROOT}/app-worker/current"
touch "${GB_HEV_RENDER_ROOT}/app-web/current/secrets.env"

gb_hev_apply_mount_map

runtime_env="${GB_ROOT}/.gb/runtime.env"
[[ -f "$runtime_env" ]] || { echo "smoke: missing ${runtime_env}" >&2; exit 1; }
grep -Fq 'HEV_APP_WEB_SECRETS='"${GB_HEV_RENDER_ROOT}/app-web/current" "$runtime_env"
grep -Fq 'HEV_APP_WORKER_SECRETS='"${GB_HEV_RENDER_ROOT}/app-worker/current" "$runtime_env"
[[ "${HEV_APP_WEB_SECRETS}" == "${GB_HEV_RENDER_ROOT}/app-web/current" ]] || {
    echo "smoke: HEV_APP_WEB_SECRETS export mismatch" >&2
    exit 1
}

revert_tmp="$(mktemp -d)"
export GB_STATE_DIR="${revert_tmp}/state"
export GB_STATE_FILE="${GB_STATE_DIR}/active"
export GB_PREVIOUS_STATE_FILE="${GB_STATE_DIR}/previous"
mkdir -p "$GB_STATE_DIR"

printf '%s\n' blue > "$GB_STATE_FILE"
printf '%s\n' green > "$GB_PREVIOUS_STATE_FILE"
read -r smoke_active smoke_previous <<< "$(gb_resolve_revert_slots)"
[[ "$smoke_active" == "blue" && "$smoke_previous" == "green" ]] || {
    echo "smoke: gb_resolve_revert_slots mismatch (${smoke_active}/${smoke_previous})" >&2
    exit 1
}

printf '%s\n' blue > "$GB_PREVIOUS_STATE_FILE"
if ( gb_resolve_revert_slots >/dev/null 2>&1 ); then
    echo "smoke: expected revert validation failure when previous equals active" >&2
    exit 1
fi

GB_INSTALL_GIT_REF=""
GB_INSTALL_REBUILD_WORKER=0
export GB_INSTALL_GIT_REF=deadbeef
gb_apply_pinned_deploy_flags
[[ "$GB_INSTALL_REBUILD_WORKER" == "1" ]] || {
    echo "smoke: pinned deploy should set GB_INSTALL_REBUILD_WORKER=1" >&2
    exit 1
}

echo "smoke: ok"
