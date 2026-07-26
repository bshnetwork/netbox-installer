#!/bin/bash
# validate.sh - Pre-flight checks

assert_root() {
    if [ "$EUID" -ne 0 ]; then
        die "Please run this script as root (sudo ./install.sh)"
    fi
}

assert_min_ram() {
    local min_mb="${1:-4096}"
    local total_mb
    total_mb=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}')
    if [ -n "$total_mb" ] && [ "$total_mb" -lt "$min_mb" ]; then
        msg_warn "System has ${total_mb}MB RAM; NetBox recommends at least ${min_mb}MB"
        confirm "Continue anyway?" n || die "Aborted by user"
    fi
}

assert_disk_space() {
    local min_gb="${1:-5}"
    local avail_kb
    avail_kb=$(df -Pk / | awk 'NR==2{print $4}')
    local avail_gb=$((avail_kb / 1024 / 1024))
    if [ "$avail_gb" -lt "$min_gb" ]; then
        die "Insufficient disk space: ${avail_gb}GB available, ${min_gb}GB required"
    fi
}

validate_config() {
    [ -n "$NETBOX_DB_PASSWORD" ] || die "NETBOX_DB_PASSWORD is not set"
    [ -n "$ADMIN_USER" ] || die "ADMIN_USER is not set"
    [ -n "$ADMIN_EMAIL" ] || die "ADMIN_EMAIL is not set"

    case "$ADMIN_EMAIL" in
        *[!@]*@*[!@]*.*[!@]*) : ;;
        *) die "ADMIN_EMAIL does not look like a valid email address: $ADMIN_EMAIL" ;;
    esac

    if [ "$WEB_SERVER" != "nginx" ] && [ "$WEB_SERVER" != "apache" ] && [ "$WEB_SERVER" != "none" ]; then
        die "WEB_SERVER must be one of: nginx, apache, none (got: $WEB_SERVER)"
    fi
}

assert_command_exists() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}
