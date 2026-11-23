# Client: Android

[Русский](ru/client-android.md) | **English**

Android has no headless option; use a GUI app that runs xray-core as a VPN service
(whole-device tunnel). Recommended: **v2rayNG** (open source, xray-core inside).
Alternatives with the same import flow: Hiddify, NekoBox.

## 1. Create a client for the phone

Use one client per device, so a lost phone can be revoked alone. On the server
(`ssh <host>`):

```
cd /opt/xray-stack
sudo bash add_user.sh
```

Answer **y** to restart xray, otherwise the new client is rejected.

## 2. Install v2rayNG

- Google Play: search "v2rayNG", or
- APK from <https://github.com/2dust/v2rayNG/releases/latest>
  (`v2rayNG_<version>_arm64-v8a.apk` for nearly all current phones).

## 3. Import the share link

**QR code (easiest)**: show it in your SSH session on the server:

```
cd /opt/xray-stack
sudo bash show_qr.sh
```

Pick the client by number (or pass its email as an argument). `add_user.sh` also
offers to show the code right after creating the client.

In v2rayNG: **+** (top right) → **Scan QR code**. Make the terminal window large
enough that the whole code is visible.

**Clipboard**: get the `vless://…` line from `clients/<email>.link.txt` onto the phone
through a private channel (not a chat app that syncs to the cloud), copy it, then
**+** → **Import config from clipboard**.

Check the imported profile: address = your domain, port 443, flow
`xtls-rprx-vision`, security `reality`, SNI = your domain, fingerprint `chrome`,
public key and short ID filled in.

## 4. Connect

Tap the profile to select it, then the round **V** button at the bottom. Accept the
Android VPN prompt. Tap "Check connection" (the bar at the bottom): it should show
a latency in ms.

## 5. Split routing (optional)

The share link carries only the server settings, not the desktop config's
direct-domain list. To send some sites direct, open ☰ → **Routing settings** →
**Direct URL or IP**, and add one rule per line, for example:

```
domain:example.com
geosite:private
geoip:private
```

Use the same domains as `routing.rules[0].domain` in your desktop
`<email>.config.json` if you want identical behaviour. Set **Domain strategy** to
`AsIs`.

Per-app tunnelling: ☰ → **Settings** → **Per-app proxy** to tunnel only selected
apps (or bypass selected apps).

## 6. Keep it running

- Android Settings → Apps → v2rayNG → Battery → **Unrestricted**, otherwise the
  system may kill the tunnel.
- Optional always-on: Android Settings → Network & internet → VPN → gear next to
  v2rayNG → **Always-on VPN** (and "Block connections without VPN" if you want a
  kill switch).

## Troubleshooting

- "Check connection" fails: phone clock wrong (REALITY needs correct time), client
  removed on the server, or xray not restarted after `add_user.sh`.
- Works on Wi-Fi but not mobile data (or vice versa): that network blocks or
  throttles 443/tcp to the server; nothing to fix in the config.
- Logs: ☰ → **Logcat**.
