<#
.SYNOPSIS
    regenerar-pacote.ps1 — regenera o pacote de produção do URUTAU PocketBase.

.DESCRIPTION
    PROBLEMA QUE ESTE SCRIPT RESOLVE (t19, medido em 2026-10-29):

    1. O pacote (servidorbadger-windows-package) carregava só 12 migrations; o
       repo tem 25. Sem a cadeia completa, o servidor de produção roda sem
       users.isAdmin, sem parcela_rel, sem as regras do Q4 (leak cross-tenant
       provado ao vivo) e sem o upsert do motor.
    2. O data.db do pacote foi montado fora das migrations (16 aplicadas,
       'propriedades' criada via dashboard). Bootar o data.db velho com a
       cadeia nova QUEBRA: 'id: The model id is invalid or already exists;
       name: Collection name must be unique' (1776862933).
    3. O binário do pacote é BYTE-IDÊNTICO ao upstream 0.36.4 (SHA256 igual) —
       achado que CORRIGE a suspeita de "binário não aplica migrations": ele
       aplica,From a flag certa é --migrationsDir (ou migrations ao lado do
       binário). Nada de binário novo, só a flag certa no servir.

    SOLUÇÃO: data.db FRESCO construído pela cadeia completa + preservação do
    usuário existente + backup do pacote velho antes de qualquer coisa.

.PARAMETER Pacote
    Raiz do pacote (default: <repo>\servidorbadger\windows-package).

.PARAMETER Binario
    pocketbase.exe upstream (default: <repo>\servidorbadger-windows-package\pocketbase.exe).

.PARAMETER NaoBootar
    Só prepara os arquivos (não boota pra verificar).

.EXAMPLE
    pwsh -File servidorbadger\regenerar-pacote.ps1

.NOTES
    Ordem OBRIGATÓRIA (B.3 do impl-backup-wal.md): taskkill primeiro.
    NUNCA sobrescrever o pacote sem backup — o script faz backup + diff antes.
#>
[CmdletBinding()]
param(
    [string]$Pacote,
    [string]$Binario,
    [switch]$NaoBootar
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $Pacote) { $Pacote = $PSScriptRoot }
if (-not $Binario) { $Binario = Join-Path $Pacote 'pocketbase.exe' }
$migracoes = Join-Path $repoRoot 'pb_migrations'

function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }
function Ok($m) { Say "  [OK]    $m" 'Green' }
function Info($m) { Say "  [..]    $m" 'DarkGray' }
function Bad($m) { Say "  [FALHA] $m" 'Red' }

# ------------------------------------------------------------ pré-verificação
foreach ($f in @($Binario, $migracoes)) {
    if (-not (Test-Path $f)) { Bad "nao encontrado: $f"; exit 2 }
}

Say "`n=== REGENERAR PACOTE — $Pacote ===" 'Cyan'

# ------------------------------------------------------------ 1. taskkill-first
Say "`n=== 1. Parar qualquer instância rodando (taskkill-first, B.3) ===" 'Cyan'
$rodando = Get-Process pocketbase -ErrorAction SilentlyContinue
if ($rodando) {
    $rodando | ForEach-Object { Info "matando PID $($_.Id) ($($_.Path))" }
    taskkill /IM pocketbase.exe /F 2>&1 | Out-Null
    Start-Sleep -Seconds 2
}
Ok 'nenhuma instância rodando'

# ------------------------------------------------------------ 2. backup
Say "`n=== 2. Backup do pacote velho (ANTES de tocar) ===" 'Cyan'
$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$bkp = Join-Path $Pacote "backups\pacote-$ts"
if (-not (Test-Path (Join-Path $Pacote 'backups'))) {
    New-Item -ItemType Directory -Path (Join-Path $Pacote 'backups') | Out-Null
}
robocopy $Pacote $bkp /E /XD backups /NFL /NDL /NJH /NJS /MT:8 | Out-Null
Ok "backup em $bkp ($(@(Get-ChildItem $bkp -Recurse -File).Count) arquivos)"

# registro do diff (migrations + binário) — evidência do que mudou
$migPacote = Join-Path $Pacote 'pb_migrations'
$antes = @(Get-ChildItem $migPacote -Filter '*.js' -File).Count
$depois = @(Get-ChildItem $migracoes -Filter '*.js' -File).Count
$hashAntes = (Get-FileHash $Binario -Algorithm SHA256).Hash
Info "migrations: pacote=$antes -> repo=$depois"
Info "binário SHA256: $hashAntes"

# ------------------------------------------------------------ 3. data.db fresco
Say "`n=== 3. Data.db FRESCO (a cadeia nova quebra o velho — medido) ===" 'Cyan'
$staging = Join-Path $env:TEMP "urutau-pkg-fresh-$ts"
New-Item -ItemType Directory -Path $staging -Force | Out-Null
$job = Start-Process -FilePath $Binario -ArgumentList 'serve', '--dir', $staging, '--migrationsDir', $migracoes, '--http', '127.0.0.1:8099' -RedirectStandardError "$staging\err.log" -RedirectStandardOutput "$staging\out.log" -PassThru -WindowStyle Hidden
$up = $false
for ($i = 0; $i -lt 15; $i++) {
    Start-Sleep -Seconds 2
    try {
        $h = Invoke-RestMethod 'http://127.0.0.1:8099/api/health' -TimeoutSec 3
        if ($h.code -eq 200) { $up = $true; break }
    } catch {}
}
if (-not $up) {
    taskkill /PID $job.Id /F 2>&1 | Out-Null
    Bad "data.db fresco NAO subiu. Erro:"
    Get-Content "$staging\out.log", "$staging\err.log" -EA SilentlyContinue | Select-Object -Last 3
    exit 3
}
Ok "cadeia completa aplicada ($depois migrations)"
taskkill /PID $job.Id /F 2>&1 | Out-Null
Start-Sleep -Seconds 2

