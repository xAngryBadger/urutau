# Phase 1 Changes — Urutau OFFLINE_REWORK (SQLite Hardening)

## Status: APPROVED

## Verification Matrix

| Task | Checkpoint | Result |
|------|-----------|--------|
| 1: WAL+Pragmas | 3 pragmas present at beforeOpen | PASS |
| 1: WAL+Pragmas | Pragmas BEFORE _garantirAdminSeNecessario and _seedCatalogoEstatico | PASS |
| 2: Transactions | `BEGIN TRANSACTION` / `COMMIT` / `ROLLBACK` in database.dart = 0 hits | PASS |
| 2: Transactions | All 8 no-tx methods wrapped | PASS |
| 2: Transactions | All 4 raw-SQL→Drift methods converted, no try/catch/rollback | PASS |
| 2: Transactions | logAudit() inside transaction for softDeleteParcela and restaurarParcela | PASS |
| 3: Integrity check | Runs both PRAGMA integrity_check and PRAGMA foreign_key_check | PASS |
| 3: Integrity check | Called AFTER runPendingRestore() and _migratePlaintextPasswords | PASS |
| 3: Integrity check | Error passed to UrutauApp | PASS |
| 3: Integrity check | UrutauApp short-circuits to IntegrityErrorScreen | PASS |
| 3: Integrity check | Restore + reset options in error screen | PASS |
| 4: compressedPath | Zero refs in lib/ (excluding .g.dart and migration DROP COLUMN) | PASS |
| 4: compressedPath | Schema version = 16 | PASS |
| 4: compressedPath | `if (from < 16)` migration with DROP COLUMN | PASS |

## Changes by Task

### Task 1: WAL + Pragmas
**File:** `lib/data/database.dart:177-180`
**Change:** Added 3 `customStatement` PRAGMA calls inside `beforeOpen` callback:
- `PRAGMA journal_mode = WAL`
- `PRAGMA foreign_keys = ON`
- `PRAGMA synchronous = NORMAL`

### Task 2: Transaction wrapping (12 methods)
**File:** `lib/data/database.dart`

8 methods that had NO transaction — now wrapped in `await transaction(() async { ... })`:
| Method | Risk if wrong |
|--------|---------------|
| `_migrarSenhasParaHash` | Password migration partial |
| `_migrarPropriedadeDeProput` | Property migration partial |
| `_seedCatalogoEstatico` | Incomplete seed catalog |
| `_limparDadosOrfaos` | Partial orphan cleanup |
| `deleteUsuarioComDados` | User deleted but parcelas remain |
| `deleteAllSyncedParcelas` | Some synced parcelas deleted, others not |
| `limparTodosDadosExcetoAdmin` | Partial data wipe |
| `purgarDeletados` | Partial purge |

4 methods converted from raw SQL `BEGIN/COMMIT/ROLLBACK` to Drift `transaction()`:
| Method | Key detail |
|--------|-----------|
| `remapUsuarioUuid` | Removed try/catch/rollback — Drift auto-rollbacks |
| `remapParcelaUuid` | Same |
| `softDeleteParcela` | `logAudit()` moved INSIDE transaction (was outside before) |
| `restaurarParcela` | Same — `logAudit()` moved inside |

### Task 3: Startup integrity check
**Files changed:**
- `lib/data/database.dart` — new `checkIntegrity()` method (end of file)
- `lib/main.dart` — call after DB open, before `runApp`; passes error to `UrutauApp`
- `lib/screens/integrity_error_screen.dart` — **NEW FILE**

**Logic:**
1. `main()` calls `await db.checkIntegrity()` after `_migratePlaintextPasswords`
2. If `!result.ok` → `integrityError` string passed to `UrutauApp`
3. `UrutauApp.build()` short-circuits to `IntegrityErrorScreen` if error present
4. `IntegrityErrorScreen` offers: file-picker restore or reset — both exit(0) after staging, OS relaunches the app

### Task 4: Remove dead compressedPath column
**Schema version:** 15 → 16

**Files changed:**
- `lib/data/database.dart` — removed column from `FotosParcela` table class; added `from < 16` migration (`ALTER TABLE fotos_parcela DROP COLUMN compressed_path`)
- `lib/services/sync_service.dart` — 2 replacements: `foto.compressedPath ?? foto.filePath` → `foto.filePath`; removed conditional compress-on-demand branch (now always compresses via `ImageService.compressImage`)
- `lib/services/export_service.dart` — 1 replacement
- `lib/screens/admin_screen.dart` — 2 replacements
- `lib/data/database.g.dart` — regenerated via `dart run build_runner build`

## Post-Audit Fix
`IntegrityErrorScreen` — after restore or reset, app now calls `exit(0)` after a 2-second SnackBar, allowing OS to relaunch the app with the restored/reset state. Previously left user stranded on the error screen.

## What was NOT touched (scope discipline)
- `onUpgrade` method — Drift wraps it internally
- `image_service.dart` — `cleanCompressedPhotos()` and `compressImage()` kept (still needed for sync)
- Phase 2-5 tasks — untouched
- Pre-existing warnings in `sync_service.dart` (deprecated `expand`, null comparisons) — not in scope
- `_migrarSenhasParaHash` silent catch — pre-existing, not introduced by Phase 1

## Known Tradeoffs
1. `ALTER TABLE DROP COLUMN` requires SQLite 3.35.0+ — Flutter bundles 3.39+, safe
2. Integrity check is async — slight startup delay, but <500ms on typical DB
3. `synchronous = NORMAL` (not FULL) — intentional for field-app speed; FULL would add ~2x fsync latency per write
4. `_seedCatalogoEstatico` nested transaction (savepoint) inside `beforeOpen` — safe, Drift handles nesting correctly
5. `exit(0)` for app restart after restore/reset — cleanest option on Android; OS relaunches the activity

## Build status
- `flutter analyze`: 0 errors, 60 warnings/infos (all pre-existing)
- `build_runner build`: succeeded, 55 outputs written
