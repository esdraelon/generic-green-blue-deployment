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

gb_apply_pinned_deploy_flags() {
    if [[ -n "$GB_INSTALL_GIT_REF" ]]; then
        GB_INSTALL_REBUILD_WORKER=1
    fi
}

gb_sessions_redis_flushdb() {
    local db="${GB_SESSION_REDIS_DB:-0}"
    if ! gb_container_running "$GB_SESSIONS_CONTAINER"; then
        gb_die "cannot flush sessions Redis: ${GB_SESSIONS_CONTAINER} is not running"
    fi
    gb_info "Flushing Redis DB ${db} in ${GB_SESSIONS_CONTAINER}..."
    docker exec "$GB_SESSIONS_CONTAINER" redis-cli -n "$db" FLUSHDB
}

gb_ensure_sessions_store_default() {
    if ! gb_stack_enabled sessions "$GB_DEPLOY_STACKS"; then
        return
    fi
    if [[ ! -f "${GB_ROOT}/${GB_SESSIONS_COMPOSE_FILES%% *}" ]]; then
        return
    fi

    if [[ -n "$GB_SHARED_NETWORK" ]]; then
        gb_ensure_network "$GB_SHARED_NETWORK"
    fi

    local -a up_args=(-d)
    if [[ "${GB_INSTALL_REBUILD_SESSIONS:-0}" == "1" ]]; then
        up_args+=(--build --force-recreate)
    fi

    gb_info "Ensuring session store (${GB_SESSIONS_CONTAINER})..."
    gb_compose_sessions "${up_args[@]}"

    if [[ "${GB_INSTALL_RESET_SESSIONS:-0}" == "1" ]]; then
        gb_sessions_redis_flushdb
    fi
}

gb_ensure_sessions_store() {
    if [[ -n "$GB_HOOK_ENSURE_SESSIONS" ]]; then
        gb_hook_run "$GB_HOOK_ENSURE_SESSIONS" ensure-sessions
    fi
    gb_ensure_sessions_store_default
}

gb_ensure_worker_default() {
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

    local -a up_args=(-d)
    if [[ "${GB_INSTALL_REBUILD_WORKER:-0}" == "1" ]]; then
        up_args+=(--build)
    fi

    gb_info "Ensuring worker stack (${GB_WORKER_CONTAINER})..."
    gb_compose_worker "${up_args[@]}"
}

gb_ensure_worker() {
    local slot="$1"
    if [[ -n "$GB_HOOK_ENSURE_WORKER" ]]; then
        gb_hook_run "$GB_HOOK_ENSURE_WORKER" "$slot"
        return
    fi
    gb_ensure_worker_default "$slot"
}
