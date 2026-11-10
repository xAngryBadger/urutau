# Bateria adversária — handshake de segurança (card `fce4063d-4037-4e2e-b2e0-86e7f5ba848e`)

Data: 2026-11-10. Alvo: app Urutau (`D:\projetos\urutau`), servidor PocketBase 0.36.4 fresco em `127.0.0.1:8093` (`--dir=D:\urutau-devtools\pb-adv`, migrations de `servidorbadger/pb_migrations`), emulador `emulator-5554` (adbd root). Cada buraco tem: comando, saída colada, PASS/FAIL.

Resultado global: **buraco 1 PASS (66/66 ao vivo + guarda 15/15)**, **buraco 2 PASS (14/14 ao vivo)**, **buraco 3 PASS no round-trip (6/6) com 2 ACHADOS novos (F-3a, F-3b) que viram tasks de fix separadas**.

---

## §1 — BURACO 1: injecção de filtro (`filter:` do PocketBase)

**Hipótese a matar:** um nome de UT/propriedade com `||`, `&&`, parênteses, aspas etc. no `filter:` muda o significado da query e devolve todos os registos.

### 1a. Guarda de regressão (código) — `test/filtro_injecao_test.dart`

O teste antigo do capitão tinha a premissa errada (afirmava que havia injecção). Foi convertido em **guarda** que usa o escape REAL exportado (`escapePbFilter`, `sync_service.dart:44` — barra escapada antes da aspa):

```
$ flutter test test/filtro_injecao_test.dart
00:00 +15: All tests passed!
```

