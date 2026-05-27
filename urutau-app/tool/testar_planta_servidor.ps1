# Testa se o PocketBase aceita planta "só categoria" (altura=0, dap=null)
# Executa na tua maquina (PowerShell): .\tool\testar_planta_servidor.ps1

$baseUrl = "http://localhost:8090"
$email = ""
$password = ""
$headers = @{ "ngrok-skip-browser-warning" = "true"; "Content-Type" = "application/json" }

Write-Host "1. Login..."
$authBody = @{ identity = $email; password = $password } | ConvertTo-Json
try {
  $auth = Invoke-RestMethod -Uri "$baseUrl/api/collections/users/auth-with-password" -Method Post -Body $authBody -Headers $headers -TimeoutSec 15
}
catch {
  Write-Host "FALHOU login: $($_.Exception.Message)"
  exit 1
}
$token = $auth.token
Write-Host "   OK. Token obtido."

Write-Host "2. Obter uma parcela..."
$getHeaders = @{ "Authorization" = "Bearer $token"; "ngrok-skip-browser-warning" = "true" }
try {
  $parcelas = Invoke-RestMethod -Uri "$baseUrl/api/collections/parcelas/records?perPage=1" -Headers $getHeaders -TimeoutSec 15
}
catch {
  Write-Host "FALHOU listar parcelas: $($_.Exception.Message)"
  exit 1
}
$parcelaId = $parcelas.items[0].id
if (-not $parcelaId) { Write-Host "FALHOU: Nenhuma parcela no servidor."; exit 1 }
Write-Host "   OK. Parcela id: $parcelaId"

Write-Host "3. Criar planta so categoria (altura=0, dap=null, categoria=1)..."
$createdAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
# Em JSON, null deve ser enviado; PowerShell ConvertTo-Json omite null por defeito, por isso incluimos explicitamente
$plantaBody = "{`"parcela`":`"$parcelaId`",`"especie`":`"Teste cat manual`",`"altura_cm`":0,`"dap_cm`":null,`"categoria`":1,`"created_at`":`"$createdAt`"}"
$createHeaders = @{ "Authorization" = "Bearer $token"; "ngrok-skip-browser-warning" = "true"; "Content-Type" = "application/json" }
try {
  $result = Invoke-RestMethod -Uri "$baseUrl/api/collections/plantas/records" -Method Post -Body $plantaBody -Headers $createHeaders -TimeoutSec 15
  Write-Host "   OK: Planta criada com id $($result.id)"
  Write-Host ""
  Write-Host "Conclusao: O servidor ACEITA plantas so categoria. As mudancas vao funcionar."
}
catch {
  Write-Host "   FALHOU: O servidor rejeitou a planta."
  Write-Host "   Erro: $($_.Exception.Message)"
  if ($_.ErrorDetails.Message) { Write-Host "   Detalhes: $($_.ErrorDetails.Message)" }
  Write-Host ""
  Write-Host "Conclusao: Ajusta a colecao 'plantas' no Dashboard (dap_cm opcional, sem validacao que exija altura/dap)."
  exit 1
}
