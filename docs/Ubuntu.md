# Installing NetBox on Ubuntu

Tested on Ubuntu 20.04, 22.04, and 24.04.

## Requirements
- 2 vCPU / 4GB RAM minimum (recommended for production: 4 vCPU / 8GB RAM)
- 5GB+ free disk space
- Root or sudo access

## Steps

**Option A — one-line remote install** (fetches the repo automatically):
```bash
curl -fsSL https://raw.githubusercontent.com/bshnetwork/netbox-installer/main/install.sh | sudo bash
```

**Option B — clone first, run locally:**
```bash
git clone https://github.com/bshnetwork/netbox-installer.git
cd netbox-installer
sudo ./install.sh
```

By default this installs:
- PostgreSQL (`postgresql`, `postgresql-contrib`)
- Redis (`redis-server`)
- Python 3 build toolchain (`python3-venv`, `build-essential`, etc.)
- NetBox itself under `/opt/netbox`, run by the dedicated `netbox` system user
- Gunicorn as the WSGI server, managed by systemd (`netbox.service`)
- Nginx as reverse proxy on port 80

## Customizing the install

Copy `config/defaults.conf` to `config/local.conf`, edit the values you
want to change, then run:

```bash
sudo ./install.sh --config config/local.conf
```

Useful overrides:
- `NETBOX_VERSION` — pin to a specific NetBox release tag
- `NGINX_PORT` — change the public HTTP port
- `WEB_SERVER=apache` — use Apache instead of Nginx
- `NETBOX_DB_PASSWORD` / `ADMIN_PASSWORD` — set explicit credentials instead
  of auto-generated ones (leave as `CHANGE_ME` to auto-generate)

## After install

Credentials are printed at the end of the run and also saved to
`/root/.netbox-installer-credentials` (root-readable only).

Check service status:
```bash
sudo systemctl status netbox
sudo systemctl status nginx
```

Logs: `/var/log/netbox-installer.log` (installer) and
`journalctl -u netbox -f` (application).

## HTTPS

This installer sets up plain HTTP. For production, put NetBox behind TLS —
either terminate TLS at Nginx/Apache with a certificate (e.g. via Certbot),
or place a load balancer / reverse proxy in front that handles TLS.

## Uninstall / Update

```bash
sudo ./uninstall.sh
sudo ./update.sh --version v4.2.0
```
