# Клиент без GUI: Linux

**Русский** | [English](../client-linux.md)

Запускает xray-core как сервис systemd с помощью официального скрипта установки XTLS.
Работает в любом дистрибутиве с systemd (Ubuntu, Debian, Fedora, Arch…).

## 1. Установка xray-core

```bash
sudo bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
xray version
```

Скрипт устанавливает `/usr/local/bin/xray`, каталог конфигурации `/usr/local/etc/xray/` и
юнит systemd `xray.service`, работающий от пользователя `nobody`.
(В Arch подойдёт и `pacman -S xray`, конфиг тогда лежит в `/etc/xray/config.json`.)

## 2. Добавление конфига

```bash
sudo install -m 644 <email>.config.json /usr/local/etc/xray/config.json
sudo xray run -test -c /usr/local/etc/xray/config.json     # "Configuration OK."
```

Права 644, потому что сервис работает от `nobody`. На машине с несколькими пользователями вместо этого
выполните `sudo chown root:nogroup … && sudo chmod 640 …` (в Fedora группа `nobody`).

## 3. Запуск и автозапуск при загрузке

```bash
sudo systemctl enable --now xray
systemctl status xray
journalctl -u xray -f            # логи
sudo systemctl restart xray      # после изменения конфига
```

Либо пробный запуск на переднем плане (сначала остановите сервис):
`sudo systemctl stop xray && xray run -c /usr/local/etc/xray/config.json`

## 4. Использование

Консольные утилиты — в текущей оболочке или в `~/.profile` / `~/.bashrc`:

```bash
export http_proxy=http://127.0.0.1:10809
export https_proxy=http://127.0.0.1:10809
export all_proxy=socks5h://127.0.0.1:10808
export no_proxy=localhost,127.0.0.1
```

Рабочий стол (GNOME): Settings → Network → Network Proxy → Manual: HTTP и HTTPS
`127.0.0.1:10809`, Socks `127.0.0.1:10808`. Или так:

```bash
gsettings set org.gnome.system.proxy mode manual
gsettings set org.gnome.system.proxy.http  host 127.0.0.1; gsettings set org.gnome.system.proxy.http  port 10809
gsettings set org.gnome.system.proxy.https host 127.0.0.1; gsettings set org.gnome.system.proxy.https port 10809
gsettings set org.gnome.system.proxy.socks host 127.0.0.1; gsettings set org.gnome.system.proxy.socks port 10808
# выключить: gsettings set org.gnome.system.proxy mode none
```

KDE: System Settings → Network → Proxy → вручную, те же значения.

## Альтернатива: Docker

Если Docker уже установлен, пакет не нужен:

```bash
docker run -d --name xray-client --restart unless-stopped --network host \
  -v "$PWD/<email>.config.json:/etc/xray/config.json:ro" \
  ghcr.io/xtls/xray-core:latest run -c /etc/xray/config.json
```

`--network host` делает порты на `127.0.0.1` доступными с хоста. Файл должен быть
доступен для чтения пользователю контейнера (`chmod 644`).

## Раздача в локальную сеть (необязательно)

Конфиг слушает только `127.0.0.1`. Чтобы другие устройства могли использовать эту машину как
прокси, замените `"listen"` в обоих inbound на `"0.0.0.0"`, перезапустите сервис и в файрволе разрешите порты
10808/10809 только из вашей локальной сети. Аутентификации на прокси нет.

## Удаление

```bash
sudo bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove --purge
```
