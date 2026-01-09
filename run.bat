@echo off
setlocal

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

if /I "%MODE%"=="host" (
  "%GODOT_EXE%" --path . -- --mode=host
  goto :eof
)

if /I "%MODE%"=="join" (
  if "%2"=="" (
    echo Usage: run.bat join 192.168.0.10
    exit /b 1
  )
  "%GODOT_EXE%" --path . -- --mode=join --ip=%2
  goto :eof
)

echo Usage: run.bat ^<host^|join^> [ip]
exit /b 1
