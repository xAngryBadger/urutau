# Plano: Correções Cirúrgicas + Foundation de Tokens/Primitives/Lint/A11y

**Objetivo:** Tornar o app usável no piloto (corrigir defeitos críticos) **e** instalar a camada de design-system que torna um redesign futuro barato e seguro.

**Escopo:** Apenas `lib/` do app Flutter. Não toca regras de negócio, persistência, sync, PocketBase, MRV, carbono.

---

## Estrutura de Tasks (DAG)

```
T1  Storage cleanup contract fix
T2  Plant save guard + error handling
T3  Error swallowing → explicit states (Home, Audit, Admin, Storage, Integrity)
T4  Pull morto removido/desabilitado no Explorer
T5  Contraste crítico: login, conflict dialog, badge, status badges, hint/switch
T6  Touch targets ≥48dp + icon-button labels
T7  Remover superfícies mortas (SyncScreenPro, readOnly destrutivo, desistir, branch morto)
T8  Tokens API única (AppTheme → semantic tokens; ThemeProvider consome)
T9  Primitives reutilizáveis (Button, Field, Card, StatusBanner, EmptyState, DestructiveDialog, FilterChip)
T10 Lint strict baseline + custom token lint + CI gates
T11 A11y/Golden matrix (320/360/412, scale 1.0/1.3/1.5, light/high-contrast)
T12 Smoke test end-to-end no emulador (login → catalog → parcel → plant → sync → settings → admin)
```

**Dependências:**
- T1–T7 independentes entre si (podem rodar em paralelo).
- T8 depende de T5 (contraste define tokens semânticos).
- T9 depende de T8 (primitives consomem tokens).
- T10 depende de T8/T9 (lint aponta para tokens/primitives).
- T11 depende de T9 (matrix testa primitives).
- T12 depende de T1–T7 + T9 (app funcional com primitives).

---

## Tasks detalhadas

### T1 — Storage cleanup contract fix
**Arquivos:** `lib/screens/storage_screen.dart`, `lib/services/storage_service.dart`
**Aceitação:**
- [ ] `StorageScreen` passa chaves exatamente iguais a `StorageService.cleanCategory` (`database`, `fotos`, `backups`, `temp`).
- [ ] UI mostra snackbar de sucesso **apenas** quando o `switch` executou um case real.
- [ ] `category == 'fotos'` comparison removida/substituída por chave correta.
- [ ] `flutter analyze` sem novos warnings nessas linhas.

### T2 — Plant save guard + error handling
**Arquivo:** `lib/screens/planta_form_screen.dart`
**Aceitação:**
- [ ] `_isSaving` atribuído `true` antes do insert, `false` em `finally`.
- [ ] Botão "Salvar" desabilitado enquanto `_isSaving`.
- [ ] `try/catch/finally` no `_savePlanta`; erro mostra Snackbar com mensagem acionável.
- [ ] Double-tap não duplica insert (guard por `_isSaving`).
- [ ] Teste unit/widget para erro de DB → Snackbar mostrado.

### T3 — Error swallowing → explicit states
**Arquivos:** `lib/screens/home_screen.dart`, `lib/screens/audit_log_screen.dart`, `lib/screens/admin_screen.dart`, `lib/screens/storage_screen.dart`, `lib/screens/integrity_error_screen.dart`
**Aceitação:**
- [ ] `StreamBuilder` em Home verifica `snapshot.hasError` → mostra banner/erro recuperável.
- [ ] `AuditLogScreen` catch loga erro e mostra estado de erro (não vazio silencioso).
- [ ] `AdminScreen` carrega usuários/parcelas com `FutureBuilder` que expõe erro.
- [ ] `StorageScreen` `_loadStorageInfo` tem `try/catch/finally` + `mounted` check.
- [ ] `IntegrityErrorScreen` restore/reset têm `try/catch` + progress indicator + erro recuperável.
- [ ] Zero `debugPrint` como único tratamento de erro user-facing.

### T4 — Pull morto removido/desabilitado no Explorer
**Arquivo:** `lib/screens/explorer_screen.dart`
**Aceitação:**
- [ ] Botão "Puxar do servidor" removido OU desabilitado com tooltip "Indisponível — configure o servidor em Configurações".
- [ ] `_doPull` removido ou mantido apenas para futura implementação (comentado).
- [ ] Empty state não menciona "puxar do servidor" quando pull desativado.

