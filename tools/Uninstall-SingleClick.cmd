@echo off
setlocal
cd /d "%~dp0"
echo Security 51 Thai Mod - Single Click Uninstaller
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-SingleClick.ps1"
set "RESULT=%ERRORLEVEL%"
echo.
if not "%RESULT%"=="0" (
  echo Uninstallation failed. Read the error above.
) else (
  echo Uninstallation finished. You can close this window.
)
pause
exit /b %RESULT%
