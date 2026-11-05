# UI/UX Audit — Checkpoint

## Current state

- Active slice: discovery and runtime inspection.
- Branch/HEAD at start: `main` / `d1f3715`.
- Worktree baseline: unrelated untracked artifacts exist one directory above the app; this audit will not touch them.
- Goal: `goal-2c2f6595-98f7-4aa2-afd3-58bb20e35f49`.

## Todo map

1. Locate canonical app and artifacts — in progress.
2. Map routes/screens/components/states/flows.
3. Inspect Android runtime and collect visual/interaction evidence.
4. Audit hierarchy, consistency, accessibility, responsive behavior, and technical debt.
5. Publish durable audit report.
6. Prepare lint/token foundation without redesign.
7. Present alternatives and recommendation.

## Completed

- Located canonical Flutter app at `D:/projetos/urutau/urutau-app`.
- Read route/theme/lint entry points and current historical product note.
- Baseline `flutter analyze --no-pub`: 98 issues under `package:lints/recommended.yaml` (warnings + infos), including UI-relevant deprecated APIs and unused UI helpers.
- Measured screen source sizes: `explorer_screen.dart` 2513 lines; `admin_screen.dart` 1885; `parcela_form_screen.dart` 1465; `home_screen.dart` 1068; `sync_screen_pro.dart` 1038; `settings_screen.dart` 853; `planta_form_screen.dart` 781; `login_screen.dart` 588.
- Confirmed Android API 34 emulator is available.

## Evidence refs

- `lib/main.dart:147-229` — route map.
- `lib/services/theme_provider.dart:34-223` — active light/high-contrast themes.
- `analysis_options.yaml:1-10` — current weak lint baseline.
- `docs/ANALISE_DETALHADA_APP.md:22-55` — historical proposal that conflicts with current code.
- `flutter analyze --no-pub` baseline captured in session output.

## Blockers

- None yet.

## Next step

Finish static screen inventory, install/launch current app on emulator, capture screenshots and UI hierarchy, then correlate runtime with source.

## Drift check

Decision: `continue`. No product behavior changed; the scope remains read-only audit plus explicitly requested safe preparation.
