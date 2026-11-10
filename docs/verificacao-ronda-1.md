# Verificação independente — Ronda 1 (t3, verificador)

Data: 2026-11-10 · Emulador: emulator-5554 · Servidor: PocketBase 127.0.0.1:8090 (pid 18640, `--dir=D:\urutau-devtools\pb-sync --migrationsDir=...\pb_migrations`, superuser isaacnathandasilva@gmail.com via env PB_ADMIN_*)

Árvore git no início: limpa (`git status --short` vazio), HEAD = 1c856de.

## Resumo

| # | Check | Resultado |
|---|-------|-----------|
| 1a | flutter analyze | **PASS** — 0 erros (54 warnings, 149 infos, 203 issues) |
| 1b | flutter test | **PASS** — 150/150, "All tests passed!", exit 0 |
| 1c | flutter build apk --release | **PASS** — exit 0, app-release.apk 67.9MB |
| 2 | apksigner verify dist/urutau-2.0.1-release.apk | **PASS** — CN=Urutau Dev, SHA-256 34fd5124… |
| 3 | adb install -r + dados locais | **PASS** — Success; 74/53/1 antes → 74/53/1 depois; sessão preservada |
| 4 | sync 3× idempotente | **PASS** — servidor: parcelas 1→2→2→2, plantas 50→53→53→53, 0 ids duplicados |
| 5 | temas claro/altoContraste/kanagawa | **PASS** — 15 testes de tema passam; 0 diferenças de bounds no emulador; prints salvos |
| 6 | primeira abertura em modo avião | **PASS** — pm clear + airplane on → /home como Convidado, sem login |

## 1a — flutter analyze

Comando: `cd D:\projetos\urutau && flutter analyze` (Flutter 3.47.8)

Saída (tail, completa em [docs/_verif_analyze.txt](_verif_analyze.txt)):

```
203 issues found. (ran in 3.9s)
[exit code: 1]
```

Contagem por severidade no ficheiro de saída: `error -` = **0**, `warning -` = 54, `info -` = 149.
→ Gate "analyze 0 erros": **PASS** (exit 1 é só porque há warnings/infos; zero erros).

## 1b — flutter test

Comando: `cd D:\projetos\urutau\urutau-app && flutter test` (completo em [docs/_verif_test.txt](_verif_test.txt))

```
00:16 +150: All tests passed!
[exit code: 0]
```
→ **PASS** — 150/150.

## 1c — flutter build apk --release

Comando: `cd D:\projetos\urutau\urutau-app && flutter build apk --release` (keystore via android/key.properties; completo em [docs/_verif_build.txt](_verif_build.txt))

```
Running Gradle task 'assembleRelease'... 62,0s
√ Built build\app\outputs\flutter-apk\app-release.apk (67.9MB)
[exit code: 0]
```
→ **PASS**. pubspec `version: 2.0.1+3` → versionCode 3 (confirma B3).

## 2 — Assinatura do APK de dist/

Comando: `apksigner verify --print-certs D:\projetos\urutau\dist\urutau-2.0.1-release.apk`

```
Signer #1 certificate DN: CN=Urutau Dev, OU=Dev, O=Urutau, L=Sao Paulo, ST=SP, C=BR
Signer #1 certificate SHA-256 digest: 34fd5124b54ce13f9706dba79ac675c92e06c6c7530961ba4103b517c26577c4
Signer #1 certificate SHA-1 digest: 61ed274125bcc3b48a082dd25ed03b6eb1aa1b25
```
→ **PASS** — CN=Urutau Dev (nunca CN=Android Debug), SHA-256 idêntico ao registado na auditoria (34fd5124…).

## 3 — install -r no emulador-5554 preserva dados

Comandos:
```
adb -s emulator-5554 shell '/system/bin/sqlite3 /data/data/com.urutau.app/app_flutter/urutau.sqlite "SELECT COUNT(*) FROM parcelas; SELECT COUNT(*) FROM plantas; SELECT COUNT(*) FROM usuarios;"'   # ANTES
adb -s emulator-5554 install -r D:\projetos\urutau\dist\urutau-2.0.1-release.apk
adb -s emulator-5554 shell '...mesma query...'                                                                                                                             # DEPOIS
```

