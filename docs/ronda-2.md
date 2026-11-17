# Auditoria ronda 2 — o que ainda falta para LISO (t6)

- **Autor:** auditor (team urutau-liso), read-only. Nenhum ficheiro de código alterado.
- **HEAD auditado:** `d95ffc8` (origin/main). `git status --porcelain` → apenas `?? docs/servidor-auditoria.md` (doc da t12, à espera de commit atómico do capitão — ver N2).
- **Data:** 2026-11-10.

## 1. Gates corridos agora (logs em `D:\urutau-devtools\logs\t6-*.log`)

| Gate | Comando | Resultado | Veredicto |
|---|---|---|---|
| analyze | `flutter analyze --no-pub` (urutau-app) | **0 erros**, 54 warnings, 149 infos (203 issues), exit 1 só por warnings | ✅ PASS |
| test | `flutter test` | **150/150 "All tests passed!"**, exit 0 | ✅ PASS |
| build | `flutter build apk --release` | exit 0, `app-release.apk` 67.9 MB (Gradle 64,6s) | ✅ PASS |
| dist | `aapt dump badging dist\urutau-2.0.1-release.apk` | `versionCode=3 versionName=2.0.1`, `com.urutau.app` | ✅ |
| assinatura dist | `apksigner verify --print-certs` | **CN=Urutau Dev**, SHA-256 `34fd5124…77c4` (nunca debug) | ✅ |
| dist vs build | CRC por entrada (python zipfile) dist vs build fresco no mesmo HEAD | entradas idênticas; **classes.dex CRC igual**; só `lib/*/libapp.so` diferem (ruído normal de rebuild nativo) | ✅ dist é o build atual |
| servidor | `GET 127.0.0.1:8090/api/health` | 200 healthy (PB segue no ar, dir pb-sync) | ✅ |
| árvore | `git status --porcelain` | 1 untracked: `docs/servidor-auditoria.md` | ⚠️ N2 |

## 2. Item a item — docs/auditoria-ronda-1.md

| Item | Estado | Evidência |
|---|---|---|
| **B1** (ficheiros fora do git) | ✅ **RESOLVIDO** | commit `32a9d33`; `git ls-files` cobre `sync_service.dart` + `1778800000…js`; status limpo |
| **B2** (dist desatualizado) | ✅ **RESOLVIDO** | `dist/` tem só `urutau-2.0.1-release.apk` (71.245.328 B); versionCode 3; CN=Urutau Dev 34fd5124; CRC prova que é o build do HEAD; t3 provou install -r no emulador (74/53/1 preservados). APK 2.0.0 antigo já removido (t4) |
| **B3** (versionCode 2) | ✅ **RESOLVIDO** | `pubspec.yaml:4` = `2.0.1+3`; aapt confirma versionCode=3 |
| **B4** (FAB "diferente entre temas") | ✅ **RETRACTADO** (falso positivo, prova em t1/t4) | sem ação |
| **B5** (~40 cores com contraste quebrado nos escuros) | ❌ **AINDA ABERTO** | grep hoje em `lib/`: **266 matches** de `Colors.<cor>[shade]`/`Color(0x…)` fora do sistema de temas; os ficheiros da lista da ronda 1 continuam com os mesmos padrões (ver §4) + ficheiros novos (main, sync_screen_pro, storage, splash, integrity_error, low_space_banner, arquivo_ausente_badge, theme_provider:103, hex 0xFF304d36 em admin/home/login/explorer). Dono: t7 |
| **B6** (blocker que a ronda 1 introduziu no banner) | ✅ **RESOLVIDO** | commit `d2196aa`; `home_screen.dart:564,615` hoje comentam o token do tema; travado por `test/theme_legibilidade_test.dart` (4.5:1 nos 3 temas, 150/150 passa) |

## 3. Item a item — t12 (servidor PocketBase, docs/servidor-auditoria.md)

Boot limpo das 30 migrations: ✅ PASS (health 200, 0 erros, ordem via `_migrations`). Mas as **regras em vigor no servidor 8090 ainda têm 4 blockers + 3 high** (provados ao vivo com probes HTTP):

| Item | Estado | Evidência (arquivo:linha) |
|---|---|---|
| t12-B1 delete de parcelas aberto a qualquer auth (`userId` relation nunca preenchida) | ❌ **ABERTO — blocker** | `1778300000…js:41-47`; app envia só texto `user` (sync_service.dart:1913,1924); probe: DELETE por não-dono → **204** |
| t12-B2 plantas editáveis/apagáveis por terceiros (`parcela_rel.userId=""`) | ❌ **ABERTO — blocker** | `1778300000:30-36`, `1778700000:1372-1377`; probe: PATCH 200 / DELETE 204 por outro user |
| t12-B3 `propriedades`/`uts` update+delete = `""` = **públicos** no PB 0.36.4 | ❌ **ABERTO — blocker** | `1776864000:41-42,50-51`; probe: anónimo PATCH 200 / DELETE 204 |
| t12-B4 `users.deleteRule=""` → anónimo apaga contas | ❌ **ABERTO — blocker** | `1776859848:7`; probe: anónimo DELETE user → 204 |
| t12-H1 auto-promoção `isAdmin` (signup público aceita campo do cliente + self-update) | ❌ **ABERTO — high** | `1778250000:33-42`, `1778300000:56`; probes: signup com isAdmin=true → 200; self-PATCH isAdmin → 200 (isAdmin=True confirmado) |
| t12-H2 `plantas.createRule=auth` sem escopo de dono | ❌ **ABERTO — high** | `1776864000:22`; probe: criar planta na parcela de outro → 200 |
| t12-H3 login bypass: fallback sem senha devolve user por email e o login sobrescreve a senha local | ❌ **ABERTO — high** | `sync_service.dart:484-496` + `login_screen.dart:86-122` (linha 111 `atualizarSenha`) |
| t12-M1..M4, L1..L4 (sem índices/UNIQUE, edge status_verificacao 404, superuser contorna append-only da trilha, list users vaza emails, bundle stale, backup local, status_parcela) | ⚠️ abertos low/medium; **L2 (bundle stale) já não existe** — `servidorbadger/windows-package` hoje só tem `regenerar-pacote.ps1` | `docs/servidor-auditoria.md` §5-§8 |
| trilha append-only vs utilizadores + índices hash | ✅ PASS | `1778800000:24-32`; probes: PATCH/DELETE → 403 (superuser contorna, M-3) |
| migrations aplicam limpas num dir novo; estilos uniformes | ✅ PASS | prova em `D:\urutau-devtools\pb-audit-t12` + log |
| contrato schema↔app↔painel (campos, required, selects, relations, `codigo` do painel) | ✅ PASS | `Parcels.jsx:482,504` → `propriedades.codigo`/`uts.codigo` required (1776862933:28-32, 1776862934:28-32) |

