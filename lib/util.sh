#!/usr/bin/env bash
# Shared helpers for generic green-blue deployment.

gb_die() {
    echo "gb: $*" >&2
    exit 1
}

gb_info() {
    echo "==> $*"
}

gb_require_cmd() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || gb_die "'${cmd}' is required but not installed."
}

gb_abs_path() {
    local path="$1"
    if [[ -d "$path" ]]; then
        (cd "$path" && pwd)
    elif [[ -f "$path" ]]; then
        local dir
        dir="$(dirname "$path")"
        echo "$(cd "$dir" && pwd)/$(basename "$path")"
    else
        gb_die "path does not exist: ${path}"
    fi
}

gb_run_priv() {
    if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        gb_die "root or sudo required for: $*"
    fi
}

gb_container_running() {
    docker ps --format '{{.Names}}' | grep -Fxq "$1"
}

gb_container_exists() {
    docker ps -a --format '{{.Names}}' | grep -Fxq "$1"
}

gb_ensure_network() {
    local network="$1"
    if docker network inspect "$network" >/dev/null 2>&1; then
        return
    fi
    gb_info "Creating Docker network ${network}..."
    docker network create "$network"
}

gb_expand_slot() {
    local template="$1"
    local slot="$2"
    echo "${template//%slot%/${slot}}"
}

gb_hook_run() {
    local hook_path="$1"
    shift
    if [[ -z "$hook_path" ]]; then
        return 0
    fi
    local full="${GB_ROOT}/${hook_path}"
    if [[ ! -x "$full" ]]; then
        gb_die "hook is set but not executable: ${hook_path}"
    fi
    (cd "$GB_ROOT" && GB_ACTIVE_SLOT="${GB_ACTIVE_SLOT:-}" GB_TARGET_SLOT="${GB_TARGET_SLOT:-}" "$full" "$@")
}
