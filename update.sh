#!/bin/bash
# update.sh - Upgrade an existing NetBox install to a new release
#
# Follows the official upgrade procedure: fetch new source into a fresh
# directory, copy over local settings/media, reinstall requirements,
# migrate, collectstatic, restart services.
#
# IMPORTANT: requires bash. If you see "syntax error near unexpected token",
# you likely ran this with `sh` instead of `bash`. Use:
#   sudo bash update.sh   /   curl ... | sudo bash
#
if [ -z "$BASH_VERSION" ]; then
    if [ -f "$0" ] && command -v bash >/dev/null 2>&1; then
        exec bash "$0" "$@"
    else
        echo "Error: this script must be run with bash, not sh/dash." >&2
        echo "Use:   sudo bash update.sh" >&2
        echo "Or:    curl -fsSL <url>/update.sh | sudo bash" >&2
        exit 1
    fi
fi
#
# Remote usage (fetches the repo into a temp dir, auto-removed afterward):
#   curl -fsSL https://raw.githubusercontent.com/bshnetwork/netbox-installer/main/update.sh | sudo bash
set -e

GITHUB_REPO="${NETBOX_INSTALLER_REPO:-bshnetwork/netbox-installer}"
GITHUB_BRANCH="${NETBOX_INSTALLER_BRANCH:-main}"

SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
fi

