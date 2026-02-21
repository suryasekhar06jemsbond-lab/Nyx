@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PYTHON=%SCRIPT_DIR%scripts\nyx_launcher.py"

if not exist "%PYTHON%" (
    echo Error: nyx_launcher.py not found at %PYTHON%
    exit /b 1
)

py -3 "%PYTHON%" %*
