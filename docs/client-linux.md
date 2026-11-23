# Headless client: Linux

[Русский](ru/client-linux.md) | **English**

Runs xray-core as a systemd service using the official XTLS install script.
Works on any systemd distro (Ubuntu, Debian, Fedora, Arch…).

## 1. Install xray-core

```bash
sudo bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
xray version
```

This installs `/usr/local/bin/xray`, the config dir `/usr/local/etc/xray/` and a
systemd unit `xray.service` that runs as user `nobody`.
(Arch: `pacman -S xray` works too, with config at `/etc/xray/config.json`.)

## 2. Add your config

```bash
sudo install -m 644 <email>.config.json /usr/local/etc/xray/config.json
sudo xray run -test -c /usr/local/etc/xray/config.json     # "Configuration OK."
```

Mode 644 because the service runs as `nobody`. On a shared machine, use
`sudo chown root:nogroup … && sudo chmod 640 …` instead (`nobody` group on Fedora).

## 3. Start and enable at boot

```bash
sudo systemctl enable --now xray
systemctl status xray
journalctl -u xray -f            # logs
sudo systemctl restart xray      # after changing the config
```

Try it in the foreground instead (stop the service first):
`sudo systemctl stop xray && xray run -c /usr/local/etc/xray/config.json`

## 4. Use it

CLI tools, per shell or in `~/.profile` / `~/.bashrc`:

```bash
export http_proxy=http://127.0.0.1:10809
export https_proxy=http://127.0.0.1:10809
export all_proxy=socks5h://127.0.0.1:10808
export no_proxy=localhost,127.0.0.1
```

Desktop (GNOME): Settings → Network → Network Proxy → Manual: HTTP and HTTPS
`127.0.0.1:10809`, Socks `127.0.0.1:10808`. Or:

```bash
gsettings set org.gnome.system.proxy mode manual
gsettings set org.gnome.system.proxy.http  host 127.0.0.1; gsettings set org.gnome.system.proxy.http  port 10809
gsettings set org.gnome.system.proxy.https host 127.0.0.1; gsettings set org.gnome.system.proxy.https port 10809
gsettings set org.gnome.system.proxy.socks host 127.0.0.1; gsettings set org.gnome.system.proxy.socks port 10808
# off: gsettings set org.gnome.system.proxy mode none
```

KDE: System Settings → Network → Proxy → manual, same values.

## Alternative: Docker

If Docker is already installed, no package needed:

```bash
docker run -d --name xray-client --restart unless-stopped --network host \
  -v "$PWD/<email>.config.json:/etc/xray/config.json:ro" \
  ghcr.io/xtls/xray-core:latest run -c /etc/xray/config.json
```

`--network host` makes the `127.0.0.1` ports reachable from the host. Make the file
readable by the container user (`chmod 644`).

## Sharing with the LAN (optional)

The config listens on `127.0.0.1` only. To let other devices use this machine as a
proxy, change both inbounds' `"listen"` to `"0.0.0.0"`, restart, and allow ports
10808/10809 only from your LAN in the firewall. There is no proxy authentication.

## Uninstall

```bash
sudo bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove --purge
```
