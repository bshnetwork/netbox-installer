# Changelog

All notable changes to this project are documented in this file.

## [1.17.0] - released

### Added
- Restructured original single-file `install_netbox.sh` into a modular
  `lib/` layout (colors, common, detect_os, validate, packages, users,
  postgresql, redis, python, netbox, nginx, apache, service, firewall).
- Templated config files under `templates/` with `@@TOKEN@@` substitution,
  replacing inline `cat > file << EOF` heredocs.
- `config/defaults.conf` for centralized, overridable configuration.
- Multi-OS support: Ubuntu, Debian, Rocky Linux, AlmaLinux (dnf-based), and
  experimental FreeBSD (pkg/rc.d-based).
- `WEB_SERVER=apache` as an alternative to the default Nginx reverse proxy.
- `uninstall.sh` for clean removal (service, files, optional DB/user drop).
- `update.sh` implementing the official NetBox upgrade procedure (backup,
  fetch new release, carry over config/media, migrate, restart).
- Auto-generated database and admin passwords (no more hardcoded secrets).
- Structured logging to `/var/log/netbox-installer.log` with colored,
  concise terminal output.
- Firewall auto-detection (`ufw` / `firewalld` / `pf` warning) via
  `lib/firewall.sh`.
- Per-OS docs (`docs/Ubuntu.md`, `docs/Rocky.md`, `docs/AlmaLinux.md`,
  `docs/FreeBSD.md`) and a troubleshooting `docs/FAQ.md`.

### Changed
- NetBox now runs as a dedicated `netbox` system user instead of the
  invoking `sudo` user.
- NetBox source now fetched from official GitHub release tags by default
  instead of a third-party mirror URL.

### Security
- Removed hardcoded database/admin passwords from the script; both are
  randomly generated at install time unless explicitly overridden.
- Credentials summary written to a root-only (`chmod 600`) file instead of
  only appearing in terminal scrollback.
