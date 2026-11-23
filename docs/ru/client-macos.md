# Клиент без GUI: macOS

**Русский** | [English](../client-macos.md)

Запускает xray-core как фоновый сервис launchd — через Homebrew (проще всего) или из
бинарника релиза.

## Вариант A: Homebrew

```bash
brew install xray
xray version
mkdir -p "$(brew --prefix)/etc/xray"
cp <email>.config.json "$(brew --prefix)/etc/xray/config.json"
chmod 600 "$(brew --prefix)/etc/xray/config.json"
xray run -test -c "$(brew --prefix)/etc/xray/config.json"   # "Configuration OK."

brew services start xray        # запуск сейчас и при входе в систему
brew services info xray
```

После изменения конфига: `brew services restart xray`. Остановка: `brew services stop xray`.
Если сервис не подхватывает файл, проверьте путь к его конфигу командой `brew services info xray --json`
(используется `$(brew --prefix)/etc/xray/config.json`).

## Вариант B: бинарник релиза + LaunchAgent

1. Скачайте `Xray-macos-arm64-v8a.zip` (Apple Silicon) или `Xray-macos-64.zip`
   (Intel) со страницы <https://github.com/XTLS/Xray-core/releases/latest>.
2. Установите:

```bash
mkdir -p ~/.local/xray
unzip ~/Downloads/Xray-macos-arm64-v8a.zip -d ~/.local/xray
xattr -dr com.apple.quarantine ~/.local/xray        # разрешить запуск неподписанного бинарника
cp <email>.config.json ~/.local/xray/config.json
chmod 600 ~/.local/xray/config.json
~/.local/xray/xray run -test -c ~/.local/xray/config.json
```

3. Создайте `~/Library/LaunchAgents/com.xtls.xray.plist` (замените `YOU` на имя своего пользователя):

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

4. Загрузите его:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.xtls.xray.plist
launchctl kickstart -k gui/$(id -u)/com.xtls.xray     # перезапуск после изменения конфига
launchctl bootout gui/$(id -u)/com.xtls.xray          # остановить / выгрузить
```

## Использование: системный прокси

System Settings → Network → (ваша сеть) → Details → Proxies (Системные настройки → Сеть → (ваша сеть) → Подробнее → Прокси): включите
**Web proxy (HTTP)** (Веб-прокси (HTTP)) и **Secure web proxy (HTTPS)** (Защищенный веб-прокси (HTTPS)) `127.0.0.1:10809` и/или
**SOCKS proxy** (SOCKS-прокси) `127.0.0.1:10808`. Safari, Chrome и большинство приложений используют эту настройку.

То же самое из терминала (имя сети — через `networksetup -listallnetworkservices`):

```bash
S="Wi-Fi"
networksetup -setwebproxy        "$S" 127.0.0.1 10809
networksetup -setsecurewebproxy  "$S" 127.0.0.1 10809
networksetup -setsocksfirewallproxy "$S" 127.0.0.1 10808
# выключить:
networksetup -setwebproxystate "$S" off
networksetup -setsecurewebproxystate "$S" off
networksetup -setsocksfirewallproxystate "$S" off
```

Консольные утилиты игнорируют системный прокси; добавьте в `~/.zshrc`:

```bash
export http_proxy=http://127.0.0.1:10809 https_proxy=http://127.0.0.1:10809
export all_proxy=socks5h://127.0.0.1:10808 no_proxy=localhost,127.0.0.1
```

## Удаление

Homebrew: `brew services stop xray && brew uninstall xray`.
Бинарник: `launchctl bootout gui/$(id -u)/com.xtls.xray`, затем удалите
`~/Library/LaunchAgents/com.xtls.xray.plist` и `~/.local/xray`.
Выключите системный прокси (команды выше).