### T5 — Contraste crítico (WCAG AA 4.5:1 texto / 3:1 gráfico)
**Arquivos:** `lib/screens/login_screen.dart`, `lib/widgets/conflict_resolution_dialog.dart`, `lib/widgets/arquivo_ausente_badge.dart`, `lib/screens/home_screen.dart`, `lib/screens/admin_screen.dart`, `lib/screens/explorer_screen.dart`, `lib/services/theme_provider.dart`
**Aceitação (medidos via `flutter test` a11y harness + golden):**
- [ ] Login: fill/input sobre surface alto contraste ≥ 4.5:1.
- [ ] Conflict dialog: local/server text sobre blue[50]/orange[50] ≥ 4.5:1 (alto contraste).
- [ ] Badge "arquivo ausente": branco sobre orange.shade800 ≥ 4.5:1.
- [ ] Status badges (Home/Admin/Explorer): verde/âmbar/vermelho/cinza sobre appBar bg ≥ 4.5:1.
- [ ] Hint text alto contraste ≥ 4.5:1; switch thumb/track ≥ 3:1.
- [ ] Explorer UT card: foreground sobre tertiaryContainer ≥ 4.5:1.
- [ ] Tokens semânticos `onSurface`, `onPrimaryContainer`, `onSurfaceVariant`, `danger`, `warning`, `success` definidos e usados.

### T6 — Touch targets ≥48dp + icon-button labels
**Arquivos:** `lib/screens/parcela_form_screen.dart`, `lib/screens/sync_screen_pro.dart` (se mantido), `lib/screens/explorer_screen.dart`, `lib/screens/home_screen.dart`, `lib/screens/admin_screen.dart`, `lib/screens/planta_form_screen.dart`, `lib/screens/login_screen.dart`
**Aceitação:**
- [ ] Remover foto (ParcelForm/PlantForm): 48×48 mínimo + `Semantics` label "Remover foto".
- [ ] Breadcrumbs Explorer: altura mínima 48dp, área de toque expandida.
- [ ] Filtros "Limpar" (Home/Admin): `InkWell`/`TextButton` com área ≥48dp + label.
- [ ] Icon-buttons login (show/hide password), admin (sync/clear), planta (remove photo): `Tooltip` + `Semantics` label.
- [ ] `flutter test` com `SemanticsTester` verifica roles/labels.

### T7 — Remover superfícies mortas
**Arquivos:** `lib/screens/sync_screen_pro.dart`, `lib/screens/parcela_form_screen.dart`, `lib/screens/explorer_screen.dart`, `lib/screens/home_screen.dart`
**Aceitação:**
- [ ] `SyncScreenPro` movido para `lib/screens/legacy/` OU deletado (sem callers).
- [ ] `ParcelaFormScreen` readOnly: AppBar remove "Próxima", "Exportar ZIP", "Excluir" quando `readOnly==true`; `_confirmDelete` consulta `readOnly`.
- [ ] `_showDesistirDialog` removido (sem callers).
- [ ] Home `case 'sync'` branch morto removido do PopupMenu.
- [ ] `flutter analyze` sem dead code warnings relacionados.

### T8 — Tokens API única
**Arquivos:** `lib/theme/app_theme.dart` (refatorado), `lib/services/theme_provider.dart` (consome tokens), `lib/theme/tokens.dart` (novo)
**Aceitação:**
- [ ] `lib/theme/tokens.dart` exporta `UrutauTokens` com: `color` (surface, surfaceContainer, primary, onPrimary, secondary, onSecondary, danger, onDanger, warning, onWarning, success, onSuccess, outline, outlineVariant, inverseSurface, inversePrimary), `typography` (display, headline, title, body, label, mono), `spacing` (xs, sm, md, lg, xl), `radius` (sm, md, lg, xl), `elevation` (level0–3), `motion` (duration, easing).
- [ ] `ThemeProvider._lightTheme` e `_highContrastTheme` constroem `ThemeData` **apenas** a partir de `UrutauTokens.light` / `UrutauTokens.highContrast`.
- [ ] `AppTheme` **deprecated** (mantido apenas para migração gradual; emite `deprecated` warning via `@Deprecated`).
- [ ] Telas/widgets migram para `Theme.of(context).extension<UrutauTokens>()` ou `Theme.of(context).colorScheme` semântico.
- [ ] `flutter analyze` sem `Colors.*`, `Color(0x)`, `fontSize` literal fora de `tokens.dart` (exceto migrations marcadas).

### T9 — Primitives reutilizáveis
**Arquivos novos:** `lib/widgets/primitives/urutau_button.dart`, `urutau_field.dart`, `urutau_card.dart`, `urutau_status_banner.dart`, `urutau_empty_state.dart`, `urutau_destructive_dialog.dart`, `urutau_filter_chip.dart`
**Aceitação:**
- [ ] `UrutauButton({required UrutauButtonIntent intent, ...})` — intents: `primary`, `secondary`, `destructive`, `ghost`, `tonal`. Tamanho mínimo 48dp, loading state, Semantics.
- [ ] `UrutauField` — wrapper `TextFormField` com `InputDecorationTheme` do token, label, hint, error, prefix/suffix icons, Semantics.
- [ ] `UrutauCard` — `Card` com token elevation/radius/padding, `InkWell` opcional.
- [ ] `UrutauStatusBanner` — substituir `LowSpaceBanner`, sync banners, conflict banner; variantes: `info`, `warning`, `danger`, `success`; ação opcional; live region.
- [ ] `UrutauEmptyState` — illustration + title + body + action; usada em Home/Explorer/Plant/Admin/Audit.
- [ ] `UrutauDestructiveDialog` — padrão único para delete/clear/reset; título, descrição, checkbox confirm, cancel/destructive actions; focus trap.
- [ ] `UrutauFilterChip` — substituir filter tags Home/Explorer/Admin; selected/disabled states, touch target 48dp.
- [ ] Pelo menos 3 telas migradas para primitives (ex.: `StorageScreen`, `IntegrityErrorScreen`, `AuditLogScreen`) como prova.

