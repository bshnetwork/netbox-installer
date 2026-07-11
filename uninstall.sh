#!/bin/bash
# babak@linuxbsh.ir
# uninstall.sh - Removes NetBox, its service, and (optionally) its database
#
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
        echo "  curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}/uninstall.sh | sudo bash" >&2
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
        exec "$INSTALL_SRC_DIR/uninstall.sh" "$@" <&3 3<&-
    else
        exec "$INSTALL_SRC_DIR/uninstall.sh" "$@"
    fi
fi

if [ ! -d "$SCRIPT_DIR/lib" ]; then
    echo "Error: could not find 'lib/' next to uninstall.sh (looked in: $SCRIPT_DIR). Run this from inside the extracted netbox-installer/ folder." >&2
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

while [ $# -gt 0 ]; do
    case "$1" in
        --config) CONFIG_FILE="$2"; shift 2 ;;
        -y|--yes) ASSUME_YES_CLI="true"; shift ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

. "$SCRIPT_DIR/lib/colors.sh"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/detect_os.sh"
. "$SCRIPT_DIR/lib/validate.sh"
. "$SCRIPT_DIR/lib/service.sh"

[ -f "$CONFIG_FILE" ] || die "Config file not found: $CONFIG_FILE"
. "$CONFIG_FILE"
[ "$ASSUME_YES_CLI" = "true" ] && ASSUME_YES="true"

log_init
assert_root
detect_os

echo -e "${C_RED}${C_BOLD}=== NetBox Uninstaller ===${C_RESET}"
msg_warn "This will stop NetBox and remove: $NETBOX_DIR, the systemd/rc.d service,"
msg_warn "and the web server vhost for NetBox."
confirm "Continue?" n || die "Aborted by user"

msg_step "Stopping services"
service_stop_disable netbox

msg_step "Removing NetBox files"
rm -rf "$NETBOX_DIR"
msg_ok "Removed $NETBOX_DIR"

if [ "$OS_FAMILY" = "freebsd" ]; then
    rm -f /usr/local/etc/rc.d/netbox
else
    rm -f /etc/systemd/system/netbox.service
    systemctl daemon-reload
fi
msg_ok "Removed service unit"

msg_step "Removing web server configuration"
rm -f /etc/nginx/sites-available/netbox /etc/nginx/sites-enabled/netbox
rm -f /etc/nginx/conf.d/netbox.conf /usr/local/etc/nginx/conf.d/netbox.conf
rm -f /etc/apache2/sites-available/netbox.conf /etc/httpd/conf.d/netbox.conf
[ -f /etc/nginx/nginx.conf ] && command -v nginx >/dev/null 2>&1 && (nginx -t >> "$LOG_FILE" 2>&1 && service_restart nginx) || true
msg_ok "Web server configuration removed"

if confirm "Also drop the PostgreSQL database and role ('$NETBOX_DB' / '$NETBOX_USER')?" n; then
    . "$SCRIPT_DIR/lib/postgresql.sh"
    _pg_exec "DROP DATABASE IF EXISTS $NETBOX_DB;"
    _pg_exec "DROP USER IF EXISTS $NETBOX_USER;"
    msg_ok "Database and role dropped"
fi

if confirm "Also remove the system user '$NETBOX_RUN_USER'?" n; then
    if [ "$OS_FAMILY" = "freebsd" ]; then
        pw userdel "$NETBOX_RUN_USER" 2>/dev/null || true
    else
        userdel -r "$NETBOX_RUN_USER" 2>/dev/null || true
    fi
    msg_ok "System user removed"
fi

echo ""
msg_ok "NetBox has been uninstalled"
