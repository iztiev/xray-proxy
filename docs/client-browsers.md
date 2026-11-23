# Browsers

[Русский](ru/client-browsers.md) | **English**

Point only a browser at the local xray client instead of the whole system. Useful
when you do not want a system proxy, or want one browser (or one profile) proxied
and another direct.

**Prerequisite**: xray is running on this computer with your
`<email>.config.json` (see the [Windows](client-windows.md), [Linux](client-linux.md)
or [macOS](client-macos.md) guide). It listens on:

| Port | Protocol |
|---|---|
| `127.0.0.1:10808` | SOCKS5. Preferred: DNS is resolved through the proxy |
| `127.0.0.1:10809` | HTTP / HTTPS |

Split routing still applies: the browser sends everything to xray, and xray sends
the domains listed in the config direct and the rest through the server. No PAC
file is needed.

## Firefox

Firefox has its own proxy settings, independent of the system.

Settings → General → **Network Settings** → Settings…:

1. **Manual proxy configuration**
2. **SOCKS Host**: `127.0.0.1`, Port `10808`, **SOCKS v5**
3. Leave HTTP Proxy empty.
4. Tick **Proxy DNS when using SOCKS v5** (otherwise DNS queries go to your local
   resolver and reveal which sites you visit).
5. **No proxy for**: `localhost, 127.0.0.1`
6. OK.

To switch back: same dialog → **No proxy** (or **Use system proxy settings** if a
system proxy is configured).

Separate proxied profile: open `about:profiles` → **Create a New Profile**, set the
proxy only there, and launch it from `about:profiles` (or `firefox -P <name>`).

## Chrome, Edge, Brave, Opera, Vivaldi (Chromium)

Chromium browsers have no proxy settings of their own: on Windows and macOS they
follow the **system proxy** (set it as in the desktop guides and they use it). For a
browser-only proxy, use a launch flag or an extension.

### Option A: launch flag (no extension)

Start the browser with `--proxy-server`. Use a separate `--user-data-dir`: the flag
is ignored if the browser is already running with the same profile, and the
separate profile keeps proxied and direct browsing apart.

**Windows** (create a desktop shortcut with this as the target):

```
"C:\Program Files\Google\Chrome\Application\chrome.exe" --proxy-server="socks5://127.0.0.1:10808" --user-data-dir="%LOCALAPPDATA%\Chrome-Proxy"
```

Edge: `"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"` with the same
arguments (and e.g. `%LOCALAPPDATA%\Edge-Proxy`).

**macOS**:

```bash
open -na "Google Chrome" --args --proxy-server="socks5://127.0.0.1:10808" --user-data-dir="$HOME/.chrome-proxy"
```

**Linux**:

```bash
google-chrome --proxy-server="socks5://127.0.0.1:10808" --user-data-dir="$HOME/.chrome-proxy"
# chromium / brave-browser / microsoft-edge accept the same flags
```

With a `socks5://` proxy, Chromium resolves host names through the proxy, so DNS
does not leak.

### Option B: proxy extension

A proxy-switcher extension (e.g. **ZeroOmega**, the maintained fork of
SwitchyOmega) lets you toggle the proxy from the toolbar:

1. Install it from the Chrome Web Store / Edge Add-ons.
2. Create a profile: protocol **SOCKS5**, server `127.0.0.1`, port `10808`,
   bypass list `localhost`, `127.0.0.1`, `<local>`.
3. Select that profile from the toolbar icon to turn the proxy on; **Direct** or
   **System** to turn it off.

Only install proxy extensions from a source you trust: they see all your traffic.

## Safari

Safari has no own proxy settings; it uses the macOS system proxy (see
[client-macos.md](client-macos.md), "system proxy").

## Phones

Mobile browsers have no proxy settings; the [Android](client-android.md) and
[iOS](client-ios.md) apps tunnel the whole device, browsers included.

## WebRTC leaks

WebRTC (video calls, some sites' scripts) can send UDP directly, bypassing the
proxy and revealing your real IP. If that matters:

- **Firefox**: `about:config` → set `media.peerconnection.ice.proxy_only_if_behind_proxy`
  to `true` (WebRTC only via the proxy; calls still work through it), or
  `media.peerconnection.enabled` to `false` (WebRTC off entirely).
- **Chromium**: install Google's **WebRTC Network Limiter** extension and choose
  "Use my proxy server (if present)".

## Verify

In the proxied browser:

- `https://ifconfig.me` shows the **server's** IP.
- In a non-proxied browser, the same page shows your own IP.
- `https://browserleaks.com/webrtc` shows no public IP other than the server's
  (after the WebRTC step above).
- A site from the direct list in your config should still load with your own IP.

If pages do not load: is xray running (`curl -x socks5h://127.0.0.1:10808 https://ifconfig.me`)?
See the troubleshooting notes in [README.md](README.md).
