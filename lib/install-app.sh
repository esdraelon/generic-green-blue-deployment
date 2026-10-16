#!/usr/bin/env bash

gb_compose_service_for_slot() {
    local slot="$1"
    if [[ -n "$GB_COMPOSE_SERVICE_PATTERN" ]]; then
        gb_expand_slot "$GB_COMPOSE_SERVICE_PATTERN" "$slot"
    else
        echo "$GB_COMPOSE_SERVICE"
    fi
}

gb_exec_in_slot() {
    local slot="$1"
    local user="$2"
    shift 2
    local service
    service="$(gb_compose_service_for_slot "$slot")"
    gb_compose_web_slot "$slot" exec -T -u "$user" -w "$GB_CONTAINER_APP_DIR" "$service" "$@"
}

gb_install_app_in_slot() {
    local slot="$1"
    GB_ACTIVE_SLOT="$slot"

    if [[ -n "$GB_HOOK_INSTALL_APP" ]]; then
        gb_hook_run "$GB_HOOK_INSTALL_APP" "$slot"
        return
    fi

    case "$GB_APP_INSTALL" in
        none)
            return 0
            ;;
        composer-phinx)
            gb_info "Installing Composer dependencies in $(gb_slot_container "$slot")..."
            read -r -a composer_flags <<< "$GB_COMPOSER_FLAGS"
            gb_exec_in_slot "$slot" "$GB_WEB_USER" composer install "${composer_flags[@]}"
            gb_info "Running Phinx migrations (${GB_PHINX_ENV})..."
            gb_exec_in_slot "$slot" "$GB_WEB_USER" vendor/bin/phinx migrate -e "$GB_PHINX_ENV"
            ;;
        *)
            gb_die "unknown GB_APP_INSTALL: ${GB_APP_INSTALL}"
            ;;
    esac
}

gb_ensure_sessions_store() {
    if ! gb_stack_enabled sessions "$GB_DEPLOY_STACKS"; then
        return
    fi
    if [[ ! -f "${GB_ROOT}/${GB_SESSIONS_COMPOSE_FILES%% *}" ]]; then
        return
    fi

    if [[ -n "$GB_SHARED_NETWORK" ]]; then
        gb_ensure_network "$GB_SHARED_NETWORK"
    fi

    gb_info "Ensuring session store (${GB_SESSIONS_CONTAINER})..."
    gb_compose_sessions up -d
}

gb_ensure_worker() {
    local slot="$1"
    if ! gb_stack_enabled worker "$GB_DEPLOY_STACKS"; then
        return
    fi
    if [[ ! -f "${GB_ROOT}/${GB_WORKER_COMPOSE_FILES%% *}" ]]; then
        return
    fi

    if [[ -n "$GB_SHARED_NETWORK" ]]; then
        gb_ensure_network "$GB_SHARED_NETWORK"
    fi

    gb_info "Ensuring worker stack (${GB_WORKER_CONTAINER})..."
    gb_compose_worker up -d --build
}
