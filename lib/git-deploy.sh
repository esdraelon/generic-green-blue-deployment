#!/usr/bin/env bash

gb_is_commit_sha() {
    [[ "$1" =~ ^[0-9a-fA-F]{7,40}$ ]]
}

gb_discard_local_version_files() {
    git restore --worktree --source=HEAD -- VERSION version.json 2>/dev/null \
        || git checkout -- VERSION version.json 2>/dev/null \
        || true
}

gb_verify_version() {
    if [[ ! -x "${GB_ROOT}/scripts/write-version.sh" ]]; then
        return
    fi
    gb_info "Verifying VERSION matches checked-out commit..."
    if "${GB_ROOT}/scripts/write-version.sh" --check; then
        return
    fi
    gb_info "VERSION is behind HEAD; restamping for this deploy..."
    "${GB_ROOT}/scripts/write-version.sh"
}

gb_resolve_commit() {
    local ref="$1"
    if git -C "$GB_ROOT" cat-file -e "${ref}^{commit}" 2>/dev/null; then
        git -C "$GB_ROOT" rev-parse --verify "${ref}^{commit}"
        return
    fi
    gb_info "Fetching ${ref} from origin..."
    git -C "$GB_ROOT" fetch --tags origin "$ref" || git -C "$GB_ROOT" fetch origin "$ref"
    if git -C "$GB_ROOT" cat-file -e "${ref}^{commit}" 2>/dev/null; then
        git -C "$GB_ROOT" rev-parse --verify "${ref}^{commit}"
        return
    fi
    if [[ "$(git -C "$GB_ROOT" rev-parse --is-shallow-repository 2>/dev/null || echo false)" == "true" ]]; then
        gb_info "Deepening shallow clone to find ${ref}..."
        git -C "$GB_ROOT" fetch --unshallow origin || git -C "$GB_ROOT" fetch --deepen=500 origin
    fi
    if git -C "$GB_ROOT" cat-file -e "${ref}^{commit}" 2>/dev/null; then
        git -C "$GB_ROOT" rev-parse --verify "${ref}^{commit}"
        return
    fi
    gb_die "commit '${ref}' not found after fetch"
}

gb_chown_app() {
    if [[ "$GB_INSTALL_SKIP_CHOWN" == "1" ]]; then
        gb_info "Skipping chown (GB_INSTALL_SKIP_CHOWN=1)."
        return
    fi
    gb_info "Setting ownership to ${GB_WEB_USER}:${GB_WEB_GROUP}..."
    gb_run_priv chown -R "${GB_WEB_USER}:${GB_WEB_GROUP}" "$GB_ROOT"
}

gb_pull_code() {
    if [[ "$GB_INSTALL_SKIP_GIT_PULL" == "1" ]]; then
        gb_info "Skipping git pull (GB_INSTALL_SKIP_GIT_PULL=1)."
        return
    fi

    gb_discard_local_version_files

    gb_info "Fetching ${GB_GIT_BRANCH} from origin..."
    git -C "$GB_ROOT" fetch origin "$GB_GIT_BRANCH"

    if [[ -n "$GB_INSTALL_GIT_REF" ]]; then
        if ! gb_is_commit_sha "$GB_INSTALL_GIT_REF"; then
            gb_die "GB_INSTALL_GIT_REF must be a 7–40 character hex commit SHA"
        fi
        local resolved
        resolved="$(gb_resolve_commit "$GB_INSTALL_GIT_REF")"
        gb_info "Checking out ${resolved} (detached HEAD)..."
        git -C "$GB_ROOT" checkout --detach "$resolved"
        gb_verify_version
        gb_chown_app
        return
    fi

    gb_info "Pulling latest ${GB_GIT_BRANCH}..."
    git -C "$GB_ROOT" checkout "$GB_GIT_BRANCH"
    git -C "$GB_ROOT" pull --ff-only origin "$GB_GIT_BRANCH"
    gb_verify_version
    gb_chown_app
}
