# Phase 2 Changes — Urutau OFFLINE_REWORK (Photo Integrity + Backup)

## Status: APPROVED (with bug fix)

## Verification Matrix

| Task | Checkpoint | Result |
|------|-----------|--------|
| 5: Photo file deletion | `ImageService.deletePhotos()` batch helper exists | PASS |
| 5: Photo file deletion | Discard flow in `parcela_form_screen.dart` deletes `_novasFotosPaths` files | PASS |
| 5: Photo file deletion | `limparTodosDadosExcetoAdmin` calls `ImageService.deletePhotos()` BEFORE transaction | PASS |
| 5: Photo file deletion | `deleteUsuarioComDados` calls `ImageService.deletePhotos()` BEFORE transaction | PASS |
| 5: Photo file deletion | `purgarDeletados` calls `ImageService.deletePhotos()` BEFORE transaction | PASS |
| 6: ZIP backup | `archive: ^3.6.1` in pubspec.yaml | PASS |
| 6: ZIP backup | Backup creates ZIP with SQLite + fotos/ + manifest.json | PASS |
| 6: ZIP backup | Photos use `store` (no compression), DB uses deflate | PASS |
| 6: ZIP backup | Backward compat with old .sqlite format | PASS |
| 7: Safe restore | Manifest validation before restore | PASS |
| 7: Safe restore | PRAGMA integrity_check on backup DB before restore | PASS |
| 7: Safe restore | Pre-restore safety copy (`*_pre_restore`) | PASS |
| 7: Safe restore | Cleanup after successful launch | PASS |
| 8: Missing photo detection | `buildImage()` logs warning for missing files | PASS |
| 8: Missing photo detection | Settings "Verificar integridade das fotos" scan UI | PASS |
| 8: Missing photo detection | DB methods for querying/cleaning missing photo refs | PASS |

## Changes by Task

### Task 5: Photo file deletion
**File:** `lib/services/image_service.dart`
- New `deletePhotos(List<String> paths)` static batch helper — deletes files, logs failures, never throws

**File:** `lib/screens/parcela_form_screen.dart`
- Discard flow: deletes `_novasFotosPaths` files before clearing the list

**File:** `lib/data/database.dart`
- `limparTodosDadosExcetoAdmin`: calls `ImageService.deletePhotos()` BEFORE transaction
- `deleteUsuarioComDados`: calls `ImageService.deletePhotos()` BEFORE transaction
- `purgarDeletados`: calls `ImageService.deletePhotos()` BEFORE transaction

**Design decision:** File deletion runs BEFORE DB transaction so that if file ops fail, DB records survive for retry. If we deleted DB records first and file deletion failed, we'd get orphaned files with no DB references.

### Task 6: ZIP backup
**File:** `lib/services/backup_service.dart`
- Backup now creates a ZIP archive containing:
  - `urutau.sqlite` (deflate-compressed)
  - `fotos/` directory with all photo files (stored, no compression — already JPEG)
  - `manifest.json` with version, timestamp, photo count, DB size
- Backward compatible: old `.sqlite` format backups still restorable

**File:** `pubspec.yaml`
- Added `archive: ^3.6.1` (not ^4.0.0 — dependency conflict)

### Task 7: Safe restore
**File:** `lib/services/backup_service.dart`
- Restore flow:
  1. Validate manifest (version, structure)
  2. Run PRAGMA integrity_check on backup DB
  3. Create pre-restore safety copy (`*_pre_restore`)
  4. Copy backup DB over active DB
  5. Copy photos to fotos/ directory
  6. On next app launch, if `_pre_restore` exists and DB is healthy → delete it (successful launch)
  7. If DB is corrupt after restore → safety copy still available for manual recovery

### Task 8: Missing photo detection
**File:** `lib/services/image_service.dart`
- `buildImage()` now logs a warning and returns null/placeholder when the file is missing on disk

**File:** `lib/screens/settings_screen.dart`
- New "Verificar integridade das fotos" button in settings
- Scan UI shows progress, reports missing photos, offers to clean orphaned DB refs

**File:** `lib/data/database.dart`
- New DB methods for querying photo records whose files don't exist on disk
- New DB methods for cleaning (deleting) those orphaned photo refs

## Bug Fix (post-review)
3 methods (`deleteUsuarioComDados`, `limparTodosDadosExcetoAdmin`, `purgarDeletados`) had `ImageService.deletePhotos()` AFTER the DB transaction. Moved BEFORE the transaction. Rationale: if file deletion fails, DB records survive for retry.

## Known Open Items (not in scope)
- `limparTodosDadosExcetoAdmin` uses `fotoEspeciePath!` force-unwrap on nullable field — should filter nulls first (pre-existing, minor)
- Pre-existing deprecated `expand` usage in sync_service.dart — not in scope

## Build status
- `flutter analyze`: 0 errors, ~65 warnings/infos (all pre-existing)
- Schema version: 16 (unchanged from Phase 1)
