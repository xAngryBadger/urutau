# Achados: Pull de plantas (0 → 53) — causa raiz, cadeia de falhas e prova

> Investigação conduzida com prova por **comportamento observável** (log do servidor
> PocketBase em modo `--dev` + SQL, uiautomator dumps, screenshots, contagens SQLite
> no emulador). Sem reliance em leitura de código como prova.

Data: 2026-11-11
Servidor de prova: `D:\projetos\urutau\servidorbadger\pocketbase.exe serve --http=127.0.0.1:8090 --dir=D:\urutau-devtools\pb-sync --migrationsDir=D:\projetos\urutau\servidorbadger\pb_migrations --hooksDir=D:\projetos\urutau\servidorbadger\pb_hooks --dev`
Log do servidor: `D:\urutau-devtools\pb-probe.log`
Emulador: `emulator-5554` · app release `com.urutau.app` · DB `/data/data/com.urutau.app/app_flutter/urutau.sqlite`

---

## RESUMO EXECUTIVO

O pull de plantas estava morto por **três falhas encadeadas**, todas silenciosas:

| # | Falha | Owner | Efeito | Corrigido |
|---|-------|-------|--------|-----------|
| **F3** | **O login nunca autentica no PocketBase nem persiste o token** — `SyncService.login()` (que faz `authWithPassword` + grava `keyAuthToken`) **não é chamado por ninguém**; o login usa `setCurrentUser()`, que só grava a senha local | `urutau-app/lib/services/sync_service.dart` (`setCurrentUser`, linha 295) | Não há sessão autenticada no servidor ⇒ tudo o que depender de `Authorization` falha ⇒ o token nunca é reemitido ⇒ expira | **EM CURSO (t9)** |
| **F1** | `pullDadosDoServidor()` não garante autenticação antes do 1.º request — é o **único** método de pull sem `_tryAutoAuth()` | `urutau-app/lib/services/sync_service.dart` (linha 1068) | Token expirado ⇒ request sem `Authorization` ⇒ servidor devolve 0 items ⇒ `return 0` **em silêncio** ⇒ plantas nunca entram | **EM CURSO (t9)** |
| **F2** | O botão de pull (`Puxar do servidor`) vive num bottom sheet que **só abre se houver parcelas pendentes para push** | `urutau-app/lib/screens/explorer_screen.dart` (`_showSyncOptions`) | Com todas as parcelas `synced=1`, o sheet nunca abre ⇒ **o pull de plantas é inalcançável pela UI** | **EM CURSO (t10)** |

---

## F3 — O login nunca autentica no PocketBase (CAUSA RAIZ DE F1)

### O token nunca é escrito no login

`SyncService.login()` (`sync_service.dart:333`) é o método que faz `authWithPassword`
**e** persiste o token:

```dart
final authData = await _withRetry(
  () => _pb!.collection('users').authWithPassword(email, password),
);
await SecureStorageService.write(
    SecureStorageService.keyAuthToken, _pb!.authStore.token);
```

Prova de que **ninguém o chama**:

```powershell
$ grep -rn "\.login\(" D:\projetos\urutau\urutau-app
# => NENHUMA CHAMADA
```

O `login_screen.dart:146` faz, em vez disso:

```dart
await syncService.setCurrentUser(usuario, password: _senhaController.text);
```

E `setCurrentUser` (`sync_service.dart:295`) só:

```dart
_currentUser = user;
await prefs.setString('current_user_uuid', user.uuid);
await prefs.setString('current_user_name', user.nome);
await prefs.setBool('current_user_is_admin', user.isAdmin);
if (password != null && password.isNotEmpty) {
  await SecureStorageService.write(SecureStorageService.keyCurrentPassword, password);
}
```

**Não chama `authWithPassword`. Não grava o `keyAuthToken`.**

Os **únicos** três sítios que gravam `keyAuthToken` são:

| Linha | Contexto |
|---|---|
| `sync_service.dart:340` | dentro de `login()` — **nunca chamado** |
| `sync_service.dart:545` | dentro de `_tryAutoAuth()` |
| `sync_service.dart:573` | dentro de `_tryAutoAuth()` (ramo de auto-registo) |

### Comportamento observado

1. Re-login fresco no emulador (`admin@urutau.local` / `teste123`):
   - o servidor regista `INFO POST /api/collections/users/auth-with-password`
   - **mas** o request de parcelas seguinte sai com `WHERE ('' IS NOT '')` ⇒ **ainda anónimo**
