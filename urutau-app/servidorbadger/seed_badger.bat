@echo off
chcp 65001 > nul
cd /d E:\servidorbadger

REM Seed PocketBase from CSV (sensitive: runs here, not in workspace)
REM Servidor: iniciar_servidor.ps1 | Configure: .env.seed com PB_ADMIN_EMAIL, PB_ADMIN_PASSWORD

if not defined PB_URL set PB_URL=http://localhost:8090

echo.
echo Executando seed a partir do CSV...
echo Servidor: %PB_URL%
echo.

powershell -ExecutionPolicy Bypass -File "E:\servidorbadger\seed_from_csv.ps1" -ServerUrl "%PB_URL%" %*

echo.
pause
