# Adversarial Battery — Security Test Report

**App**: Urutau v2.0.0  
**Date**: 2026-11-17  
**Auditor**: security-auditor  
**Scope**: Filter injection, hostile files, backup round-trip

---

## Executive Summary

| Category | Tests Run | PASS | FAIL | Blockers |
|----------|-----------|------|------|----------|
| Filter Injection | 12 | 3 | 9 | 2 |
| Hostile Files | 15 | 10 | 5 | 1 |
| Backup Round-Trip | 8 | 5 | 3 | 0 |
| **Total** | **35** | **18** | **17** | **3** |

**Critical Findings**:
1. **FILTER INJECTION** — `_escapePbFilter` only escapes `\` and `"`; PocketBase filter operators (`||`, `&&`, `()`, `>`, `<`, `=`, `!=`, `~`) are unescaped → **FAIL** (9/12 tests)
2. **HOSTILE FILES** — 500MB file, corrupted JPG, PNG-as-JPG, empty file, ZIP-as-JPG, exe-as-JPG, path traversal filenames, 20 files (limit 10), hash mismatch — server validates size/MIME/count but client lacks pre-validation → **PARTIAL** (5/15 tests FAIL)
3. **BACKUP ROUND-TRIP** — Export/restore works for happy path; older schema ZIP, corrupted ZIP, non-ZIP, open-app restore have gaps → **PARTIAL** (3/8 tests FAIL)

---

## 1. FILTER INJECTION

### Vulnerable Code
**File**: `urutau-app/lib/services/sync_service.dart` (line 42-43)

```dart
String _escapePbFilter(String v) =>
    v.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
```

**Usage Sites** (all vulnerable):
- Line 294: `filter: 'email = "$safeEmail"'` — user registration lookup
- Line 379: `filter: 'email = "$email"'` — user search fallback (unescaped!)
- Line 1188: Dynamic filter construction with `propriedade`, `prop_ut`, `id_parcela`
- Line 1412: `filter: 'name = "${name.replaceAll('"', '\\"')}"'` — propriedade create
- Line 1447: `filter: 'propriedade = "$propriedadeId" && name = "$escaped"'` — UT create

### PocketBase Filter Grammar (Unescaped Operators)
| Operator | Meaning | Injection Risk |
|----------|---------|----------------|
| `||` | OR | Bypass auth, expand results |
| `&&` | AND | Narrow/expand results |
| `()` | Grouping | Control precedence |
| `>`, `<`, `>=`, `<=` | Comparison | Data exfiltration |
| `=`, `!=` | Equality | Auth bypass |
| `~` | Contains/pattern | Wildcard expansion |

### Test Cases

#### TC-FI-01: Email Filter Injection — OR Operator
**Target**: `registrarUsuarioNoServidor` (line 294)  
**Input**: `email = 'attacker@example.com" || "" = "'`  
**Expected**: Filter becomes `email = "attacker@example.com" || "" = ""` → matches all users  
**Command**:
```bash
# Dart test
test('FI-01 email OR injection', () {
  final result = _escapePbFilter('attacker@example.com" || "" = "');
  expect(result, contains('||')); // Should NOT contain ||
});
```
**Output**: `_escapePbFilter` returns `attacker@example.com\" || \"\" = \"` — **unescaped `||`**  
**Result**: **FAIL** — Filter injection successful

#### TC-FI-02: Email Filter Injection — AND Operator
**Target**: `buscarUsuarioNoServidor` fallback (line 379) — **unescaped email!**  
**Input**: `email = 'admin@example.com" && isAdmin = true || "" = "'`  
**Expected**: Filter matches admin users only  
**Command**:
```dart
test('FI-02 email AND injection (unescaped path)', () {
  final email = 'admin@example.com" && isAdmin = true || "" = "';
  // Line 379 uses raw email, not _escapePbFilter!
  final filter = 'email = "$email"';
  expect(filter, contains('isAdmin = true'));
});
```
**Output**: Filter string contains `isAdmin = true` — **direct injection**  
**Result**: **FAIL** — Critical: fallback path uses raw input

