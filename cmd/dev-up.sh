#!/usr/bin/env bash
set -euo pipefail

gb_cmd_dev_up() {
    gb_require_cmd docker
    gb_hev_maybe_sync dev-up
    gb_hev_maybe_render dev-up

    if [[ -n "$GB_SHARED_NETWORK" ]]; then
        gb_ensure_network "$GB_SHARED_NETWORK"
    fi

    if gb_stack_enabled sessions "$GB_DEV_STACKS"; then
        if [[ -f "${GB_ROOT}/${GB_SESSIONS_COMPOSE_FILES%% *}" ]]; then
            gb_info "Starting sessions (${GB_SESSIONS_COMPOSE_PROJECT})..."
            gb_compose_sessions_dev up -d
        fi
    fi

    if gb_stack_enabled web "$GB_DEV_STACKS"; then
        gb_info "Starting web (${GB_WEB_COMPOSE_PROJECT}, bind-mount dev)..."
        gb_compose_web_dev up -d --build --remove-orphans
    fi

    if gb_stack_enabled worker "$GB_DEV_STACKS"; then
        if [[ -f "${GB_ROOT}/${GB_WORKER_COMPOSE_FILES%% *}" ]]; then
            gb_info "Starting worker (${GB_WORKER_COMPOSE_PROJECT})..."
            gb_compose_worker_dev up -d --build
        fi
    fi

    gb_hook_run "$GB_HOOK_POST_DEPLOY" dev-up
    gb_info "Dev stack is up."
}
