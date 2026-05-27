# ========================================================
# Script para criar automaticamente as collections
# do Monitoramento Florestal no PocketBase
# ========================================================

param(
[string]$ServerUrl = "http://localhost:8090",
[string]$AdminEmail = "",
[string]$AdminPassword = ""
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Criando Collections no PocketBase" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ---- 1. Autenticar como admin ----
Write-Host "[1/4] Autenticando como admin..." -ForegroundColor Yellow

$authBody = @{
    identity = $AdminEmail
    password = $AdminPassword
} | ConvertTo-Json

$token = $null

# Tenta PocketBase 0.23+ (superusers)
try {
    $authResult = Invoke-RestMethod -Uri "$ServerUrl/api/collections/_superusers/auth-with-password" -Method Post -Body $authBody -ContentType "application/json" -ErrorAction Stop
    $token = $authResult.token
    Write-Host "[OK] Autenticado (PB 0.23+)" -ForegroundColor Green
}
catch {
    # Tenta PocketBase antigo (admins)
    try {
        $authResult = Invoke-RestMethod -Uri "$ServerUrl/api/admins/auth-with-password" -Method Post -Body $authBody -ContentType "application/json" -ErrorAction Stop
        $token = $authResult.token
        Write-Host "[OK] Autenticado (PB legado)" -ForegroundColor Green
    }
    catch {
        Write-Host "[!] ERRO: Nao foi possivel autenticar." -ForegroundColor Red
        Write-Host "    Verifique email/senha do admin." -ForegroundColor Red
        Write-Host "    Acesse $ServerUrl/_/ para criar a conta admin primeiro." -ForegroundColor Red
        Write-Host ""
        Write-Host "    Erro: $_" -ForegroundColor Red
        pause
        exit 1
    }
}

$headers = @{
    Authorization = "Bearer $token"
}

# ---- 2. Criar collection PARCELAS ----
Write-Host "[2/4] Criando collection 'parcelas'..." -ForegroundColor Yellow

$parcelasJson = @{
    name       = "parcelas"
    type       = "base"
    schema     = @(
        @{
            name     = "prop_ut"
            type     = "text"
            required = $true
            options  = @{ min = 1; max = 500 }
        },
        @{
            name     = "id_parcela"
            type     = "number"
            required = $true
            options  = @{ min = 0; noDecimal = $true }
        },
        @{
            name     = "observacoes"
            type     = "text"
            required = $false
            options  = @{ max = 5000 }
        },
        @{
            name     = "user"
            type     = "text"
            required = $false
            options  = @{ max = 500 }
        },
        @{
            name     = "fotos_parcela"
            type     = "file"
            required = $false
            options  = @{
                maxSelect = 20
                maxSize   = 10485760
                mimeTypes = @("image/jpeg", "image/png", "image/webp")
            }
        }
    )
    listRule   = ""
    viewRule   = ""
    createRule = ""
    updateRule = ""
    deleteRule = ""
} | ConvertTo-Json -Depth 5

try {
    $result = Invoke-RestMethod -Uri "$ServerUrl/api/collections" -Method Post -Body $parcelasJson -ContentType "application/json" -Headers $headers -ErrorAction Stop
    Write-Host "[OK] Collection 'parcelas' criada com sucesso!" -ForegroundColor Green
}
catch {
    $errorMsg = $_.ToString()
    if ($errorMsg -match "already exists" -or $errorMsg -match "name is already") {
        Write-Host "[OK] Collection 'parcelas' ja existe, pulando..." -ForegroundColor DarkYellow
    }
    else {
        Write-Host "[!] Erro ao criar 'parcelas': $errorMsg" -ForegroundColor Red
    }
}

# ---- 3. Criar collection PLANTAS ----
Write-Host "[3/4] Criando collection 'plantas'..." -ForegroundColor Yellow

$plantasJson = @{
    name       = "plantas"
    type       = "base"
    schema     = @(
        @{
            name     = "parcela"
            type     = "text"
            required = $true
            options  = @{ max = 500 }
        },
        @{
            name     = "especie"
            type     = "text"
            required = $true
            options  = @{ min = 1; max = 500 }
        },
        @{
            name     = "altura_cm"
            type     = "number"
            required = $true
            options  = @{ min = 0 }
        },
        @{
            name     = "dap_cm"
            type     = "number"
            required = $false
            options  = @{ min = 0 }
        },
        @{
            name     = "categoria"
            type     = "number"
            required = $true
            options  = @{ min = 1; max = 3; noDecimal = $true }
        },
        @{
            name     = "foto_especie"
            type     = "file"
            required = $false
            options  = @{
                maxSelect = 1
                maxSize   = 10485760
                mimeTypes = @("image/jpeg", "image/png", "image/webp")
            }
        },
        @{
            name     = "created_at"
            type     = "text"
            required = $false
            options  = @{ max = 100 }
        }
    )
    listRule   = ""
    viewRule   = ""
    createRule = ""
    updateRule = ""
    deleteRule = ""
} | ConvertTo-Json -Depth 5

try {
    $result = Invoke-RestMethod -Uri "$ServerUrl/api/collections" -Method Post -Body $plantasJson -ContentType "application/json" -Headers $headers -ErrorAction Stop
    Write-Host "[OK] Collection 'plantas' criada com sucesso!" -ForegroundColor Green
}
catch {
    $errorMsg = $_.ToString()
    if ($errorMsg -match "already exists" -or $errorMsg -match "name is already") {
        Write-Host "[OK] Collection 'plantas' ja existe, pulando..." -ForegroundColor DarkYellow
    }
    else {
        Write-Host "[!] Erro ao criar 'plantas': $errorMsg" -ForegroundColor Red
    }
}

# ---- 4. Verificar collection USERS (ja existe) ----
Write-Host "[4/4] Verificando collection 'users'..." -ForegroundColor Yellow

try {
    $usersCol = Invoke-RestMethod -Uri "$ServerUrl/api/collections/users" -Method Get -Headers $headers -ErrorAction Stop
    Write-Host "[OK] Collection 'users' ja existe (auth built-in)" -ForegroundColor Green
}
catch {
    Write-Host "[!] Collection 'users' nao encontrada. Criando..." -ForegroundColor Yellow
    $usersJson = @{
        name       = "users"
        type       = "auth"
        schema     = @(
            @{
                name     = "name"
                type     = "text"
                required = $false
                options  = @{ max = 500 }
            }
        )
        listRule   = ""
        viewRule   = ""
        createRule = ""
        updateRule = ""
        deleteRule = ""
    } | ConvertTo-Json -Depth 5

    try {
        Invoke-RestMethod -Uri "$ServerUrl/api/collections" -Method Post -Body $usersJson -ContentType "application/json" -Headers $headers -ErrorAction Stop
        Write-Host "[OK] Collection 'users' criada!" -ForegroundColor Green
    }
    catch {
        Write-Host "[!] Erro ao criar 'users': $_" -ForegroundColor Red
    }
}

# ---- Resumo ----
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Setup completo!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Collections criadas:" -ForegroundColor Cyan
Write-Host "  - users    (auth - login/registro)" -ForegroundColor White
Write-Host "  - parcelas (dados das parcelas + fotos)" -ForegroundColor White
Write-Host "  - plantas  (dados das plantas + foto especie)" -ForegroundColor White
Write-Host ""
Write-Host "Painel admin: $ServerUrl/_/" -ForegroundColor Yellow
Write-Host "API health:   $ServerUrl/api/health" -ForegroundColor Yellow
Write-Host ""
pause
