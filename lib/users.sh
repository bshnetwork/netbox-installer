#!/bin/bash
# users.sh - Manage the system-level user NetBox runs as

# Creates a dedicated system user for running NetBox, if it doesn't exist.
ensure_netbox_system_user() {
    if id "$NETBOX_RUN_USER" >/dev/null 2>&1; then
        msg_info "System user '$NETBOX_RUN_USER' already exists"
        return 0
    fi

    msg_step "Creating system user '$NETBOX_RUN_USER'"
    if [ "$OS_FAMILY" = "freebsd" ]; then
        run_quiet pw useradd "$NETBOX_RUN_USER" -m -s /usr/sbin/nologin -c "NetBox service account"
    else
        run_quiet useradd --system --create-home --shell /usr/sbin/nologin "$NETBOX_RUN_USER"
    fi
    msg_ok "System user '$NETBOX_RUN_USER' created"
}
