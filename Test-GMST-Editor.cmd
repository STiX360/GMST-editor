@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\start-test.ps1" %*
pause
