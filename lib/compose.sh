#!/usr/bin/env bash

gb_docker_compose() {
    local runtime_env="${GB_RUNTIME_ENV_FILE:-${GB_ROOT}/.gb/runtime.env}"
    if [[ -f "$runtime_env" ]]; then
        docker compose --env-file "$runtime_env" "$@"
    else
        docker compose "$@"
    fi
}

gb_compose_sessions() {
    local -a args=()
    local f
    for f in $GB_SESSIONS_COMPOSE_FILES; do
        args+=(-f "${GB_ROOT}/${f}")
    done
    gb_docker_compose --project-directory "$GB_ROOT" -p "$GB_SESSIONS_COMPOSE_PROJECT" "${args[@]}" "$@"
}

gb_compose_sessions_dev() {
    local -a args=()
    local f
    for f in $GB_SESSIONS_COMPOSE_FILES $GB_SESSIONS_COMPOSE_DEV_FILES; do
        [[ -z "$f" ]] && continue
        args+=(-f "${GB_ROOT}/${f}")
    done
    gb_docker_compose --project-directory "$GB_ROOT" -p "$GB_SESSIONS_COMPOSE_PROJECT" "${args[@]}" "$@"
}

gb_compose_worker() {
    local -a args=()
    local f
    for f in $GB_WORKER_COMPOSE_FILES; do
        args+=(-f "${GB_ROOT}/${f}")
    done
    gb_docker_compose --project-directory "$GB_ROOT" -p "$GB_WORKER_COMPOSE_PROJECT" "${args[@]}" "$@"
}

gb_compose_worker_dev() {
    local -a args=()
    local f
    for f in $GB_WORKER_COMPOSE_FILES $GB_WORKER_COMPOSE_DEV_FILES; do
        [[ -z "$f" ]] && continue
        args+=(-f "${GB_ROOT}/${f}")
    done
    gb_docker_compose --project-directory "$GB_ROOT" -p "$GB_WORKER_COMPOSE_PROJECT" "${args[@]}" "$@"
}

gb_compose_web_slot() {
    local slot="$1"
    shift
    local slot_file
    slot_file="$(gb_expand_slot "$GB_WEB_COMPOSE_SLOT" "$slot")"
    gb_docker_compose --project-directory "$GB_ROOT" -p "${GB_WEB_COMPOSE_PROJECT}-${slot}" \
        -f "${GB_ROOT}/${GB_WEB_COMPOSE_BASE}" \
        -f "${GB_ROOT}/${slot_file}" \
        "$@"
}

gb_compose_web_dev() {
    local slot="${GB_DEV_SLOT:-blue}"
    local slot_file
    slot_file="$(gb_expand_slot "$GB_WEB_COMPOSE_SLOT" "$slot")"
    gb_docker_compose --project-directory "$GB_ROOT" -p "$GB_WEB_COMPOSE_PROJECT" \
        -f "${GB_ROOT}/${GB_WEB_COMPOSE_BASE}" \
        -f "${GB_ROOT}/${slot_file}" \
        -f "${GB_ROOT}/${GB_WEB_COMPOSE_DEV}" \
        "$@"
}

gb_stack_enabled() {
    local stack="$1"
    local list="$2"
    [[ " ${list} " == *" ${stack} "* ]]
}