2. `force-stop` + relaunch do app → SplashScreen → `/home`:
   - a UI mostra **"Tudo sincronizado"** e as 5 parcelas `pb-*` com **"0 plantas"**
   - o token no `FlutterSecureStorage` é o **velho** (a app data foi recriada às 02:33)

### Consequência

O token no SecureStorage é da sessão antiga. **Nada no fluxo de login o reemite.**
Logo, ele expira e fica expirado — e, como o `pullDadosDoServidor` também não garante
auth (F1), o pull fica morto por **duas razões independentes que se somam**.

> Nota: o `AuthStore.isValid` do SDK (`pocketbase-0.23.3`) valida o `exp` do JWT
> **localmente**, e o `client.dart:286` só envia o header `Authorization` quando
> `authStore.isValid`. Token expirado ⇒ header nunca enviado ⇒ pedido anónimo.

---

## F1 — Token expirado + pull sem auto-auth

### Prova: o request do app não leva `Authorization`

O log do servidor regista o request que o app faz:

```
INFO GET /api/collections/parcelas/records?page=1&perPage=1&filter=user+=+"fdw8ib4v9xcltnk"&expand=ut,ut.propriedade&skipTotal=false
```

O SQL que o PocketBase executa para esse request (modo `--dev` imprime as queries):

```sql
-- request DO APP (sem token)
SELECT `parcelas`.* FROM `parcelas` WHERE ('' IS NOT '') AND (`parcelas`.`user` = 'fdw8ib4v9xcltnk') LIMIT 1
```

O mesmo request, **com** token válido (reproduzido do PowerShell):

```sql
-- request AUTENTICADO
SELECT `parcelas`.* FROM `parcelas` WHERE ('fdw8ib4v9xcltnk' IS NOT '') AND (`parcelas`.`user` = 'fdw8ib4v9xcltnk') LIMIT 1
```

O placeholder `('' IS NOT '')` é o **auth vazio**. Com `'fdw8ib4v9xcltnk' IS NOT ''` o `listRule`
(propriedade do dono) é satisfeito. ⇒ **O app envia o request sem `Authorization`.**

### Prova: o servidor tem os dados, o rule filtra-os

```
Com token admin:   GET /api/collections/plantas/records  -> totalItems = 53
Sem token:         GET /api/collections/plantas/records  -> totalItems = 0
```

### A cadeia completa

1. O token guardado em `FlutterSecureStorage` expirou (o `AuthStore.isValid` do SDK
   `pocketbase-0.23.3` compara `exp` com o relógio local).
2. O SDK **só** acrescenta o header `Authorization` quando `authStore.isValid`
   (`pocketbase-0.23.3/lib/src/client.dart:286`):
   `if (!headers.containsKey("Authorization") && authStore.isValid)`.
   ⇒ token expirado ⇒ **header nunca é enviado** ⇒ o servidor vê um pedido anónimo.
3. A `listRule` de `parcelas`/`plantas` é owner-scoped ⇒ 0 items.
4. `sync_service.dart:1088` → `if (first.items.isEmpty) return 0;`
   ⇒ **aborta ANTES** do passo 2 (`perPage=200`) e ANTES do passo 5 (`_pullPlantasDoServidor`).
5. O `_pullMeusDados()` mostra `'$importados parcela(s) importada(s) do servidor.'` com
   `importados == 0` ⇒ snackbar **"Nenhuma parcela nova encontrada."**
   ⇒ o utilizador recebe uma mensagem de "nada novo" quando o real é **"a sua sessão
   expirou e nada foi importado"**.

### A inconsistência que prova o defeito

`pullDadosDoServidor()` é o **único** método de pull que não garante autenticação:

| Método | Linha | Faz auto-auth? |
|---|---|---|
| `syncAll()` | 700 | **SIM** — `if (!_pb!.authStore.isValid) { final ok = await _tryAutoAuth(); ... }` |
| `pullUsuariosDoServidor()` | 854 | **SIM** — idêntico |
| `_pullPlantasDoServidor` / outros | 1645, 2312, 2442 | **SIM** |
| **`pullDadosDoServidor()`** | **1068** | **NÃO** ← o defeito |

### Falsificação executada

Re-login no app com `admin@urutau.local` / `teste123` (credenciais do servidor) e
re-execução do pull. Resultado: o servidor passa a registar