Para cada valor hostil (`UT-90 || 1=1`, `&&`, `") || true || ("`, `(`, `!=`, `>`, `UT-90\`, `UT-90\"`, `UT-90"`, newline+`||`, unicode, nome literal `P1 - UT1 || 1=1`) a guarda afirma: (a) zero operadores lógicos fora das strings além do `&&` próprio da condição, (b) cada string literal do filtro, desfeita o escape, é **exactly** o valor original (round-trip). Commit `457e622`.

### 1b. Prova ao vivo contra o servidor — `D:\urutau-devtools\probe-adv1.ps1`

Setup: superuser `admin@urutau.local`, utilizadores A e B, 4 parcelas no servidor (listRule de `parcelas` é `@request.auth.id != ""` — qualquer autenticado lista tudo, por isso vazamento = dados de outros utilizadores). Comando:

```
pwsh -NoProfile -File D:\urutau-devtools\probe-adv1.ps1     # base http://127.0.0.1:8093
```

Para cada ataque, o filtro foi montado **das duas formas**: como o app monta hoje em `sync_service.dart:1435` (escape inline só de aspas) e com o escape forte `escapePbFilter`, usando o token de B (outro utilizador):

```
GET /api/collections/parcelas/records?perPage=100&filter=(prop_ut = "<valor escapado>" && id_parcela = 90)
```

Saída (resumo; completo em `probe-adv1-out.txt`):

```
há 4 parcelas no servidor (base)                            totalItems=4   PASS
ataque 1  [UT-90 || 1=1]              INLINE totalItems=0  FORTE totalItems=0   PASS
ataque 2  [UT-90 && 1=1]              INLINE totalItems=0  FORTE totalItems=0   PASS
ataque 3  [UT-90") || true || ("]     INLINE totalItems=0  FORTE totalItems=0   PASS
ataque 4  [(UT-90]                    INLINE totalItems=0  FORTE totalItems=0   PASS
ataque 5  [UT-90 != x]                INLINE totalItems=0  FORTE totalItems=0   PASS
ataque 6  [UT-90 > x]                 INLINE totalItems=0  FORTE totalItems=0   PASS
ataque 7  [UT-90\]                    INLINE HTTP 400      FORTE HTTP 400      PASS (filtro malformado -> 400 limpo, sem vazar)
ataque 8  [UT-90\"]                   INLINE totalItems=0  FORTE totalItems=0   PASS
ataque 9  [UT-90"]                    INLINE totalItems=0  FORTE totalItems=0   PASS
ataque 10 [UT-90\n|| 1=1]             INLINE totalItems=0  FORTE totalItems=0   PASS
ataque 11 [UT-90 || id_parcela > 0]   INLINE totalItems=0  FORTE totalItems=0   PASS
ataque 12 [UT-90 é ✨]                INLINE totalItems=0  FORTE totalItems=0   PASS
ataque 13 [P1 - UT1 || 1=1] (nome real) INLINE totalItems=1 certos=1  FORTE totalItems=1  PASS
nome literal com || devolve exactamente 1 (o certo)         totalItems=1       PASS
TOTAL: 66 checks | PASS: 66 | FALHAS: 0
```

**Veredicto §1: PASS.** Nenhum ataque devolve "todos" — no máximo 0, ou exactamente o registo cujo nome é literalmente o ataque. Filtro malformado (barra no fim) dá 400 limpo, não 500 nem vazamento.

Nota de auditoria (sem buraco hoje): além do sítio escapado, há filtros montados com valores não controlados pelo utilizador ou validados pelo servidor — `entry_hash = '${e.entryHash}'` (:169, hash hex), `user != ""` (:1354), `parcela = "${record.id}"` (:2009/:2195/:2279, id de registo do servidor), `email = "$email"` (:2359/:2400/:2446, e-mail validado pelo PB — não aceita aspas), `user = "$uid"` (:2413, id). Nenhum recebe texto livre de utilizador sem escape; o único texto livre (`prop_ut` em :1435) provou aguentar.

---

## §2 — BURACO 2: ficheiros hostis no upload de fotos (`fotos_parcela`)

Superfície: campo `fotos_parcela` na coleção `parcelas` com `maxSize=10485760` (10 MB), `mimeTypes=[image/jpeg, image/png, image/webp]`, `maxSelect=10` (migration `1776864000_updated_rules_and_limits.js`). No emulador atual o banco está vazio (`fotos_parcela = 0`), por isso a superfície foi exercida direto no servidor, exactamente como o app sobe (`sync_service.dart:1972-1988`, multipart `PATCH /api/collections/parcelas/records/{id}` com `-F fotos_parcela=@file;filename=...` — o PATCH precisa de `status_verificacao` no body por causa do updateRule).

Comando: `pwsh -NoProfile -File D:\urutau-devtools\probe-adv2.ps1` (gera os ficheiros em `D:\urutau-devtools\hostis`, sobe via `curl.exe -F`, e depois de cada caso lê o registo para contar `fotos_parcela`).

Saída (resumo; completo em `probe-adv2-out.txt`):

```
controle positivo jpeg 2KB                HTTP 200 | fotos na parcela depois: 1   PASS
jpeg 9MB (abaixo do limite 10MB)          HTTP 200 | fotos depois: 1                PASS
jpeg 11MB (acima do limite)               HTTP 400 validation_file_size_limit  PASS
500MB com magic de jpeg                   HTTP 413 Request entity too large    PASS
corrompido com .jpg (lixo aleatório)      HTTP 400 validation_invalid_mime_type PASS
PNG renomeado para .jpg                   HTTP 200 (mime é detetado pelo CONTEÚDO; png está na whitelist) PASS
0 bytes .jpg                              HTTP 400 validation_invalid_mime_type PASS
ZIP renomeado para .jpg                   HTTP 400 validation_invalid_mime_type PASS
nome com ../ (path traversal)             HTTP 200, gravado sanitizado (sem ../) PASS
nome unicode (foto-é✨.jpg)               HTTP 200                            PASS
nome 255 chars                            HTTP 200                            PASS
nome com newline                          HTTP 200, gravado como foto_0_aquebrada_7ymi9rwrsl.jpg (sanitizado) PASS
20 ficheiros numa parcela                 HTTP 400 (maxSelect=10 no servidor) PASS
estado do storage depois de tudo: 2 ficheiros, 2284 bytes — só o que foi aceite ficou no disco
TOTAL: 14 checks | PASS: 14 | FALHAS: 0
```

Pontos medidos:
- **Tamanho:** >10 MB → 400 `validation_file_size_limit`; 500 MB → 413 no limite do pedido. Estado consistente (o registo não muda).
- **MIME por conteúdo, não por extensão:** lixo/0-bytes/ZIP com `.jpg` → 400 `validation_invalid_mime_type`; PNG renomeado `.jpg` → 200 porque `image/png` está na whitelist. Ou seja, o servidor valida o que entra, não confia na extensão.
- **Nomes:** `../`, newline, unicode e 255 chars são aceitos mas **sanitizados no storage** (sem path traversal — `nomes gravados não têm path traversal: PASS`).
- **Quantidade:** 20 ficheiros numa parcela → 400 (maxSelect=10). O limite de 10 é do servidor, não só do app.
- **Hash divergente (RC-04):** bloqueio do lado do cliente, antes do upload — `sync_service.dart:1957-1969` recalcula `sha256De` e, se não bate com o catálogo, loga `hash_divergente_upload` na auditoria e aborta o envio. O servidor não conoce o hash — essa defesa é só do app (documentado; não é buraco do servidor).

**Veredicto §2: PASS** — nenhum ficheiro hostil deixa estado inconsistente ou crash no servidor; os aceites são sanitizados; os rejeitados são 400/413 limpos. No app, `ImageService.metadadosDe` devolve sempre `mime: image/jpeg` (não fareja conteúdo — `image_service.dart:50`); quem barra o conteúdo inválido é o servidor, como provado acima.
