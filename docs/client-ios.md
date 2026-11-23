# Client: iOS / iPadOS

[Русский](ru/client-ios.md) | **English**

iOS has no headless option and no official xray-core app; use an App Store client
that supports **VLESS + REALITY + XTLS-Vision** and runs as a system VPN.

| App | Price | Notes |
|---|---|---|
| **Streisand** | free | Simple; QR / clipboard import; routing rules. |
| **V2Box** | free (ads) | Also on macOS. |
| **Hiddify** | free | Open source; also on Android/desktop. |
| **Shadowrocket** | paid | Most flexible rules; widely used. |

Availability differs by App Store region; if one is missing, try another from the
list. All import the same `vless://` link.

## 1. Create a client for the device

One client per device, so a lost phone can be revoked alone. On the server
(`ssh <host>`):

```
cd /opt/xray-stack
sudo bash add_user.sh
```

Answer **y** to restart xray, otherwise the new client is rejected.

## 2. Import the share link

**QR code (easiest)**: show it in your SSH session on the server:

```
cd /opt/xray-stack
sudo bash show_qr.sh
```

Pick the client by number (or pass its email as an argument). `add_user.sh` also
offers to show the code right after creating the client.

In the app, use its **+** / **Scan QR** action (Streisand: **+** → *Scan QR code*;
Shadowrocket: scanner icon top left). The iOS Camera app also recognises the code
and offers to open it in an installed client.

**Clipboard**: get the `vless://…` line from `clients/<email>.link.txt` onto the
device through a private channel (AirDrop from a Mac, a password manager note; not a
chat app that syncs to the cloud), copy it and open the app; most apps offer to
import from the clipboard automatically, or use **+** → *Import from clipboard*.

Check the imported profile: address = your domain, port 443, flow
`xtls-rprx-vision`, security `reality`, SNI = your domain, fingerprint `chrome`,
public key and short ID filled in.

## 3. Connect

Select the profile and toggle the connection on. The first time, iOS asks to
**add a VPN configuration**: allow it (Face ID / passcode). The VPN icon appears
in the status bar.

## 4. Split routing (optional)

The share link carries only the server settings. To send some sites direct, add
rules in the app (Streisand: *Routing*; Shadowrocket: *Config* → *Rule*), with
action **DIRECT** for the domains you want to bypass, e.g. `DOMAIN-SUFFIX,example.com`
in Shadowrocket. Use the same domains as `routing.rules[0].domain` in your desktop
`<email>.config.json` for identical behaviour; keep LAN ranges direct.

## 5. Keep it running

- iOS may drop the tunnel on network changes; most apps have an **On Demand** /
  *Connect on demand* option to reconnect automatically.
- Settings → VPN shows the connection; you can also toggle it there.

## Troubleshooting

- Connection test fails: device clock wrong (REALITY needs correct time), client
  removed on the server, or xray not restarted after `add_user.sh`.
- Works on Wi-Fi but not cellular (or vice versa): that network blocks or throttles
  443/tcp to the server; nothing to fix in the config.
