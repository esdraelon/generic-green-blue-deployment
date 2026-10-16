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

gb_hev_vault_root() {
    local cfg
    if [[ -n "${GB_HEV_VAULT_ROOT:-}" ]]; then
        if [[ -d "$GB_HEV_VAULT_ROOT" ]]; then
            gb_abs_path "$GB_HEV_VAULT_ROOT"
        else
            echo "$GB_HEV_VAULT_ROOT"
        fi
        return
    fi
    cfg="$(gb_hev_effective_config)"
    if [[ -n "$cfg" && -f "$cfg" ]]; then
        dirname "$(gb_abs_path "$cfg")"
    fi
}

gb_hev_config_for_cli() {
    local cfg_abs vault_root
    cfg_abs="$(gb_abs_path "$(gb_hev_effective_config)")"
    vault_root="$(gb_hev_vault_root)"
    if [[ -n "$vault_root" && -d "$vault_root" ]]; then
        vault_root="$(cd "$vault_root" && pwd)"
        if [[ "$cfg_abs" == "${vault_root}/"* ]]; then
            echo "${cfg_abs#"${vault_root}/"}"
            return
        fi
    fi
    echo "$cfg_abs"
}

gb_hev_invoke() {
    local bin vault_root
    bin="$(gb_hev_bin)"
    vault_root="$(gb_hev_vault_root)"
    if [[ -n "$vault_root" && -d "$vault_root" ]]; then
        (cd "$vault_root" && "$bin" "$@")
    else
        "$bin" "$@"
    fi
}

gb_hev_on_failure() {
    local step="$1"
    local rc="$2"
    if [[ "$rc" -eq 0 ]]; then
        return 0
    fi
    if [[ "${GB_HEV_SYNC_STRICT:-1}" == "1" ]]; then
        gb_die "host-env-vault ${step} failed (set GB_HEV_SYNC_STRICT=0 in .greenblue to continue on failure)"
    fi
    gb_info "host-env-vault ${step} failed (GB_HEV_SYNC_STRICT=0, continuing)"
    return 0
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
    local cfg
    cfg="$(gb_hev_config_for_cli)"
    local -a args=(
        sync
        --config "$cfg"
    )

    if [[ -n "${GB_HEV_SYNC_SOURCE:-}" ]]; then
        args+=(--source "$GB_HEV_SYNC_SOURCE")
    fi

    gb_info "host-env-vault sync..."
    local rc=0
    gb_hev_invoke "${args[@]}" || rc=$?
    gb_hev_on_failure sync "$rc"
}

gb_hev_render_profile() {
    local profile="$1"
    local dest parent cfg rc=0
    gb_hev_require_config
    cfg="$(gb_hev_config_for_cli)"
    dest="$(gb_hev_render_root)/${profile}/current"
    parent="$(dirname "$dest")"

    mkdir -p "$parent"
    if [[ -d "$dest" ]]; then
        rm -rf "$dest"
    fi
    mkdir -p "$dest"

    gb_info "host-env-vault render --profile ${profile} -> ${dest}"
    gb_hev_invoke render --profile "$profile" --dest "$dest" --config "$cfg" || rc=$?
    gb_hev_on_failure "render (${profile})" "$rc"
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

gb_hev_runtime_env_file() {
    echo "${GB_RUNTIME_ENV_FILE:-${GB_ROOT}/.gb/runtime.env}"
}

gb_hev_write_runtime_env_line() {
    local key="$1"
    local value="$2"
    local file
    file="$(gb_hev_runtime_env_file)"
    mkdir -p "$(dirname "$file")"
    printf '%s=%s\n' "$key" "$value" >>"$file"
}

gb_hev_apply_mount_map() {
    if [[ -z "${GB_HEV_MOUNT_MAP:-}" ]]; then
        return 0
    fi

    local render_root entry profile rest env_var host_path file
    render_root="$(gb_hev_render_root)"
    file="$(gb_hev_runtime_env_file)"
    export GB_RUNTIME_ENV_FILE="$file"
    mkdir -p "$(dirname "$file")"
    : >"$file"

    for entry in $GB_HEV_MOUNT_MAP; do
        profile="${entry%%:*}"
        rest="${entry#*:}"
        env_var="${rest%%:*}"
        if [[ -z "$profile" || -z "$env_var" || "$profile" == "$entry" ]]; then
            gb_die "invalid GB_HEV_MOUNT_MAP entry (expected profile:ENV_VAR[:container_path]): ${entry}"
        fi
        if [[ -d "${render_root}/${profile}/current" ]]; then
            host_path="$(gb_abs_path "${render_root}/${profile}/current")"
        else
            host_path="${render_root}/${profile}/current"
        fi
        export "${env_var}=${host_path}"
        gb_hev_write_runtime_env_line "$env_var" "$host_path"
    done
}

gb_hev_after_render() {
    gb_hev_apply_mount_map
    gb_hook_run "$GB_HOOK_HEV_AFTER_RENDER" hev-after-render
}

gb_hev_maybe_sync() {
    local when="$1"
    gb_hev_wants_sync "$when" || return 0
    gb_hev_sync
}

gb_hev_maybe_render() {
    local when="$1"
    local did_render=0
    if gb_hev_wants_render "$when"; then
        gb_hev_render_all
        did_render=1
    fi
    if [[ "$did_render" -eq 1 || -n "${GB_HEV_MOUNT_MAP:-}" || -n "${GB_HOOK_HEV_AFTER_RENDER:-}" ]]; then
        gb_hev_after_render
    fi
}