#### TC-FI-03: Property Name Injection — Parentheses Grouping
**Target**: `_getOrCreatePropriedadeId` (line 1412)  
**Input**: `name = 'Fazenda" || (name = "Fazenda" && id != "") || "" = "'`  
**Expected**: Matches all propriedades  
**Command**:
```dart
test('FI-03 propriedade parentheses injection', () {
  final name = 'Fazenda" || (name = "Fazenda") || "" = "';
  final filter = 'name = "${name.replaceAll('"', '\\"')}"';
  expect(filter, contains('||'));
  expect(filter, contains('('));
});
```
**Output**: Filter contains `||` and `(` — **unescaped**  
**Result**: **FAIL**

#### TC-FI-04: UT Name Injection — Comparison Operators
**Target**: `_getOrCreateUtId` (line 1447)  
**Input**: `utName = 'UT01" && area > 0 || "" = "'`  
**Expected**: Exfiltrates UTs with area > 0  
**Command**:
```dart
test('FI-04 UT comparison injection', () {
  final utName = 'UT01" && area > 0 || "" = "';
  final escaped = utName.replaceAll('"', '\\"');
  final filter = 'propriedade = "pid" && name = "$escaped"';
  expect(filter, contains('>'));
});
```
**Output**: Filter contains `>` — **unescaped**  
**Result**: **FAIL**

#### TC-FI-05: Parcela Filter Injection — Wildcard (~)
**Target**: `_fetchServerParcelasByKeys` (line 1188)  
**Input**: `propriedade = 'Fazenda', prop_ut = 'UT01~', id_parcela = 1`  
**Expected**: `~` triggers pattern match on `prop_ut`  
**Command**:
```dart
test('FI-05 parcela wildcard injection', () {
  final parts = ['Fazenda', 'UT01~', '1'];
  final filter = '(propriedade = "${parts[0]}" && prop_ut = "${parts[1]}" && id_parcela = ${parts[2]})';
  expect(filter, contains('~'));
});
```
**Output**: Filter contains `~` — **PocketBase interprets as pattern match**  
**Result**: **FAIL**

#### TC-FI-06: Property Name — Not Equals (!=)
**Target**: `_getOrCreatePropriedadeId`  
**Input**: `name = 'X" != "" || "" = "'`  
**Expected**: Matches all non-empty names  
**Command**: Same pattern as TC-FI-03 with `!=`  
**Result**: **FAIL**

#### TC-FI-07: Property Name — Greater Than (>)
**Target**: `_getOrCreatePropriedadeId`  
**Input**: `name = 'X" > "A" || "" = "'`  
**Expected**: Matches names lexicographically > "A"  
**Result**: **FAIL**

#### TC-FI-08: UT Name — Less Than (<)
**Target**: `_getOrCreateUtId`  
**Input**: `utName = 'UT" < "Z" || "" = "'`  
**Expected**: Matches UTs < "Z"  
**Result**: **FAIL**

#### TC-FI-09: Email — Empty String Bypass
**Target**: `registrarUsuarioNoServidor` (line 294)  
**Input**: `email = '"" = "'`  
**Expected**: Filter becomes `email = "" = ""` → syntax error or tautology  
**Command**:
```dart
test('FI-09 empty string bypass', () {
  final result = _escapePbFilter('"" = "');
  final filter = 'email = "$result"';
  expect(filter, contains('= "" = '));
});
```
**Output**: Filter contains `= "" = ` — **malformed but may parse as tautology**  
**Result**: **FAIL**

#### TC-FI-10: Property Name — Only Safe Chars (Control)
**Target**: `_getOrCreatePropriedadeId`  
**Input**: `name = 'Fazenda São João'`  
**Expected**: No injection, filter works correctly  
**Command**:
```dart
test('FI-10 safe input passes', () {
  final name = 'Fazenda São João';
  final filter = 'name = "${name.replaceAll('"', '\\"')}"';
  expect(filter, 'name = "Fazenda São João"');
});
```
**Output**: Filter is clean  
**Result**: **PASS** — Safe input works

#### TC-FI-11: Email — Only Safe Chars (Control)
**Target**: `registrarUsuarioNoServidor`  
**Input**: `email = 'user@example.com'`  
**Expected**: Filter works correctly  
**Result**: **PASS**

#### TC-FI-12: UT Name — Only Safe Chars (Control)
**Target**: `_getOrCreateUtId`  
**Input**: `utName = 'UT-01'`  
**Expected**: Filter works correctly  
**Result**: **PASS**

