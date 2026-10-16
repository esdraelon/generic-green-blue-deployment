#!/usr/bin/env bash

gb_activate_nginx_slot() {
    local slot="$1"
    if [[ "$GB_INSTALL_SKIP_HOST_NGINX" == "1" ]]; then
        gb_info "Skipping host nginx (GB_INSTALL_SKIP_HOST_NGINX=1). Would activate ${slot} -> port $(gb_slot_port "$slot")"
        return
    fi

    case "$GB_NGINX_STRATEGY" in
        site-file)
            gb_nginx_activate_site_file "$slot"
            ;;
        color-symlink)
            gb_nginx_activate_color_symlink "$slot"
            ;;
        *)
            gb_die "unknown GB_NGINX_STRATEGY: ${GB_NGINX_STRATEGY} (use site-file or color-symlink)"
            ;;
    esac
}

gb_nginx_activate_site_file() {
    local slot="$1"
    local source
    source="${GB_ROOT}/$(gb_expand_slot "$GB_NGINX_TEMPLATE" "$slot")"

    if [[ ! -f "$source" ]]; then
        gb_die "nginx template missing: ${source}"
    fi

    gb_info "Activating host nginx for ${slot} (port $(gb_slot_port "$slot"))..."
    gb_run_priv cp "$source" "$GB_NGINX_SITES_AVAILABLE"
    gb_run_priv ln -sf "$GB_NGINX_SITES_AVAILABLE" "$GB_NGINX_SITES_ENABLED"
    gb_run_priv nginx -t
    if command -v systemctl >/dev/null 2>&1; then
        gb_run_priv systemctl reload nginx
    else
        gb_run_priv service nginx reload
    fi
}

gb_nginx_activate_color_symlink() {
    local slot="$1"
    local available="${GB_NGINX_SITES_AVAILABLE_DIR}/${slot}"
    gb_info "Switching nginx color symlink to ${slot} (port $(gb_slot_port "$slot"))..."
    gb_run_priv rm -f "$GB_NGINX_SITES_ENABLED_DEFAULT"
    gb_run_priv ln -s "$available" "$GB_NGINX_SITES_ENABLED_DEFAULT"
    if command -v systemctl >/dev/null 2>&1; then
        gb_run_priv systemctl restart nginx
    else
        gb_run_priv service nginx restart
    fi
}
