#!/usr/bin/env bash
set -euo pipefail

gb_cmd_status() {
    local active
    active="$(gb_read_active_slot)"
    if [[ -z "$active" ]]; then
        echo "active slot: (none — not bootstrapped)"
    else
        echo "active slot: ${active} (port $(gb_slot_port "$active"), container $(gb_slot_container "$active"))"
    fi
    if [[ -f "$GB_PREVIOUS_STATE_FILE" ]]; then
        echo "previous slot: $(tr -d '[:space:]' < "$GB_PREVIOUS_STATE_FILE")"
    fi
    echo "state file: ${GB_STATE_FILE}"
}
