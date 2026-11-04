@echo off
"C:\Program Files\PowerShell\7\pwsh.exe" -NoLogo -NoProfile -STA -File "F:\srv\vibecoding\Bridge-Console2.ps1"
if errorlevel 1 pause
