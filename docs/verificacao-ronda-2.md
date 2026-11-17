# Verificação independente da ronda 2 — verificador (t8)

> **SUPERSEDIDO — registo histórico da reprovação da ronda 2 no HEAD `c8f239d`.** O blocker aqui apontado (construção de release quebrada por `IconData` não-const em `image_service.dart:315`) foi fechado no commit `128e1ab`. O estado actual está medido em **[verificacao-83f8a40.md](verificacao-83f8a40.md)** (HEAD `83f8a40`) e a análise do acervo t23 em **[evidencias-t23-analise.md](evidencias-t23-analise.md)**.
>
> Afirmações deste documento que já **não** são verdade hoje, para não serem relidas como actuais:
> - "**BLOCKER — build release quebrado no HEAD**" → **fechado** em `128e1ab`; `flutter build apk --release` dá exit 0 no HEAD `83f8a40`.
> - "**BLOCKER — dist/ stale**" → **fechado**; `dist/urutau-2.0.1-release.apk` é byte-idêntico ao build fresco do HEAD `83f8a40` (sha256 `04B476F6…`).
> - as capturas `tema-kanagawa.png` / `ui_theme_kanagawa.xml` citadas na §5 **já não existem**: o tema Kanagawa foi removido por decisão do utilizador no commit `40d4062`.
> - o servidor passou a ter as migrations `1779400000` (create com dono atado ao auth) e `1779500000` (UNIQUE em `parcelas(prop_ut, id_parcela)`); a §4 foi medida antes dessas regras.

HEAD verificado: `c8f239d` (12 commits atómicos da ronda 2, a0a5b66..c8f239d). Árvore limpa (`git status --short` vazio).
Ambiente: emulator-5554 (320x640@160dpi, com.urutau.app), PocketBase em 127.0.0.1:8090 (subido por mim com `--dir=D:\urutau-devtools\pb-sync`, estava fora do ar), flutter D:\urutau-devtools\flutter.

Veredito geral: **5/6 checks PASS, 1 BLOCKER** — `flutter build apk --release` FALHA no HEAD e o APK de `dist/` está stale (build da ronda 1). A ronda 2 NÃO pode ser distribuída como está.

## 1 — Gates

### 1a. flutter analyze → PASS (0 erros)
```
flutter analyze   (exit 0)
202 issues found. (ran in 3.2s)
erros: 0 | warnings: 53 | infos: 149
```
Evidência: [docs/_verif2_analyze.txt](_verif2_analyze.txt)

### 1b. flutter test → PASS (151/151)
```
flutter test   (exit 0)
00:09 +151: All tests passed!
```
Inclui a nova guarda `test/b5_sem_fuga_cor_test.dart`. Isolamento: `flutter test test/b5_sem_fuga_cor_test.dart test/hc_spacing_test.dart test/theme_legibilidade_test.dart test/theme_contrast_test.dart` → `+16: All tests passed!`
Evidência: [docs/_verif2_test.txt](_verif2_test.txt)

### 1c. flutter build apk --release → **FAIL (BLOCKER)**
```
flutter build apk --release   (exit 1)
BUILD FAILED in 1m 8s
This application cannot tree shake icons fonts. It has non-constant instances of IconData at the following locations:
  - file:///D:/projetos/urutau/urutau-app/lib/services/image_service.dart:315:21
Target aot_android_asset_bundle failed: Error: Avoid non-constant invocations of IconData or try to build again with --no-tree-shake-icons.
FAILURE: Build failed with an exception. Execution failed for task ':app:compileFlutterBuildRelease'.
```
Causa: commit `f73c151` (B5 image_service) introduziu `Icon(IconData(0xe09a, fontFamily: 'MaterialIcons'), ...)` **não-const** em `lib/services/image_service.dart:315` (`_BrokenImagePlaceholder.build`). O tree-shake de ícones do release não aceita IconData construído em runtime → o build de distribuição quebra. É a mesma classe do B1: um rebuild limpo do HEAD falha.
Evidência: [docs/_verif2_build.txt](_verif2_build.txt)
Workaround usado só para testar o código no emulador: `flutter build apk --release --no-tree-shake-icons` → exit 0, `app-release.apk` (68.6MB). Evidência: [docs/_verif2_build_nts.txt](_verif2_build_nts.txt)

## 2 — APK de dist/ → assinatura PASS, conteúdo STALE (parte do blocker)

