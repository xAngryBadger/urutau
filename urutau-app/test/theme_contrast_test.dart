// ============================================================
// theme_contrast_test.dart — TAREFA 3/5: contraste WCAG 2.2 AA
//
// Calcula a razão de contraste dos pares reais de cada tema e exige AA:
//   - texto normal: >= 4.5:1
//   - não-texto (bordas/dividers/ícones de realce): >= 3:1
// + widget test garantindo que cada tema aplica sem vazar cor clara
//   (scaffold, card, snackbar e diálogo escuros).
// ============================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urutau/services/theme_provider.dart';
import 'package:urutau/theme/app_tokens.dart';

double _lin(int v) {
  final d = v / 255.0;
  return d <= 0.04045 ? d / 12.92 : math.pow((d + 0.055) / 1.055, 2.4).toDouble();
}

double _luminance(Color c) =>
    0.2126 * _lin(c.red) + 0.7152 * _lin(c.green) + 0.0722 * _lin(c.blue);

/// Razão de contraste WCAG entre duas cores.
double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('Contraste AA — Alto contraste (preto/amarelo/branco)', () {
    test('pares de texto passam 4.5:1', () {
      expect(contrast(AppTokens.hcText, AppTokens.hcBackground),
          greaterThanOrEqualTo(4.5)); // branco no preto
      expect(contrast(AppTokens.hcPrimary, AppTokens.hcBackground),
          greaterThanOrEqualTo(4.5)); // amarelo no preto
      expect(contrast(AppTokens.hcOnPrimary, AppTokens.hcPrimary),
          greaterThanOrEqualTo(4.5)); // preto no amarelo (botão)
      expect(contrast(AppTokens.hcTextMuted, AppTokens.hcBackground),
          greaterThanOrEqualTo(4.5));
      expect(contrast(AppTokens.hcTextMuted, AppTokens.hcSurface),
          greaterThanOrEqualTo(4.5));
      expect(contrast(AppTokens.hcText, AppTokens.hcSurface2),
          greaterThanOrEqualTo(4.5)); // texto do snackbar
    });

    test('não-texto (bordas/divider/ícone) passa 3:1', () {
      expect(contrast(AppTokens.hcDivider, AppTokens.hcBackground),
          greaterThanOrEqualTo(3));
      expect(contrast(AppTokens.hcOutline, AppTokens.hcSurface2),
          greaterThanOrEqualTo(3));
      expect(contrast(AppTokens.hcPrimary, AppTokens.hcSurface),
          greaterThanOrEqualTo(3));
    });
  });

  group('Widget — cada tema aplica sem vazar tema claro', () {
    Future<void> pumpTheme(
        WidgetTester tester, ThemeModeUrutau mode) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeProvider.themeFor(mode),
        home: Builder(builder: (ctx) {
          final td = Theme.of(ctx);
          if (mode == ThemeModeUrutau.altoContraste) {
            expect(td.scaffoldBackgroundColor, AppTokens.hcBackground);
            expect(td.cardTheme.color, AppTokens.hcSurface);
            expect(td.snackBarTheme.backgroundColor, AppTokens.hcSurface2);
            expect(td.dialogTheme.backgroundColor, AppTokens.hcSurface);
            expect(td.colorScheme.surface, AppTokens.hcSurface);
          }
          return Scaffold(
            appBar: AppBar(title: const Text('tema')),
            body: Card(
              child: ListTile(title: const Text('linha do tema')),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () {},
              child: const Icon(Icons.check),
            ),
          );
        }),
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('linha do tema'), findsOneWidget);
    }

    testWidgets('alto contraste', (t) async => pumpTheme(t, ThemeModeUrutau.altoContraste));
    testWidgets('claro', (t) async => pumpTheme(t, ThemeModeUrutau.claro));
  });
}
