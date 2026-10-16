#!/usr/bin/env bash
# Load .greenblue from the target application repository.

gb_load_config() {
    local project_root="$1"
    GB_ROOT="$(gb_abs_path "$project_root")"

    if [[ ! -f "${GB_ROOT}/.greenblue" ]]; then
        gb_die "missing config: ${GB_ROOT}/.greenblue (copy examples/.greenblue.dev.example or examples/.greenblue.prod.example)"
    fi

    # shellcheck disable=SC1090
    source "${GB_ROOT}/.greenblue"

    gb_config_normalize
}

gb_effective_mode() {
    case "${GB_MODE:-}" in
        dev | prod)
            echo "$GB_MODE"
            ;;
        "")
            if gb_uses_blue_green; then
                echo "prod"
            else
                echo "dev"
            fi
            ;;
        *)
            gb_die "GB_MODE must be dev or prod (got: ${GB_MODE})"
            ;;
    esac
}

gb_config_normalize() {
    # Optional legacy variable aliases (see README)
    : "${GB_PROJECT_NAME:=${PROJECT_NAME:-}}"
    : "${GB_WEB_USER:=${WEB_USER:-www-data}}"
    : "${GB_WEB_GROUP:=${WEB_GROUP:-www-data}}"
    : "${GB_CONTAINER_APP_DIR:=${CONTAINER_APP_DIR:-}}"
    : "${GB_COMPOSE_SERVICE:=${COMPOSE_SERVICE:-app}}"
    : "${GB_COMPOSE_SERVICE_PATTERN:=}"
    : "${GB_COMPOSER_FLAGS:=${COMPOSER_FLAGS:---no-dev --optimize-autoloader}}"
    : "${GB_PHINX_ENV:=${PHINX_ENV:-production}}"

    : "${GB_LEGACY_CONTAINER:=${LEGACY_CONTAINER:-}}"
    : "${GB_BLUE_CONTAINER:=${BLUE_CONTAINER:-${GB_PROJECT_NAME}-blue}}"
    : "${GB_GREEN_CONTAINER:=${GREEN_CONTAINER:-${GB_PROJECT_NAME}-green}}"
    : "${GB_BLUE_PORT:=${BLUE_PORT:-8080}}"
    : "${GB_GREEN_PORT:=${GREEN_PORT:-8081}}"

    : "${GB_STATE_DIR:=${DEPLOY_STATE_DIR:-${GB_ROOT}/.greenblue-state}}"
    GB_STATE_FILE="${GB_STATE_FILE:-${GB_STATE_DIR}/active}"
    GB_PREVIOUS_STATE_FILE="${GB_PREVIOUS_STATE_FILE:-${GB_STATE_DIR}/previous}"

    : "${GB_NGINX_STRATEGY:=site-file}"
    : "${GB_NGINX_SITE_NAME:=${NGINX_SITE_NAME:-${GB_PROJECT_NAME}}}"
    : "${GB_NGINX_SITES_AVAILABLE:=${NGINX_SITES_AVAILABLE:-/etc/nginx/sites-available/${GB_NGINX_SITE_NAME}}}"
    : "${GB_NGINX_SITES_ENABLED:=${NGINX_SITES_ENABLED:-/etc/nginx/sites-enabled/${GB_NGINX_SITE_NAME}}}"
    : "${GB_NGINX_TEMPLATE:=host/nginx.%slot%.conf}"
    : "${GB_NGINX_SITES_AVAILABLE_DIR:=${NGINX_SITES_AVAILABLE_DIR:-/etc/nginx/sites-available}}"
    : "${GB_NGINX_SITES_ENABLED_DEFAULT:=${NGINX_SITES_ENABLED_DEFAULT:-/etc/nginx/sites-enabled/default}}"

    : "${GB_HEALTH_PATH:=${HEALTH_PATH:-/}}"
    : "${GB_HEALTH_RETRIES:=${HEALTH_RETRIES:-30}}"
    : "${GB_HEALTH_INTERVAL:=${HEALTH_INTERVAL:-2}}"

    : "${GB_GIT_BRANCH:=${GIT_BRANCH:-main}}"
    : "${GB_INSTALL_SKIP_GIT_PULL:=${INSTALL_SKIP_GIT_PULL:-0}}"
    : "${GB_INSTALL_SKIP_CHOWN:=${INSTALL_SKIP_CHOWN:-0}}"
    : "${GB_INSTALL_SKIP_HOST_NGINX:=${INSTALL_SKIP_HOST_NGINX:-0}}"
    : "${GB_INSTALL_GIT_REF:=${INSTALL_GIT_REF:-}}"
    : "${GB_INSTALL_REBUILD_SESSIONS:=${INSTALL_REBUILD_SESSIONS:-0}}"
    : "${GB_INSTALL_RESET_SESSIONS:=${INSTALL_RESET_SESSIONS:-0}}"
    : "${GB_SESSION_REDIS_DB:=${SESSION_REDIS_DB:-0}}"
    : "${GB_INSTALL_REBUILD_WORKER:=${INSTALL_REBUILD_WORKER:-0}}"

    : "${GB_SHARED_NETWORK:=${SESSIONS_NETWORK:-${NETWORK:-}}}"
    : "${GB_SESSIONS_COMPOSE_PROJECT:=${SESSIONS_COMPOSE_PROJECT:-${GB_PROJECT_NAME}-sessions}}"
    : "${GB_SESSIONS_COMPOSE_FILES:=docker/compose.sessions.yml}"
    : "${GB_SESSIONS_COMPOSE_DEV_FILES:=docker/compose.sessions.dev.yml}"
    : "${GB_SESSIONS_COMPOSE_SERVICE:=${SESSIONS_COMPOSE_SERVICE:-sessions}}"
    : "${GB_SESSIONS_CONTAINER:=${SESSIONS_CONTAINER:-${GB_PROJECT_NAME}-sessions}}"

    : "${GB_WORKER_COMPOSE_PROJECT:=${WORKER_COMPOSE_PROJECT:-${GB_PROJECT_NAME}-worker}}"
    : "${GB_WORKER_COMPOSE_FILES:=docker/compose.worker.yml}"
    : "${GB_WORKER_COMPOSE_DEV_FILES:=docker/compose.worker.dev.yml}"
    : "${GB_WORKER_CONTAINER:=${WORKER_CONTAINER:-${GB_PROJECT_NAME}-worker}}"

    : "${GB_WEB_COMPOSE_PROJECT:=${WEB_PROJECT:-${GB_PROJECT_NAME}}}"
    : "${GB_WEB_COMPOSE_BASE:=docker/compose.prod.yml}"
    : "${GB_WEB_COMPOSE_SLOT:=docker/compose.%slot%.yml}"
    : "${GB_WEB_COMPOSE_DEV:=docker/compose.dev.yml}"

    : "${GB_DEV_SLOT:=blue}"
    : "${GB_DEV_STACKS:=web}"
    : "${GB_DEPLOY_STACKS:=sessions web worker}"

    : "${GB_APP_INSTALL:=composer-phinx}"
    : "${GB_MODE:=}"
    : "${GB_HOOK_PRE_DEPLOY:=}"
    : "${GB_HOOK_POST_DEPLOY:=}"
    : "${GB_HOOK_POST_COMMAND:=}"
    : "${GB_HOOK_INSTALL_APP:=}"
    : "${GB_HOOK_AFTER_SLOT_UP:=}"
    : "${GB_HOOK_AFTER_SLOT_HEALTH:=}"
    : "${GB_HOOK_HEV_AFTER_RENDER:=}"
    : "${GB_HOOK_ENSURE_WORKER:=}"
    : "${GB_HOOK_ENSURE_SESSIONS:=}"

    : "${GB_HEV_CONFIG:=}"
    : "${GB_HEV_BIN:=}"
    : "${GB_HEV_REPO:=}"
    : "${GB_HEV_PROFILES:=}"
    : "${GB_HEV_RENDER_ROOT:=}"
    : "${GB_HEV_VAULT_ROOT:=}"
    : "${GB_HEV_SYNC_STRICT:=1}"
    : "${GB_HEV_MOUNT_MAP:=}"
    : "${GB_HEV_RENDER_ON_DEV_UP:=0}"
    : "${GB_HEV_RENDER_ON_DEPLOY:=1}"
    : "${GB_HEV_SYNC_ON_DEV_UP:=0}"
    : "${GB_HEV_SYNC_ON_DEPLOY:=0}"

    if [[ -n "${GB_HEV_CONFIG_CLI:-}" ]]; then
        GB_HEV_CONFIG="$GB_HEV_CONFIG_CLI"
    fi

    if [[ -z "$GB_HEV_VAULT_ROOT" && -n "$GB_HEV_CONFIG" ]]; then
        GB_HEV_VAULT_ROOT="$(dirname "$GB_HEV_CONFIG")"
    fi

    GB_RUNTIME_ENV_FILE="${GB_RUNTIME_ENV_FILE:-${GB_ROOT}/.gb/runtime.env}"

    if [[ -z "$GB_PROJECT_NAME" ]]; then
        gb_die "GB_PROJECT_NAME (or PROJECT_NAME) must be set in .greenblue"
    fi
    if [[ -z "$GB_CONTAINER_APP_DIR" ]]; then
        gb_die "GB_CONTAINER_APP_DIR (or CONTAINER_APP_DIR) must be set in .greenblue"
    fi
}

gb_config_show() {
    cat <<EOF
GB_ROOT=${GB_ROOT}
GB_PROJECT_NAME=${GB_PROJECT_NAME}
GB_WEB_COMPOSE_PROJECT=${GB_WEB_COMPOSE_PROJECT}
GB_BLUE_PORT=${GB_BLUE_PORT} GB_GREEN_PORT=${GB_GREEN_PORT}
GB_STATE_FILE=${GB_STATE_FILE}
GB_NGINX_STRATEGY=${GB_NGINX_STRATEGY}
GB_HEV_CONFIG=${GB_HEV_CONFIG:-<unset>}
GB_HEV_PROFILES=${GB_HEV_PROFILES:-<none>}
GB_MODE=$(gb_effective_mode)
EOF
}
