#!/bin/bash
# service.sh - Cross-platform service start/enable/restart helpers
#
# On Linux this wraps systemctl. On FreeBSD it wraps service/sysrc.
# usage: service_start_enable <logical_name> <actual_service_name>

service_start_enable() {
    local actual="$2"
    if [ "$OS_FAMILY" = "freebsd" ]; then
        run_quiet sysrc "${actual}_enable=YES"
        service "$actual" start >> "$LOG_FILE" 2>&1 || service "$actual" restart >> "$LOG_FILE" 2>&1
    else
        run_quiet systemctl enable "$actual"
        run_quiet systemctl start "$actual"
    fi
}

service_restart() {
    local actual="$1"
    if [ "$OS_FAMILY" = "freebsd" ]; then
        run_quiet service "$actual" restart
    else
        run_quiet systemctl restart "$actual"
    fi
}

service_status() {
    local actual="$1"
    if [ "$OS_FAMILY" = "freebsd" ]; then
        service "$actual" status
    else
        systemctl status "$actual" --no-pager -l
    fi
}

service_stop_disable() {
    local actual="$1"
    if [ "$OS_FAMILY" = "freebsd" ]; then
        service "$actual" stop 2>/dev/null || true
        run_quiet sysrc "${actual}_enable=NO"
    else
        systemctl stop "$actual" 2>/dev/null || true
        systemctl disable "$actual" 2>/dev/null || true
    fi
}

# Installs the NetBox systemd unit (or FreeBSD rc.d script) from templates/
install_netbox_service() {
    msg_step "Installing NetBox service"

    if [ "$OS_FAMILY" = "freebsd" ]; then
        render_template "$INSTALLER_ROOT/templates/netbox.rc" "/usr/local/etc/rc.d/netbox"
        chmod +x /usr/local/etc/rc.d/netbox
        service_start_enable netbox netbox
    else
        render_template "$INSTALLER_ROOT/templates/netbox.service" "/etc/systemd/system/netbox.service"
        run_quiet systemctl daemon-reload
        service_start_enable netbox netbox
    fi

    msg_ok "NetBox service installed and started"
}
