# Re-verificação do HEAD 128e1ab — blocker de build fechado (t14)

HEAD verificado: `128e1ab` (fix: `const Icon(Icons.broken_image)` no placeholder, import de material.dart com `show Theme, Icons`). Árvore limpa.
Veredito: **6/6 provas PASS — blocker de build FECHADO, dist/ sincronizado com o HEAD.**

## 1 — BUILD LIMPO → PASS
```
cd urutau-app && flutter clean        (build/, .dart_tool apagados)
flutter build apk --release           → exit 0
√ Built build\app\outputs\flutter-apk\app-release.apk (68.0MB)   [177s gradle]
```
Era exactamente o que quebrava na t8 ("Avoid non-constant invocations of IconData", image_service.dart:315). Evidência: [docs/_verif14_build_clean.txt](_verif14_build_clean.txt)

## 2 — STALE: dist == build limpo → PASS
```
sha256 dist/urutau-2.0.1-release.apk                       = 82B2047F3DB450B06E3E85F258B69F0D8271EB862A266D4DBC3E806041AFE42B  (= valor do capitão)
sha256 libapp.so arm64 dentro do dist                     = FB9BB8C3CB5D65560296D6E84B5B1D05ED599FC135D4F974C057049E2298D68B  (= valor do capitão)
sha256 libapp.so arm64 do build limpo de agora (128e1ab)   = FB9BB8C3CB5D65560296D6E84B5B1D05ED599FC135D4F974C057049E2298D68B  → IGUAL
```
O dist já não está stale (na t8 o libapp.so do dist era 2F5430EB… = build da ronda 1). O APK inteiro difere byte-a-byte do build local só por metadados de assinatura/zip — o conteúdo Dart (libapp.so) é idêntico.

## 3 — Gates → PASS
```
flutter analyze  → 0 erros, 53 warnings, 149 infos (202 issues)   [docs/_verif14_analyze2.txt]
flutter test     → 00:19 +151: All tests passed!  exit 0           [docs/_verif14_test2.txt]
```
Nota: a primeira corrida de `flutter test` apanhou 2 falhas espúrias ("Asset 'shaders/ink_sparkle.frag' not found") porque corri `flutter clean` em paralelo — a clean apagou o bundle de assets a meio do teste. Re-run depois de clean+build: 151/151. Não é regressão de código.

## 4 — install -r do dist no emulator-5554 → PASS
```
antes:  SELECT COUNT(*) parcelas/plantas/usuarios = 74 / 53 / 1
adb -s emulator-5554 install -r dist\urutau-2.0.1-release.apk  → Success
depois: 74 / 53 / 1     dumpsys: versionCode=3 versionName=2.0.1
sessão (current_user_uuid=fdw8ib4v9xcltnk) preservada — cold start foi direto a /home
```

## 5 — Placeholder de imagem quebrada nos 3 temas → PASS
Injetei uma linha em `fotos_parcela` com `file_path` inexistente (`/sdcard/fotos/nao_existe_123.jpg`) na parcela UT-77 (pb-78mni24nr5os3mc), abri o formulário → Etapa 2 Fotos:
- [evidencias-emulador/placeholder-claro.png](evidencias-emulador/placeholder-claro.png) — card claro, **ícone broken_image escuro visível**, badge "arquivo ausente" por cima
- [evidencias-emulador/placeholder-altoContraste.png](evidencias-emulador/placeholder-altoContraste.png) — preto/amarelo, **ícone amarelo** (segue o tema)
- [evidencias-emulador/placeholder-kanagawa.png](evidencias-emulador/placeholder-kanagawa.png) — kanagawa escuro, **ícone azul-claro** (segue o tema)
- dumps: [ui_placeholder_claro.xml](evidencias-emulador/ui_placeholder_claro.xml), [ui_placeholder_altoContraste.xml](evidencias-emulador/ui_placeholder_altoContraste.xml), [ui_placeholder_kanagawa.xml](evidencias-emulador/ui_placeholder_kanagawa.xml)
O placeholder aparece EM CIMA do card, legível, e a cor do ícone muda com o tema (vem do IconTheme, como diz o comentário do código). Linha de teste removida depois.

## 6 — Sync idempotente (mín. 3 syncs) → PASS
```
servidor antes: parcelas=2, plantas=53, trilha=7, 0 ids duplicados
sync #1 (UI, Enviar agora): servidor 2 / 53 / 7, 0 duplicados
sync #2:                    servidor 2 / 53 / 7, 0 duplicados
sync #3:                    servidor 2 / 53 / 7, 0 duplicados
re-login fresco + sync #4 (autenticado): pb-78mni24nr5os3mc synced 0→1 (upsert),
  servidor continua 2 / 53 / 7, 0 duplicados
local após tudo: 74 parcelas / 53 plantas / 1 usuario, 0 com deleted_at
```
Info herdada da t8 (não é blocker): com token expirado o sync segue anônimo, o GET do registo dá 404 e o push não acontece — nunca duplica, mas o badge fica pendente até re-login.

## Veredito
**VERDE — 6/6.** O blocker da t8 (build release quebrado + dist stale) está fechado no HEAD 128e1ab: build limpo exit 0, dist com libapp.so idêntico ao build, gates 0 erros/151 testes, install -r preserva dados, placeholder legível nos 3 temas, sync idempotente.

## Comandos corridos (resumo)
- `flutter clean && flutter build apk --release` → exit 0 (docs/_verif14_build_clean.txt)
- sha256 do APK dist + libapp.so arm64 extraído vs build novo → iguais
- `flutter analyze` → 0 erros; `flutter test` → 151/151
- `adb install -r dist/urutau-2.0.1-release.apk` → Success, 74/53/1 preservados
- foto quebrada injetada + 3 temas (set_theme.sh + restart + etapa Fotos) → 3 screenshots
- 4× sync via UI + count_server.ps1 → 0 duplicados sempre
