# Seed PocketBase (schema flat): limpa plantas + parcelas e re-popula parcelas a partir do CSV.
# Hierarquia: prop_ut = "Propriedade - UT". Área em observacoes (campo area_ha não existe na coleção).
$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
$projectRoot = Split-Path $scriptDir -Parent

$envFile = Join-Path $scriptDir ".env.seed"
if (-not (Test-Path $envFile)) { Write-Error "Missing $envFile"; exit 1 }
$pbUrl = $null
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*PB_URL=(.+)$') { $pbUrl = $matches[1].Trim() }
}
$baseUrl = $pbUrl.TrimEnd('/') + '/'
$csvPath = Join-Path $env:USERPROFILE "Downloads\Planilha_ISAAC 1(mapeamento_area_pt).csv"
if (-not (Test-Path $csvPath)) { $csvPath = Join-Path $projectRoot "Planilha_ISAAC 1(mapeamento_area_pt).csv" }
if (-not (Test-Path $csvPath)) { Write-Error "CSV not found"; exit 1 }

function LooksLikeUt($s) {
    if (-not $s -or $s.Length -lt 2) { return $false }
    $t = $s.Trim().ToUpper()
    if (-not $t.StartsWith("UT")) { return $false }
    $rest = $t.Substring(2)
    if ($rest.Length -eq 0) { return $true }
    if ($rest.StartsWith("E") -and $rest.Length -gt 1) { return $true }
    return $rest -match '^[A-Z0-9]+$'
}

# Limpar
foreach ($coll in @('plantas', 'parcelas')) {
    do {
        $r = Invoke-RestMethod -Uri "${baseUrl}api/collections/$coll/records?perPage=200&page=1"
        foreach ($item in $r.items) {
            Invoke-RestMethod -Uri "${baseUrl}api/collections/$coll/records/$($item.id)" -Method Delete | Out-Null
        }
    } while ($r.items.Count -gt 0)
    Write-Host "Cleaned $coll"
}

# Parse CSV
$rows = @()
$lines = Get-Content $csvPath -Encoding UTF8
foreach ($line in $lines) {
    $line = $line.Trim(); if (-not $line) { continue }
    $p = $line -split ';'
    if ($p.Length -lt 4) { continue }
    if ($p[0] -eq 'ID_PROP' -and $p[1] -eq 'ID_UT') { continue }
    $col0 = $p[0].Trim(); $col1 = $p[1].Trim()
    if ((LooksLikeUt $col0) -and -not (LooksLikeUt $col1)) { $col0, $col1 = $col1, $col0 }
    $areaStr = $p[2].Trim() -replace ',', '.'
    $area = 0.0; [double]::TryParse($areaStr, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$area) | Out-Null
    $qtd = 1; [int]::TryParse($p[3].Trim(), [ref]$qtd) | Out-Null
    if (-not $col0 -or -not $col1 -or $qtd -lt 1) { continue }
    $rows += @{ prop = $col0; ut = $col1; areaHa = $area; qtd = $qtd }
}

Write-Host "CSV parsed: $($rows.Count) rows"
$totalExpected = 0; foreach ($rr in $rows) { $totalExpected += $rr.qtd }
Write-Host "Expected parcelas: $totalExpected"

# Inserir parcelas
$nextId = @{}
$created = 0
foreach ($r in $rows) {
    $key = "$($r.prop)|$($r.ut)"
    $start = if ($nextId[$key]) { $nextId[$key] } else { 1 }
    for ($k = 0; $k -lt $r.qtd; $k++) {
        $areaFormatted = $r.areaHa.ToString("F4", [System.Globalization.CultureInfo]::InvariantCulture)
        $body = @{
            prop_ut     = "$($r.prop) - $($r.ut)"
            id_parcela  = $start + $k
            observacoes = "area_ha:$areaFormatted"
            user        = ""
        } | ConvertTo-Json
        try {
            Invoke-RestMethod -Uri "${baseUrl}api/collections/parcelas/records" -Method Post -Body $body -ContentType "application/json" | Out-Null
            $created++
            if ($created % 50 -eq 0 -and $created -gt 0) { Write-Host "  $created..." }
        }
        catch { Write-Warning "Post failed for $($r.prop)-$($r.ut) parcela $($start + $k): $_" }
    }
    $nextId[$key] = $start + $r.qtd
}
Write-Host "Done. Created $created parcelas (expected $totalExpected)."