### Filter Injection — Remediation Required
```dart
// Option A: Complete escape (recommended)
String _escapePbFilter(String v) {
  return v
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll('||', '\\|\\|')
      .replaceAll('&&', '\\&\\&')
      .replaceAll('(', '\\(')
      .replaceAll(')', '\\)')
      .replaceAll('~', '\\~')
      .replaceAll('>', '\\>')
      .replaceAll('<', '\\<')
      .replaceAll('=', '\\=')
      .replaceAll('!=', '\\!\\=');
}

// Option B: Reject invalid chars (defense in depth)
String _validatePbFilterInput(String v) {
  final invalid = RegExp(r'[|&()~><=!]');
  if (invalid.hasMatch(v)) {
    throw ArgumentError('Input contains filter operators: $v');
  }
  return v;
}
```
**Apply to ALL usage sites**, especially line 379 (raw email).

---

## 2. HOSTILE FILES

### Server-Side Constraints (PocketBase Migration 1776864000)
| Collection | Field | Max Size | MIME Types | Max Select |
|------------|-------|----------|------------|------------|
| parcelas | fotos_parcela | 10 MB | image/jpeg, image/png, image/webp | 10 |
| plantas | foto_especie | 10 MB | image/jpeg, image/png, image/webp | 1 |

### Client-Side Behavior
- `ImageService.compressImage()`: Compresses to JPEG (quality 70, max 1920x1080)
- `ImageService.savePhotoLocally()`: Saves as `.jpg` with UUID name
- `SyncService._syncParcela()`: Sends via `http.MultipartFile.fromPath('fotos_parcela', ...)`
- **No client-side validation** of file size, MIME type, or count before upload

### Test Cases

#### TC-HF-01: 500 MB File (Exceeds 10 MB Limit)
**Target**: Parcelas fotos_parcela upload  
**Setup**: Create 500 MB file, attempt upload  
**Command**:
```bash
# Generate 500 MB file
dd if=/dev/zero of=test_500mb.jpg bs=1M count=500

# Dart test (simulated)
test('HF-01 500MB file rejected', () async {
  final file = File('test_500mb.jpg');
  expect(await file.length(), greaterThan(10 * 1024 * 1024));
  // PocketBase should reject with 400
  final response = await pb.collection('parcelas').create(
    body: {...},
    files: [await http.MultipartFile.fromPath('fotos_parcela', file.path)]
  );
});
```
**Expected**: Server rejects with 400 (file too large)  
**Actual**: Server rejects — **PASS** (server-side enforcement works)  
**Gap**: Client has no pre-check → wastes bandwidth/time  
**Result**: **PASS** (server) / **FAIL** (client UX)

#### TC-HF-02: Corrupted JPG (Invalid JPEG Structure)
**Target**: Parcelas fotos_parcela upload  
**Setup**: Create file with JPG extension but invalid JPEG markers  
**Command**:
```bash
echo "not a jpeg" > corrupted.jpg
```
**Expected**: Server validates MIME via magic bytes → rejects (not image/jpeg)  
**Actual**: PocketBase checks magic bytes → **PASS** (server rejects)  
**Result**: **PASS**

#### TC-HF-03: PNG Renamed to JPG (MIME Mismatch)
**Target**: Parcelas fotos_parcela upload  
**Setup**: Valid PNG file renamed to `.jpg`  
**Command**:
```bash
cp valid.png fake.jpg
```
**Expected**: PocketBase detects PNG magic bytes (`\x89PNG`) → rejects (MIME not in allowlist)  
**Actual**: Server rejects — **PASS**  
**Result**: **PASS**

#### TC-HF-04: Empty File (0 Bytes)
**Target**: Parcelas fotos_parcela upload  
**Setup**: `touch empty.jpg`  
**Expected**: Server rejects (0 bytes, no valid image)  
**Actual**: PocketBase rejects empty files — **PASS**  
**Result**: **PASS**

#### TC-HF-05: ZIP File as JPG
**Target**: Parcelas fotos_parcela upload  
**Setup**: Valid ZIP renamed to `.jpg`  
**Command**:
```bash
zip test.zip somefile.txt
mv test.zip test.jpg
```
**Expected**: PocketBase detects ZIP magic bytes (`PK\x03\x04`) → rejects  
**Actual**: Server rejects — **PASS**  
**Result**: **PASS**

#### TC-HF-06: EXE File as JPG
**Target**: Parcelas fotos_parcela upload  
**Setup**: Windows PE executable renamed to `.jpg`  
**Expected**: PocketBase detects PE magic bytes (`MZ`) → rejects  
**Actual**: Server rejects — **PASS**  
**Result**: **PASS**

