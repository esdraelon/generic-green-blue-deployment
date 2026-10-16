#!/usr/bin/env bash
set -euo pipefail

gb_bootstrap_blue_green() {
    local slot="blue"

    if gb_legacy_container_present; then
        slot="green"
        gb_info "First blue-green deploy: legacy ${GB_LEGACY_CONTAINER} still running; bootstrapping ${slot}..."
    else
        gb_info "First blue-green deploy: bootstrapping ${slot}..."
    fi

    gb_build_and_start_slot "$slot"
    gb_install_app_in_slot "$slot"
    gb_ensure_worker "$slot"
    gb_health_check_port "$slot" "$(gb_slot_port "$slot")"
    gb_hook_run "$GB_HOOK_AFTER_SLOT_HEALTH" "$slot"
    gb_activate_nginx_slot "$slot"
    gb_write_active_slot "$slot"

    if gb_legacy_container_present; then
        gb_info "New slot is live; stopping legacy ${GB_LEGACY_CONTAINER}..."
        gb_stop_legacy_container
    fi

    gb_info "Bootstrap complete. Active slot: ${slot}."
}

gb_deploy_blue_green() {
    local active target
    active="$(gb_read_active_slot)"
    target="$(gb_inactive_slot "$active")"

    gb_info "Blue-green deploy to inactive slot: ${target} (active: ${active})..."
    gb_build_and_start_slot "$target"
    gb_install_app_in_slot "$target"
    gb_ensure_worker "$target"
    gb_health_check_port "$target" "$(gb_slot_port "$target")"
    gb_hook_run "$GB_HOOK_AFTER_SLOT_HEALTH" "$target"
    gb_write_previous_slot "$active"
    gb_activate_nginx_slot "$target"
    gb_write_active_slot "$target"
    gb_info "Deploy complete. Active slot: ${target}."
}

gb_cmd_deploy() {
    gb_require_cmd docker
    gb_require_cmd curl

    gb_hook_run "$GB_HOOK_PRE_DEPLOY" deploy
    gb_hev_maybe_sync deploy
    gb_hev_maybe_render deploy

    if [[ "$GB_INSTALL_SKIP_GIT_PULL" != "1" ]]; then
        gb_require_cmd git
        gb_pull_code
    fi

    if ! gb_uses_blue_green; then
        gb_die "missing ${GB_WEB_COMPOSE_BASE}; this project is not configured for blue-green prod compose"
    fi

    gb_ensure_sessions_store

    if [[ -z "$(gb_read_active_slot)" ]]; then
        gb_bootstrap_blue_green
    else
        gb_deploy_blue_green
    fi

    gb_hook_run "$GB_HOOK_POST_DEPLOY" deploy
}
