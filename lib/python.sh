#!/bin/bash
# python.sh - Create the Python virtual environment and install requirements

setup_python_venv() {
    msg_step "Creating Python virtual environment (this can take a few minutes)"

    su - "$NETBOX_RUN_USER" -c "cd $NETBOX_DIR && python3 -m venv venv" \
        || die "Failed to create virtualenv"

    su - "$NETBOX_RUN_USER" -c "
        cd $NETBOX_DIR &&
        source venv/bin/activate &&
        pip install --upgrade pip wheel -q &&
        pip install -q -r requirements.txt
    " >> "$LOG_FILE" 2>&1 || die "Failed to install Python requirements (see $LOG_FILE)"

    if [ -f "$NETBOX_DIR/requirements-container.txt" ] && [ "$INSTALL_LDAP" = "true" ]; then
        su - "$NETBOX_RUN_USER" -c "
            cd $NETBOX_DIR &&
            source venv/bin/activate &&
            pip install -q django-auth-ldap
        " >> "$LOG_FILE" 2>&1
    fi

    msg_ok "Python virtual environment ready"
}
