@echo off
setlocal EnableDelayedExpansion

set GODOT_EXE=%GODOT_EXE%
if "%GODOT_EXE%"=="" (
  if exist "tools\godot\Godot_v4.2.2-stable_win64.exe" (
    set GODOT_EXE=tools\godot\Godot_v4.2.2-stable_win64.exe
  ) else (
    set GODOT_EXE=godot
  )
)

if not exist ".godot\imported" (
  "%GODOT_EXE%" --path . --import
)

if "%1"=="" (
  set MODE=host
) else (
  set MODE=%1
)

set PORT=
set PORT_ARG=
if /I "%MODE%"=="host" (
  if not "%2"=="" set PORT_ARG=%2
) else if /I "%MODE%"=="join" (
  if not "%3"=="" set PORT_ARG=%3
)
if not "%PORT_ARG%"=="" (
  if /I "!PORT_ARG:~0,7!"=="--port=" (
    set PORT=!PORT_ARG:~7!
  ) else (
    for /f "delims=0123456789" %%A in ("!PORT_ARG!") do set "PORT_NONNUM=%%A"
    if not defined PORT_NONNUM set PORT=!PORT_ARG!
    set PORT_NONNUM=
  )
)

if /I "%MODE%"=="host" (
  set LOCAL_IP=
  for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "$ips = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '169.254*' -and $_.IPAddress -ne '127.0.0.1' -and $_.IPAddress -ne '0.0.0.0' -and $_.InterfaceAlias -notmatch 'vEthernet|WSL|Hyper-V|Virtual' }; ($ips | Sort-Object -Property InterfaceMetric, PrefixLength | Select-Object -First 1 -ExpandProperty IPAddress)"`) do set LOCAL_IP=%%i
  set JOIN_PORT=
  if not "!PORT!"=="" set JOIN_PORT= !PORT!
  echo Same PC: run.bat join 127.0.0.1!JOIN_PORT!
  if not "!LOCAL_IP!"=="" (
    echo Host IP: !LOCAL_IP!
    echo Join with: run.bat join !LOCAL_IP!!JOIN_PORT!
  ) else (
    echo Host IP not found. Run ipconfig to find your LAN IPv4 address.
  )
  if not "!PORT!"=="" (
    "%GODOT_EXE%" --path . -- --mode=host --port=!PORT!
  ) else (
    "%GODOT_EXE%" --path . -- --mode=host
  )
  goto :eof
)

if /I "%MODE%"=="join" (
  if "%2"=="" (
    echo Usage: run.bat join 192.168.0.10
    exit /b 1
  )
  if not "!PORT!"=="" (
    "%GODOT_EXE%" --path . -- --mode=join --ip=%2 --port=!PORT!
  ) else (
    "%GODOT_EXE%" --path . -- --mode=join --ip=%2
  )
  goto :eof
)

echo Usage: run.bat ^<host^|join^> [ip]
exit /b 1
