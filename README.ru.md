# Xray REALITY stack

**Русский** | [English](README.md)

Собственный прокси VLESS + XTLS-Vision + REALITY на TCP 443. Подключения без
действительных учётных данных REALITY передаются настоящему HTTPS-сайту с
сертификатом Let's Encrypt для вашего домена, поэтому сервер выглядит как обычный
веб-хостинг.

Конфигурация лежит в `templates/` с плейсхолдерами `{{VARIABLE}}`; на сервере её
заполняет `install.sh` (список переменных: [templates/README.md](templates/README.md), на английском).

## Документация

| Тема | Документ |
|---|---|
| Обзор вариантов клиента | [docs/ru/README.md](docs/ru/README.md) |
| Сервер: установка, проверка, добавление и удаление клиентов, QR-коды, обслуживание | [server.md](docs/ru/server.md) |
| Архитектура: путь трафика, инварианты, бюджет памяти | [architecture.md](docs/ru/architecture.md) |
| Клиент: Windows (без GUI) | [client-windows.md](docs/ru/client-windows.md) |
| Клиент: Linux (без GUI) | [client-linux.md](docs/ru/client-linux.md) |
| Клиент: macOS (без GUI) | [client-macos.md](docs/ru/client-macos.md) |
| Клиент: Android | [client-android.md](docs/ru/client-android.md) |
| Клиент: iOS / iPadOS | [client-ios.md](docs/ru/client-ios.md) |
| Клиент: только браузер (Firefox, Chrome/Edge, Safari) | [client-browsers.md](docs/ru/client-browsers.md) |

## Быстрый старт

Сервер на Ubuntu LTS, DNS домена уже указывает на него, порты 80 и 443 открыты.
На сервере (`ssh <host>`):

```bash
sudo apt-get update && sudo apt-get install -y git
sudo git clone https://github.com/iztiev/xray-proxy.git /opt/xray-stack
cd /opt/xray-stack
sudo bash install.sh        # ответьте на вопросы
```

Затем настройте клиент: `clients/<email>.config.json` (компьютер) или QR-код
(телефон). В повседневной работе, в `/opt/xray-stack` на сервере:

| Задача | Команда |
|---|---|
| Добавить клиента | `sudo bash add_user.sh` |
| Удалить клиента | `sudo bash remove_user.sh` |
| QR-код для телефона | `sudo bash show_qr.sh` |
| Обновить скрипты и шаблоны | `sudo git pull` |

Сгенерированные конфиги, файлы клиентов и `data/` игнорируются git, поэтому
`git pull` обновляет скрипты и шаблоны, не трогая секреты. Подробнее:
[docs/ru/server.md](docs/ru/server.md).
