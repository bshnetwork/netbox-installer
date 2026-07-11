#!/bin/bash
# install.sh - NetBox Installer Entry Point by babak@linuxbsh.ir
# babak@linuxbsh.ir
set -e

GITHUB_REPO="${NETBOX_INSTALLER_REPO:-bshnetwork/netbox-installer}"
GITHUB_BRANCH="${NETBOX_INSTALLER_BRANCH:-main}"
INSTALL_SRC_DIR="${NETBOX_INSTALLER_SRC_DIR:-/opt/netbox-installer}"

# Resolve the directory this script actually lives in on disk, if any.
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
fi

# ---- bootstrap mode: fetch the full repo from GitHub, then re-exec --------
if [ -z "$SCRIPT_DIR" ] || [ ! -d "$SCRIPT_DIR/lib" ]; then
    if [ "$EUID" -ne 0 ]; then
        echo "Error: please run as root, e.g.:" >&2
        echo "  curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}/install.sh | sudo bash" >&2
        exit 1
    fi
    command -v curl >/dev/null 2>&1 || { echo "Error: curl is required but not installed." >&2; exit 1; }
    command -v tar  >/dev/null 2>&1 || { echo "Error: tar is required but not installed." >&2; exit 1; }

    echo "==> Fetching netbox-installer (${GITHUB_REPO}@${GITHUB_BRANCH}) from GitHub..."

    TARBALL_URL="https://github.com/${GITHUB_REPO}/archive/refs/heads/${GITHUB_BRANCH}.tar.gz"
    TMP_TARBALL="$(mktemp /tmp/netbox-installer-XXXXXX.tar.gz)"

    if ! curl -fsSL -H "User-Agent: netbox-installer" -o "$TMP_TARBALL" "$TARBALL_URL"; then
        rm -f "$TMP_TARBALL"
        echo "Error: failed to download $TARBALL_URL" >&2
        echo "Check your network settings / the repo & branch name (NETBOX_INSTALLER_REPO=${GITHUB_REPO}, NETBOX_INSTALLER_BRANCH=${GITHUB_BRANCH})." >&2
        exit 1
    fi

    mkdir -p "$INSTALL_SRC_DIR"
    if ! tar -xzf "$TMP_TARBALL" -C "$INSTALL_SRC_DIR" --strip-components=1; then
        rm -f "$TMP_TARBALL"
        echo "Error: failed to extract the downloaded archive." >&2
        exit 1
    fi
    rm -f "$TMP_TARBALL"

    [ -x "$INSTALL_SRC_DIR/install.sh" ] || chmod +x "$INSTALL_SRC_DIR/install.sh"
    echo "==> Fetched to $INSTALL_SRC_DIR, continuing installation..."
    echo ""

    # Re-exec the real install.sh from the now-local checkout, forwarding
    # any arguments. Try to re-attach the controlling terminal for stdin so
    # interactive prompts still work even though this script was piped in;
    # fall back silently to inherited stdin if no controlling tty exists
    # (e.g. CI, containers, non-interactive shells).
    if { exec 3<>/dev/tty; } 2>/dev/null; then
        exec "$INSTALL_SRC_DIR/install.sh" "$@" <&3 3<&-
    else
        exec "$INSTALL_SRC_DIR/install.sh" "$@"
    fi
fi

if [ ! -d "$SCRIPT_DIR/lib" ]; then
    echo "Error: could not find the 'lib/' directory next to install.sh (looked in: $SCRIPT_DIR)" >&2
    echo "" >&2
    echo "This usually means install.sh was copied/run on its own, separate from the" >&2
    echo "rest of the netbox-installer/ folder. Re-extract the full archive and run" >&2
    echo "install.sh from inside it, e.g.:" >&2
    echo "  tar -xzf netbox-installer.tar.gz" >&2
    echo "  cd netbox-installer" >&2
    echo "  sudo ./install.sh" >&2
    exit 1
fi

CONFIG_FILE="$SCRIPT_DIR/config/defaults.conf"
CLI_YES="false"
CLI_WEB=""

# ---- parse CLI args -------------------------------------------------------
while [ $# -gt 0 ]; do
    case "$1" in
        --config)
            CONFIG_FILE="$2"; shift 2 ;;
        -y|--yes)
            CLI_YES="true"; shift ;;
        --web)
            CLI_WEB="$2"; shift 2 ;;
        -h|--help)
            cat <<EOF
NetBox Installer

Usage: sudo ./install.sh [options]

