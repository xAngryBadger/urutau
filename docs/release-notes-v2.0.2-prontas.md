# Release notes — colar em https://github.com/xAngryBadger/urutau/releases/new?tag=v2.0.2

**Tag:** v2.0.2 (já existe no origin)
**Anexo:** `urutau-app/build/app/outputs/flutter-apk/app-release.apk` (70.973.464 bytes)

---

## Urutau v2.0.2 — correções críticas de integridade, sync e backup

APK `com.urutau.app` • versionCode **4** • versionName **2.0.2**
SHA256 `e0c801208462a8cc2ff503b710cb2ea2fd3735bb1650abcd20457cfc8d71dbd4`
Assinado `CN=Urutau, OU=Dev, O=Badger` (v2)

### Corrigido

**Integridade de arquivos (SHA-256)** — nenhuma verificação de hash existia no
fluxo de fotos (captura → compressão → upload → download → backup → restore →
exportação). Agora o hash é calculado e comparado no download, com fallback
para o catálogo local `ativosBrutos`; divergência gera incidente e rejeita o ativo.

**Round-trip de fotos quebrado** — `downloadFotosOrganizadas()` exportava para
`~/Download/` sem tocar no banco local, então push → pull → re-push duplicava ou
perdia registros. Agora salva em `documents/fotos/` **e** grava em `fotosParcela`.

**Injeção de filtro PocketBase** — todos os 17 pontos de construção de `filter:`
usam `escapePbFilter()` (barra invertida antes da aspa). Teste de regressão com
13 payloads hostis cobre download, parcelas, plantas, propriedades e UT.

**Identidade de planta** — fotos de espécie usam `uuid_local` do servidor, não o
id de registro; `fotosParcela` não recebe mais entrada indevida de foto de
espécie.

**Concorrência** — `downloadFotosOrganizadas()` passa pelo `_syncLock`.

**Backup** — `buildBackupZip` com retry (3 tentativas, backoff exponencial) e
validação do manifesto **antes** de criar o `pre_restore` (evita backup órfão).

**Autor** — `autorUuid` com fallback `currentUser` → `device_uuid` → gerado.

### Verificação

- `flutter analyze --no-fatal-infos --no-fatal-warnings` — exit 0, 0 erros
- `flutter test` — 252 testes passaram
- Review adversarial independente em 3 rodadas: 10 achados → 6 achados → pass
- `apksigner verify` — válido

### Migração de host (Linux)

Build agora em CachyOS com Flutter 3.50.0 / AGP 9+. Pacotes Android atualizados
(`image_picker`, `package_info_plus`, `share_plus`, `file_picker`) e API do
`file_picker` v13 ajustada em `settings_screen.dart` e `integrity_error_screen.dart`.
`integration_test/` fica fora da análise até receber as dependências e os helpers
que ainda não existem no repo.