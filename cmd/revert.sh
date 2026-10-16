#!/usr/bin/env bash
set -euo pipefail

gb_read_previous_slot() {
    if [[ ! -f "$GB_PREVIOUS_STATE_FILE" ]]; then
        echo ""
        return
    fi
    local slot
    slot="$(tr -d '[:space:]' < "$GB_PREVIOUS_STATE_FILE")"
    if [[ "$slot" == "blue" || "$slot" == "green" ]]; then
        echo "$slot"
        return
    fi
    echo ""
}

gb_cmd_revert() {
    local mode
    mode="$(gb_effective_mode)"
    if [[ "$mode" == "dev" ]]; then
        gb_die "revert is only available in prod (GB_MODE=prod) blue-green deployments"
    fi

    if ! gb_uses_blue_green; then
        gb_die "revert requires prod blue-green compose (${GB_WEB_COMPOSE_BASE})"
    fi

    local active previous
    active="$(gb_read_active_slot)"
    previous="$(gb_read_previous_slot)"

    if [[ -z "$active" ]]; then
        gb_die "no active slot — nothing to revert"
    fi
    if [[ -z "$previous" ]]; then
        gb_die "no previous slot recorded in ${GB_PREVIOUS_STATE_FILE}"
    fi
    if [[ "$previous" == "$active" ]]; then
        gb_die "previous slot matches active (${active}); cannot revert"
    fi

    gb_info "Reverting nginx from ${active} to ${previous} (containers left running)..."
    GB_TARGET_SLOT="$previous"
    GB_ACTIVE_SLOT="$active"
    gb_activate_nginx_slot "$previous"
    gb_write_previous_slot "$active"
    gb_write_active_slot "$previous"
    gb_info "Revert complete. Active slot: ${previous}."
}
