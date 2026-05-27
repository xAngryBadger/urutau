Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Urutau - Servidor" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$servidorDir = $PSScriptRoot
$ngrokDir = Join-Path $PSScriptRoot "ngrok"

if (-not (Test-Path $ngrokDir)) { mkdir $ngrokDir }

$pbExe = "$servidorDir\pocketbase.exe"

if (-not (Test-Path $pbExe)) {
    $pbZip = "$servidorDir\pocketbase_windows_amd64.zip"
    if ((Test-Path $pbZip)) {
        Write-Host "[+] Extraindo PocketBase..." -ForegroundColor Yellow
        Expand-Archive -Path $pbZip -DestinationPath $servidorDir -Force
        Write-Host "[OK] PocketBase extraido" -ForegroundColor Green
    } else {
        Write-Host "[!] ERRO: pocketbase.exe nao encontrado em $servidorDir" -ForegroundColor Red
        pause
        exit
    }
}

$ngrokExe = "$ngrokDir\ngrok.exe"
if (-not (Test-Path $ngrokExe)) {
    $ngrokZip = "$servidorDir\ngrok-v3-stable-windows-amd64.zip"
    if ((Test-Path $ngrokZip)) {
        Write-Host "[+] Extraindo ngrok..." -ForegroundColor Yellow
        Expand-Archive -Path $ngrokZip -DestinationPath $ngrokDir -Force
        Write-Host "[OK] ngrok extraido" -ForegroundColor Green
    } else {
        Write-Host "[!] ERRO: ngrok.exe nao encontrado em $ngrokDir" -ForegroundColor Red
        pause
        exit
    }
}

# Kill existing processes to avoid conflicts
Get-Process -Name "pocketbase" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1

Write-Host "[+] Iniciando PocketBase..." -ForegroundColor Green
Start-Process -FilePath $pbExe -ArgumentList "serve" -WorkingDirectory $servidorDir -WindowStyle Minimized
Start-Sleep -Seconds 4

Write-Host "[+] Iniciando ngrok..." -ForegroundColor Green
Start-Process -FilePath $ngrokExe -ArgumentList "http 8090" -WorkingDirectory $ngrokDir
Start-Sleep -Seconds 5

# Fetch current ngrok public URL from the local API
Write-Host "[+] Detectando URL publica..." -ForegroundColor Yellow
$ngrokUrl = ""
try {
    $response = Invoke-RestMethod -Uri "http://127.0.0.1:4040/api/tunnels" -TimeoutSec 10
    $ngrokUrl = ($response.tunnels | Where-Object { $_.proto -eq "https" } | Select-Object -First 1).public_url
} catch {
    Write-Host "[!] Nao foi possivel detectar URL automaticamente" -ForegroundColor Red
    Write-Host "    Abra http://127.0.0.1:4040 no navegador para ver a URL" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "   Servidor iniciado!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
if ($ngrokUrl) {
    Write-Host "  URL publica: $ngrokUrl" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Links para enviar:" -ForegroundColor White
    Write-Host "  -----------------------------" -ForegroundColor DarkGray
    Write-Host "  Admin (colega):  $ngrokUrl/urutau-admin/" -ForegroundColor Cyan
    Write-Host "  PB Admin:        $ngrokUrl/_/" -ForegroundColor DarkGray
    Write-Host "  App (campo):     $ngrokUrl" -ForegroundColor Cyan
    Write-Host "  Landing page:    $ngrokUrl/" -ForegroundColor DarkGray
    Write-Host "  -----------------------------" -ForegroundColor DarkGray
} else {
    Write-Host "  Local: http://localhost:8090" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "  Pressione qualquer tecla para parar o servidor..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

Get-Process -Name "ngrok" -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process -Name "pocketbase" -ErrorAction SilentlyContinue | Stop-Process -Force
Write-Host "Servidor parado." -ForegroundColor Red
