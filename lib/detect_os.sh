#!/bin/bash
# detect_os.sh - Detect distro family and set PKG_MANAGER / OS_FAMILY
#
# Exposes:
#   OS_ID          e.g. ubuntu, debian, rocky, almalinux, freebsd
#   OS_VERSION_ID  e.g. 22.04, 12, 9
#   OS_FAMILY      debian | rhel | freebsd
#   PKG_MANAGER    apt | dnf | pkg

detect_os() {
    if [ "$(uname -s)" = "FreeBSD" ]; then
        OS_ID="freebsd"
        OS_VERSION_ID="$(freebsd-version 2>/dev/null | cut -d- -f1)"
        OS_FAMILY="freebsd"
        PKG_MANAGER="pkg"
        return 0
    fi

    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        OS_ID="$ID"
        OS_VERSION_ID="$VERSION_ID"
    else
        die "Cannot detect operating system: /etc/os-release not found"
    fi

    case "$OS_ID" in
        ubuntu|debian)
            OS_FAMILY="debian"
            PKG_MANAGER="apt"
            ;;
        rocky|almalinux|rhel|centos|fedora)
            OS_FAMILY="rhel"
            PKG_MANAGER="dnf"
            ;;
        *)
            die "Unsupported operating system: $OS_ID. Supported: Ubuntu, Debian, Rocky, AlmaLinux, FreeBSD"
            ;;
    esac

    export OS_ID OS_VERSION_ID OS_FAMILY PKG_MANAGER
}

# Print a human readable OS summary
print_os_info() {
    msg_info "Detected OS: ${OS_ID} ${OS_VERSION_ID} (family: ${OS_FAMILY}, package manager: ${PKG_MANAGER})"
}

# Ensure detected OS is one this installer has been validated against
assert_supported_os() {
    case "$OS_ID" in
        ubuntu)
            case "$OS_VERSION_ID" in
                20.04|22.04|24.04) : ;;
                *) msg_warn "Ubuntu $OS_VERSION_ID is not officially validated, continuing anyway" ;;
            esac
            ;;
        debian)
            case "$OS_VERSION_ID" in
                11|12) : ;;
                *) msg_warn "Debian $OS_VERSION_ID is not officially validated, continuing anyway" ;;
            esac
            ;;
        rocky|almalinux)
            case "$OS_VERSION_ID" in
                9*) : ;;
                *) msg_warn "$OS_ID $OS_VERSION_ID is not officially validated, continuing anyway" ;;
            esac
            ;;
        freebsd)
            msg_warn "FreeBSD support is experimental. Review docs/FreeBSD.md before continuing."
            ;;
    esac
}
