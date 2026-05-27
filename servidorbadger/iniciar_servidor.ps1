Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Extraindo e Iniciando Servidor" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$servidorDir = $PSScriptRoot
$ngrokDir = Join-Path $PSScriptRoot "ngrok"

if (-not (Test-Path $ngrokDir)) { mkdir $ngrokDir }

$pbZip = "$servidorDir\pocketbase_windows_amd64.zip"
$pbExe = "$servidorDir\pocketbase.exe"

if ((Test-Path $pbZip) -and -not (Test-Path $pbExe)) {
    Write-Host "[+] Extraindo PocketBase..." -ForegroundColor Yellow
    Expand-Archive -Path $pbZip -DestinationPath $servidorDir -Force
    Write-Host "[OK] PocketBase extraido" -ForegroundColor Green
}

$ngrokZip = "$servidorDir\ngrok-v3-stable-windows-amd64.zip"
$ngrokExe = "$ngrokDir\ngrok.exe"

if ((Test-Path $ngrokZip) -and -not (Test-Path $ngrokExe)) {
    Write-Host "[+] Extraindo ngrok..." -ForegroundColor Yellow
    Expand-Archive -Path $ngrokZip -DestinationPath $ngrokDir -Force
    Write-Host "[OK] ngrok extraido" -ForegroundColor Green
}

if (-not (Test-Path $pbExe)) {
    Write-Host "[!] ERRO: pocketbase.exe nao encontrado em $servidorDir" -ForegroundColor Red
    pause
    exit
}

if (-not (Test-Path $ngrokExe)) {
    Write-Host "[!] ERRO: ngrok.exe nao encontrado em $ngrokDir" -ForegroundColor Red
    pause
    exit
}

Write-Host "[+] Iniciando PocketBase..." -ForegroundColor Green
Start-Process -FilePath $pbExe -ArgumentList "serve" -WorkingDirectory $servidorDir -WindowStyle Minimized

Start-Sleep -Seconds 4

Write-Host "[+] Iniciando ngrok..." -ForegroundColor Green
Start-Process -FilePath $ngrokExe -ArgumentList "http 8090" -WorkingDirectory $ngrokDir

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "OK: Servidor iniciado!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "URL publica: (verifique http://127.0.0.1:4040)" -ForegroundColor Yellow
