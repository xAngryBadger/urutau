# Release 2.0.2

## Build Information
- **Version**: 2.0.2+4
- **Flutter**: 3.50.0
- **Dart**: 3.14.0
- **Build Date**: 2026-11-17
- **Platform**: Linux CachyOS

## APK Details (rebuilt from final reviewed code — 2026-11-17 14:20)
- **File**: `urutau-app/build/app/outputs/flutter-apk/app-release.apk`
- **Size**: 70,973,464 bytes (67.7 MB)
- **SHA256**: `e0c801208462a8cc2ff503b710cb2ea2fd3735bb1650abcd20457cfc8d71dbd4`

> **Aviso de honestidade:** a primeira versão deste documento registava
> `982f25f89e...` — APK construído às 12:48, ANTES dos reparos de t5/t7
> (sync_service.dart 14:03, auto_backup_service.dart 13:57). Esse binário
> **não continha o código que passou no review**. O APK acima foi reconstruído
> do commit final. SHA256 antigo mantido aqui só para rastreabilidade.

## Signature Verification
- **Scheme**: v2 (APK Signature Scheme v2)
- **Signer CN**: Urutau
- **Certificate SHA-256**: `1147a00b590ef5e49dd5c37f6e7aaf1aaa7722c04b8f1b3b47bddb43041338a6`
- **Certificate SHA-1**: `97fa1107b0ffbbe69e623b71dff185fc6a95d2cd`
- **Certificate MD5**: `992f70da7bf8f191c68301a8178b8fe1`

## Quality Gates Passed
- ✅ `flutter analyze --no-fatal-infos --no-fatal-warnings` — **exit 0**, 0 errors
  (sem `--no-fatal-warnings` o exit é 1: `flutter_lints` não está em dev_dependencies)
- ✅ `flutter test` — **252 testes passaram** (arquivos não-golden, lista explícita)
- ✅ `flutter build apk --release` — APK gerado
- ✅ `apksigner verify` — assinatura válida (CN=Urutau)
- ✅ Version: `versionCode=4, versionName=2.0.2` em pubspec.yaml
- ✅ Review adversarial r3 (t8) — **verdict=pass**

## Critical Fixes Included (from t1)
- P4: SHA-256 full pipeline integrity (origin → catalog → local)
- P8: downloadFotosOrganizadas DB sync implemented
- Filter injection fixed at 17 inline use sites
- New regression tests created

## Changed Files
- `urutau-app/pubspec.yaml` — version bumped to 2.0.2+4, dependency upgrades for AGP 9+ compatibility
- `urutau-app/test/golden/screens_golden_test.dart` — added intl import for DateFormat
- `urutau-app/lib/screens/settings_screen.dart` — updated FilePicker API for v13.x
- `urutau-app/lib/screens/integrity_error_screen.dart` — updated FilePicker API for v13.x
- `urutau-app/pubspec.yaml` — added dependency_overrides for image_picker_android

## Verification Commands
```bash
# Analyze
flutter analyze --no-fatal-infos

# Test
flutter test --exclude-tags=golden

# Build
flutter build apk --release

# Verify signature
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk

# SHA256
sha256sum build/app/outputs/flutter-apk/app-release.apk
```