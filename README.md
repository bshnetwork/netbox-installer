netbox-installer  
A modular, multi-OS installer for NetBox.
Supported platformsOS : Debian Bases / RHL Bases / FreeSD 13/14 Experimental pkg docs/FreeBSD.md 
Quick start :

curl -fsSL https://raw.githubusercontent.com/babakkeshavarzb-stack/netbox-installer/main/install.sh | sudo bash

git clone <this-repo-url> netbox-installer
cd netbox-installer
sudo ./install.sh

Non-interactive install with all defaults: bash sudo ./install.sh -y 
Custom config: bash cp config/defaults.conf config/local.conf $EDITOR config/local.conf sudo .
install.sh --config config/local.conf 
Layout 
netbox-installer/
├── install.sh # entry point: orchestrates the full install
├── uninstall.sh # removes NetBox, service, and (optionally) DB/user
├── update.sh # upgrades an existing install to a new release
│
├── lib/ # one focused module per concern
│ ├── colors.sh # terminal color codes
│ ├── common.sh # logging, prompts, template rendering, misc
│ ├── detect_os.sh # distro/family/package-manager detection
│ ├── validate.sh # pre-flight checks (root, RAM, disk, config)
│ ├── packages.sh # OS-aware apt/dnf/pkg wrappers
│ ├── users.sh # system user creation
│ ├── postgresql.sh # database install + create db/role
│ ├── redis.sh # cache/queue backend
│ ├── python.sh # venv + pip requirements
│ ├── netbox.sh # fetch source, configure, migrate, superuser
│ ├── nginx.sh # reverse proxy (default)
│ ├── apache.sh # reverse proxy (alternative)
│ ├── service.sh # systemd / rc.d abstraction
│ └── firewall.sh # ufw / firewalld / pf
│
├── templates/ # config file templates, @@TOKEN@@ substituted
│ ├── configuration.py
│ ├── gunicorn.conf.py
│ ├── nginx.conf
│ ├── apache.conf
│ ├── netbox.service
│ └── netbox.rc
│
├── config/│ └── defaults.conf│
└── docs/
# all tunable variables, copy & edit for your env
# per-OS notes + FAQ
How templating works 
lib/common.sh provides render_template <src> <dest>. It scans the source file for @@VAR_NAME@@ tokens and replaces
each one with the current value of the shell variable VAR_NAME. This keeps templates/*.conf files free of inline bash and easy
to hand-edit. 
Design notes / changes from the original single-file script 
Runs NetBox as a dedicated unprivileged system user (netbox by default) instead of the invoking sudo user.
Database and admin passwords are auto-generated (gen_secret) unless you explicitly set them in your config file —
nothing sensitive is hardcoded.
Every external command’s output goes to /var/log/netbox-installer.log instead of scrolling past in the terminal;
only step-level status lines are printed live.
Adds Rocky/AlmaLinux (dnf) and experimental FreeBSD (pkg/rc.d) support alongside the original Ubuntu/Debian (apt)
path.
Adds an Apache option alongside Nginx (WEB_SERVER=apache).
Adds uninstall.sh and update.sh companions to the original install-only script.
NetBox source is fetched from the official GitHub releases by default (NETBOX_SOURCE_URL in config/defaults.conf)
rather than a third-party mirror — override it if you maintain your own internal mirror. 
License 
See LICENSE
