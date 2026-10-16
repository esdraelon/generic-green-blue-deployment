#!/usr/bin/env bash
# host-env-vault integration (local dev-shared or production config.toml).

gb_hev_bin() {
    local bin="${HOST_ENV_VAULT_BIN:-host-env-vault}"
    if command -v "$bin" >/dev/null 2>&1; then
        echo "$bin"
        return
    fi

    local repo="${GB_HEV_REPO:-${HOST_ENV_VAULT_REPO:-}}"
    if [[ -z "$repo" && -n "${GREENBLUE_TOOLKIT_ROOT:-}" ]]; then
        local sibling
        sibling="$(dirname "$GREENBLUE_TOOLKIT_ROOT")/host-env-vault"
        if [[ -d "$sibling" ]]; then
            repo="$sibling"
        elif [[ -d "${sibling}/Untitled" ]]; then
            repo="${sibling}/Untitled"
        fi
    fi

    if [[ -n "$repo" && -f "${repo}/Cargo.toml" ]]; then
        if [[ -x "${repo}/target/release/host-env-vault" ]]; then
            echo "${repo}/target/release/host-env-vault"
            return
        fi
        gb_info "Building host-env-vault from ${repo}..."
        (cd "$repo" && cargo build --release)
        echo "${repo}/target/release/host-env-vault"
        return
    fi

    gb_die "host-env-vault binary not found; install it or set HOST_ENV_VAULT_BIN / GB_HEV_REPO"
}

gb_hev_render_root() {
    if [[ -n "$GB_HEV_RENDER_ROOT" ]]; then
        echo "$GB_HEV_RENDER_ROOT"
        return
    fi
    if [[ -n "${HOST_ENV_VAULT_CONFIG:-}" && -f "$HOST_ENV_VAULT_CONFIG" ]]; then
        local dir
        dir="$(dirname "$HOST_ENV_VAULT_CONFIG")"
        echo "${dir}/run"
        return
    fi
    gb_die "set GB_HEV_RENDER_ROOT or HOST_ENV_VAULT_CONFIG for render destinations"
}

gb_hev_sync() {
    local bin
    bin="$(gb_hev_bin)"
    local -a args=(sync)

    if [[ -n "${HOST_ENV_VAULT_CONFIG:-}" && -f "$HOST_ENV_VAULT_CONFIG" ]]; then
        args+=(--config "$HOST_ENV_VAULT_CONFIG")
    fi

    if [[ -n "${GB_HEV_SYNC_SOURCE:-}" ]]; then
        args+=(--source "$GB_HEV_SYNC_SOURCE")
    fi

    gb_info "host-env-vault sync..."
    "$bin" "${args[@]}"
}

gb_hev_render_profile() {
    local profile="$1"
    local bin dest parent
    bin="$(gb_hev_bin)"
    dest="$(gb_hev_render_root)/${profile}/current"
    parent="$(dirname "$dest")"

    mkdir -p "$parent"
    if [[ -d "$dest" ]]; then
        rm -rf "$dest"
    fi
    mkdir -p "$dest"

    local -a args=(
        render
        --profile "$profile"
        --dest "$dest"
    )
    if [[ -n "${HOST_ENV_VAULT_CONFIG:-}" && -f "$HOST_ENV_VAULT_CONFIG" ]]; then
        args+=(--config "$HOST_ENV_VAULT_CONFIG")
    fi

    gb_info "host-env-vault render --profile ${profile} -> ${dest}"
    "$bin" "${args[@]}"
}

gb_hev_render_all() {
    if [[ -z "$GB_HEV_PROFILES" ]]; then
        return 0
    fi
    local profile
    for profile in $GB_HEV_PROFILES; do
        gb_hev_render_profile "$profile"
    done
}

gb_hev_maybe_sync() {
    local when="$1"
    case "$when" in
        dev-up)
            [[ "$GB_HEV_SYNC_ON_DEV_UP" == "1" ]] && gb_hev_sync
            ;;
        deploy)
            [[ "$GB_HEV_SYNC_ON_DEPLOY" == "1" ]] && gb_hev_sync
            ;;
    esac
}

gb_hev_maybe_render() {
    local when="$1"
    case "$when" in
        dev-up)
            [[ "$GB_HEV_RENDER_ON_DEV_UP" == "1" ]] && gb_hev_render_all
            ;;
        deploy)
            [[ "$GB_HEV_RENDER_ON_DEPLOY" == "1" ]] && gb_hev_render_all
            ;;
    esac
}