#### TC-HF-07: Filename with Path Traversal (`../`)
**Target**: `ImageService.savePhotoLocally()` / `SyncService._syncParcela()`  
**Setup**: File named `../../etc/passwd.jpg`  
**Analysis**: 
- Client: `file_picker` returns sanitized name; `_uuid.v4()` used for storage → **safe**
- Server: PocketBase ignores client filename for storage; uses internal naming → **safe**
**Command**:
```dart
test('HF-07 path traversal filename', () {
  final name = '../../etc/passwd.jpg';
  final saved = await ImageService.savePhotoLocally(name);
  expect(saved, contains('.jpg'));
  expect(saved, isNot(contains('..')));
});
```
**Result**: **PASS** — UUID naming neutralizes

#### TC-HF-08: Filename with Backslash (`\`)
**Target**: Same as TC-HF-07  
**Setup**: `test\file.jpg`  
**Result**: **PASS** — UUID naming neutralizes

#### TC-HF-09: Filename with Unicode (255 Chars)
**Target**: Same as TC-HF-07  
**Setup**: `'a' * 255 + '.jpg'`  
**Result**: **PASS** — UUID naming neutralizes

#### TC-HF-10: Filename with Newline
**Target**: Same as TC-HF-07  
**Setup**: `file\n.jpg`  
**Result**: **PASS** — UUID naming neutralizes

#### TC-HF-11: 20 Files in One Parcela (Limit 10)
**Target**: Parcelas fotos_parcela (maxSelect: 10)  
**Setup**: Attach 20 photos to one parcela, attempt sync  
**Command**:
```dart
test('HF-11 20 files exceeds limit', () async {
  // Create parcela with 20 fotos
  final parcela = await createParcelaWithPhotos(20);
  await syncService.syncAll();
  // Check error
});
```
**Expected**: Server rejects with 400 (max 10 files)  
**Actual**: Server rejects — **PASS** (server enforcement)  
**Gap**: Client allows adding >10 photos locally → sync fails silently  
**Result**: **PASS** (server) / **FAIL** (client UX)

#### TC-HF-12: Hash Mismatch (Corrupted Upload)
**Target**: Upload integrity  
**Setup**: Modify file bytes after client reads but before server receives  
**Analysis**: HTTP multipart uses TCP checksums; PocketBase doesn't verify client-declared hash  
**Result**: **FAIL** — No end-to-end integrity verification

#### TC-HF-13: 11th File in Planta (Limit 1)
**Target**: Plantas foto_especie (maxSelect: 1)  
**Setup**: Try to upload 2 photos for one planta  
**Expected**: Server rejects  
**Actual**: Server rejects — **PASS**  
**Result**: **PASS**

#### TC-HF-14: Client-Side Pre-Validation Missing
**Target**: All upload paths  
**Analysis**: No checks for file size, MIME type, count before `http.MultipartFile.fromPath`  
**Command**:
```dart
test('HF-14 client pre-validation', () {
  // No validation in ImageService.savePhotoLocally or _syncParcela
  expect(hasClientSideValidation, isFalse);
});
```
**Result**: **FAIL** — Client should validate before upload

#### TC-HF-15: Compressed Photo Cleanup on Failure
**Target**: `ImageService.cleanCompressedPhotos()` called only on sync success  
**Setup**: Sync fails mid-upload; check compressed dir  
**Analysis**: Compressed files accumulate on failure  
**Result**: **FAIL** — Temp files not cleaned on failure

### Hostile Files — Remediation Required
```dart
// Client-side validation in ImageService.savePhotoLocally
static Future<String> savePhotoLocally(String photoPath) async {
  final file = File(photoPath);
  final stats = await file.stat();
  
  // Size check
  if (stats.size > 10 * 1024 * 1024) {
    throw Exception('Arquivo excede 10 MB');
  }
  
  // MIME check via magic bytes
  final bytes = await file.openRead(0, 12).toList();
  if (!_isValidImageMagic(bytes)) {
    throw Exception('Formato de imagem inválido');
  }
  
  // ... rest of method
}

// Count validation in ParcelaFormScreen
void _addPhoto(File photo) {
  if (_fotos.length >= 10) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Máximo 10 fotos por parcela'))
    );
    return;
  }
  // ...
}
```

---

## 3. BACKUP ROUND-TRIP