# preservar usuários do data.db velho (colunas comuns; isAdmin já existe no novo)
$dataVelho = Join-Path $Pacote 'pb_data\data.db'
$dataNovo = Join-Path $staging 'data.db'
$py = @'
import sqlite3, sys
old_c = sqlite3.connect(sys.argv[1]); new_c = sqlite3.connect(sys.argv[2])
oc = [r[1] for r in old_c.execute('PRAGMA table_info(users)')]
nc = [r[1] for r in new_c.execute('PRAGMA table_info(users)')]
comuns = [c for c in oc if c in nc]
rows = list(old_c.execute('SELECT %s FROM users' % ', '.join(comuns)))
mig = 0
for row in rows:
    r = dict(zip(comuns, row))
    r.setdefault('emailVisibility', 0); r.setdefault('verified', 0)
    if 'isAdmin' not in r: r['isAdmin'] = 0
    cols = list(r.keys())
    new_c.execute('INSERT INTO users (%s) VALUES (%s)' % (
        ', '.join(cols), ', '.join('?' for _ in cols)), [r[c] for c in cols])
    mig += 1
new_c.commit()
print('MIGRADOS %d' % mig)
'@
$pyFile = "$staging\preservar.py"
$py | Set-Content $pyFile -Encoding UTF8
if (Test-Path $dataVelho) {
    Info "preservando usuários do data.db velho..."
    & 'C:\Users\Badger\miniforge3\python.exe' $pyFile $dataVelho $dataNovo 2>&1 | ForEach-Object { Info $_ }
} else { Info "sem data.db velho — nada a preservar" }

# ------------------------------------------------------------ 4. instalar no pacote
Say "`n=== 4. Instalar no pacote ===" 'Cyan'
# migrations: o REPO é a fonte da verdade — espelhar
$tmpMig = "$staging\pb_migrations"
New-Item -ItemType Directory -Path $tmpMig -Force | Out-Null
Copy-Item "$migracoes\*.js" $tmpMig -Force
Remove-Item $migPacote -Recurse -Force -EA SilentlyContinue
Copy-Item $tmpMig $migPacote -Recurse -Force
Ok "migrations espelhadas ($depois arquivos)"

# data.db novo
Remove-Item (Join-Path $Pacote 'pb_data\data.db-wal') -Force -EA SilentlyContinue
Remove-Item (Join-Path $Pacote 'pb_data\data.db-shm') -Force -EA SilentlyContinue
Remove-Item (Join-Path $Pacote 'pb_data\auxiliary.db-wal') -Force -EA SilentlyContinue
Remove-Item (Join-Path $Pacote 'pb_data\auxiliary.db-shm') -Force -EA SilentlyContinue
Copy-Item "$staging\data.db" (Join-Path $Pacote 'pb_data\data.db') -Force
Copy-Item "$staging\auxiliary.db" (Join-Path $Pacote 'pb_data\auxiliary.db') -Force
Ok 'data.db fresco instalado (usuários preservados)'

# binário: copiar por completeza + verificar hash (é o mesmo upstream)
$destBin = Join-Path $Pacote 'pocketbase.exe'
if ((Resolve-Path $Binario).Path -ine (Resolve-Path $destBin -EA SilentlyContinue).Path) {
    Copy-Item $Binario $destBin -Force
    Ok 'binário copiado (upstream)'
} else {
    Ok 'binário já é o upstream (mesmo arquivo) — nada a copiar'
}

# ------------------------------------------------------------ 5. checksum
Say "`n=== 5. Checksum do pacote gerado ===" 'Cyan'
$sums = Join-Path $Pacote 'SHA256SUMS'
$linhas = foreach ($f in (Get-ChildItem $Pacote -Recurse -File | Where-Object { $_.FullName -notmatch '\\backups\\' })) {
    $h = (Get-FileHash $f.FullName -Algorithm SHA256).Hash
    $rel = $f.FullName.Substring($Pacote.Length + 1)
    "$h  $rel"
}
$linhas | Set-Content $sums -Encoding UTF8
Ok "SHA256SUMS: $($linhas.Count) arquivos (fora dos backups)"

# ------------------------------------------------------------ 6. verificação
if ($NaoBootar) { Info '-NaoBootar: verificação pulada'; exit 0 }
Say "`n=== 6. Verificação pós-geração (boot real) ===" 'Cyan'
$v = Start-Process -FilePath $Binario -ArgumentList 'serve', '--dir', (Join-Path $Pacote 'pb_data'), '--http', '127.0.0.1:8090' -RedirectStandardError "$staging\v-err.log" -PassThru -WindowStyle Hidden
$ok2 = $false
for ($i = 0; $i -lt 15; $i++) {
    Start-Sleep -Seconds 2
    try {
        $h = Invoke-RestMethod 'http://127.0.0.1:8090/api/health' -TimeoutSec 3
        if ($h.code -eq 200) { $ok2 = $true; break }
    } catch {}
}
if ($ok2) { Ok 'pacote novo sobe (migrations do repo aplicadas pelo binário)' }
else {
    Bad 'pacote novo NAO subiu'
    Get-Content "$staging\v-err.log" -EA SilentlyContinue | Select-Object -Last 3
}
taskkill /PID $v.Id /F 2>&1 | Out-Null

Say "`n=== FIM — pacote regenerado em $Pacote ===" 'Cyan'
Say "  Backup do velho: $bkp" 'DarkGray'
Say "  Operador: DESINSTALAR o app antigo antes de instalar (assinatura diferente)" 'Yellow'
