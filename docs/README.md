# Client setup

Server installation, adding/removing clients and QR codes: [server.md](server.md).

Desktops run the official **xray-core** binary headless (not v2fly `v2ray`, which
has no REALITY/Vision support) with the client config generated on the server.
Phones use a GUI app that imports the share link and tunnels the whole device.

| OS | Guide | Uses |
|---|---|---|
| Windows | [client-windows.md](client-windows.md) | `<email>.config.json`, headless |
| Linux | [client-linux.md](client-linux.md) | `<email>.config.json`, headless |
| macOS | [client-macos.md](client-macos.md) | `<email>.config.json`, headless |
| Android | [client-android.md](client-android.md) | `<email>.link.txt`, v2rayNG |
| iOS / iPadOS | [client-ios.md](client-ios.md) | `<email>.link.txt`, Streisand / V2Box / Shadowrocket |
| Browsers only | [client-browsers.md](client-browsers.md) | Firefox, Chromium (Chrome/Edge/Brave…), Safari, on top of a desktop client |

Sections 2–3 below apply to the desktop (headless) setup.

## 1. Get your client config

Each client has its own files, created by `install.sh` (first client) or `add_user.sh`:

- `clients/<email>.config.json`: xray-core config, used by the guides below.
- `clients/<email>.link.txt`: `vless://` share link for GUI apps (v2rayN, v2rayNG,
  Streisand, Hiddify…), if you prefer a GUI.

Copy them from the server by running this on your computer (Windows Terminal,
macOS or Linux; OpenSSH `scp` is built in):

```
scp "<host>:/opt/xray-stack/clients/<email>.*" .
```

Or print the file on the server (`sudo cat clients/<email>.config.json`) and paste
it into a file. More in [server.md](server.md#get-the-client-files-onto-a-computer).

Treat both files like a password: anyone with them can use the proxy until the
client is removed with `remove_user.sh`. Use one client per device.

## 2. What the client gives you

The config opens two local proxies, bound to `127.0.0.1` only:

| Port | Protocol | Use for |
|---|---|---|
| `10808` | SOCKS5 (TCP + UDP) | apps with SOCKS support, `curl -x socks5h://…` |
| `10809` | HTTP/HTTPS | OS "system proxy" settings, `http_proxy` env vars |

Routing is split: the domains listed in the config (including your own domain) and
LAN addresses go **direct**; everything else goes through the server. Edit the `routing.rules[0].domain` list to change that
(`domain:example.com` matches the domain and all subdomains).

Nothing is tunnelled automatically: apps must use the proxy (system proxy setting,
app setting, or env vars). For a system-wide VPN-like tunnel use a GUI client with
TUN mode instead (v2rayN on Windows, Hiddify, etc.) and import the share link.

## 3. Verify (any OS)

```
curl -x socks5h://127.0.0.1:10808 https://ifconfig.me      # prints the server IP
curl -x http://127.0.0.1:10809 https://ifconfig.me         # same, via HTTP proxy
curl https://ifconfig.me                                   # your real IP (no proxy)
```

(On Windows use `curl.exe`, not the PowerShell `curl` alias.)

If it fails, run xray in the foreground (see each guide) and read the log. Common causes:
wrong system clock (REALITY needs it within ~2 minutes), the client was removed or
xray on the server was not restarted after `add_user.sh`, or 443/tcp blocked on your network.

## Updating

Download a newer xray-core release (or `brew upgrade xray` / re-run the Linux
install script) and restart the client. The config does not change.
