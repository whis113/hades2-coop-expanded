@echo off
setlocal

set "SCRIPT_DIR=%~dp0"

echo ========================================
echo Hades II Co-op Mod - build and deploy
echo ========================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%build_and_deploy.ps1"
if errorlevel 1 (
    echo.
    echo Build or deploy failed.
    pause
    exit /b 1
)

echo.
echo Done. You can launch Hades II for testing.
pause
