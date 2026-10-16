#!/usr/bin/env bash
set -euo pipefail

gb_cmd_hev_sync() {
    gb_hev_sync
}

gb_cmd_hev_render() {
    if [[ $# -gt 0 ]]; then
        local profile
        for profile in "$@"; do
            gb_hev_render_profile "$profile"
        done
        return
    fi
    gb_hev_render_all
}