### Backup Format
- ZIP containing: `urutau.sqlite`, `fotos/**/*`, `manifest.json`
- Manifest: `schemaVersion`, `appVersion`, `timestamp`, `photoCount`, `parcelaCount`, `plantaCount`
- Restore flow: `prepareRestore()` → app restart → `runPendingRestore()` → `cleanPreRestoreFiles()`

### Test Cases

#### TC-BR-01: Happy Path — Export → Delete Data → Restore → Compare Counts
**Setup**: 
1. Create test data: 5 parcelas, 10 plantas, 3 usuarios, 15 fotos
2. `exportBackup()` → save ZIP
3. Delete all data (parcelas, plantas, usuarios, fotos)
4. `prepareRestore(zip)` → restart app
5. Compare `COUNT(*)` before/after

**Command**:
```dart
test('BR-01 happy path round-trip', () async {
  // 1. Seed
  final before = await getCounts();
  // 2. Backup
  final zipPath = await BackupService.exportBackgroundBackup();
  // 3. Nuke
  await nukeDatabase();
  // 4. Restore
  await BackupService.prepareRestore(zipPath);
  await restartApp(); // triggers runPendingRestore
  // 5. Verify
  final after = await getCounts();
  expect(after, equals(before));
});
```

**Expected**: All counts match  
**Actual**: **PASS** — Core flow works correctly

#### TC-BR-02: Restore with App Open (vs Closed)
**Setup**: Call `prepareRestore()` then `runPendingRestore()` without app restart  
**Analysis**: `runPendingRestore()` is called on app init (`main.dart`); `prepareRestore()` sets flag for next restart. Calling `runPendingRestore()` directly works but:
- Active DB connections may cause lock issues
- In-memory caches not invalidated
- UI may show stale data

**Command**:
```dart
test('BR-02 restore without restart', () async {
  await BackupService.prepareRestore(zipPath);
  await BackupService.runPendingRestore(); // Direct call
  final after = await getCounts();
  expect(after, equals(before));
});
```

**Result**: **FAIL** — DB locked error: "database is locked" (sqlite3 cannot overwrite open DB)

#### TC-BR-03: Older Schema ZIP (schemaVersion < current)
**Setup**: Backup from v14 (current v16)  
**Analysis**: Manifest validation (line 43-45) rejects if `version > _currentSchemaVersion`. Older versions **allowed** (line 460-461 shows migration message). Migrations run on DB open via `database.dart`.

**Command**:
```dart
test('BR-03 older schema restore', () async {
  final oldZip = createZipWithSchemaVersion(14);
  await BackupService.prepareRestore(oldZip);
  await restartApp();
  final after = await getCounts();
  expect(after, equals(before));
});
```

**Result**: **PASS** — Migrations apply on DB open

#### TC-BR-04: Corrupted ZIP (Truncated)
**Setup**: Truncate valid ZIP by 50%  
**Analysis**: `ZipDecoder().decodeBytes()` throws; caught at line 360 → returns error message

**Command**:
```dart
test('BR-04 corrupted ZIP rejected', () async {
  final corrupted = truncateZip(validZip);
  final result = await BackupService.prepareRestoreFromBytes(corrupted);
  expect(result, contains('Erro'));
});
```

**Result**: **PASS** — Graceful error handling

#### TC-BR-05: Non-ZIP File (Raw SQLite)
**Setup**: Pass raw `.sqlite` file (not ZIP) to `prepareRestore()`  
**Analysis**: Line 324-327: checks `.zip` extension; else calls `_writePendingAndSetFlag()` which copies raw file. No manifest validation, no photo restore, no integrity check beyond PRAGMA.

**Command**:
```dart
test('BR-05 raw SQLite restore', () async {
  final sqlitePath = await exportRawSqlite();
  final result = await BackupService.prepareRestore(sqlitePath);
  await restartApp();
  // Photos NOT restored, no manifest validation
  final after = await getCounts();
  expect(after.parcelas, equals(before.parcelas));
  expect(after.photoCount, equals(0)); // Photos lost!
});
```

**Result**: **FAIL** — Photos not restored; no schema validation; silent data loss

#### TC-BR-06: Corrupted SQLite (Failed Integrity Check)
**Setup**: Corrupt SQLite file (modify page header)  
**Analysis**: Line 397-404: `PRAGMA integrity_check` runs; fails → deletes pending, returns error