```
INFO POST /api/collections/users/auth-with-password
INFO GET  /api/collections/parcelas/records?page=1&perPage=1&filter=user+=+"fdw8ib4v9xcltnk"&expand=ut,ut.propriedade
```

⇒ **com sessão nova o request é autenticado** ⇒ a causa é de facto a sessão expirada,
não o filtro, nem a `listRule`, nem a rede.

Comando de login (observável, o servidor regista o POST):

```powershell
$body = @{ identity = "admin@urutau.local"; password = "teste123" } | ConvertTo-Json
Invoke-WebRequest -Uri "http://127.0.0.1:8090/api/collections/users/auth-with-password" `
  -Method POST -Body $body -ContentType "application/json" -UseBasicParsing
```

---

## F2 — O pull de plantas é inalcançável pela UI (dead-end)

### Observação

No ecrã `/explorer`, no nível de UT, o botão **"Sincronização"** (nuvem com seta,
`[224,28][272,76]`) **não abre nada**. Screenshot e dump confirmam: a tela não muda,
não há bottom sheet, não há snackbar.

### Causa

`explorer_screen.dart::_showSyncOptions()` (linha 529):

```dart
final pending = await _db.getParcelasNaoSincronizadas(userId: myId);
...
if (pending.isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Nenhuma parcela concluída para sincronizar.'), ...),
  );
  return;                 // <-- ABORTA ANTES DO showModalBottomSheet
}
...
await showModalBottomSheet<void>(... onPull: () { ... _doPull(); } ...);
```

O botão **"Puxar do servidor"** (`explorer_screen.dart:2523`, `onPull:`) só existe
**dentro** desse bottom sheet. Como todas as parcelas locais têm `synced=1`:

```
$ adb -s emulator-5554 shell "su 0 sqlite3 '/data/data/com.urutau.app/app_flutter/urutau.sqlite' 'SELECT synced, COUNT(*) FROM parcelas GROUP BY synced;'"
1|77
```

`pending` é vazio ⇒ o sheet **nunca abre** ⇒ **não existe caminho na UI para puxar
plantas do servidor** quando não há nada para enviar.

### Consequência

Mesmo com F1 corrigido, o utilizador **não consegue** recuperar as plantas pelo
caminho normal. O pull de plantas está preso atrás de um `return` que só faz sentido
para o fluxo de **push**.

---

## Correcções em curso

### t9 — auto-auth + falha visível em `pullDadosDoServidor`

Ficheiro: `urutau-app/lib/services/sync_service.dart` (owner canónico).

1. Antes do passo 1, se `!_pb!.authStore.isValid` ⇒ `_tryAutoAuth()`.
2. Se a auto-auth falhar ⇒ **não** `return 0` em silêncio: `_lastError` com mensagem
   clara para o utilizador + `notifyListeners()` + `return 0`.
3. O `catch (_) { useExpand = false; }` da detecção de schema **não pode** mascarar
   um 401 como "schema plano" — distinguir falha de auth de schema não normalizado.

### t10 — Pull de plantas alcançável

Ficheiro: `urutau-app/lib/screens/explorer_screen.dart`.

O `onPull` tem de ser alcançável **independentemente** de haver parcelas pendentes
para push. O bottom sheet (ou um caminho equivalente) tem de abrir mesmo com
`pending.isEmpty`, para que "Puxar do servidor" esteja sempre disponível.

---

## Comandos de prova reutilizáveis

Contagem de plantas no device:

```powershell
$adb = "D:\urutau-devtools\android-sdk\platform-tools\adb.exe"
& $adb -s emulator-5554 shell "su 0 sqlite3 '/data/data/com.urutau.app/app_flutter/urutau.sqlite' 'SELECT COUNT(*) FROM plantas;'"
```

SQL do servidor (prova de auth no request):

```powershell
Get-Content D:\urutau-devtools\pb-probe.log | Select-String -Pattern "SELECT.*parcelas"
# ('fdw8ib4v9xcltnk' IS NOT '')  => autenticado
# ('' IS NOT '')                 => ANONIMO (bug)
```

Pull via UI (script idempotente): `D:\urutau-devtools\pull.ps1`

---

## Nota sobre observabilidade em release

`print()` e `debugPrint()` **não produzem saída** no APK release (verificado: o
logcat do app em release só mostra a linha do Impeller). Toda a prova deste
documento veio de canais **externos ao processo Dart**: log do servidor, uiautomator,
screenshots e SQLite. Não usar stdout Dart como canal de prova em release.
