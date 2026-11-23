# Headless client: macOS

Runs xray-core as a background launchd service, via Homebrew (simplest) or the
release binary.

## Option A: Homebrew

```bash
brew install xray
xray version
mkdir -p "$(brew --prefix)/etc/xray"
cp <email>.config.json "$(brew --prefix)/etc/xray/config.json"
chmod 600 "$(brew --prefix)/etc/xray/config.json"
xray run -test -c "$(brew --prefix)/etc/xray/config.json"   # "Configuration OK."

brew services start xray        # starts now and at login
brew services info xray
```

After changing the config: `brew services restart xray`. Stop: `brew services stop xray`.
Check the service's config path with `brew services info xray --json` if it does not
pick up the file (it uses `$(brew --prefix)/etc/xray/config.json`).

## Option B: release binary + LaunchAgent

1. Download `Xray-macos-arm64-v8a.zip` (Apple Silicon) or `Xray-macos-64.zip`
   (Intel) from <https://github.com/XTLS/Xray-core/releases/latest>.
2. Install:

```bash
mkdir -p ~/.local/xray
unzip ~/Downloads/Xray-macos-arm64-v8a.zip -d ~/.local/xray
xattr -dr com.apple.quarantine ~/.local/xray        # allow the unsigned binary
cp <email>.config.json ~/.local/xray/config.json
chmod 600 ~/.local/xray/config.json
~/.local/xray/xray run -test -c ~/.local/xray/config.json
```

3. Create `~/Library/LaunchAgents/com.xtls.xray.plist` (replace `YOU` with your user name):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.xtls.xray</string>
  <key>ProgramArguments</key>
  <array>
    <string>/Users/YOU/.local/xray/xray</string>
    <string>run</string>
    <string>-c</string>
    <string>/Users/YOU/.local/xray/config.json</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardErrorPath</key><string>/Users/YOU/.local/xray/xray.log</string>
  <key>StandardOutPath</key><string>/Users/YOU/.local/xray/xray.log</string>
</dict>
</plist>
```

4. Load it:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.xtls.xray.plist
launchctl kickstart -k gui/$(id -u)/com.xtls.xray     # restart after config changes
launchctl bootout gui/$(id -u)/com.xtls.xray          # stop / unload
```

## Use it: system proxy

System Settings → Network → (your network) → Details → Proxies: enable
**Web proxy (HTTP)** and **Secure web proxy (HTTPS)** `127.0.0.1:10809`, and/or
**SOCKS proxy** `127.0.0.1:10808`. Safari, Chrome and most apps follow this.

Same from the terminal (`networksetup -listallnetworkservices` for the name):

```bash
S="Wi-Fi"
networksetup -setwebproxy        "$S" 127.0.0.1 10809
networksetup -setsecurewebproxy  "$S" 127.0.0.1 10809
networksetup -setsocksfirewallproxy "$S" 127.0.0.1 10808
# off:
networksetup -setwebproxystate "$S" off
networksetup -setsecurewebproxystate "$S" off
networksetup -setsocksfirewallproxystate "$S" off
```

CLI tools ignore the system proxy; add to `~/.zshrc`:

```bash
export http_proxy=http://127.0.0.1:10809 https_proxy=http://127.0.0.1:10809
export all_proxy=socks5h://127.0.0.1:10808 no_proxy=localhost,127.0.0.1
```

## Uninstall

Homebrew: `brew services stop xray && brew uninstall xray`.
Binary: `launchctl bootout gui/$(id -u)/com.xtls.xray`, then delete
`~/Library/LaunchAgents/com.xtls.xray.plist` and `~/.local/xray`.
Turn the system proxy off (commands above).