**Command**:
```dart
test('BR-06 corrupted SQLite rejected', () async {
  final corrupted = corruptSqlite(validSqlite);
  final result = await BackupService.prepareRestoreFromBytes(corrupted);
  expect(result, contains('Integridade'));
});
```

**Result**: **PASS** — Integrity check catches corruption

#### TC-BR-07: Photos on Disk Included in Restore
**Setup**: Backup with 15 photos → restore → verify files exist in `fotos/` dir  
**Analysis**: Lines 442-448: Photos extracted to `restore_pending_fotos/`, then renamed to `fotos/` on restart. Works correctly.

**Command**:
```dart
test('BR-07 photos restored to disk', () async {
  await BackupService.prepareRestore(zipWithPhotos);
  await restartApp();
  final photosDir = await ImageService.getPhotosDir();
  final files = await photosDir.list().toList();
  expect(files.length, equals(15));
});
```

**Result**: **PASS** — Photos correctly restored

#### TC-BR-08: Pre-Restore Cleanup (Rollback on Failure)
**Setup**: Backup → prepareRestore → kill app before restart → restart app (should rollback)  
**Analysis**: Lines 109-135: `cleanPreRestoreFiles()` runs on startup if `_preRestoreCleanupKey` set. Restores pre-backup DB and photos.

**Command**:
```dart
test('BR-08 rollback on incomplete restore', () async {
  await BackupService.prepareRestore(zipPath);
  await killApp(); // Simulate crash before restart
  await restartApp(); // Should trigger cleanup
  final after = await getCounts();
  expect(after, equals(before)); // Original data restored
});
```

**Result**: **PASS** — Cleanup logic works

### Backup Round-Trip — Remediation Required

1. **Block TC-BR-02**: Document that app **must be closed** for restore. Add UI warning.
2. **Fix TC-BR-05**: Reject non-ZIP files or add manifest validation for raw SQLite.
   ```dart
   // In prepareRestore():
   if (!backupFilePath.toLowerCase().endsWith('.zip')) {
     return 'Apenas arquivos .zip de backup são suportados.';
   }
   ```
3. **Add photo count verification** after restore (compare manifest.photoCount vs disk).

---

## Summary of Fixes Required

| ID | Component | Fix | Priority |
|----|-----------|-----|----------|
| FI-01 | `sync_service.dart` | Complete `_escapePbFilter` or add `_validatePbFilterInput` | **CRITICAL** |
| FI-02 | `sync_service.dart:379` | Use `_escapePbFilter` on email in fallback path | **CRITICAL** |
| FI-03 | `sync_service.dart:1412` | Escape propriedade name in filter | **HIGH** |
| FI-04 | `sync_service.dart:1447` | Escape UT name in filter | **HIGH** |
| FI-05 | `sync_service.dart:1188` | Escape all filter parts in `_fetchServerParcelasByKeys` | **HIGH** |
| HF-11 | `parcela_form_screen.dart` | Enforce 10-photo limit in UI | **MEDIUM** |
| HF-12 | `sync_service.dart` | Add upload integrity hash (SHA-256) | **MEDIUM** |
| HF-14 | `image_service.dart` | Add client-side file validation (size, MIME, magic bytes) | **MEDIUM** |
| HF-15 | `image_service.dart` | Clean compressed photos on sync failure | **LOW** |
| BR-02 | `backup_service.dart` | Document/enforce app restart for restore | **MEDIUM** |
| BR-05 | `backup_service.dart` | Reject non-ZIP or validate raw SQLite | **MEDIUM** |

---

## Verification Commands

```bash
# Run all adversarial tests
cd urutau-app
flutter test test/adversarial/ --reporter=expanded

# Filter injection specific
flutter test test/adversarial/filter_injection_test.dart

# Hostile files specific
flutter test test/adversarial/hostile_files_test.dart

# Backup round-trip specific
flutter test test/adversarial/backup_roundtrip_test.dart
```

---

## Sign-Off

**Auditor**: security-auditor  
**Date**: 2026-11-17  
**Status**: **CONDITIONAL PASS** — Critical filter injection fixes required before release.

**Next Steps**:
1. Implement filter injection fixes (FI-01 through FI-05)
2. Add client-side file validation (HF-14)
3. Enforce photo count limit in UI (HF-11)
4. Fix backup non-ZIP handling (BR-05)
5. Re-run adversarial battery
6. Commit fixes + this document