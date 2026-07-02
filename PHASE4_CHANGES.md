# Phase 4 Changes — Urutau OFFLINE_REWORK (Polish & Hardening)

## Status: COMPLETE

## Verification Matrix

| Task | Checkpoint | Result |
|------|-----------|--------|
| 12: Placeholder passwords | `senha: 'servidor'`/`'importado'` in lib/ → 0 hits | PASS |
| 12: Placeholder passwords | `generateServerPlaceholder()` used in sync_service x2 | PASS |
| 12: Placeholder passwords | `isServerPlaceholder()` check in `autenticarUsuario()` | PASS |
| 12: Placeholder passwords | `_migrarSenhasParaHash()` replaces 'servidor'/'importado' with SRV: placeholder | PASS |
| 12: Placeholder passwords | `PasswordService` has both new static methods | PASS |
| 13: Plantas updatedAt | Column added to Plantas table class | PASS |
| 13: Plantas updatedAt | Schema v18, migration adds column + sets from createdAt | PASS |
| 13: Plantas updatedAt | `updatePlanta()` uses `copyWith(updatedAt: Value(DateTime.now()))` | PASS |
| 13: Plantas updatedAt | `marcarPlantaSynced()` sets updatedAt | PASS |
| 13: Plantas updatedAt | `softDeleteParcela()` bulk planta update sets updatedAt | PASS |
| 13: Plantas updatedAt | `restaurarParcela()` bulk planta update sets updatedAt | PASS |
| 13: Plantas updatedAt | `cleanMissingFotoPlanta()` sets updatedAt | PASS |
| 14: GPS columns | Decision: KEEP with reserved-for-future comment | PASS |

## Changes by Task

### Task 12: Fix placeholder passwords

**File:** `lib/services/password_service.dart`
- Added `static bool isServerPlaceholder(String storedValue)` → checks `SRV:` prefix
- Added `static String generateServerPlaceholder()` → returns `'SRV:' + hashPassword(randomValue)` where randomValue is derived from `DateTime.now().microsecondsSinceEpoch`

**File:** `lib/services/sync_service.dart`
- Line 794: `senha: 'servidor'` → `senha: PasswordService.generateServerPlaceholder()`
- Line 983: `senha: 'importado'` → `senha: PasswordService.generateServerPlaceholder()`

**File:** `lib/data/database.dart`
- `autenticarUsuario()` (line 534): added `if (PasswordService.isServerPlaceholder(user.senha)) return null;` BEFORE verifyPassword call
- `_migrarSenhasParaHash()` (lines 247-249): if plaintext is `'servidor'` or `'importado'`, replaces with `generateServerPlaceholder()` instead of hashing the guessable word

**Design decision:** `SRV:` prefix approach — no new column needed. The prefix makes server-only users explicitly identifiable and blocks local auth unconditionally.

### Task 13: Add updatedAt to plantas

**File:** `lib/data/database.dart`
- `Plantas` table class: added `DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();`
- Schema version: 17 → 18
- Migration `from < 18`: adds column, then `UPDATE plantas SET updated_at = created_at WHERE updated_at IS NULL`
- `updatePlanta()`: now uses `.write(planta.copyWith(updatedAt: Value(DateTime.now())))`
- `marcarPlantaSynced()`: removed `const`, added `updatedAt: Value(DateTime.now())`
- `softDeleteParcela()` bulk planta update: added `updatedAt: Value(now)` (reuses existing `now` variable)
- `restaurarParcela()` bulk planta update: removed `const`, added `updatedAt: Value(DateTime.now())`
- `cleanMissingFotoPlanta()`: removed `const`, added `updatedAt: Value(DateTime.now())`

**File:** `lib/data/database.g.dart` — regenerated via `dart run build_runner build`

### Task 14: GPS columns decision

**Decision:** KEEP — not worth a schema bump + migration + build_runner cycle for dead nullable columns.
**Change:** Added `// Reservado para uso futuro com GPS — atualmente sem uso (GPS desativado)` comment above latitude/longitude columns in Parcelas table class.

## Build status
- `flutter analyze`: 0 errors, 66 warnings/infos (all pre-existing)
- `build_runner build`: succeeded, 30 outputs
- Schema version: 18
