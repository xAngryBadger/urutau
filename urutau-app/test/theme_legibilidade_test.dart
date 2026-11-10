import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urutau/services/theme_provider.dart';

/// Contraste por tema: nenhum texto pode ficar invisível em nenhum dos temas.
///
/// MOTIVO (regressão real, introduzida pela própria correcção de um vazamento
/// de cor): o banner "parcela incompleta" tinha fundo `Colors.blue[50]` do
/// tema claro. Ao trocar o fundo para `colorScheme.surfaceContainerHighest`
/// — que é ESCURO nos temas escuros — o texto continuou `Colors.blue[900]`,
/// ficando invisível no alto contraste e no Kanagawa.
///
/// Estes testes fixam a regra: todo o par (fundo, texto) passa 4.5:1.
void main() {
  /// Razão de contraste WCAG entre duas cores (1.0 = igual, 21.0 = branco/preto).
  double contrast(Color a, Color b) {
    double lum(Color c) {
      double ch(double v) =>
          v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
      return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
    }

    final la = lum(a), lb = lum(b);
    final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  test('pares de texto passam 4.5:1 em TODOS os temas', () {
    for (final modo in ThemeModeUrutau.values) {
      final t = ThemeProvider.themeFor(modo);
      final cs = t.colorScheme;

      expect(contrast(cs.onSurface, cs.surface), greaterThanOrEqualTo(4.5),
          reason: '$modo: onSurface sobre surface');
      expect(contrast(cs.onSurface, t.scaffoldBackgroundColor),
          greaterThanOrEqualTo(4.5),
          reason: '$modo: onSurface sobre scaffold');
      expect(contrast(cs.onSurface, cs.surfaceContainerHighest),
          greaterThanOrEqualTo(4.5),
          reason: '$modo: onSurface sobre surfaceContainerHighest');
      expect(contrast(cs.onSurface, cs.surfaceContainerHigh),
          greaterThanOrEqualTo(4.5),
          reason: '$modo: onSurface sobre surfaceContainerHigh');
      expect(contrast(cs.onSurfaceVariant, cs.surfaceVariant),
          greaterThanOrEqualTo(4.5),
          reason: '$modo: texto secundario sobre surfaceVariant');

      // Label de botão: onPrimary sobre primary (par real dos botões).
      expect(contrast(cs.onPrimary, cs.primary), greaterThanOrEqualTo(4.5),
          reason: '$modo: onPrimary sobre primary (label de botao)');
      expect(contrast(cs.onPrimaryContainer, cs.primaryContainer),
          greaterThanOrEqualTo(4.5),
          reason: '$modo: onPrimaryContainer sobre primaryContainer');
      // AppBar: o título vive sobre appBarTheme.backgroundColor (não sobre
      // cs.surface — no claro os dois são brancos, o que daria 1.05).
      final appBarBg = t.appBarTheme.backgroundColor;
      if (appBarBg != null) {
        expect(
            contrast(t.appBarTheme.foregroundColor ?? cs.onSurface, appBarBg),
            greaterThanOrEqualTo(4.5),
            reason: '$modo: titulo da appbar sobre o fundo da appbar');
      }
    }
  });

  test('banner de parcela incompleta fica legivel nos 3 temas', () {
    // Regressao especifica: fundo do tema + texto do tema, nunca cor fixa.
    for (final modo in ThemeModeUrutau.values) {
      final cs = ThemeProvider.themeFor(modo).colorScheme;
      expect(contrast(cs.onSurface, cs.surfaceContainerHighest),
          greaterThanOrEqualTo(4.5),
          reason: '$modo: texto do banner sobre o fundo do banner');
      expect(contrast(cs.primary, cs.surfaceContainerHighest),
          greaterThanOrEqualTo(3.0),
          reason: '$modo: icone do banner sobre o fundo do banner');
    }
  });

  test('nao-texto (bordas e realce) passa 3:1 em todos os temas', () {
    for (final modo in ThemeModeUrutau.values) {
      final cs = ThemeProvider.themeFor(modo).colorScheme;
      expect(contrast(cs.primary, cs.surface), greaterThanOrEqualTo(3.0),
          reason: '$modo: realce sobre surface');
      expect(contrast(cs.primary, cs.surfaceContainerHighest),
          greaterThanOrEqualTo(3.0),
          reason: '$modo: realce sobre surfaceContainerHighest');
    }
  });
}
