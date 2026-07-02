# Phase 5 Implementation Summary

## TASK 15: Admin screen unsynced filter - COMPLETED

### Goal: Add ability to see which users have pending (unsynced) parcelas.

### Implementation Summary:

1. **Added unsynced count to user cards:**
   - Added `_unsyncedPorUsuario` map to track unsynced parcelas per user
   - Modified `_carregarDados()` to calculate unsynced parcelas count:
     ```dart
     int unsyncedCount = parcelas.where((p) => !p.synced).length;
     ```
   - Stored in map: `_unsyncedPorUsuario[usuario.uuid] = unsyncedCount;`
   - Updated user card Semantics label to include unsynced count
   - Added visual indicator: "X parcelas (Y pendentes)" next to parcela count

2. **Added "Pending only" filter toggle:**
   - Added state variable: `bool _filterPendingOnly = false;`
   - Added CheckboxListTile toggle near the user dropdown
   - When enabled, filters user list to only show users with `unsyncedCount > 0`
   - Updated `_filteredUsuarios` to apply this filter

3. **Updated the user card display:**
   - Calculated unsynced: `final unsynced = parcelas.where((p) => !p.synced).length;`
   - Displayed in card with orange chip: "$unsynced pendentes" when > 0

### Files Modified:
- `lib/screens/admin_screen.dart`

### UI Changes:
- User cards show unsynced count when > 0
- New "Apenas com pendências" checkbox filter
- Filter shows only users with unsynced parcelas when active
- Visual indicator uses orange info chip for unsynced count

## TASK 16: Add audit log for dedup events - COMPLETED

### Goal: Log when concurrent sync deduplication happens.

### Implementation Summary:

1. **Added audit log for propriedade dedup events:**
   - Modified `_getOrCreatePropriedadeId()` in `sync_service.dart`
   - Added log after successful re-fetch in retry block:
     ```dart
     await _db.logAudit('dedup_propriedade',
         entityType: 'propriedade',
         details: 'Concurrent create detected, reused existing: $name',
         newValue: 'deduplicated');
     ```

2. **Added audit log for UT dedup events:**
   - Modified `_getOrCreateUtId()` in `sync_service.dart`
   - Added log after successful re-fetch in retry block:
     ```dart
     await _db.logAudit('dedup_ut',
         entityType: 'ut',
         details: 'Concurrent create detected, reused existing: $utName',
         newValue: 'deduplicated');
     ```

### Files Modified:
- `lib/services/sync_service.dart`

### Verification:
- Grep for `logAudit.*dedup` shows 2 new calls as required

## Build Results

- Ran `flutter analyze`: 66 issues (pre-existing, no new errors from our changes)
- All requested functionality implemented as specified
- Changes follow existing code patterns and conventions