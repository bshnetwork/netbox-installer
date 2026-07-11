#!/bin/bash
# postgresql.sh - Install and configure PostgreSQL for NetBox

install_postgresql() {
    msg_step "Installing PostgreSQL"
    case "$OS_FAMILY" in
        debian)
            pkg_install postgresql postgresql-contrib
            ;;
        rhel)
            pkg_install postgresql-server postgresql-contrib
            if [ ! -d /var/lib/pgsql/data/base ]; then
                run_quiet postgresql-setup --initdb
            fi
            ;;
        freebsd)
            pkg_install postgresql15-server postgresql15-client
            run_quiet sysrc postgresql_enable=YES
            [ -d /var/db/postgres/data15 ] || run_quiet service postgresql initdb
            ;;
    esac

    service_start_enable postgresql "${PG_SERVICE_NAME:-postgresql}"
    msg_ok "PostgreSQL installed and running"
}

# Run a single SQL statement as the postgres superuser
_pg_exec() {
    su - postgres -c "psql -v ON_ERROR_STOP=0 -c \"$1\"" >> "$LOG_FILE" 2>&1
}

# Idempotently (re)create the NetBox database and role
setup_netbox_database() {
    msg_step "Configuring NetBox database"

    if confirm "Drop and recreate database '$NETBOX_DB' if it already exists?" y; then
        _pg_exec "REVOKE ALL PRIVILEGES ON SCHEMA public FROM $NETBOX_USER;" || true
        _pg_exec "DROP DATABASE IF EXISTS $NETBOX_DB;"
        _pg_exec "DROP USER IF EXISTS $NETBOX_USER;"
    fi

    _pg_exec "CREATE DATABASE $NETBOX_DB;" || die "Failed to create database $NETBOX_DB (see $LOG_FILE)"
    _pg_exec "CREATE USER $NETBOX_USER WITH PASSWORD '$NETBOX_DB_PASSWORD';" || die "Failed to create DB user $NETBOX_USER"
    _pg_exec "ALTER DATABASE $NETBOX_DB OWNER TO $NETBOX_USER;"
    _pg_exec "GRANT ALL PRIVILEGES ON DATABASE $NETBOX_DB TO $NETBOX_USER;"
    _pg_exec "GRANT ALL PRIVILEGES ON SCHEMA public TO $NETBOX_USER;"

    msg_ok "Database '$NETBOX_DB' and user '$NETBOX_USER' ready"
}