Saída:
```
ANTES:  74 / 53 / 1
install: Performing Streamed Install / Success [exit=0]
DEPOIS: 74 / 53 / 1
```

Prefs depois do install (sessão preservada):
```
<string name="flutter.server_url">http://10.0.2.2:8090</string>
<string name="flutter.current_user_uuid">fdw8ib4v9xcltnk</string>
<string name="flutter.theme_mode">claro</string>
```
App instalado: `versionCode=3 versionName=2.0.1`, assinatura `fc1b605` (a mesma chave do APK — o `install -r` só é aceite com chave idêntica, o que prova a assinatura).
App abriu direto em /home logado ("Urutau - Admin Emulador").
→ **PASS** — install -r com a chave de release preserva 74 parcelas, 53 plantas, 1 usuário e a sessão.

## 4 — Sync idempotente (3 syncs com servidor no ar)

Servidor: PocketBase já no ar em 127.0.0.1:8090 com a cmdline esperada. Superuser auth OK (`_superusers/auth-with-password`). Coleções: users, parcelas, plantas, propriedades, uts, trilha_auditoria.

Contagens no servidor (via `/api/collections/<c>/records?page=1&perPage=1`, token superuser):

| momento | parcelas | plantas | trilha_auditoria |
|---------|----------|---------|------------------|
| ANTES   | 1        | 50      | 2                |
| sync 1  | 2        | 53      | 3                |
| sync 2  | 2        | 53      | 4                |
| sync 3  | 2        | 53      | 4                |

Como foi disparado cada sync: no app (emulador), marquei 1 parcela local como `pronta_para_sync=1` (synced=0) via sqlite, abri o app, badge "1" no botão cloud → "Sincronizar dados" → diálogo "Sincronizar parcelas?" → "Enviar agora" → `syncAll()`. Snackbar: "Enviadas 1 parcela(s) concluída(s)." Para os syncs 2 e 3, voltei a por `synced=0` na MESMA parcela (uuid `pb-78mni24nr5os3mc`) e repeti — ou seja, re-push da mesma identidade.

Verificação de duplicados (sync 3): `GET /api/collections/parcelas/records?perPage=500` → 2 registos, **0 ids duplicados** (`Group-Object id` sem grupos > 1).
→ **PASS** — sync 3× não duplica no servidor; o re-push da mesma identidade faz upsert (parcelas estaciona em 2, plantas em 53). A trilha_auditoria cresce por desenho (é um log), não é duplicação de dados de negócio.

RETRATAÇÃO (verificador, após o desafio do capitão — confirmado com comandos): a menção anterior a "74→72 no pull" era **artefacto de medição meu**, não perda de dados. O "72" foi lido numa cópia restaurada do DB durante o teste de modo avião (ficheiro guest de 446464 bytes, antes do segundo `cp` do backup), comparando estados diferentes. No DB live atual (pós-sync, pós-restore): `SELECT COUNT(*) FROM parcelas` = **74** (72 com `user_id=''` — as seed-* de fábrica, sem dono — + 2 com `user_id='fdw8ib4v9xcltnk'`), `deleted_at IS NOT NULL` = 0, `COUNT(DISTINCT uuid)` = 74, e `trilha_auditoria` só tem `sync_push`/`update` — **nenhuma ação de delete/purge**. Nada se perdeu no pull; o check 3 (install -r) mediu 74→74 no DB live.

## 5 — Temas: layout idêntico nos 3 temas

Testes: `flutter test test/hc_spacing_test.dart test/theme_legibilidade_test.dart test/theme_contrast_test.dart`
```
00:00 +10: hc_spacing_test.dart: trocar de tema não muda o layout (os três)
...
00:00 +15: All tests passed!
```
→ **PASS** (hc_spacing + contraste sem fuga + legibilidade 4.5:1).

