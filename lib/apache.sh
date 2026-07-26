#!/bin/bash
# apache.sh - Install and configure Apache httpd as reverse proxy for NetBox
# (alternative to nginx.sh, selected via WEB_SERVER=apache)

install_and_configure_apache() {
    msg_step "Installing and configuring Apache"

    case "$OS_FAMILY" in
        debian)
            pkg_install apache2
            a2enmod proxy proxy_http headers rewrite >> "$LOG_FILE" 2>&1
            ;;
        rhel)
            pkg_install httpd mod_ssl
            ;;
        freebsd)
            pkg_install apache24
            ;;
    esac

    export NGINX_PORT SERVER_FQDN SERVER_IP GUNICORN_PORT NETBOX_DIR

    local conf_dest
    case "$OS_FAMILY" in
        debian) conf_dest="/etc/apache2/sites-available/netbox.conf" ;;
        rhel)   conf_dest="/etc/httpd/conf.d/netbox.conf" ;;
        freebsd) conf_dest="/usr/local/etc/apache24/Includes/netbox.conf" ;;
    esac

    render_template "$INSTALLER_ROOT/templates/apache.conf" "$conf_dest"

    if [ "$OS_FAMILY" = "debian" ]; then
        a2ensite netbox.conf >> "$LOG_FILE" 2>&1
        a2dissite 000-default.conf >> "$LOG_FILE" 2>&1 || true
    fi

    local svc="apache2"
    [ "$OS_FAMILY" = "rhel" ] && svc="httpd"
    service_start_enable "$svc" "$svc"

    msg_ok "Apache configured, listening on port $NGINX_PORT"
}
