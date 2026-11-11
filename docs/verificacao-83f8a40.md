# Verificação ao vivo no HEAD `83f8a40` — capitão

- **Objeto:** provas mensuráveis do estado do repo e do app neste HEAD, corridas pelo capitão em 2026-11-10 (21:30–22:10 -0300).
- **HEAD:** `83f8a40` (`docs(t22): provas ao vivo da constraint UNIQUE e dos dois caminhos da migration`).
- **Ambiente:** `flutter` em `D:\urutau-devtools\flutter\bin\flutter.bat`; emulador `emulator-5554` (320×640); PocketBase 0.36.4 em `127.0.0.1:8090` com `--dir=D:\urutau-devtools\pb-sync` e `--migrationsDir=D:\projetos\urutau\servidorbadger\pb_migrations` (sobescido sem `--hooksDir` nesta rodada).
- **Método:** cada número abaixo é saída colada de comando. Nada aqui é inferido de leitura de código.

## 1. Gates em `D:\projetos\urutau\urutau-app`

| Gate | Resultado | Comando |
|---|---|---|
| `flutter analyze` | **exit 0** — 203 issues, **0 erros** (todos warnings/infos; 207 linhas de saída) | `flutter analyze` |
| `flutter test` | **182/182 — "All tests passed!"** | `flutter test` |
| `flutter build apk --release` | **exit 0** — `build\app\outputs\flutter-apk\app-release.apk`, 71 458 292 bytes (68,1 MB), 86,5 s de `assembleRelease` | `flutter build apk --release` |

Nota: `flutter analyze` emite apenas warnings (`unnecessary_non_null_assertion` em `tool/seed_pocketbase_from_csv.dart:84/88/93`); zero erros.

## 2. APK de distribuição (`dist/`)

O APK de `dist/` **não está stale** — é byte-idêntico ao build fresco deste HEAD:

| Métrica | `dist/urutau-2.0.1-release.apk` | build fresco do HEAD | Veredicto |
|---|---|---|---|
| sha256 do ficheiro | `04B476F668DFAA9319A3CD773D0715F53F2C9B94ABE83CC1383368B6ECB25155` | idem | **iguais** |
| tamanho | 71 458 292 bytes | 71 458 292 bytes | iguais |
| `lib/arm64-v8a/libapp.so` sha256 | `8EDE53C0BB9B42FC…` (9 831 304 B) | idem | iguais |
| `lib/armeabi-v7a/libapp.so` sha256 | `4BCEC4EECAD65D25…` (10 879 560 B) | idem | iguais |

Assinatura (`apksigner verify --print-certs`, build-tools 34.0.0):

```
Signer #1 certificate DN: CN=Urutau Dev, OU=Dev, O=Urutau, L=Sao Paulo, ST=SP, C=BR
Signer #1 certificate SHA-256 digest: 34fd5124b54ce13f9706dba79ac675c92e06c6c7530961ba4103b517c26577c4
Signer #1 certificate SHA-1 digest:    61ed274125bcc3b48a082dd25ed03b6eb1aa1b25
Signer #1 certificate MD5 digest:      26cbcadf9b9ded66129dc1127d10a6ef
```

`aapt2 dump badging`: `package: name='com.urutau.app' versionCode='3' versionName='2.0.1'`, `application-label:'Urutau'`, compileSdk 36.

## 3. Emulador `emulator-5554` — comportamento observado

### 3.1 Primeiro arranque, perfil convidado (sem login)

```
adb shell am start -n com.urutau.app/.MainActivity
→ home "Urutau - Convidado / Nunca sincronizado"
  5 cartões de convidado (UT01, UT05, UT03, UT06, UT03), "0 plantas / 0 fotos"
  FAB "Nova Parcela" [152,568][304,624]
```

**Sem ecrã de login.** Preferências lidas no dispositivo (`shared_prefs/FlutterSharedPreferences.xml`):

