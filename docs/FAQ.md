# FAQ / Troubleshooting babak keshavarz

**Q: Where are the generated credentials?**
A: Printed at the end of `install.sh`, and saved to
`/root/.netbox-installer-credentials` (mode 600). The installer log
(`/var/log/netbox-installer.log`) does not contain plaintext passwords.

**Q: The installer stopped with "Command failed: ..."**
A: Check `/var/log/netbox-installer.log` — every underlying command's
stdout/stderr is captured there, even though the terminal only shows a
short status line.

**Q: How do I re-run just one step (e.g. re-issue the Nginx config)?**
A: Source the relevant lib file and call its function directly, e.g.:
```bash
cd netbox-installer
. lib/colors.sh; . lib/common.sh; . lib/detect_os.sh; detect_os
. config/defaults.conf
. lib/nginx.sh
install_and_configure_nginx
```

**Q: How do I switch from Nginx to Apache after installing?**
A: Run `uninstall.sh` selectively is overkill — instead:
```bash
sudo systemctl stop nginx && sudo systemctl disable nginx
sudo WEB_SERVER=apache bash -c '. lib/colors.sh; . lib/common.sh; . lib/detect_os.sh; detect_os; . config/defaults.conf; . lib/packages.sh; . lib/service.sh; . lib/apache.sh; install_and_configure_apache'
```
(A dedicated `--switch-web-server` flag is a good candidate for a future
`update.sh` enhancement.)

**Q: Migrations fail with a permissions error on the database.**
A: Re-run the database setup step, which drops and recreates the role:
```bash
sudo ./install.sh --config config/local.conf
# answer "y" when asked to drop/recreate the database
```

**Q: Can I point this at a private/internal NetBox mirror instead of GitHub?**
A: Yes — set `NETBOX_SOURCE_URL` in your config file to any URL serving a
`.tar.gz` with the NetBox source at its root (after stripping one leading
path component, matching GitHub's release tarball layout).

**Q: Does this configure HTTPS?**
A: No, by design — TLS termination is environment-specific (Let's Encrypt,
internal CA, load balancer, etc.). Put a certificate on the Nginx/Apache
vhost this installer creates, or terminate TLS upstream.

**Q: FreeBSD support?**
A: Experimental — see `docs/FreeBSD.md`.