Prints no emulador (tema trocado via pref `flutter.theme_mode` + restart, home screen):
- [evidencias-emulador/tema-claro.png](evidencias-emulador/tema-claro.png) — claro (verde claro)
- [evidencias-emulador/tema-altoContraste.png](evidencias-emulador/tema-altoContraste.png) — preto/amarelo AA
- [evidencias-emulador/tema-kanagawa.png](evidencias-emulador/tema-kanagawa.png) — kanagawa escuro

Dumps uiautomator por tema: [evidencias-emulador/ui_theme_claro.xml](evidencias-emulador/ui_theme_claro.xml), [ui_theme_altoContraste.xml](evidencias-emulador/ui_theme_altoContraste.xml), [ui_theme_kanagawa.xml](evidencias-emulador/ui_theme_kanagawa.xml).
Comparação automática (desc→bounds/clickable de todos os nós visíveis da home, texto do relógio da sync normalizado):
```
claro: 11 elementos | altoContraste: 11 | kanagawa: 11
TOTAL DE DIFERENCAS DE LAYOUT (bounds/click): 0
```
→ **PASS** — as cores mudam (prints provam que o tema aplicou), as métricas de layout são idênticas (0 diffs).

## 6 — Primeira abertura em modo avião → /home sem login

Comandos:
```
adb -s emulator-5554 shell 'settings put global airplane_mode_on 1; svc wifi disable; svc data disable; am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true'
adb -s emulator-5554 shell 'settings get global airplane_mode_on'   # → 1
adb -s emulator-5554 shell pm clear com.urutau.app                  # → Success (primeira abertura)
adb -s emulator-5554 shell am start -n com.urutau.app/.MainActivity
```

UI resultante (uiautomator): título `Urutau - Convidado / Convidado / Nunca sincronizado`, lista de parcelas seed do convidado (UT01, UT05, UT03, UT06…), FAB "Nova Parcela" — **está em /home, sem ecrã de login**.
Print: [evidencias-emulador/modo-aviao-primeira-abertura.png](evidencias-emulador/modo-aviao-primeira-abertura.png)
→ **PASS**.

(Pós-teste: avião desligado, backup do DB/prefs restaurado, app relogado como admin@urutau.local → home "Admin Emulador". O `pm clear` apagou o keystore Android do emulador — efeito colateral esperado do teste de primeira abertura.)

## Achados laterais (não bloqueiam esta ronda)

1. **dist/ contém também o APK antigo** `urutau-2.0.0-release.apk` (71.2 MB, 09/11 14:09) ao lado do `urutau-2.0.1-release.apk` correcto. O APK de distribuição correcto está lá e assinado certo; o antigo pode confundir — candidato a remover na ronda 2.
2. **RETRATADO** — a suspeita de "pull reduziu parcelas locais de 74 → 72" era artefacto de medição do verificador (leu 72 numa cópia restaurada do DB durante o teste de modo avião, não no DB live). DB live pós-sync: 74 parcelas (72 seed com `user_id=''` + 2 do admin), 0 deleted, trilha só com `sync_push`/`update`. Nada perdido. Ver a RETRATAÇÃO na secção 4.
3. analyze com 54 warnings / 149 infos (0 erros) — dentro do gate, mas a limpeza pode entrar na ronda 2.

## Comandos corridos (resumo)

- `git status --short` / `git log --oneline -8` — árvore limpa, HEAD 1c856de
- `flutter analyze` (D:\projetos\urutau) — 0 erros
- `flutter test` (urutau-app) — 150/150
- `flutter build apk --release` (urutau-app) — exit 0, 67.9MB
- `apksigner verify --print-certs dist\urutau-2.0.1-release.apk` — CN=Urutau Dev
- `adb -s emulator-5554 install -r dist\urutau-2.0.1-release.apk` — Success
- `sqlite3 urutau.sqlite "SELECT COUNT(*)..."` antes/depois — 74/53/1 → 74/53/1
- 3× sync via UI do app + `GET /api/collections/*/records` no PocketBase — sem duplicados
- `flutter test test/hc_spacing_test.dart test/theme_legibilidade_test.dart test/theme_contrast_test.dart` — 15/15
- troca de tema no emulador + `uiautomator dump` + `screencap` ×3 — 0 diffs de layout
- `pm clear` + airplane mode + `am start` — /home Convidado sem login
