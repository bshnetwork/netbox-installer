# Installing NetBox on AlmaLinux

Tested on AlmaLinux 9. AlmaLinux is binary-compatible with RHEL/Rocky, so
the installer treats it identically (`OS_FAMILY=rhel`, `PKG_MANAGER=dnf`).

Follow the same steps and notes as [Rocky.md](Rocky.md):

```bash
git clone https://github.com/bshnetwork/netbox-installer.git
cd netbox-installer
sudo ./install.sh
```

Differences worth knowing:
- AlmaLinux's AppStream repo layout matches RHEL's; if `dnf install` fails
  for a `-devel` package, confirm the `crb` (CodeReady Builder / "PowerTools")
  repo is enabled:
  ```bash
  sudo dnf install -y epel-release
  sudo dnf config-manager --set-enabled crb
  ```
- Everything else (SELinux, firewalld, systemd unit) is the same as on Rocky.