Options:
  --config <file>   Use a custom config file (default: config/defaults.conf)
  -y, --yes         Assume "yes" to all prompts (non-interactive)
  --web <server>    nginx | apache | none  (overrides config file)
  -h, --help        Show this help message
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# ---- load libraries ---------------------------------------------------
# shellcheck source=lib/colors.sh
. "$SCRIPT_DIR/lib/colors.sh"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/detect_os.sh
. "$SCRIPT_DIR/lib/detect_os.sh"
# shellcheck source=lib/validate.sh
. "$SCRIPT_DIR/lib/validate.sh"
# shellcheck source=lib/packages.sh
. "$SCRIPT_DIR/lib/packages.sh"
# shellcheck source=lib/users.sh
. "$SCRIPT_DIR/lib/users.sh"
# shellcheck source=lib/postgresql.sh
. "$SCRIPT_DIR/lib/postgresql.sh"
# shellcheck source=lib/redis.sh
. "$SCRIPT_DIR/lib/redis.sh"
# shellcheck source=lib/python.sh
. "$SCRIPT_DIR/lib/python.sh"
# shellcheck source=lib/service.sh
. "$SCRIPT_DIR/lib/service.sh"
# shellcheck source=lib/netbox.sh
. "$SCRIPT_DIR/lib/netbox.sh"
# shellcheck source=lib/nginx.sh
. "$SCRIPT_DIR/lib/nginx.sh"
# shellcheck source=lib/apache.sh
. "$SCRIPT_DIR/lib/apache.sh"
# shellcheck source=lib/firewall.sh
. "$SCRIPT_DIR/lib/firewall.sh"

# ---- load config --------------------------------------------------------
[ -f "$CONFIG_FILE" ] || die "Config file not found: $CONFIG_FILE"
# shellcheck source=config/defaults.conf
. "$CONFIG_FILE"

[ -n "$CLI_WEB" ] && WEB_SERVER="$CLI_WEB"
[ "$CLI_YES" = "true" ] && ASSUME_YES="true"

log_init
assert_root

echo -e "${C_BOLD}=== NetBox Installer ===${C_RESET}"
echo "Config file: $CONFIG_FILE"
echo "Log file:    $LOG_FILE"
echo ""

detect_os
print_os_info
assert_supported_os
assert_disk_space 5
assert_min_ram 3072

# Auto-generate secrets that were left as CHANGE_ME
if [ "$NETBOX_DB_PASSWORD" = "CHANGE_ME" ] && [ "$NETBOX_DB_PASSWORD_AUTOGEN" = "true" ]; then
    NETBOX_DB_PASSWORD="$(gen_secret 24)"
fi
if [ "$ADMIN_PASSWORD" = "CHANGE_ME" ] && [ "$ADMIN_PASSWORD_AUTOGEN" = "true" ]; then
    ADMIN_PASSWORD="$(gen_secret 16)"
fi

validate_config
resolve_netbox_version

msg_step "Installation plan"
msg_info "NetBox version:  ${NETBOX_VERSION}"
msg_info "Install dir:     ${NETBOX_DIR}"
msg_info "Run as user:     ${NETBOX_RUN_USER}"
msg_info "Database:        ${NETBOX_DB} (user: ${NETBOX_USER})"
msg_info "Web server:      ${WEB_SERVER}"
confirm "Proceed with installation?" y || die "Aborted by user"

pkg_update
install_build_dependencies
ensure_netbox_system_user

install_postgresql
setup_netbox_database

install_redis

fetch_netbox_source
setup_python_venv
configure_netbox
run_netbox_migrations
create_netbox_superuser
collect_static_files
configure_gunicorn

install_netbox_service

case "$WEB_SERVER" in
    nginx)  install_and_configure_nginx ;;
    apache) install_and_configure_apache ;;
    none)   msg_info "WEB_SERVER=none, skipping reverse proxy setup" ;;
esac

configure_firewall

# ---- summary ------------------------------------------------------------
CREDS_FILE="/root/.netbox-installer-credentials"
cat > "$CREDS_FILE" <<EOF
NetBox installation credentials - generated $(date)
NetBox URL:      http://${SERVER_FQDN:-$SERVER_IP}

Admin login:
  Username: $ADMIN_USER
  Password: $ADMIN_PASSWORD

Database credentials:
  Database: $NETBOX_DB
  User:     $NETBOX_USER
  Password: $NETBOX_DB_PASSWORD
EOF
chmod 600 "$CREDS_FILE"

echo ""
echo -e "${C_GREEN}${C_BOLD}=== Installation Complete! ===${C_RESET}"
echo ""
echo -e "NetBox URL:      ${C_BOLD}http://${SERVER_FQDN:-$SERVER_IP}${C_RESET}"
echo ""
echo "Admin login:"
echo "  Username: $ADMIN_USER"
echo "  Password: $ADMIN_PASSWORD"
echo ""
echo "Database credentials (save these somewhere safe!):"
echo "  Database: $NETBOX_DB"
echo "  User:     $NETBOX_USER"
echo "  Password: $NETBOX_DB_PASSWORD"
echo ""
echo "These credentials were also saved to: $CREDS_FILE (mode 600, root only)"
echo ""

msg_step "Service status"
service_status netbox || true
