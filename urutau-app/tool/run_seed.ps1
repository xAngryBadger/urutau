# Executa o seed do PocketBase (schema normalizado). Duplo-clique ou: .\tool\run_seed.ps1
# Requer: PocketBase a correr (ex: iniciar_servidor.ps1 em e:\servidorbadger) e tool\.env.seed preenchido.
$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
$projectRoot = Split-Path $scriptDir -Parent
$csvPath = Join-Path $env:USERPROFILE "Downloads\Planilha_ISAAC 1(mapeamento_area_pt).csv"
if (-not (Test-Path $csvPath)) {
    $csvPath = Join-Path $projectRoot "Planilha_ISAAC 1(mapeamento_area_pt).csv"
}
if (-not (Test-Path $csvPath)) {
    Write-Host "CSV nao encontrado. Coloque Planilha_ISAAC 1(mapeamento_area_pt).csv em Downloads ou na raiz do projeto."
    exit 1
}
$envFile = Join-Path $scriptDir ".env.seed"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$' -and $line -notmatch '^#') {
            [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2].Trim(), 'Process')
        }
    }
}
Set-Location $projectRoot
Write-Host "A executar seed (CSV: $csvPath)..."
& dart run tool/seed_pocketbase_from_csv.dart $csvPath
$exitCode = $LASTEXITCODE
if ($exitCode -eq 0) {
    Write-Host "Seed concluido. Pode abrir o app e usar 'Atualizar catálogo do servidor'."
} else {
    Write-Host "Seed falhou (exit $exitCode). Verifique se o PocketBase esta a correr e tool\.env.seed esta correto."
}
exit $exitCode
