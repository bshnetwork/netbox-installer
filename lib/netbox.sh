#!/bin/bash
# netbox.sh - Fetch NetBox source, configure it, run migrations, create admin

# Resolves NETBOX_VERSION="latest" to an actual release tag (e.g. v4.1.3)
# by querying the GitHub API, and rebuilds NETBOX_SOURCE_URL to match.
# No-op if NETBOX_VERSION is already a concrete tag.
resolve_netbox_version() {
    if [ "$NETBOX_VERSION" != "latest" ]; then
        return 0
    fi

    msg_step "Resolving latest NetBox release"
    local tag

    # Primary: GitHub REST API (subject to a 60 req/hr unauthenticated rate limit)
    tag=$(curl -fsSL -H "User-Agent: netbox-installer" -H "Accept: application/vnd.github+json" \
            https://api.github.com/repos/netbox-community/netbox/releases/latest \
            | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')

    # Fallback: github.com/<repo>/releases/latest redirects to .../tag/<tag>,
    # which works even when the API is rate-limited (no REST quota involved).
    if [ -z "$tag" ]; then
        msg_warn "GitHub API lookup failed (likely rate-limited); trying redirect-based fallback"
        local final_url
        final_url=$(curl -fsSL -H "User-Agent: netbox-installer" -o /dev/null -w '%{url_effective}' \
                        https://github.com/netbox-community/netbox/releases/latest)
        tag="${final_url##*/tag/}"
    fi

    if [ -z "$tag" ] || [ "$tag" = "$final_url" ]; then
        die "Could not determine latest NetBox release (API and redirect fallback both failed). Set NETBOX_VERSION explicitly in your config, e.g. NETBOX_VERSION=\"v4.1.3\"."
    fi

    NETBOX_VERSION="$tag"
    NETBOX_SOURCE_URL="https://github.com/netbox-community/netbox/archive/refs/tags/${NETBOX_VERSION}.tar.gz"
    export NETBOX_VERSION NETBOX_SOURCE_URL
    msg_ok "Latest NetBox release: $NETBOX_VERSION"
}

# Downloads and unpacks NetBox source into $NETBOX_DIR
fetch_netbox_source() {
    resolve_netbox_version

    msg_step "Downloading NetBox ($NETBOX_VERSION)"

    rm -rf "$NETBOX_DIR"
    mkdir -p "$NETBOX_DIR"
    chown "$NETBOX_RUN_USER:$NETBOX_RUN_USER" "$NETBOX_DIR"

    local archive_url="$NETBOX_SOURCE_URL"
    local tmp_archive="/tmp/netbox-src.tar.gz"

    msg_info "Fetching from $archive_url"
    su - "$NETBOX_RUN_USER" -c "curl -fsSL '$archive_url' -o '$tmp_archive'" \
        || die "Failed to download NetBox source from $archive_url"

    su - "$NETBOX_RUN_USER" -c "tar -xzf '$tmp_archive' -C '$NETBOX_DIR' --strip-components=1" \
        || die "Failed to extract NetBox archive"
    rm -f "$tmp_archive"

    chown -R "$NETBOX_RUN_USER:$NETBOX_RUN_USER" "$NETBOX_DIR"
    msg_ok "NetBox source ready at $NETBOX_DIR"
}

# Renders configuration.py from the template
configure_netbox() {
    msg_step "Writing NetBox configuration"

    SECRET_KEY="${SECRET_KEY:-$(gen_secret 50)}"
    SERVER_FQDN="${SERVER_FQDN:-$(get_fqdn)}"
    SERVER_IP="${SERVER_IP:-$(get_primary_ip)}"
    LOCAL_NETWORK="${LOCAL_NETWORK:-$(get_local_network)}"

    export NETBOX_DB NETBOX_USER NETBOX_DB_PASSWORD SECRET_KEY \
           SERVER_FQDN SERVER_IP LOCAL_NETWORK

    render_template "$INSTALLER_ROOT/templates/configuration.py" \
        "$NETBOX_DIR/netbox/netbox/configuration.py"
    chown "$NETBOX_RUN_USER:$NETBOX_RUN_USER" "$NETBOX_DIR/netbox/netbox/configuration.py"
    chmod 640 "$NETBOX_DIR/netbox/netbox/configuration.py"

    msg_ok "configuration.py written (SECRET_KEY generated, ALLOWED_HOSTS=$SERVER_FQDN,$SERVER_IP,localhost,127.0.0.1,$LOCAL_NETWORK)"
}

run_netbox_migrations() {
    msg_step "Running database migrations"
    su - "$NETBOX_RUN_USER" -c "
        cd $NETBOX_DIR && source venv/bin/activate && cd netbox && python manage.py migrate
    " >> "$LOG_FILE" 2>&1 || die "Database migration failed (see $LOG_FILE)"
    msg_ok "Migrations applied"
}

create_netbox_superuser() {
    msg_step "Creating NetBox admin user"

    su - "$NETBOX_RUN_USER" -c "
        cd $NETBOX_DIR && source venv/bin/activate && cd netbox &&
        echo \"
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='$ADMIN_USER').exists():
    User.objects.create_superuser('$ADMIN_USER', '$ADMIN_EMAIL', '$ADMIN_PASSWORD')
\" | python manage.py shell
    " >> "$LOG_FILE" 2>&1 || die "Failed to create superuser (see $LOG_FILE)"

    msg_ok "Admin user '$ADMIN_USER' ready"
}

collect_static_files() {
    msg_step "Collecting static files"
    su - "$NETBOX_RUN_USER" -c "
        cd $NETBOX_DIR && source venv/bin/activate && cd netbox && python manage.py collectstatic --no-input
    " >> "$LOG_FILE" 2>&1 || die "collectstatic failed (see $LOG_FILE)"
    msg_ok "Static files collected"
}

configure_gunicorn() {
    msg_step "Writing Gunicorn configuration"
    export NETBOX_DIR GUNICORN_PORT NETBOX_RUN_USER
    render_template "$INSTALLER_ROOT/templates/gunicorn.conf.py" "$NETBOX_DIR/gunicorn.conf.py"
    chown "$NETBOX_RUN_USER:$NETBOX_RUN_USER" "$NETBOX_DIR/gunicorn.conf.py"
    msg_ok "Gunicorn configuration written"
}

# Housekeeping task NetBox expects to run periodically (safe to re-run)
run_housekeeping() {
    su - "$NETBOX_RUN_USER" -c "
        cd $NETBOX_DIR && source venv/bin/activate && cd netbox && python manage.py remove_stale_contenttypes --no-input
    " >> "$LOG_FILE" 2>&1 || true
}
