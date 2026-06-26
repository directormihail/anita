@echo off
setlocal
cd /d "%~dp0"

where python >nul 2>nul
if errorlevel 1 (
    echo Python not found. Install Python 3.10+ from https://www.python.org/downloads/
    echo Check "Add python.exe to PATH" during install.
    exit /b 1
)

echo Creating virtual environment...
python -m venv .venv
if errorlevel 1 exit /b 1

call .venv\Scripts\activate.bat
python -m pip install --upgrade pip
pip install -r requirements.txt
if errorlevel 1 exit /b 1

playwright install chromium
if errorlevel 1 exit /b 1

if not exist config.yaml (
    copy config.example.yaml config.yaml >nul
    echo Created config.yaml - edit friend_name and send_time before running.
)

echo.
echo Setup complete.
echo Next steps:
echo   1. Edit config.yaml
echo   2. .venv\Scripts\activate
echo   3. python main.py login
echo   4. python main.py test
echo   5. powershell -ExecutionPolicy Bypass -File install-windows-task.ps1
