#!/bin/bash
# firewall.sh - Open the required ports on whichever firewall is active

configure_firewall() {
    [ "$MANAGE_FIREWALL" = "true" ] || { msg_info "Skipping firewall configuration (MANAGE_FIREWALL=false)"; return 0; }

    msg_step "Configuring firewall"

    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        run_quiet ufw allow "${NGINX_PORT}/tcp"
        msg_ok "ufw: opened port ${NGINX_PORT}/tcp"

    elif command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
        run_quiet firewall-cmd --permanent --add-port="${NGINX_PORT}/tcp"
        run_quiet firewall-cmd --reload
        msg_ok "firewalld: opened port ${NGINX_PORT}/tcp"

    elif [ "$OS_FAMILY" = "freebsd" ] && command -v pfctl >/dev/null 2>&1; then
        msg_warn "pf detected: please ensure port ${NGINX_PORT}/tcp is allowed in /etc/pf.conf"

    else
        msg_info "No supported active firewall detected; skipping"
    fi
}
