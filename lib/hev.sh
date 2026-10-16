#!/usr/bin/env bash
# host-env-vault integration (sync + render).

gb_hev_effective_config() {
    if [[ -n "${GB_HEV_CONFIG:-}" ]]; then
        echo "$GB_HEV_CONFIG"
    fi
}

gb_hev_require_config() {
    local cfg
    cfg="$(gb_hev_effective_config)"
    if [[ -z "$cfg" ]]; then
        gb_die "host-env-vault config required: pass --hev-config PATH or set GB_HEV_CONFIG in .greenblue"
    fi
    if [[ ! -f "$cfg" ]]; then
        gb_die "host-env-vault config not found: ${cfg}"
    fi
}

gb_hev_bin() {
    local bin="${GB_HEV_BIN:-host-env-vault}"
    if command -v "$bin" >/dev/null 2>&1; then
        echo "$bin"
        return
    fi

    if [[ -n "${GB_HEV_REPO:-}" && -f "${GB_HEV_REPO}/Cargo.toml" ]]; then
        if [[ -x "${GB_HEV_REPO}/target/release/host-env-vault" ]]; then
            echo "${GB_HEV_REPO}/target/release/host-env-vault"
            return
        fi
        gb_info "Building host-env-vault from ${GB_HEV_REPO}..."
        (cd "$GB_HEV_REPO" && cargo build --release)
        echo "${GB_HEV_REPO}/target/release/host-env-vault"
        return
    fi

    gb_die "host-env-vault binary not found on PATH; install it or set GB_HEV_BIN / GB_HEV_REPO in .greenblue"
}

gb_hev_render_root() {
    if [[ -n "$GB_HEV_RENDER_ROOT" ]]; then
        echo "$GB_HEV_RENDER_ROOT"
        return
    fi
    gb_hev_require_config
    local cfg
    cfg="$(gb_hev_effective_config)"
    echo "$(dirname "$cfg")/run"
}

gb_hev_sync() {
    gb_hev_require_config
    local bin cfg
    bin="$(gb_hev_bin)"
    cfg="$(gb_hev_effective_config)"
    local -a args=(
        sync
        --config "$cfg"
    )

    if [[ -n "${GB_HEV_SYNC_SOURCE:-}" ]]; then
        args+=(--source "$GB_HEV_SYNC_SOURCE")
    fi

    gb_info "host-env-vault sync..."
    "$bin" "${args[@]}"
}

gb_hev_render_profile() {
    local profile="$1"
    local bin dest parent cfg
    gb_hev_require_config
    bin="$(gb_hev_bin)"
    cfg="$(gb_hev_effective_config)"
    dest="$(gb_hev_render_root)/${profile}/current"
    parent="$(dirname "$dest")"

    mkdir -p "$parent"
    if [[ -d "$dest" ]]; then
        rm -rf "$dest"
    fi
    mkdir -p "$dest"

    gb_info "host-env-vault render --profile ${profile} -> ${dest}"
    "$bin" render --profile "$profile" --dest "$dest" --config "$cfg"
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

gb_hev_wants_sync() {
    local when="$1"
    case "$when" in
        dev-up) [[ "$GB_HEV_SYNC_ON_DEV_UP" == "1" ]] ;;
        deploy) [[ "$GB_HEV_SYNC_ON_DEPLOY" == "1" ]] ;;
        *) return 1 ;;
    esac
}

gb_hev_wants_render() {
    local when="$1"
    case "$when" in
        dev-up) [[ "$GB_HEV_RENDER_ON_DEV_UP" == "1" ]] ;;
        deploy) [[ "$GB_HEV_RENDER_ON_DEPLOY" == "1" ]] ;;
        *) return 1 ;;
    esac
}

gb_hev_maybe_sync() {
    local when="$1"
    gb_hev_wants_sync "$when" || return 0
    gb_hev_sync
}

gb_hev_maybe_render() {
    local when="$1"
    gb_hev_wants_render "$when" || return 0
    gb_hev_render_all
}
