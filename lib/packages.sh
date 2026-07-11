#!/bin/bash
# packages.sh - OS-aware system package installation

pkg_update() {
    msg_info "Refreshing package indexes..."
    case "$PKG_MANAGER" in
        apt)
            wait_for_apt_lock
            run_quiet apt-get update
            ;;
        dnf)
            run_quiet dnf makecache
            ;;
        pkg)
            run_quiet pkg update -f
            ;;
    esac
}

pkg_install() {
    # usage: pkg_install pkg1 pkg2 ...
    case "$PKG_MANAGER" in
        apt)
            wait_for_apt_lock
            run_quiet env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
            ;;
        dnf)
            run_quiet dnf install -y "$@"
            ;;
        pkg)
            run_quiet pkg install -y "$@"
            ;;
    esac
}

# Maps a logical package name to the correct name per-distro and installs it
install_build_dependencies() {
    msg_step "Installing build dependencies"
    case "$OS_FAMILY" in
        debian)
            pkg_install python3-pip python3-venv python3-dev build-essential \
                libxml2-dev libxslt1-dev libffi-dev libpq-dev libssl-dev zlib1g-dev \
                git curl
            ;;
        rhel)
            pkg_install python3-pip python3-devel gcc gcc-c++ make \
                libxml2-devel libxslt-devel libffi-devel libpq-devel openssl-devel zlib-devel \
                git curl
            ;;
        freebsd)
            pkg_install python3 py3-pip git curl libxml2 libxslt libffi \
                postgresql-client openssl
            ;;
    esac
    msg_ok "Build dependencies installed"
}
