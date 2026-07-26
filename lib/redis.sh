#!/bin/bash
# redis.sh - Install and start Redis (used by NetBox for caching & task queue)

install_redis() {
    msg_step "Installing Redis"
    case "$OS_FAMILY" in
        debian)
            pkg_install redis-server
            service_start_enable redis "redis-server"
            ;;
        rhel)
            pkg_install redis
            service_start_enable redis "redis"
            ;;
        freebsd)
            pkg_install redis
            run_quiet sysrc redis_enable=YES
            run_quiet service redis start
            ;;
    esac
    msg_ok "Redis installed and running"
}
