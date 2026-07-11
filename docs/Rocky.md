# Installing NetBox on Rocky Linux babak keshavarz

Tested on Rocky Linux 10.

## Requirements
- 2 vCPU / 4GB RAM minimum
- 5GB+ free disk space
- Root or sudo access
- SELinux: the installer does not configure SELinux policy. If SELinux is
  enforcing, you may need `setsebool -P httpd_can_network_connect 1` (Apache)
  or an equivalent policy for Nginx/Gunicorn, and `semanage fcontext` rules
  for `/opt/netbox`.

## Steps

```bash
git clone <this-repo-url> netbox-installer
cd netbox-installer
sudo ./install.sh
```

On Rocky, this installer uses `dnf` and installs:
- `postgresql-server` / `postgresql-contrib` (with `postgresql-setup --initdb`
  run automatically on first install)
- `redis`
- `python3-devel`, `gcc`, `gcc-c++`, and related `-devel` packages
- Nginx (`nginx`) or Apache (`httpd`), selectable via `WEB_SERVER`

## Firewall

Rocky ships with `firewalld` active by default. The installer detects this
and opens `NGINX_PORT/tcp` automatically. To do it manually:

```bash
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --reload
```

## Notes

- Package names differ slightly between RHEL-family releases; if a package
  is not found, check `lib/packages.sh` and adjust the `rhel` case block for
  your exact Rocky/Alma minor version.
- See `docs/FAQ.md` for common migration/database issues.