```
apksigner verify --print-certs dist\urutau-2.0.1-release.apk
Signer #1 certificate DN: CN=Urutau Dev, OU=Dev, O=Urutau, L=Sao Paulo, ST=SP, C=BR
Signer #1 certificate SHA-256 digest: 34fd5124b54ce13f9706dba79ac675c92e06c6c7530961ba4103b517c26577c4
aapt2 dump badging dist\urutau-2.0.1-release.apk
  → package: name='com.urutau.app' versionCode='3' versionName='2.0.1'
```
Assinatura e versão corretos, e `dist/` contém apenas o 2.0.1 (o 2.0.0 antigo foi removido). **MAS** o conteúdo Dart é o da ronda 1 — comparação de `libapp.so` (AOT) extraído dos APKs:
```
dist/urutau-2.0.1-release.apk  lib/arm64-v8a/libapp.so  sha256=2F5430EB30196D3F... (9765768 bytes)
build HEAD (--no-tree-shake)  lib/arm64-v8a/libapp.so  sha256=6E4ACB77817E2051... (9831304 bytes)
dist x86_64 libapp.so = F840671B...  vs  HEAD x86_64 = 3FBCDB2C...  → DIFERENTES
```
(classes.dex é igual porque o wrapper Kotlin não mudou; a fonte MaterialIcons difere só pelo flag --no-tree-shake-icons.) Conclusão: `dist/urutau-2.0.1-release.apk` foi buildado antes dos 12 commits da ronda 2 e, como o build limpo falha no HEAD (check 1c), não pode ser regenerado sem corrigir o IconData. **Blocker de distribuição (classe B2) reaberto.**

## 3 — install -r no emulator-5554 preserva dados → PASS

```
adb -s emulator-5554 shell sqlite3 .../urutau.sqlite "SELECT COUNT(*) FROM parcelas; plantas; usuarios;"
  antes: 74 / 53 / 1
adb -s emulator-5554 install -r dist\urutau-2.0.1-release.apk  → Success
  depois: 74 / 53 / 1   (versionCode=3, versionName=2.0.1 no dumpsys)
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-release.apk  (build HEAD, workaround)
  → Success ; depois: 74 / 53 / 1
```
Sessão (current_user_uuid=fdw8ib4v9xcltnk) preservada. Observação de ambiente: após o meu restore manual o dir `shared_prefs` estava root:root e o cold start caía no login ("Couldn't create directory for SharedPreferences" no logcat) — corrigi com `chown u0_a199` no emulador; não é bug do app.

## 4 — Sync idempotente (PocketBase no ar) → PASS

Servidor antes: parcelas=2, plantas=53, trilha_auditoria=5, 0 ids duplicados (`count_server.ps1` com auth de superuser).

Rodei sync pela UI do app (botão "Sincronizar dados" → diálogo → "Enviar agora") com `pb-78mni24nr5os3mc` recolocado como pendente (`q6.sql`) antes de cada ronda:

```
SYNC 1..4 (sessão com token expirado/sem senha no secure storage):
  logcat: "Auto-auth: sem senha armazenada" → sync anônimo → GET /parcelas/records/78mni24nr5os3mc → 404 (regra esconde o registo de anônimo) → 3 retries → erro, synced fica 0
  servidor: parcelas=2, plantas=53, trilha=5, 0 duplicados (nada duplicou, nada mudou)
re-login pela UI (senha correta) → token válido →
SYNC 5: push OK — local: pb-78mni24nr5os3mc synced 0→1, trilha_local sync_push 3→4
  servidor: parcelas=2, plantas=53, trilha=6, 0 duplicados
SYNC 6: servidor: parcelas=2, plantas=53, trilha=7, 0 duplicados
SYNC 7: servidor: parcelas=2, plantas=53, trilha=7→, 0 duplicados
```
`SELECT COUNT(*) FROM parcelas WHERE id IN (SELECT id FROM parcelas GROUP BY id HAVING COUNT(*)>1)` no servidor → 0. Local pós-syncs: 74/53/1, `deleted_at IS NOT NULL`=0, por user_id: ''=72 (seed-*), fdw8ib4v9xcltnk=2. **Idempotente: o servidor nunca duplicou; o pull não apagou nada local.** A trilha_auditoria cresce a cada sync com pendente por desenho (log append-only). Nota: o push só acontece com sessão autenticada válida — herdado da ronda 1, não é regressão da ronda 2.

## 5 — Temas: sem fuga de cor (B5) e sem diferença de layout → PASS