```
flutter.theme_mode                    = altoContraste
flutter.current_user_uuid             = 5f320f34-aadf-415a-9193-e6bb785b96bf
flutter.current_user_name             = Convidado
flutter.first_run_wizard_skipped      = true
flutter.auto_backup_last_version_code = 3
flutter.server_url                    = (ausente neste arranque)
```

`flutter.auto_backup_last_version_code = 3` confirma que o backup automático antes de actualizar (t19) já correu para o versionCode instalado.

### 3.2 Login como administrador contra o servidor ao vivo

Com `server_url = http://10.0.2.2:8090` e `admin@urutau.local` / `teste123`:

```
→ home "Admin Urutau / Nunca sincronizado"
  propriedades puxadas do servidor: DIMI0020 (2 UTs), DIMI0021 (1 UT),
                                    GHGH0058 (1 UT), GHGH0059 (1 UT)
```

O **pull funciona** com as migrations novas aplicadas. Autenticação confirmada pela API:

```
POST /api/collections/users/auth-with-password → 200
record.id = fdw8ib4v9xcltnk   record.isAdmin = true
```

### 3.3 Idempotência do sync (4 sincronizações repetidas)

| Momento | propriedades | uts | parcelas | plantas |
|---|---|---|---|---|
| antes | 3 | 3 | 3 | 53 |
| sync 1 | 3 | 3 | 3 | 53 |
| sync 2 | 3 | 3 | 3 | 53 |
| sync 3 | 3 | 3 | 3 | 53 |
| sync 4 | 3 | 3 | 3 | 53 |

Chaves repetidas no servidor (`prop_ut` + `id_parcela`): **0 grupos duplicados** em 3 parcelas lidas.

Donos das parcelas no servidor — as três têm `user = fdw8ib4v9xcltnk` (o id do auth) e `userId = ''`:

| id | prop_ut | id_parcela | user | userId |
|---|---|---|---|---|
| `sk6mdrkvtqcs6tz` | `UT-90` | 90 | `fdw8ib4v9xcltnk` | `''` |
| `78mni24nr5os3mc` | `UT-77` | 7 | `fdw8ib4v9xcltnk` | `''` |
| `8zron835bf2h7ih` | `Hostil - UT-99` | 99 | `fdw8ib4v9xcltnk` | `''` |

Isto é relevante para a migration `1779400000` (`parcelas.createRule = '@request.auth.id != "" && @request.body.user = @request.auth.id'`): o app envia `user` igual ao id do auth, portanto o create continua a passar.

## 4. O que ficou provado e o que não

**Provado neste HEAD (comando + saída):** gates verdes; build de release limpo; `dist/` byte-identico ao build do HEAD e bem assinado; perfil convidado arranca em `/home` sem login; login e pull contra o servidor ao vivo funcionam; sync idempotente em 4 repetições; zero chaves duplicadas no servidor; contrato de dono (`user` = auth.id) compatível com a `createRule` nova.

**Não provado por rodada do capitão:**

1. **Paridade de métrica do diálogo entre temas** — o acervo `docs/evidencias-t23/` mostra 6/17 nós diferentes no par PH1 (ver `docs/evidencias-t23-analise.md` §3.2). A ser fechado pelo time `urutau-nemotron` (tarefa t1) com medição no build actual.
2. **Caminho completo criar-parcela → push → servidor** neste HEAD — o capitão ficou a meio do wizard (propriedade `DIMI0022`, UT `UT-TESTE-PUSH`, "Parcela Teste Push", número 4242, Quadrada 900); o app recusa concluir sem planta ("Adicione pelo menos 1 planta para concluir a parcela"). Fica para a t2 do time.
3. **Modo avião** — herdado de `docs/verificacao-ronda-2.md` §6 no HEAD `c8f239d`, não revalidado aqui.
4. **Cor/contraste** — fora do alcance de dumps de `bounds`; coberto por `test/theme_legibilidade_test.dart`, `test/theme_contrast_test.dart`, `test/hc_spacing_test.dart` e pelo gate `flutter test`.