### T10 — Lint strict baseline + custom token lint + CI gates
**Arquivos:** `analysis_options.yaml`, `.github/workflows/analyze.yml` (ou equivalente), `tool/lint_tokens.dart` (custom lint)
**Aceitação:**
- [ ] `analysis_options.yaml`: SDK alinhado, `include: package:flutter_lints/flutter.yaml`, `linter.rules` com `prefer_const_constructors`, `prefer_const_declarations`, `use_super_parameters`, `avoid_print`, `always_use_package_imports`, `sort_child_properties_last`, `use_build_context_synchronously`, `sized_box_for_whitespace`, `unawaited_futures`, `deprecated_member_use`, `prefer_single_quotes`, `omit_local_variable_types`.
- [ ] Baseline CI: `flutter analyze --no-pub` registra issues (não falha); `flutter test --no-pub` gate obrigatório.
- [ ] Custom lint `no_raw_tokens`: proíbe `Colors.*`, `Color(0x`, `fontSize:`, `BorderRadius.circular(`, `EdgeInsets.` fora de `lib/theme/tokens.dart` e `lib/widgets/primitives/**`; exceptions listadas e versionadas.
- [ ] CI falha em `no_raw_tokens` regressivo (novos arquivos/linhas).
- [ ] Documentação `docs/LINT_TOKENS.md` com exemplos de migração.

### T11 — A11y/Golden matrix
**Arquivos:** `test/golden/`, `test/a11y/`, `integration_test/`
**Aceitação:**
- [ ] Golden tests: 3 larguras (320, 360, 412) × 2 temas (light, high-contrast) × 2 text scales (1.0, 1.5) para primitives e 3 telas migradas = 36 imagens baseline.
- [ ] A11y widget tests: `SemanticsTester` verifica labels, roles, live regions, touch target ≥48dp, contraste via `flutter_test` `matchesGoldenFile` + custom matcher.
- [ ] `integration_test` roda em emulador API 34 (320×640) login→catalog→parcel→plant→sync→settings→admin; captura screenshots em cada step.
- [ ] CI roda goldens + a11y tests em headless; falha em regressão visual/a11y.

### T12 — Smoke test end-to-end no emulador
**Arquivo:** script `tool/smoke_test.dart` ou `integration_test/smoke_test.dart`
**Aceitação:**
- [ ] Roteiro automatizado: install debug APK → seed fixture → login → explorer → create parcel + plants + photo → draft/conclude → sync (offline) → settings (test conn, backup) → admin (overview, user parcels) → logout.
- [ ] Zero crashes, zero exceptions não tratadas, todos os Snackbars/feedback aparecem.
- [ ] Screenshots de cada step salvos em `docs/aegis/work/.../evidence/smoke/`.

---

## Estimativa de esforço (horas)

| Task | Horas | Paralelizável |
|---|---|---|
| T1 | 2 | sim |
| T2 | 3 | sim |
| T3 | 6 | sim |
| T4 | 1 | sim |
| T5 | 8 | sim (por arquivo) |
| T6 | 6 | sim (por arquivo) |
| T7 | 3 | sim |
| T8 | 12 | — |
| T9 | 16 | — (depende T8) |
| T10 | 6 | — (depende T8/T9) |
| T11 | 12 | — (depende T9) |
| T12 | 4 | — (depende T1–T7, T9) |
| **Total** | **~79h** | **T1–T7 paralelas → T8→T9→T10/T11→T12** |

---

## Critérios de "pronto para piloto"

- [ ] T1–T7 **done** (app usável, sem defeitos críticos de dados/feedback/a11y).
- [ ] T8–T9 **done** (tokens + primitives instalados, 3 telas migradas).
- [ ] T10 baseline CI verde (não falha em código existente; falha só em regressão).
- [ ] T11 matrix passa local.
- [ ] T12 smoke test passa no emulador.

---

## Fora de escopo (não fazem parte deste plano)
- Redesenho visual (direção, tipografia de marca, motion, ilustrações).
- Mudança de navegação canônica (Explorer vs Home) — decisão de produto separada.
- Internacionalização, RTL, novos idiomas.
- Migração para Material 3 completo (já usa `useMaterial3: true`).
- Admin web panel.

---

## Próximo passo

Se você aprova este plano, eu:
1. Crio as tasks no AgentTeams (ou task board local) com assignees.
2. Executo T1–T7 em paralelo (correções cirúrgicas).
3. Entrego T8–T11 sequencialmente.
4. Fecho com T12.

**Confirma?** Responda `aprovado` para iniciar.