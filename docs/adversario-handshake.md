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
