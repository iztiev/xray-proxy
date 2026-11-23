# Server setup and administration

[Русский](ru/server.md) | **English**

Install, verify and run the stack on an Ubuntu LTS server, and manage proxy clients.

Everything runs **on the server**: log in with `ssh <host>` and work in the install
folder. The stack is installed straight from this repository with `git clone`;
nothing needs to be uploaded from your computer.

Throughout: `<host>` is your SSH login (`user@1.2.3.4` or an `~/.ssh/config` alias),
`<domain>` your domain, `/opt/xray-stack` the install folder (any folder works).

## 1. Requirements

- **Server**: Ubuntu LTS (22.04 / 24.04), 1 vCPU, 1 GB RAM minimum, root or sudo.
  With 1 GB RAM, 2 GB of swap is required; `install.sh` offers to create it.
- **Domain**: an `A` record (and `AAAA` if the server has IPv6) for `<domain>`
  pointing at the server, resolving **before** the first start (the certificate
  is issued over port 80).
- **Ports**: 80/tcp and 443/tcp reachable from the internet, plus SSH.
  Nothing else needs to be open.

Firewall with `ufw` (or use your provider's cloud firewall with the same rules):

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

Note: ports published by Docker bypass `ufw` (Docker writes its own iptables rules).
That is fine here because the stack publishes only 80 and 443; the internal 8443
and the database are never published. Do not add `ports:` to other services.

## 2. Install

```bash
ssh <host>
sudo apt-get update && sudo apt-get install -y git
sudo git clone https://github.com/iztiev/xray-proxy.git /opt/xray-stack
cd /opt/xray-stack
sudo bash install.sh
```

`install.sh`:

1. Checks the OS and swap (offers a 2 GB `/swapfile` if needed).
2. Installs Docker Engine + Compose plugin from Docker's official apt repository
   (skipped if already installed), plus `jq` and `openssl`.
3. Asks for:
   - **Domain**: used for the certificate, the website and the REALITY SNI.
   - **Email**: Let's Encrypt contact, website admin login, and the name of the
     first proxy client.
   - **Admin password** for the website (hidden, min 8 chars, no `'`).
4. Generates all secrets: 64-hex-char database/JWT secrets, the REALITY key pair,
   the first client's UUID and short ID.
5. Renders `templates/` into the install folder, validates everything
   (`docker compose config`, `xray run -test`).
6. Asks whether to start the stack, and whether to show the first client's QR code.

It refuses to run a second time (if `.env` or `xray/server.json` exist): new
database secrets would lock the website out of its existing database.

After the first start, follow the post-install hint printed by `install.sh`
(lower the web app's worker count for a 1 GB server, then restart that service).

### What ends up on the server

Next to the repository files, all git-ignored:

| Path | Content | Secret |
|---|---|---|
| `.env` | domain, emails, database/JWT secrets, admin password | yes (600) |
| `compose.yml`, `Caddyfile` | stack definition, rendered from `templates/` | no |
| `xray/server.json` | REALITY private key, all client UUIDs and short IDs | yes |
| `xray/server.json.bak-*` | backups made by `add_user.sh` / `remove_user.sh` | yes |
| `clients/<email>.config.json` | desktop client config | yes |
| `clients/<email>.link.txt` | `vless://` share link (phones, GUI apps) | yes |
| `data/` | certificates, database, website files | yes |

## 3. Verify

On the server:

```bash
cd /opt/xray-stack
sudo docker compose ps                     # all services "running" / "healthy"
sudo docker compose logs --tail 50         # look for errors
free -m && sudo docker stats --no-stream   # memory headroom
```

From any machine:

```bash
curl -sI https://<domain>             # HTTP 200/302 from the website, valid certificate
```

A browser opening `https://<domain>` must show the website with a valid
certificate: that is what every non-client visitor and scanner sees.

Then connect a client: see [README.md](README.md).

## 4. Manage clients

On the server, in the install folder (`cd /opt/xray-stack`). Use one client per
device; a lost device can then be revoked alone.

### Add

```bash
sudo bash add_user.sh
```

Asks for an email (any unique label in email form), then adds a UUID and a short ID
to `xray/server.json` (validated, previous version kept as a backup), writes
`clients/<email>.config.json` and `.link.txt`, and asks to restart xray.
**Answer y**: the new client works only after the restart (existing connections
drop for a moment). Finally it offers to show the QR code.

### Show a QR code (phones)

```bash
sudo bash show_qr.sh             # pick from a list
sudo bash show_qr.sh <email>     # directly
```

Scan it with v2rayNG (Android) or Streisand / V2Box / Shadowrocket (iOS). Use a
terminal large enough to show the whole code, and run `clear` afterwards: the code
is a credential.

### Get the client files onto a computer

The desktop clients need `clients/<email>.config.json`. Either print it on the
server and paste it into a file on the computer:

```bash
sudo cat clients/<email>.config.json
```

or copy it with `scp`, run **on the computer** (works in Windows Terminal, macOS
and Linux; the files are owned by your SSH user when the scripts ran via `sudo`):

```bash
scp "<host>:/opt/xray-stack/clients/<email>.*" .
```

### Remove

```bash
sudo bash remove_user.sh
```

Lists clients numbered, asks which one to remove and confirms. Removes its UUID and
short ID from `xray/server.json` (validated, backed up), deletes its client files,
and asks to restart xray; the client is locked out after the restart. The last
remaining client cannot be removed (add another first). Website accounts are not
affected.

## 5. Operations

All in the install folder (`cd /opt/xray-stack`):

| Task | Command |
|---|---|
| Status | `sudo docker compose ps` |
| Logs (follow) | `sudo docker compose logs -f --tail 100` (or `… logs -f xray`) |
| Restart xray only | `sudo docker compose restart xray` |
| Stop / start everything | `sudo docker compose down` / `sudo docker compose up -d` |
| Update container images | `sudo docker compose pull && sudo docker compose up -d` |
| Clean old images | `sudo docker image prune -f` |

The stack restarts automatically after a reboot (`restart: unless-stopped`).

### Updating the scripts

```bash
cd /opt/xray-stack
sudo git pull
```

Rendered configs, client files and `data/` are git-ignored, so a pull only updates
the scripts, templates and docs; your secrets and clients are untouched. A pull does
**not** re-render existing configs: if a release changes a template, apply that
change to the rendered file by hand (keeping its secrets), then restart the affected
service.

### Backups

Everything needed to restore is in the install folder: `.env`, `xray/`, `clients/`
and `data/`. Stop the stack for a consistent database copy:

```bash
cd /opt/xray-stack
sudo docker compose down
sudo tar czf /root/xray-stack-$(date +%F).tgz .env compose.yml Caddyfile xray clients data
sudo docker compose up -d
```

The archive contains every secret; store it encrypted and off the server.

## 6. Troubleshooting

| Symptom | Check |
|---|---|
| Website has no / invalid certificate | DNS points at the server? Port 80 open? `sudo docker compose logs caddy` |
| Website works, clients cannot connect | xray restarted after `add_user.sh`? `sudo docker compose logs xray`; device clock correct (REALITY rejects >~2 min skew) |
| Only some networks fail | Those networks block or throttle 443/tcp to the server; not a config issue |
| Containers restarting / killed | Out of memory: `free -m`, `docker stats`, `dmesg \| grep -i oom`; is swap on? |
| `install.sh` refuses to run | Already installed. Manage clients with the scripts above; never delete `.env` on a server whose website has been started |
| `lib.sh … is outdated` / `command not found` | Scripts and `lib.sh` out of step: `sudo git pull` updates them together |
| `git pull` complains about local changes | A tracked file was edited on the server: `sudo git status`, then `sudo git stash` or `sudo git checkout -- <file>` |
