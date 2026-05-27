# Verificar servidor PocketBase — plantas com "só categoria"

O app envia plantas em dois fluxos:

- **Normal:** `altura_cm` > 0, `dap_cm` opcional, `categoria` calculada.
- **Só categoria:** `altura_cm: 0`, `dap_cm: null`, `categoria: 1|2|3` (manual).

Para o servidor aceitar o segundo caso, a coleção `plantas` deve permitir `altura_cm = 0` e `dap_cm` vazio/null.

---

## 1. Verificar no Dashboard PocketBase

1. Abre o Dashboard: **<https://REDACTED.ngrok-free.dev/_/>** (ou <http://localhost:8090/_/>)
2. Faz login (admin).
3. Vai a **Collections** → **plantas** → **API preview** (ou **Settings** da coleção).
4. Confirma o schema:
   - **altura_cm** — tipo Number; se tiver "Required" (obrigatório), pode bloquear em alguns casos. O app envia sempre um número (0 ou positivo), por isso está ok.
   - **dap_cm** — deve ser **opcional** (não required) para aceitar plantas "só categoria", onde enviamos `null`.
   - **categoria** — tipo Number, valores 1, 2 ou 3.
5. Em **API Rules** da coleção `plantas`:
   - Regra de **create**: se existir validação que exija `altura_cm > 0` ou `dap_cm` preenchido, remove ou altera para permitir `altura_cm = 0` e `dap_cm` vazio quando `categoria` está preenchido.

---

## 2. Testar com script (PowerShell)

Guarda o bloco abaixo num ficheiro, por exemplo `test_planta_categoria.ps1`, na pasta do projeto. **Substitui** `SEU_EMAIL`, `SUA_SENHA` e, se necessário, a URL do servidor. Depois executa no PowerShell:

```powershell
# Configuração — altera para o teu servidor e credenciais
$baseUrl = "https://REDACTED.ngrok-free.dev"
$email = "SEU_EMAIL"
$password = "SUA_SENHA"

# Header para ngrok (evitar aviso no browser)
$headers = @{
  "ngrok-skip-browser-warning" = "true"
  "Content-Type" = "application/json"
}

# 1) Login e obter token
$authBody = @{ identity = $email; password = $password } | ConvertTo-Json
$auth = Invoke-RestMethod -Uri "$baseUrl/api/collections/users/auth-with-password" -Method Post -Body $authBody -Headers $headers
$token = $auth.token

# 2) Obter um ID de parcela existente (para associar a planta)
$parcelas = Invoke-RestMethod -Uri "$baseUrl/api/collections/parcelas/records?perPage=1" -Headers @{ "Authorization" = "Bearer $token"; "ngrok-skip-browser-warning" = "true" }
$parcelaId = $parcelas.items[0].id
if (-not $parcelaId) { Write-Host "Erro: nenhuma parcela no servidor. Cria uma parcela primeiro."; exit 1 }

# 3) Criar uma planta "só categoria" (altura 0, dap null, categoria 1)
$plantaBody = @{
  parcela = $parcelaId
  especie = "Teste categoria manual"
  altura_cm = 0
  dap_cm = $null
  categoria = 1
  created_at = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
} | ConvertTo-Json

$createHeaders = @{
  "Authorization" = "Bearer $token"
  "ngrok-skip-browser-warning" = "true"
  "Content-Type" = "application/json"
}
try {
  $result = Invoke-RestMethod -Uri "$baseUrl/api/collections/plantas/records" -Method Post -Body $plantaBody -Headers $createHeaders
  Write-Host "OK: Planta criada com id $($result.id) (só categoria: altura=0, dap=null, categoria=1)"
} catch {
  Write-Host "FALHOU: O servidor rejeitou a planta. Detalhes:"
  Write-Host $_.Exception.Message
  if ($_.ErrorDetails.Message) { Write-Host $_.ErrorDetails.Message }
}
```

- Se aparecer **OK**, o servidor está a aceitar plantas "só categoria".
- Se aparecer **FALHOU**, lê a mensagem de erro (por exemplo "validation failed") e ajusta o schema/regras da coleção `plantas` no Dashboard como no ponto 1.

---

## 3. Testar pelo app

1. No app (telefone ou emulador), configura o servidor com:
   - **URL:** `https://REDACTED.ngrok-free.dev`
   - Login com o mesmo utilizador do PocketBase.
2. Cria ou abre uma parcela, adiciona uma planta:
   - Marca **"Quero apenas selecionar a categoria"**.
   - Escolhe categoria 1, 2 ou 3.
   - Preenche espécie e guarda.
3. Sincroniza (envia ao servidor).
4. Se a sincronização concluir sem erro, o servidor aceitou. Se der erro de "planta" ou "validation", volta ao Dashboard e confirma schema/regras da coleção `plantas` (passo 1).

---

## Resumo

| Onde verificar | O que garantir |
|----------------|----------------|
| Dashboard → coleção **plantas** | `dap_cm` opcional; sem regra que exija altura > 0 ou dap preenchido. |
| Script PowerShell | Correr com a tua URL e credenciais; deve imprimir "OK". |
| App | Fluxo "só categoria" + sync sem erro. |

Não partilhes este ficheiro com senhas preenchidas; usa variáveis de ambiente ou substitui manualmente ao testar.
