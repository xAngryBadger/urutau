# UI/UX Audit — Intent

Date: 2026-10-30

## Requested outcome

Discover the current Urutau app UI/UX from real code and runtime evidence; critique the experience; prepare a durable, low-risk foundation (lint/design-system guardrails) for a future reformulation; present design directions without implementing an unapproved redesign.

## Scope

- Primary: Flutter field app at `D:/projetos/urutau/urutau-app`.
- Primary evidence: navigation and screen composition, primary tasks, hierarchy, forms, feedback, empty/error/loading states, accessibility, responsive behavior, visual consistency, and code-level design-system debt.
- Preparation only: analysis/lint rules, token inventory, and guardrails that do not silently redesign the product.
- Adjacent surface to confirm after mobile audit: web admin panel.

## Non-goals

- No visual redesign before user approval.
- No removal of login, sync, admin, or other current product behavior.
- No change to business rules, persistence, server contracts, or the MRV/carbon pipeline.
- No claim that code inspection alone proves runtime quality.

## Success evidence

1. A screen/route/state map with source attribution.
2. Runtime screenshots and/or interaction evidence from the Android emulator.
3. Severity-ranked findings separating deterministic defects from subjective recommendations.
4. A written audit report durable on disk.
5. A conservative lint/design-token foundation whose current baseline and remaining debt are explicit.
6. Two or three reformulation directions with trade-offs and a recommendation for the user to choose.

## Authority and baseline

Required read-set:

- `README.md` (currently Flutter boilerplate; not a product authority).
- `analysis_options.yaml` (currently recommended Dart lints only).
- `lib/main.dart` (route authority).
- `lib/services/theme_provider.dart` (active theme authority).
- `lib/theme/app_theme.dart` (partially used token set).
- `lib/screens/*.dart` and `lib/widgets/*.dart` (runtime composition).
- Existing docs are historical/product-context candidates only. `docs/ANALISE_DETALHADA_APP.md` conflicts with current code (it proposes removing login/sync/admin); it is not treated as current approval.

No current product design specification or approved UI direction was found. This is a known authority gap.

## Compatibility and retirement boundary

- Preserve current behavior while auditing.
- Lint work must not introduce failing CI without an explicit debt baseline or a staged adoption policy.
- Do not add a second design system owner; reuse/extend the existing Flutter theme seam.
- Do not introduce a token/fallback/compat layer until a direction is selected.

## Risks

- Runtime may require credentials/server state not available on the emulator.
- `flutter analyze` already reports 98 issues under the weak baseline; stricter rules could create a misleading wall of debt.
- Visual findings from one emulator size may miss device-specific issues.
- The app has both `HomeScreen` and `ExplorerScreen`; runtime navigation must establish which is canonical.

## Stop states

- `done`: audit, durable report, safe foundation, and options delivered.
- `needs-verification`: runtime state inaccessible for a meaningful surface.
- `blocked`: repository or emulator cannot be inspected.
- `scope-exceeded`: audit would require destructive/product changes.
