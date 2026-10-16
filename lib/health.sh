#!/usr/bin/env bash

gb_health_check_port() {
    local label="$1"
    local port="$2"
    local url="http://127.0.0.1:${port}${GB_HEALTH_PATH}"

    gb_info "Health check ${label} at ${url}..."
    local i
    for ((i = 1; i <= GB_HEALTH_RETRIES; i++)); do
        if curl -fsS --max-time 5 "$url" >/dev/null 2>&1; then
            gb_info "${label} is healthy."
            return 0
        fi
        sleep "$GB_HEALTH_INTERVAL"
    done

    gb_die "health check failed for ${label} (${url})"
}
