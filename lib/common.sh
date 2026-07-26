#!/bin/bash
# common.sh - Shared helper functions used across the installer
#
# This file must be sourced AFTER colors.sh

SCRIPT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(dirname "$SCRIPT_LIB_DIR")"
LOG_FILE="${LOG_FILE:-/var/log/netbox-installer.log}"

# ---- branding -------------------------------------------------------

print_banner() {
    [ "$NETBOX_INSTALLER_NO_BANNER" = "true" ] && return 0
    echo -e "${C_CYAN}${C_BOLD}"
    cat <<'EOF'
 _         _                _                      _    
| |__  ___| |__  _ __   ___| |___      _____  _ __| | __
| '_ \/ __| '_ \| '_ \ / _ \ __\ \ /\ / / _ \| '__| |/ /
| |_) \__ \ | | | | | |  __/ |_ \ V  V / (_) | |  |   < 
|_.__/|___/_| |_|_| |_|\___|\__| \_/\_/ \___/|_|  |_|\_\
EOF
    echo -e "${C_RESET}${C_BOLD}                by babak keshavarz${C_RESET}"
    echo -e "${C_CYAN}                   linuxbsh.ir${C_RESET}"
    echo ""
}

# ---- logging / output helpers ---------------------------------------

log_init() {
    touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/netbox-installer.log"
    echo "===== NetBox Installer started at $(date) =====" >> "$LOG_FILE"
}

_log() {
    echo -e "$1" | tee -a "$LOG_FILE" >/dev/null
}

msg_step() {
    echo -e "\n${C_BLUE}${C_BOLD}==>${C_RESET} ${C_BOLD}$1${C_RESET}"
    _log "[STEP] $1"
}

msg_info() {
    echo -e "${C_CYAN}  -${C_RESET} $1"
    _log "[INFO] $1"
}

msg_ok() {
    echo -e "${C_GREEN}  ✔${C_RESET} $1"
    _log "[ OK ] $1"
}

msg_warn() {
    echo -e "${C_YELLOW}  ⚠${C_RESET} $1"
    _log "[WARN] $1"
}

msg_error() {
    echo -e "${C_RED}  ✘ $1${C_RESET}" >&2
    _log "[FAIL] $1"
}

die() {
    msg_error "$1"
    exit "${2:-1}"
}

# ---- generic utilities -----------------------------------------------

# run a command, sending its output to the log file only (quiet mode)
run_quiet() {
    if ! "$@" >> "$LOG_FILE" 2>&1; then
        die "Command failed: $* (see $LOG_FILE for details)"
    fi
}

# Wait until dpkg/apt lock is released (Debian/Ubuntu only)
wait_for_apt_lock() {
    [ "$PKG_MANAGER" = "apt" ] || return 0
    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
        msg_info "Waiting for other apt/dpkg processes to finish..."
        sleep 2
    done
}

# Generate a random alphanumeric secret of a given length (default 50)
gen_secret() {
    local length="${1:-50}"
    python3 -c "import secrets; print(secrets.token_urlsafe($length))" 2>/dev/null \
        || tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
}

# Ask a yes/no question, returns 0 for yes, 1 for no
confirm() {
    local prompt="$1"
    local default="${2:-y}"
    local reply
    if [ "$ASSUME_YES" = "true" ]; then
        return 0
    fi
    if [ "$default" = "y" ]; then
        read -r -p "$prompt [Y/n]: " reply
        reply="${reply:-y}"
    else
        read -r -p "$prompt [y/N]: " reply
        reply="${reply:-n}"
    fi
    case "$reply" in
        [Yy]) return 0 ;;
        *) return 1 ;;
    esac
}

# Render a template file: replaces @@VAR@@ placeholders with the value
# of the shell variable VAR. Usage: render_template src.tpl dest.file
render_template() {
    local src="$1"
    local dest="$2"
    [ -f "$src" ] || die "Template not found: $src"

    local tmp
    tmp="$(mktemp)"
    cp "$src" "$tmp"

    # Extract every @@TOKEN@@ occurring in the template and substitute it
    # with the current value of the shell variable of the same name.
    for token in $(grep -oE '@@[A-Z0-9_]+@@' "$src" | sort -u); do
        local var_name="${token//@/}"
        local var_value="${!var_name}"
        # Escape sed special characters in the replacement value
        local escaped
        escaped=$(printf '%s' "$var_value" | sed -e 's/[\/&]/\\&/g')
        sed -i "s/@@${var_name}@@/${escaped}/g" "$tmp"
    done

    mkdir -p "$(dirname "$dest")"
    mv "$tmp" "$dest"
}

# Get primary IPv4 address of the host
get_primary_ip() {
    hostname -I 2>/dev/null | awk '{print $1}'
}

# Get FQDN, falling back to hostname if FQDN resolution fails
get_fqdn() {
    hostname -f 2>/dev/null || hostname
}

# Guess the local /24 network based on the primary interface source IP
get_local_network() {
    ip route 2>/dev/null | grep -oP '(?<=src )[\d.]+' | head -1 \
        | awk -F. '{print $1"."$2"."$3".0/24"}'
}
