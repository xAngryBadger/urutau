# ========================================================
# Seed PocketBase parcelas from Planilha_ISAAC CSV
# Runs in servidorbadger folder (outside workspace).
# 1) Cleans all plantas then parcelas
# 2) Inserts parcelas from CSV (ID_PROP;ID_UT;Área;Qtd Parcelas)
# ========================================================

param(
    [string]$CsvPath = "",
    [string]$ServerUrl = "",
    [string]$AdminEmail = "",
    [string]$AdminPassword = ""
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

# Load .env.seed if present (never commit .env.seed)
$envPath = Join-Path $scriptDir ".env.seed"
if (Test-Path $envPath) {
    Get-Content $envPath | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#")) {
            $i = $line.IndexOf("=")
            if ($i -gt 0) {
                $k = $line.Substring(0, $i).Trim()
                $v = $line.Substring($i + 1).Trim()
                [Environment]::SetEnvironmentVariable($k, $v, "Process")
            }
        }
    }
}

if (-not $ServerUrl) { $ServerUrl = $env:PB_URL }
if (-not $AdminEmail) { $AdminEmail = $env:PB_ADMIN_EMAIL }
if (-not $AdminPassword) { $AdminPassword = $env:PB_ADMIN_PASSWORD }

$ServerUrl = $ServerUrl.TrimEnd("/")
if (-not $ServerUrl) {
    Write-Host "Defina PB_URL ou use -ServerUrl (ex: http://localhost:8090)" -ForegroundColor Red
    exit 1
}
if (-not $AdminEmail -or -not $AdminPassword) {
    Write-Host "Defina PB_ADMIN_EMAIL e PB_ADMIN_PASSWORD (ou .env.seed)" -ForegroundColor Red
    exit 1
}

if (-not $CsvPath) {
    $defaultCsv = Join-Path $env:USERPROFILE "Downloads\Planilha_ISAAC 1(mapeamento_area_pt).csv"
    if (Test-Path $defaultCsv) { $CsvPath = $defaultCsv }
    else { $CsvPath = "Planilha_ISAAC 1(mapeamento_area_pt).csv" }
}
if (-not (Test-Path $CsvPath)) {
    Write-Host "CSV nao encontrado: $CsvPath" -ForegroundColor Red
    exit 1
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Seed PocketBase a partir do CSV" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Servidor: $ServerUrl" -ForegroundColor Gray
Write-Host "CSV:     $CsvPath" -ForegroundColor Gray
Write-Host ""

# ---- 1. Auth (try superusers then admins) ----
Write-Host "[1/4] Autenticando..." -ForegroundColor Yellow
$authBody = @{ identity = $AdminEmail; password = $AdminPassword } | ConvertTo-Json
$token = $null
try {
    $r = Invoke-RestMethod -Uri "$ServerUrl/api/collections/_superusers/auth-with-password" -Method Post -Body $authBody -ContentType "application/json" -ErrorAction Stop
    $token = $r.token
} catch {
    try {
        $r = Invoke-RestMethod -Uri "$ServerUrl/api/admins/auth-with-password" -Method Post -Body $authBody -ContentType "application/json" -ErrorAction Stop
        $token = $r.token
    } catch {
        Write-Host "ERRO: Falha de autenticacao. Verifique email/senha do admin." -ForegroundColor Red
        exit 1
    }
}
Write-Host "  OK" -ForegroundColor Green

$headers = @{ Authorization = "Bearer $token" }

# ---- 2. Delete all plantas then parcelas ----
Write-Host "[2/4] Limpando plantas e parcelas..." -ForegroundColor Yellow
foreach ($coll in @("plantas", "parcelas")) {
    $page = 1
    do {
        $list = Invoke-RestMethod -Uri "$ServerUrl/api/collections/$coll/records?perPage=200&page=$page" -Headers $headers -ErrorAction Stop
        $items = $list.items
        foreach ($rec in $items) {
            Invoke-RestMethod -Uri "$ServerUrl/api/collections/$coll/records/$($rec.id)" -Method Delete -Headers $headers -ErrorAction SilentlyContinue | Out-Null
        }
        if ($items.Count -lt 200) { break }
        $page++
    } while ($true)
}
Write-Host "  OK" -ForegroundColor Green

# ---- 3. Parse CSV ----
Write-Host "[3/4] A ler CSV..." -ForegroundColor Yellow
$lines = Get-Content $CsvPath -Encoding UTF8
$rows = @()
foreach ($line in $lines) {
    $line = $line.Trim()
    if (-not $line) { continue }
    $p = $line -split ";"
    if ($p.Length -lt 4) { continue }
    if ($p[0] -eq "ID_PROP") { continue }
    $idProp = $p[0].Trim()
    $idUt = $p[1].Trim()
    $areaStr = $p[2].Trim() -replace ",", "."
    $qtdStr = $p[3].Trim()
    $area = [double]::TryParse($areaStr, [ref]$null)
    $qtd = [int]::TryParse($qtdStr, [ref]$null)
    if ($qtd -lt 1) { $qtd = 1 }
    if ($idProp -and $idUt -and $area) {
        $rows += @{ idProp = $idProp; idUt = $idUt; areaHa = $area; qtd = $qtd }
    }
}

$nextId = @{}
$records = @()
foreach ($r in $rows) {
    $key = "$($r.idProp)|$($r.idUt)"
    $start = 1
    if ($nextId.ContainsKey($key)) { $start = $nextId[$key] }
    for ($k = 0; $k -lt $r.qtd; $k++) {
        $records += @{
            propriedade = $r.idProp
            prop_ut     = $r.idUt
            id_parcela  = $start + $k
            area_ha     = $r.areaHa
            user        = ""
        }
    }
    $nextId[$key] = $start + $r.qtd
}

Write-Host "  $($records.Count) parcelas a inserir" -ForegroundColor Green

# ---- 4. Insert parcelas ----
Write-Host "[4/4] A inserir parcelas..." -ForegroundColor Yellow
$created = 0
foreach ($b in $records) {
    $prop = ($b.propriedade -replace '\\', '\\\\' -replace '"', '\"')
    $ut = ($b.prop_ut -replace '\\', '\\\\' -replace '"', '\"')
    $areaVal = ($b.area_ha -as [double]).ToString().Replace(',', '.')
    $json = "{`"propriedade`":`"$prop`",`"prop_ut`":`"$ut`",`"id_parcela`":$($b.id_parcela),`"area_ha`":$areaVal,`"user`":`"`"}"
    try {
        Invoke-RestMethod -Uri "$ServerUrl/api/collections/parcelas/records" -Method Post -Body $json -ContentType "application/json; charset=utf-8" -Headers $headers -ErrorAction Stop | Out-Null
        $created++
        if ($created % 50 -eq 0) { Write-Host "  $created..." -ForegroundColor Gray }
    } catch {
        Write-Host "  Erro ao inserir: $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Concluido. $created parcelas criadas." -ForegroundColor Green
Write-Host ""
