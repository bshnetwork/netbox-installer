# Installing NetBox on FreeBSD (experimental) by babak keshavarz

FreeBSD support is **experimental**. It uses `pkg` for packages and
`rc.d`/`sysrc` instead of systemd. Review this document before running the
installer in production.

## Requirements
- FreeBSD 13 or 14
- `pkg` bootstrapped (`pkg -N || pkg bootstrap`)
- root access

## Steps

```sh
git clone <this-repo-url> netbox-installer
cd netbox-installer
sudo ./install.sh
```

On FreeBSD the installer:
- Installs `postgresql15-server`/`postgresql15-client` and initializes the
  database under `/var/db/postgres/data15` if it doesn't already exist
- Installs `redis` via `pkg` and enables it with `sysrc redis_enable=YES`
- Installs `nginx` (or `apache24` if `WEB_SERVER=apache`) from `pkg`
- Installs the NetBox `rc.d` script at `/usr/local/etc/rc.d/netbox`
  (see `templates/netbox.rc`)

## Known limitations

- `firewall.sh` does not manage `pf` rules automatically — you'll get a
  warning reminding you to open the port in `/etc/pf.conf` yourself.
- The `pw useradd` system-user creation path is less tested than the Linux
  `useradd` path; verify the `netbox` user's home directory and shell after
  install.
- PostgreSQL major version is pinned to 15 in `lib/postgresql.sh`
  (`postgresql15-*` packages) — adjust if you need a different version.

## Manual verification checklist after install

```sh
service postgresql status
service redis status
service netbox status
service nginx status
```