if [ -z "$SCRIPT_DIR" ] || [ ! -d "$SCRIPT_DIR/lib" ]; then
    if [ "$EUID" -ne 0 ]; then
        echo "Error: please run as root, e.g.:" >&2
        echo "  curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}/update.sh | sudo bash" >&2
        exit 1
    fi
    command -v curl >/dev/null 2>&1 || { echo "Error: curl is required but not installed." >&2; exit 1; }
    command -v tar  >/dev/null 2>&1 || { echo "Error: tar is required but not installed." >&2; exit 1; }

    if [ -n "$NETBOX_INSTALLER_SRC_DIR" ]; then
        INSTALL_SRC_DIR="$NETBOX_INSTALLER_SRC_DIR"
        AUTO_CLEANUP_DIR=""
        mkdir -p "$INSTALL_SRC_DIR"
    else
        INSTALL_SRC_DIR="$(mktemp -d /tmp/netbox-installer.XXXXXX)"
        AUTO_CLEANUP_DIR="$INSTALL_SRC_DIR"
    fi

    echo "==> Fetching netbox-installer (${GITHUB_REPO}@${GITHUB_BRANCH}) into a temporary directory..."
    TARBALL_URL="https://github.com/${GITHUB_REPO}/archive/refs/heads/${GITHUB_BRANCH}.tar.gz"
    TMP_TARBALL="$(mktemp /tmp/netbox-installer-XXXXXX.tar.gz)"

    if ! curl -fsSL -H "User-Agent: netbox-installer" -o "$TMP_TARBALL" "$TARBALL_URL"; then
        rm -f "$TMP_TARBALL"
        [ -n "$AUTO_CLEANUP_DIR" ] && rm -rf "$AUTO_CLEANUP_DIR"
        echo "Error: failed to download $TARBALL_URL" >&2
        exit 1
    fi
    if ! tar -xzf "$TMP_TARBALL" -C "$INSTALL_SRC_DIR" --strip-components=1; then
        rm -f "$TMP_TARBALL"
        [ -n "$AUTO_CLEANUP_DIR" ] && rm -rf "$AUTO_CLEANUP_DIR"
        echo "Error: failed to extract the downloaded archive." >&2
        exit 1
    fi
    rm -f "$TMP_TARBALL"
    chmod +x "$INSTALL_SRC_DIR"/*.sh
    echo ""

    export NETBOX_INSTALLER_AUTO_CLEANUP_DIR="$AUTO_CLEANUP_DIR"

    if { exec 3<>/dev/tty; } 2>/dev/null; then
        exec "$INSTALL_SRC_DIR/update.sh" "$@" <&3 3<&-
    else
        exec "$INSTALL_SRC_DIR/update.sh" "$@"
    fi
fi

if [ ! -d "$SCRIPT_DIR/lib" ]; then
    echo "Error: could not find 'lib/' next to update.sh (looked in: $SCRIPT_DIR). Run this from inside the extracted netbox-installer/ folder." >&2
    exit 1
fi

if [ -n "$NETBOX_INSTALLER_AUTO_CLEANUP_DIR" ] && [ "$NETBOX_INSTALLER_AUTO_CLEANUP_DIR" = "$SCRIPT_DIR" ]; then
    trap '
        ec=$?
        rm -rf "$SCRIPT_DIR"
        exit $ec
    ' EXIT
fi

CONFIG_FILE="$SCRIPT_DIR/config/defaults.conf"
NEW_VERSION=""

while [ $# -gt 0 ]; do
    case "$1" in
        --config) CONFIG_FILE="$2"; shift 2 ;;
        --version) NEW_VERSION="$2"; shift 2 ;;
        -y|--yes) ASSUME_YES_CLI="true"; shift ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

. "$SCRIPT_DIR/lib/colors.sh"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/detect_os.sh"
. "$SCRIPT_DIR/lib/validate.sh"
. "$SCRIPT_DIR/lib/service.sh"
. "$SCRIPT_DIR/lib/netbox.sh"

[ -f "$CONFIG_FILE" ] || die "Config file not found: $CONFIG_FILE"
. "$CONFIG_FILE"
[ "$ASSUME_YES_CLI" = "true" ] && ASSUME_YES="true"
[ -n "$NEW_VERSION" ] && NETBOX_VERSION="$NEW_VERSION"

log_init
assert_root
detect_os

[ -d "$NETBOX_DIR" ] || die "No existing NetBox install found at $NETBOX_DIR. Use install.sh instead."

print_banner
echo -e "${C_BOLD}=== NetBox Updater ===${C_RESET}"
resolve_netbox_version
msg_info "Target version: $NETBOX_VERSION"
confirm "Proceed with update? NetBox will be briefly unavailable." y || die "Aborted by user"

BACKUP_DIR="/opt/netbox-backup-$(date +%Y%m%d%H%M%S)"
NEW_DIR="/opt/netbox-new"

msg_step "Backing up current installation"
cp -a "$NETBOX_DIR" "$BACKUP_DIR"
msg_ok "Backed up to $BACKUP_DIR"

msg_step "Dumping database"
su - postgres -c "pg_dump $NETBOX_DB" > "${BACKUP_DIR}/${NETBOX_DB}.sql" 2>> "$LOG_FILE" \
    || msg_warn "Database dump failed; continuing without it (check $LOG_FILE)"

msg_step "Downloading new NetBox release"
rm -rf "$NEW_DIR"
mkdir -p "$NEW_DIR"
su - "$NETBOX_RUN_USER" -c "curl -fsSL '$NETBOX_SOURCE_URL' -o /tmp/netbox-new.tar.gz" \
    || die "Failed to download $NETBOX_SOURCE_URL"
su - "$NETBOX_RUN_USER" -c "tar -xzf /tmp/netbox-new.tar.gz -C '$NEW_DIR' --strip-components=1"
rm -f /tmp/netbox-new.tar.gz

msg_step "Carrying over local configuration and media"
cp "$NETBOX_DIR/netbox/netbox/configuration.py" "$NEW_DIR/netbox/netbox/configuration.py"
[ -d "$NETBOX_DIR/netbox/media" ] && cp -a "$NETBOX_DIR/netbox/media" "$NEW_DIR/netbox/"
[ -d "$NETBOX_DIR/netbox/reports" ] && cp -a "$NETBOX_DIR/netbox/reports" "$NEW_DIR/netbox/"
[ -d "$NETBOX_DIR/netbox/scripts" ] && cp -a "$NETBOX_DIR/netbox/scripts" "$NEW_DIR/netbox/"
cp "$NETBOX_DIR/gunicorn.conf.py" "$NEW_DIR/gunicorn.conf.py" 2>/dev/null || true

msg_step "Swapping in new release"
service_stop_disable netbox
rm -rf "${NETBOX_DIR}.old"
mv "$NETBOX_DIR" "${NETBOX_DIR}.old"
mv "$NEW_DIR" "$NETBOX_DIR"
chown -R "$NETBOX_RUN_USER:$NETBOX_RUN_USER" "$NETBOX_DIR"

setup_python_venv
run_netbox_migrations
collect_static_files
run_housekeeping

msg_step "Restarting services"
service_start_enable netbox netbox
command -v nginx >/dev/null 2>&1 && service_restart nginx || true
command -v httpd >/dev/null 2>&1 && service_restart httpd || true
command -v apache2 >/dev/null 2>&1 && service_restart apache2 || true

rm -rf "${NETBOX_DIR}.old"

echo ""
msg_ok "NetBox updated to $NETBOX_VERSION"
msg_info "Pre-update backup kept at: $BACKUP_DIR"
