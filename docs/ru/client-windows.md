# Клиент без GUI: Windows

**Русский** | [English](../client-windows.md)

Запускает `xray.exe` в фоне как задачу планировщика (без окна, стартует при загрузке)
и направляет на него системный прокси Windows. Все команды выполняются в PowerShell **от имени администратора**.

## 1. Установка xray-core

1. Скачайте `Xray-windows-64.zip` (или `Xray-windows-arm64-v8a.zip` для ARM) со страницы
   <https://github.com/XTLS/Xray-core/releases/latest>.
2. Распакуйте и установите:

```powershell
$dir = "$env:ProgramFiles\Xray"
New-Item -ItemType Directory -Force $dir | Out-Null
Expand-Archive "$env:USERPROFILE\Downloads\Xray-windows-64.zip" -DestinationPath $dir -Force
Get-ChildItem $dir | Unblock-File          # снять пометку «загружено из интернета»
& "$dir\xray.exe" version
```

## 2. Добавление конфига

```powershell
Copy-Item ".\<email>.config.json" "$dir\config.json"
& "$dir\xray.exe" run -test -c "$dir\config.json"     # должно вывести "Configuration OK."
```

Необязательно: ограничьте доступ к конфигу группой Administrators и SYSTEM (он содержит учётные данные):

```powershell
icacls "$dir\config.json" /inheritance:r /grant:r "Administrators:F" "SYSTEM:F"
```

## 3. Пробный запуск на переднем плане

```powershell
& "$dir\xray.exe" run -c "$dir\config.json"
```

В другом окне: `curl.exe -x socks5h://127.0.0.1:10808 https://ifconfig.me`
должен вывести IP сервера. Остановка — Ctrl+C.

## 4. Запуск в фоне (старт при загрузке)

Задача планировщика, запускаемая от имени SYSTEM: без окна консоли, продолжает работать
после выхода из системы, перезапускается, если xray завершился.

```powershell
$action    = New-ScheduledTaskAction -Execute "$dir\xray.exe" -Argument "run -c `"$dir\config.json`"" -WorkingDirectory $dir
$trigger   = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) `
               -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) `
               -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName "Xray" -Action $action -Trigger $trigger -Principal $principal -Settings $settings
Start-ScheduledTask -TaskName "Xray"
```

Управление:

```powershell
Get-ScheduledTask -TaskName "Xray" | Select-Object State     # работает?
Stop-ScheduledTask  -TaskName "Xray"
Start-ScheduledTask -TaskName "Xray"                          # после изменения config.json
Unregister-ScheduledTask -TaskName "Xray" -Confirm:$false    # удалить
```

## 5. Использование: системный прокси

Settings → Network & internet → Proxy (Параметры → Сеть и Интернет → Прокси-сервер) → **Manual proxy setup** → Edit:
адрес `127.0.0.1`, порт `10809`, отметьте «Don't use the proxy server for local
(intranet) addresses». Браузеры (Edge, Chrome) и большинство приложений используют эту настройку.

То же самое из PowerShell (от текущего пользователя, не от администратора):

```powershell
$k = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
Set-ItemProperty $k ProxyServer   '127.0.0.1:10809'
Set-ItemProperty $k ProxyOverride '<local>;localhost;127.*;10.*;192.168.*'
Set-ItemProperty $k ProxyEnable   1        # 0 — выключить прокси
```

Приложения, которые игнорируют системный прокси:
- **Firefox**: Settings → Network Settings → «Use system proxy settings» (или вручную SOCKS5 `127.0.0.1:10808` с отметкой «Proxy DNS when using SOCKS v5»).
- **Консольные утилиты** (git, curl, pip, npm…): задайте переменные окружения на сеанс или постоянно:

```powershell
$env:HTTP_PROXY  = 'http://127.0.0.1:10809'
$env:HTTPS_PROXY = 'http://127.0.0.1:10809'
$env:NO_PROXY    = 'localhost,127.0.0.1'
# постоянно (для новых терминалов): [Environment]::SetEnvironmentVariable('HTTPS_PROXY','http://127.0.0.1:10809','User')
```

## Удаление

```powershell
Unregister-ScheduledTask -TaskName "Xray" -Confirm:$false
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' ProxyEnable 0
Remove-Item -Recurse "$env:ProgramFiles\Xray"
```
