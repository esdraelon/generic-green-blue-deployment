#!/usr/bin/env bash

gb_slot_port() {
    case "$1" in
        blue) echo "$GB_BLUE_PORT" ;;
        green) echo "$GB_GREEN_PORT" ;;
        *) gb_die "invalid slot: $1 (expected blue or green)" ;;
    esac
}

gb_slot_container() {
    case "$1" in
        blue) echo "$GB_BLUE_CONTAINER" ;;
        green) echo "$GB_GREEN_CONTAINER" ;;
        *) gb_die "invalid slot: $1" ;;
    esac
}

gb_inactive_slot() {
    if [[ "$1" == "blue" ]]; then
        echo "green"
    else
        echo "blue"
    fi
}

gb_read_active_slot() {
    if [[ -f "$GB_STATE_FILE" ]]; then
        local slot
        slot="$(tr -d '[:space:]' < "$GB_STATE_FILE")"
        if [[ "$slot" == "blue" || "$slot" == "green" ]]; then
            echo "$slot"
            return
        fi
    fi
    echo ""
}

gb_write_active_slot() {
    local slot="$1"
    mkdir -p "$(dirname "$GB_STATE_FILE")"
    if [[ "$GB_STATE_DIR" == "${GB_ROOT}/"* ]] || [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
        mkdir -p "$GB_STATE_DIR"
        printf '%s\n' "$slot" > "$GB_STATE_FILE"
    else
        gb_run_priv mkdir -p "$GB_STATE_DIR"
        printf '%s\n' "$slot" | gb_run_priv tee "$GB_STATE_FILE" >/dev/null
    fi
}

gb_write_previous_slot() {
    local slot="$1"
    if [[ "$GB_STATE_DIR" == "${GB_ROOT}/"* ]] || [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
        mkdir -p "$GB_STATE_DIR"
        printf '%s\n' "$slot" > "$GB_PREVIOUS_STATE_FILE"
    else
        gb_run_priv mkdir -p "$GB_STATE_DIR"
        printf '%s\n' "$slot" | gb_run_priv tee "$GB_PREVIOUS_STATE_FILE" >/dev/null
    fi
}

gb_uses_blue_green() {
    [[ -f "${GB_ROOT}/${GB_WEB_COMPOSE_BASE}" ]]
}

gb_stop_legacy_container() {
    if [[ -z "$GB_LEGACY_CONTAINER" ]]; then
        return
    fi
    if gb_container_running "$GB_LEGACY_CONTAINER"; then
        gb_info "Stopping legacy container ${GB_LEGACY_CONTAINER}..."
        docker stop "$GB_LEGACY_CONTAINER" || true
    fi
    if gb_container_exists "$GB_LEGACY_CONTAINER"; then
        docker rm "$GB_LEGACY_CONTAINER" || true
    fi
}

gb_legacy_container_present() {
    [[ -n "$GB_LEGACY_CONTAINER" ]] && gb_container_exists "$GB_LEGACY_CONTAINER"
}

gb_build_and_start_slot() {
    local slot="$1"
    GB_TARGET_SLOT="$slot"
    gb_info "Building Docker image for ${slot} (app copied into image)..."
    gb_compose_web_slot "$slot" build --pull
    gb_info "Starting ${slot} container..."
    gb_compose_web_slot "$slot" up -d --remove-orphans
    gb_hook_run "$GB_HOOK_AFTER_SLOT_UP" "$slot"
}
