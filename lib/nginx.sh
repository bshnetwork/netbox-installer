#!/bin/bash
# nginx.sh - Install and configure Nginx as reverse proxy for NetBox

install_and_configure_nginx() {
    msg_step "Installing and configuring Nginx"

    pkg_install nginx

    export NGINX_PORT SERVER_FQDN SERVER_IP GUNICORN_PORT NETBOX_DIR

    if [ "$OS_FAMILY" = "debian" ]; then
        render_template "$INSTALLER_ROOT/templates/nginx.conf" "/etc/nginx/sites-available/netbox"
        ln -sf /etc/nginx/sites-available/netbox /etc/nginx/sites-enabled/netbox
        rm -f /etc/nginx/sites-enabled/default
    else
        # RHEL family / FreeBSD use conf.d style includes
        local conf_dir="/etc/nginx/conf.d"
        [ "$OS_FAMILY" = "freebsd" ] && conf_dir="/usr/local/etc/nginx/conf.d"
        mkdir -p "$conf_dir"
        render_template "$INSTALLER_ROOT/templates/nginx.conf" "$conf_dir/netbox.conf"
    fi

    if [ "$OS_FAMILY" = "freebsd" ]; then
        nginx -t || die "Nginx configuration test failed"
        service_start_enable nginx nginx
    else
        run_quiet nginx -t
        service_start_enable nginx nginx
    fi

    msg_ok "Nginx configured, listening on port $NGINX_PORT"
}
