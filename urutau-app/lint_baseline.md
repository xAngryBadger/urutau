# Urutau Lint Baseline
# This file records the current state of lint violations.
# The CI regression gate compares against this baseline.
# 
# To update the baseline after intentional changes:
# 1. Run: flutter analyze 2>&1 | grep "issues found"
# 2. Update the baseline count below

# Current baseline (as of T10 implementation - 2026-10-30):
# flutter analyze: 3697 issues (mostly info/warnings from strict rules)
#   - Errors: 0 (excluding pre-existing sync_service.dart error)
#   - Warnings: ~10
#   - Info: ~3687

# Pre-existing known issues (not counted as regressions):
# - urutau-app/lib/services/sync_service.dart:1227:13 - non_bool_operand (error, pre-existing)
# - urutau-app/test/conflict_info_test.dart: pre-existing test failure

# Allowed directories for raw tokens (when custom_lint is enabled):
# - lib/theme/ (tokens definitions)
# - lib/widgets/primitives/ (primitives implementations)

# Forbidden patterns (to be enforced by no_raw_tokens custom_lint):
# - Colors.* (e.g., Colors.red, Colors.blue)
# - Color(0x...) constructor calls
# - fontSize: in TextStyle (outside tokens/primitives)
# - BorderRadius.* constructors (outside tokens/primitives)
# - EdgeInsets.* constructors (outside tokens/primitives)

# Custom lint package (packages/urutau_lints) created but not enabled due to SDK compatibility:
# - Requires custom_lint ^0.8.0+ with analyzer ^10.0.0 support
# - Currently blocked by drift_dev/custom_lint dependency conflict
# - Enable when Flutter SDK >= 3.16 (Dart >= 3.2) with macros support

# To regenerate baseline:
# cd urutau-app && flutter analyze 2>&1 | grep "issues found"