# 🌐 NetBox Installer

> **A modular, multi-OS installer for NetBox — the premier open-source IPAM and DCIM tool**

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Supported OS](https://img.shields.io/badge/OS-Linux%20%7C%20FreeBSD-success)](https://github.com/babakkeshavarzb-stack/netbox-installer)
[![NetBox](https://img.shields.io/badge/NetBox-Latest-6C2BD9)](https://github.com/netbox-community/netbox)

---

## Features

- **Multi-Platform Support** — Debian/Ubuntu, RHEL/CentOS/Rocky/AlmaLinux, and FreeBSD (experimental)
- **Modular Architecture** — Clean, maintainable, and extensible codebase
- **Secure by Default** — Dedicated unprivileged user, auto-generated secrets, no hardcoded credentials
- **Dual Web Server Options** — Choose between Nginx (default) or Apache
- **Production-Ready** — Systemd/rc.d integration, firewall configuration, logging
- **Complete Lifecycle Management** — Install, update, and uninstall with a single command

---

## Supported Platforms

| OS Family | Distribution | Status |
|-----------|--------------|--------|
| 🐧 Debian-based | Ubuntu, Debian | ✅ Stable |
| 🐧 RHEL-based | Rocky Linux, AlmaLinux, CentOS, RHEL | ✅ Stable |
| 🐚 FreeBSD | 13.x, 14.x | ⚡ Experimental |

> **Note:** See [FreeBSD documentation](docs/FreeBSD.md) for installation details.

---

## Quick Start

### One-Line Installation

```bash
curl -fsSL https://raw.githubusercontent.com/bshnetwork/netbox-installer/main/install.sh | sudo bash
```
### One-Line Update
```bash
curl -fsSL https://raw.githubusercontent.com/bshnetwork/netbox-installer/main/update.sh | sudo bash
```
### Pass any `install.sh` flag after `-s --`, e.g. to use Apache instead of Nginx:
```bash
curl -fsSL https://raw.githubusercontent.com/bshnetwork/netbox-installer/main/install.sh | sudo bash -s -- --web apache -y
```

This downloads the full repo into `/opt/netbox-installer` (override with
`NETBOX_INSTALLER_SRC_DIR=/some/path`) and re-runs the real installer from
there, so `uninstall.sh` / `update.sh` are available afterward too:
```bash
cd /opt/netbox-installer
sudo ./update.sh
sudo ./uninstall.sh
```


### **Local install** (clone/download the repo yourself first):


```bash
git clone https://github.com/bshnetwork/netbox-installer.git
cd netbox-installer
sudo ./install.sh
```

Non-interactive install with all defaults:
```bash
sudo ./install.sh -y
```

Custom config:
```bash
cp config/defaults.conf config/local.conf
$EDITOR config/local.conf
sudo ./install.sh --config config/local.conf
```

## 📂 Project Structure

```
netbox-installer/
├── 📜 install.sh                 # Entry point — orchestrates full installation
├── 📜 uninstall.sh               # Removes NetBox, service, and (optionally) DB/user
├── 📜 update.sh                  # Upgrades existing installation to new release
│
├── 📁 lib/                       # Modular, focused components
│   ├── colors.sh                 # Terminal color codes
│   ├── common.sh                 # Logging, prompts, template rendering, utilities
│   ├── detect_os.sh              # OS detection and package manager identification
│   ├── validate.sh               # Pre-flight checks (root, RAM, disk, config)
│   ├── packages.sh               # OS-aware package management (apt/dnf/pkg)
│   ├── users.sh                  # System user creation
│   ├── postgresql.sh             # Database installation and setup
│   ├── redis.sh                  # Cache and queue backend
│   ├── python.sh                 # Virtual environment and pip requirements
│   ├── netbox.sh                 # Source fetch, configuration, migration, superuser
│   ├── nginx.sh                  # Nginx reverse proxy setup
│   ├── apache.sh                 # Apache reverse proxy setup
│   ├── service.sh                # Systemd / rc.d abstraction layer
│   └── firewall.sh               # Firewall configuration (ufw/firewalld/pf)
│
├── 📁 templates/                 # Config templates with @TOKEN@ substitution
│   ├── configuration.py
│   ├── gunicorn.conf.py
│   ├── nginx.conf
│   ├── apache.conf
│   ├── netbox.service
│   └── netbox.rc
│
├── 📁 config/
│   └── defaults.conf             # All tunable variables — copy & edit for your env
│
└── 📁 docs/
    └── *                         # Per-OS notes and FAQ
```

---

## 🎨 Templating Engine

The installer uses a simple yet powerful token-based templating system:

- `lib/common.sh` provides the `render_template` function
- Templates use `@@VAR_NAME@@` placeholders
- Replaced with current shell variable values at runtime
- Keeps `templates/*.conf` files clean, editable, and free of inline bash

---

## 🔄 What's New

This modular rewrite transforms the original single-file script with:

- **Dedicated System User** — Runs NetBox as `netbox` (unprivileged) instead of the invoking sudo user
- **Auto-Generated Secrets** — Database and admin passwords are securely generated unless explicitly set
- **Comprehensive Logging** — All command output goes to `/var/log/netbox-installer.log`; terminal shows only progress status
- **Extended OS Support** — Added Rocky/AlmaLinux (dnf) and experimental FreeBSD (pkg/rc.d)
- **Flexible Web Server** — Apache option alongside Nginx
- **Full Lifecycle** — Uninstall and update scripts included
- **Official Sources** — Fetches from official NetBox GitHub releases by default

---

## 🛠️ Prerequisites

- **Root/sudo access** on the target system
- **Minimum 2GB RAM** (4GB+ recommended for production)
- **At least 4GB free disk space**
- **Outbound internet access** for package downloads

---

## 🤝 Contributing

Contributions are welcome! Please see our [Contributing Guidelines](CONTRIBUTING.md) for:

- Bug reports and feature requests
- Code contributions
- Documentation improvements
- Translation efforts

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- [NetBox Community](https://github.com/netbox-community/netbox) for the excellent IPAM/DCIM tool
- All contributors and users who have provided feedback and improvements

---

## 📬 Support

- **Issues**: [GitHub Issues](https://github.com/babakkeshavarzb-stack/netbox-installer/issues)
- **Documentation**: Check the [docs](docs/) folder for detailed guides

---

<p align="center">
  <strong>⭐ Star this repository if you find it useful!</strong><br>
  <sub>Built with ❤️ for the NetBox community</sub>
</p>