- Testes: `flutter test test/b5_sem_fuga_cor_test.dart test/hc_spacing_test.dart test/theme_legibilidade_test.dart test/theme_contrast_test.dart` → 16/16 pass.
- Varredura independente: `grep -r "Colors\.(red|green|blue|orange|amber|grey|...)\[" lib/` → só 3 matches, todos em **comentários** de home_screen.dart; o único uso real (`Colors.grey[50]` em theme_provider.dart:103) está dentro da própria definição do tema claro. `Color(0x...)` ocorre só em `lib/theme/app_tokens.dart`, `lib/theme/app_theme.dart` e `lib/services/theme_provider.dart` (as fontes dos tokens). Zero cores duras em screens/widgets/main.
- Emulador (build HEAD), troca via pref `flutter.theme_mode` + restart, home screen:
  - prints: [evidencias-emulador/tema-claro.png](evidencias-emulador/tema-claro.png), [tema-altoContraste.png](evidencias-emulador/tema-altoContraste.png), [tema-kanagawa.png](evidencias-emulador/tema-kanagawa.png) — kanagawa escuro legível (fundo escuro, texto claro), alto contraste preto/amarelo AA legível; nenhum vazamento claro-sobre-escuro.
  - dumps uiautomator: [ui_theme_claro.xml](evidencias-emulador/ui_theme_claro.xml), [ui_theme_altoContraste.xml](evidencias-emulador/ui_theme_altoContraste.xml), [ui_theme_kanagawa.xml](evidencias-emulador/ui_theme_kanagawa.xml)
  - comparação automática de bounds/clickable: `claro: 11 elementos | altoContraste: 11 | kanagawa: 11` → **TOTAL DE DIFERENÇAS DE LAYOUT: 0**

## 6 — Primeira abertura em modo avião → /home sem login → PASS

```
(backup limpo com app parado: urutau.sqlite 479232 bytes + prefs em /sdcard/backup_emu2/)
settings put global airplane_mode_on 1; svc wifi disable; svc data disable
pm clear com.urutau.app  → Success
am start -n com.urutau.app/.MainActivity
```
UI resultante: `Urutau - Convidado / Nunca sincronizado` + parcelas guest (UT01, UT05, UT03, UT06...) — foi direto para **/home como Convidado, sem tela de login**, offline. Print: [evidencias-emulador/modo-aviao-primeira-abertura-r2.png](evidencias-emulador/modo-aviao-primeira-abertura-r2.png). Emulador restaurado depois (74/53/1, sessão admin de volta).

## Outros itens da ronda 2 conferidos

- N1: `git ls-files | grep backup` → só `backup_rules.xml`, `backup_service.dart`, `backup_wal_test.dart` (nomes legítimos); `login_screen.dart.backup` não está mais no git. PASS.
- cfbfc1e (colisão de identidade): conferido no código — `registrarUsuarioNoServidor` agora exige `authWithPassword` verificado pelo servidor antes de adotar id existente por email; senha que não confere retorna null. Código OK (teste de auth negativo ficaria para t11, fora do escopo).

## Achados (bloqueadores primeiro)

1. **BLOCKER — build release quebrado no HEAD** `c8f239d`: `lib/services/image_service.dart:315` usa `IconData(0xe09a, fontFamily: 'MaterialIcons')` não-const dentro de `_BrokenImagePlaceholder.build` → `flutter build apk --release` exit 1 ("Avoid non-constant invocations of IconData"). Introduzido em `f73c151`. Fix esperado: `const Icon(Icons.broken_image, ...)` (ou IconData const). Até lá nenhum APK novo sai do HEAD.
2. **BLOCKER — dist/ stale**: `dist/urutau-2.0.1-release.apk` tem `libapp.so` da ronda 1 (sha256 difere do build do HEAD). Depois de corrigir o item 1, rebuild + copiar para dist/.
3. Info: sync com sessão expirada faz GET anônimo → 404 no registo → push não acontece (mas nunca duplica). Comportamento herdado; o push funciona com login válido (provado no sync 5).

## Comandos corridos (resumo)

- `git status --short`, `git log --oneline -16` — limpo, HEAD c8f239d
- `flutter analyze` — 0 erros (docs/_verif2_analyze.txt)
- `flutter test` — 151/151 (docs/_verif2_test.txt)
- `flutter build apk --release` — **exit 1** (docs/_verif2_build.txt); `--no-tree-shake-icons` — exit 0 (docs/_verif2_build_nts.txt)
- `apksigner verify --print-certs dist\urutau-2.0.1-release.apk` — CN=Urutau Dev 34fd5124...
- `aapt2 dump badging` — versionCode=3 versionName=2.0.1
- comparação sha256 de libapp.so dist vs HEAD build — diferentes
- `adb install -r` dist + HEAD build — Success, 74/53/1 antes e depois
- 7× sync via UI + `count_server.ps1` — servidor 2/53, 0 duplicados em todos
- `flutter test` dos 4 arquivos de tema/B5 — 16/16
- troca de tema ×3 + `uiautomator dump` + `screencap` — 0 diffs de layout
- airplane on + `pm clear` + `am start` — /home Convidado sem login