## 4. Novos achados desta ronda (t6)

- **N1 (low):** `urutau-app/lib/screens/login_screen.dart.backup` está **tracked no git** (`git ls-files` confirma) e contém cores hardcoded (306-317). Backup dentro do repo deve sair (remover ou gitignore).
- **N2 (processo, medium):** `docs/servidor-auditoria.md` (t12) está **untracked** — os 4 blockers de servidor existem só num ficheiro fora do git. Precisa de commit atómico antes de fechar a ronda, senão "árvore limpa" falha e os achados perdem rastreabilidade.
- **N3 (low):** analyze com 54w/149i — dentro do gate (0 erros), candidatos a limpeza (ex.: `tool/seed_pocketbase_from_csv.dart` com `!` desnecessários).
- **N4 (info):** dist vs build fresco: só os `.so` nativos diferem (rebuild noise); Dart idêntico → B2 fechado de vez.
- **N5 (info):** B5 estende-se para lá da lista original da ronda 1: `main.dart:312,322`, `sync_screen_pro.dart:957-1069`, `storage_screen.dart:78-142`, `splash_screen.dart:68`, `integrity_error_screen.dart:25,37`, `low_space_banner.dart:45-57` (fundos `red.shade100`/`amber.shade100`), `arquivo_ausente_badge.dart:19`, `theme_provider.dart:103`, e hex crus `Color(0xFF304d36)`/`0xFF5A6B5C`/`0xFFF9F5F5`-ish em `admin_screen.dart:552-1512`, `home_screen.dart:864`, `login_screen.dart:170-204`, `explorer_screen.dart:1309`. Total medido hoje: **266 usos** de cor fora do tema em `lib/`.
- **F1-F4 da revisão t4:** registados como low e sem doc próprio (F1 = commit `d2196aa` com 2 assuntos). Sem bloqueio.

## 5. Lista priorizada para a ronda 2 (t7+)

1. **Blockers de segurança no servidor** (t12-B1..B4): trocar `""` por `null`/filtro-admin em `propriedades`/`uts`/`users.delete`, e unificar o dono de parcelas (app passa a enviar `userId` relation OU deleteRule passa a usar `user`; plantas passam a usar o mesmo campo). Provas ao vivo já em `docs/servidor-auditoria.md` §4.
2. **H-1 + H-3 (segurança app/servidor):** proteger `isAdmin` com hook (create/update) e remover o fallback sem senha de `buscarUsuarioNoServidor` (sync_service.dart:484-496) + login_screen.dart:111.
3. **B5 (t7):** ~266 usos de cor hardcoded em `lib/`, ~40 com contraste quebrado nos escuros — lista file:line na §4 de `docs/auditoria-ronda-1.md` + N5 acima; padrão de troca já documentado (onSurfaceVariant / surfaceContainerHighest / error / primary) e travado por `test/theme_legibilidade_test.dart`.
4. **H-2:** `plantas.createRule` com escopo dono-via-parcela_rel.
5. **Médios:** M-1 índices/UNIQUE (parcelas: UNIQUE(user, prop_ut, id_parcela) p/ idempotência server-side), M-2 edge status_verificacao, M-4 privacidade da listagem de users, N2 commit do doc t12.
6. **Lows:** N1 (remover `.backup` do git), N3 (limpar 54w/149i), F1-F4, M-3 (superuser contorna trilha — aceitável se a verificação de hash for o controlo), t12-L1/L3/L4.

## 6. Veredicto LISO

**Ainda NÃO dá para dizer LISO.** Blockers abertos hoje: **4 no servidor** (t12-B1..B4, todos com prova ao vivo: delete cross-tenant de parcelas e plantas, update/delete públicos de propriedades/uts, delete público de users) + **B5** (~40 vazamentos de cor com contraste quebrado nos temas escuros, high). Os gates do app estão verdes (analyze 0 erros, test 150/150, build release exit 0, dist correto e assinado versionCode 3) e a ronda 1 fechou lisa; o que falta é segurança das regras do PocketBase + o resto das cores. Critério objetivo para LISO: zero blockers na lista acima implementados, gates re-corridos verdes, sync idempotente re-provado contra o servidor com as regras novas, e árvore limpa (inclui commitar `docs/servidor-auditoria.md` e este doc).
