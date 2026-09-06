@echo off
setlocal
cd /d "%~dp0"
echo Security 51 Thai Mod - Single Click Installer
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-SingleClick.ps1"
set "RESULT=%ERRORLEVEL%"
echo.
if not "%RESULT%"=="0" (
  echo Installation failed. Read the error above.
) else (
  echo Installation finished. You can close this window.
)
pause
exit /b %RESULT%
