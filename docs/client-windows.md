# Headless client: Windows

Runs `xray.exe` in the background as a scheduled task (no window, starts at boot)
and points the Windows system proxy at it. All commands: PowerShell **as Administrator**.

## 1. Install xray-core

1. Download `Xray-windows-64.zip` (or `Xray-windows-arm64-v8a.zip` on ARM) from
   <https://github.com/XTLS/Xray-core/releases/latest>.
2. Extract and install:

```powershell
$dir = "$env:ProgramFiles\Xray"
New-Item -ItemType Directory -Force $dir | Out-Null
Expand-Archive "$env:USERPROFILE\Downloads\Xray-windows-64.zip" -DestinationPath $dir -Force
Get-ChildItem $dir | Unblock-File          # remove the "downloaded from internet" mark
& "$dir\xray.exe" version
```

## 2. Add your config

```powershell
Copy-Item ".\<email>.config.json" "$dir\config.json"
& "$dir\xray.exe" run -test -c "$dir\config.json"     # must print "Configuration OK."
```

Optional: restrict the config to Administrators/SYSTEM (it is a credential):

```powershell
icacls "$dir\config.json" /inheritance:r /grant:r "Administrators:F" "SYSTEM:F"
```

## 3. Try it in the foreground

```powershell
& "$dir\xray.exe" run -c "$dir\config.json"
```

In another window: `curl.exe -x socks5h://127.0.0.1:10808 https://ifconfig.me`
should print the server's IP. Stop with Ctrl+C.

## 4. Run in the background (starts at boot)

A scheduled task running as SYSTEM: no console window, survives logoff, restarts
if xray exits.

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

Manage it:

```powershell
Get-ScheduledTask -TaskName "Xray" | Select-Object State     # Running?
Stop-ScheduledTask  -TaskName "Xray"
Start-ScheduledTask -TaskName "Xray"                          # after changing config.json
Unregister-ScheduledTask -TaskName "Xray" -Confirm:$false    # remove
```

## 5. Use it: system proxy

Settings → Network & internet → Proxy → **Manual proxy setup** → Edit:
address `127.0.0.1`, port `10809`, tick "Don't use the proxy server for local
(intranet) addresses". Browsers (Edge, Chrome) and most apps follow this.

Same from PowerShell (current user, not as Administrator):

```powershell
$k = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
Set-ItemProperty $k ProxyServer   '127.0.0.1:10809'
Set-ItemProperty $k ProxyOverride '<local>;localhost;127.*;10.*;192.168.*'
Set-ItemProperty $k ProxyEnable   1        # 0 to turn the proxy off
```

Apps that ignore the system proxy:
- **Firefox**: Settings → Network Settings → "Use system proxy settings" (or manual SOCKS5 `127.0.0.1:10808`, tick "Proxy DNS when using SOCKS v5").
- **CLI tools** (git, curl, pip, npm…): set env vars for the session or permanently:

```powershell
$env:HTTP_PROXY  = 'http://127.0.0.1:10809'
$env:HTTPS_PROXY = 'http://127.0.0.1:10809'
$env:NO_PROXY    = 'localhost,127.0.0.1'
# permanent (new terminals): [Environment]::SetEnvironmentVariable('HTTPS_PROXY','http://127.0.0.1:10809','User')
```

## Uninstall

```powershell
Unregister-ScheduledTask -TaskName "Xray" -Confirm:$false
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' ProxyEnable 0
Remove-Item -Recurse "$env:ProgramFiles\Xray"
```
