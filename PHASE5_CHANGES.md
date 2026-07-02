# Phase 5 Changes — Urutau OFFLINE_REWORK (Multi-User Readiness)

## Status: COMPLETE

## Verification Matrix

| Task | Checkpoint | Result |
|------|-----------|--------|
| 15: Admin unsynced filter | `_unsyncedPorUsuario` map tracks counts per user | PASS |
| 15: Admin unsynced filter | `_carregarDados()` calculates unsynced counts | PASS |
| 15: Admin unsynced filter | `_filterPendingOnly` toggle added | PASS |
| 15: Admin unsynced filter | User cards show unsynced count with orange chip | PASS |
| 15: Admin unsynced filter | Semantics label updated for accessibility | PASS |
| 15: Admin unsynced filter | "Pending only" filter shows users with unsynced > 0 | PASS |
| 16: Dedup audit logging | `_getOrCreatePropriedadeId()` logs `dedup_propriedade` | PASS |
| 16: Dedup audit logging | `_getOrCreateUtId()` logs `dedup_ut` | PASS |

## Changes by Task

### Task 15: Admin screen unsynced filter

**File:** `lib/screens/admin_screen.dart`

**State variables added:**
- Line 23: `Map<String, int> _unsyncedPorUsuario = {};`
- Line 26: `bool _filterPendingOnly = false;`

**Logic changes in `_carregarDados()` (lines 287-298):**
```dart
// Calculate unsynced parcelas per usuario
Map<String, int> unsyncedPorUsuario = {};
for (var usuario in usuarios) {
  final unsyncedCount = todasParcelas.where((p) => p.userId == usuario.uuid && !p.synced).length;
  unsyncedPorUsuario[usuario.uuid] = unsyncedCount;
}
// ... later:
_unsyncedPorUsuario = unsyncedPorUsuario;
```

**Filter toggle UI (lines 593-601):**
```dart
CheckboxListTile(
  value: _filterPendingOnly,
  onChanged: (value) {
    setState(() {
      _filterPendingOnly = value ?? false;
      _applyAdminFilter();
    });
  },
  title: const Text('Apenas pendentes'),
  subtitle: const Text('Mostra apenas usuários com parcelas não sincronizadas'),
)
```

**Filter logic in `_filteredUsuarios` (lines 325-328):**
```dart
if (_filterPendingOnly) {
  return _usuarios.where((u) {
    return (_unsyncedPorUsuario[u.uuid] ?? 0) > 0;
  }).toList();
}
```

**User card display updates:**
- Line 876: `final unsyncedCount = parcelas.where((p) => !p.synced).length;`
- Line 881: Semantics label updated to include "$unsyncedCount pendentes"
- Lines 953-954: Orange info chip shown when `unsyncedCount > 0`:
  ```dart
  if (unsyncedCount > 0)
    _infoChip(Icons.pending, '$unsyncedCount pendentes', Colors.orange),
  ```

**User experience:**
- Each user card now shows "5 parcelas (2 pendentes)" with an orange chip for pending count
- "Apenas pendentes" checkbox filters to show only users with unsynced parcelas
- Accessibility label includes pending count

### Task 16: Add audit log for dedup events

**File:** `lib/services/sync_service.dart`

**`_getOrCreatePropriedadeId()` (lines 1257-1262):**
```dart
if (retry.items.isNotEmpty) {
  await _db.logAudit('dedup_propriedade',
      entityType: 'propriedade',
      details: 'Concurrent create detected, reused existing: $name',
      newValue: 'deduplicated');
  return retry.items.first.id;
}
```

**`_getOrCreateUtId()` (lines 1294-1299):**
```dart
if (retry.items.isNotEmpty) {
  await _db.logAudit('dedup_ut',
      entityType: 'ut',
      details: 'Concurrent create detected, reused existing: $utName',
      newValue: 'deduplicated');
  return retry.items.first.id;
}
```

**Audit log entries created:**
- Action: `dedup_propriedade` — when concurrent propriedade creation is detected and existing is reused
- Action: `dedup_ut` — when concurrent UT creation is detected and existing is reused
- Both include entity type, details with the name, and `newValue: 'deduplicated'`

## Build status
- `flutter analyze`: 0 errors, 66 warnings/infos (all pre-existing)
- Schema version: 18 (unchanged — UI-only changes)

## What This Achieves

**Before:** Admin couldn't quickly see which users had pending sync data. Concurrent sync dedup happened silently.

**After:** Admin sees unsynced counts per user at a glance, can filter to "pending only" for quick triage. Dedup events are logged to audit trail for visibility and debugging.