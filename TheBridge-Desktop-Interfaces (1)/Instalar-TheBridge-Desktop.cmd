@echo off
setlocal
set "BRIDGE_DESKTOP_SETUP=%~dp0Instalar-Desktop.ps1"
set "BRIDGE_PWSH=%ProgramFiles%\PowerShell\7\pwsh.exe"
if not exist "%BRIDGE_PWSH%" (
 echo PowerShell 7 nao encontrado.
 pause
 exit /b 1
)
if not exist "%BRIDGE_DESKTOP_SETUP%" (
 echo Extraia TODOS os arquivos do ZIP para uma mesma pasta antes de executar.
 pause
 exit /b 1
)
"%BRIDGE_PWSH%" -NoLogo -NoProfile -STA -Command "$ErrorActionPreference='Stop'; try { Unblock-File -LiteralPath $env:BRIDGE_DESKTOP_SETUP; $global:LASTEXITCODE=0; & $env:BRIDGE_DESKTOP_SETUP -Apply; exit $LASTEXITCODE } catch { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }"
set "BRIDGE_DESKTOP_RESULT=%ERRORLEVEL%"
echo.
echo Codigo de saida: %BRIDGE_DESKTOP_RESULT%
pause
endlocal & exit /b %BRIDGE_DESKTOP_RESULT%
