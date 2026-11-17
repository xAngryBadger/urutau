<#
.SYNOPSIS
    bootstrap-primeiro-admin.ps1 — nasce o PRIMEIRO admin do Urutau no PocketBase.

.DESCRIPTION
    A migration 1778300000 (Q4) fecha as regras com @request.auth.isAdmin,
    mas todo usuário nasce com isAdmin=false (default da 1778250000). Sem
    ninguém true, o promote/demote do app (syncAdminFlagToServer) não tem
    de onde partir — a admin screen morre com fome de superuser.

    Este script promove UM usuário conhecido via API de superuser do
    PocketBase (bypassa collection rules — só o superuser pode). É o
    caminho exato do bootstrap, documentado no README do patch-s3-hash.

.PARAMETER PbUrl
    URL base do PocketBase. Default: http://127.0.0.1:8090

.PARAMETER SuperuserEmail
    Email do superuser (admin do painel). Criado com:
      pocketbase superuser upsert EMAIL SENHA
    ou no prompt do primeiro boot.

.PARAMETER SuperuserPassword
    Senha do superuser.

.PARAMETER AdminEmail
    Email do usuário do app (collection users) a promover.

.PARAMETER ListUsers
    Só lista os usuários (não promove).

.EXAMPLE
    . D:\urutau-devtools\env-workstation.ps1
    pwsh -File D:\urutau-devtools\pb-test\bootstrap-primeiro-admin.ps1 `
      -SuperuserEmail admin@urutau.local -SuperuserPassword 'TROQUE' `
      -AdminEmail coletor1@urutau.local

.OUTPUTS
    Exit 0 = admin promovido (ou listado) · Exit 1 = falha
#>
[CmdletBinding()]
param(
    [string]$PbUrl = 'http://127.0.0.1:8090',
    [string]$SuperuserEmail,
    [string]$SuperuserPassword,
    [string]$AdminEmail,
    [switch]$ListUsers
)

$ErrorActionPreference = 'Stop'

function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }

# ------------------------------------------------------------ 1. superuser
if (-not $SuperuserEmail -or -not $SuperuserPassword) {
    Say "ERRO: informe -SuperuserEmail e -SuperuserPassword" 'Red'
    Say "  (crie o superuser com: pocketbase superuser upsert EMAIL SENHA)" 'DarkGray'
    exit 1
}

$authBody = @{ identity = $SuperuserEmail; password = $SuperuserPassword } |
    ConvertTo-Json
try {
    $auth = Invoke-RestMethod -Uri "$PbUrl/api/admins/auth-with-password" `
        -Method Post -ContentType 'application/json' -Body $authBody
} catch {
    Say "ERRO: login de superuser falhou: $_" 'Red'
    exit 1
}
$hdrs = @{ Authorization = $auth.token }
Say "  [OK]   superuser autenticado" 'Green'

# ------------------------------------------------------------ 2. usuarios
$users = Invoke-RestMethod -Uri "$PbUrl/api/collections/users/records?perPage=200" `
    -Headers $hdrs
Say "  [..]   $($users.totalItems) usuário(s) na collection users" 'DarkGray'
$users.items | ForEach-Object {
    Say ("        {0,-38} isAdmin={1}" -f $_.email, $_.isAdmin) 'DarkGray'
}

if ($ListUsers) { exit 0 }

if (-not $AdminEmail) {
    Say "ERRO: informe -AdminEmail (usuário a promover) ou use -ListUsers" 'Red'
    exit 1
}

$alvo = $users.items | Where-Object { $_.email -eq $AdminEmail } | Select-Object -First 1
if (-not $alvo) {
    Say "ERRO: usuário '$AdminEmail' não encontrado em users" 'Red'
    exit 1
}
if ($alvo.isAdmin -eq $true) {
    Say "  [OK]   '$AdminEmail' JÁ é admin — nada a fazer" 'Green'
    exit 0
}

# ------------------------------------------------------------ 3. promover
$patchBody = @{ isAdmin = $true } | ConvertTo-Json
Invoke-RestMethod -Uri "$PbUrl/api/collections/users/records/$($alvo.id)" `
    -Method Patch -Headers $hdrs -ContentType 'application/json' -Body $patchBody |
    Out-Null

# ------------------------------------------------------------ 4. confirmar
$conf = Invoke-RestMethod -Uri "$PbUrl/api/collections/users/records/$($alvo.id)" `
    -Headers $hdrs
if ($conf.isAdmin -eq $true) {
    Say "  [OK]   '$AdminEmail' promovido a admin (isAdmin=true)" 'Green'
    Say ""
    Say "  CRITÉRIO DE ACEITE DUPLO (Q4):" 'Cyan'
    Say "  1. coletor comum NAO apaga planta de outro  -> 403" 'DarkGray'
    Say "  2. este admin PROMOVE/rebaixa outro usuario -> 200 (com o pacote," 'DarkGray'
    Say "     que nao tem pb_hooks — o teste que quebrava)" 'DarkGray'
    exit 0
} else {
    Say "ERRO: PATCH não surtiu efeito (isAdmin ainda false)" 'Red'
    exit 1
}
