# Xray REALITY stack

Self-hosted VLESS + XTLS-Vision + REALITY proxy on TCP 443. Connections without valid
REALITY credentials fall through to a real HTTPS website with a Let's Encrypt
certificate for your domain, so the server looks like an ordinary web host.

Config files live in `templates/` with `{{VARIABLE}}` placeholders, rendered on the
server by `install.sh` (see [templates/README.md](templates/README.md) for the variable list).

## Documentation

| Topic | Doc |
|---|---|
| Overview of client options | [docs/README.md](docs/README.md) |
| Server: install, verify, add/remove clients, QR codes, operations | [server.md](docs/server.md) |
| Architecture: traffic flow, invariants, memory budget | [architecture.md](docs/architecture.md) |
| Client: Windows (headless) | [client-windows.md](docs/client-windows.md) |
| Client: Linux (headless) | [client-linux.md](docs/client-linux.md) |
| Client: macOS (headless) | [client-macos.md](docs/client-macos.md) |
| Client: Android | [client-android.md](docs/client-android.md) |
| Client: iOS / iPadOS | [client-ios.md](docs/client-ios.md) |
| Client: browsers only (Firefox, Chrome/Edge, Safari) | [client-browsers.md](docs/client-browsers.md) |

## Quick start

Ubuntu LTS server, DNS for your domain already pointing at it, ports 80 and 443 open:

On the server (`ssh <host>`):

```bash
sudo apt-get update && sudo apt-get install -y git
sudo git clone https://github.com/iztiev/xray-proxy.git /opt/xray-stack
cd /opt/xray-stack
sudo bash install.sh        # answer the prompts
```

Then set up a client with `clients/<email>.config.json` (desktop) or the QR code
(phone). Day-to-day, in `/opt/xray-stack` on the server:

| Task | Command |
|---|---|
| Add a client | `sudo bash add_user.sh` |
| Remove a client | `sudo bash remove_user.sh` |
| QR code for a phone | `sudo bash show_qr.sh` |
| Update scripts and templates | `sudo git pull` |

Rendered configs, client files and `data/` are git-ignored, so `git pull` updates
the scripts and templates without touching secrets. Details: [docs/server.md](docs/server.md).
