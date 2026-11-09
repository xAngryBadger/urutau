import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urutau/services/theme_provider.dart';
import 'package:urutau/theme/app_tokens.dart';

/// Regressão de espaçamento: alto contraste NÃO pode mudar a métrica do app.
///
/// RECLAMAÇÃO DO USUÁRIO: "high contrast mode changes the spacing of the app
/// for some fucking reason."
///
/// CAUSA MEDIDA (test/hc_probe_test.dart): o tema alto contraste fixava
/// textTheme com tamanhos e pesos DIFERENTES dos padrões Material 3 que o tema
/// claro herda — bodyMedium 15 vs 14, bodySmall 13 vs 12, titleLarge 20 vs 22,
/// labelLarge 16 vs 14, e pesos bold/w600/w700 vs w400/w500. Texto mais largo
/// embrulha mais cedo → mais linhas → layout "respira" diferente.
///
/// A correcção: mudar SÓ a cor no textTheme (contraste vem da cor, não do peso).
/// Estes testes fixam isso e detectam a regressão.
void main() {
  // Valores padrão Material 3, medidos a partir do tema claro resolvido.
  const m3 = <String, double>{
    'bodyLarge': 16,
    'bodyMedium': 14,
    'bodySmall': 12,
    'titleLarge': 22,
    'titleMedium': 16,
    'titleSmall': 14,
    'labelLarge': 14,
    'labelMedium': 12,
    'labelSmall': 11,
  };
  const m3Weight = <String, FontWeight>{
    'bodyLarge': FontWeight.w400,
    'bodyMedium': FontWeight.w400,
    'bodySmall': FontWeight.w400,
    'titleLarge': FontWeight.w400,
    'titleMedium': FontWeight.w500,
    'titleSmall': FontWeight.w500,
    'labelLarge': FontWeight.w500,
    'labelMedium': FontWeight.w500,
    'labelSmall': FontWeight.w500,
  };

  TextTheme stylesOf(ThemeData t) => t.textTheme;
  double? sizeOf(ThemeData t, String key) {
    final s = stylesOf(t);
    return switch (key) {
      'bodyLarge' => s.bodyLarge?.fontSize,
      'bodyMedium' => s.bodyMedium?.fontSize,
      'bodySmall' => s.bodySmall?.fontSize,
      'titleLarge' => s.titleLarge?.fontSize,
      'titleMedium' => s.titleMedium?.fontSize,
      'titleSmall' => s.titleSmall?.fontSize,
      'labelLarge' => s.labelLarge?.fontSize,
      'labelMedium' => s.labelMedium?.fontSize,
      'labelSmall' => s.labelSmall?.fontSize,
      _ => null,
    };
  }

  FontWeight? weightOf(ThemeData t, String key) {
    final s = stylesOf(t);
    return switch (key) {
      'bodyLarge' => s.bodyLarge?.fontWeight,
      'bodyMedium' => s.bodyMedium?.fontWeight,
      'bodySmall' => s.bodySmall?.fontWeight,
      'titleLarge' => s.titleLarge?.fontWeight,
      'titleMedium' => s.titleMedium?.fontWeight,
      'titleSmall' => s.titleSmall?.fontWeight,
      'labelLarge' => s.labelLarge?.fontWeight,
      'labelMedium' => s.labelMedium?.fontWeight,
      'labelSmall' => s.labelSmall?.fontWeight,
      _ => null,
    };
  }

  test('alto contraste usa a MESMA métrica de texto que o Material 3',
      () {
    final hc = ThemeProvider.themeFor(ThemeModeUrutau.altoContraste);
    for (final key in m3.keys) {
      expect(sizeOf(hc, key), m3[key],
          reason: '$key mudou de tamanho no alto contraste');
      expect(weightOf(hc, key), m3Weight[key],
          reason: '$key mudou de peso no alto contraste');
    }
  });

  test('alto contraste mantém o contraste AA (cor, não peso)', () {
    final hc = ThemeProvider.themeFor(ThemeModeUrutau.altoContraste);
    // Texto principal branco puro sobre superfície preta: 21:1.
    expect(hc.textTheme.bodyLarge?.color, AppTokens.hcText);
    expect(hc.textTheme.bodySmall?.color, AppTokens.hcTextMuted);
    // A appbar continua amarela sobre preto (realce AA).
    expect(hc.appBarTheme.backgroundColor, AppTokens.hcSurface2);
    expect(hc.appBarTheme.foregroundColor, AppTokens.hcPrimary);
  });

  test('TODOS os temas usam a mesma métrica de texto', () {
    // Kanagawa e alto contraste são variações de cor do mesmo layout. Se um
    // deles fixar tamanho/peso diferente, o espaçamento muda ao trocar de tema.
    // O tema claro não define textTheme de todo — isso é legítimo (herda os
    // padrões Material 3), e é justamente o valor que os outros temas devem
    // reproduzir quando os definem.
    for (final modo in ThemeModeUrutau.values) {
      final t = ThemeProvider.themeFor(modo);
      for (final key in m3.keys) {
        final size = sizeOf(t, key);
        final weight = weightOf(t, key);
        if (size == null && weight == null) continue; // herda Material 3
        expect(size, m3[key],
            reason: '$modo/$key mudou de tamanho (${size ?? 'null'})');
        expect(weight, m3Weight[key],
            reason: '$modo/$key mudou de peso (${weight ?? 'null'})');
      }
    }
  });

  testWidgets('trocar de tema não muda o layout (os três)',
      (tester) async {
    const kSample = Key('sample3');

    Widget sample() => Builder(builder: (c) {
          final t = Theme.of(c).textTheme;
          return Column(
            key: kSample,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Eucalyptus grandis', style: t.bodyLarge),
              Text('Handroanthus heptaphyllus', style: t.bodyMedium),
              Text('Cecropia pachystachya', style: t.bodySmall),
              Text('UT-90', style: t.titleLarge),
              Text('Parcela 90', style: t.titleMedium),
              const ListTile(
                  title: Text('Fazenda Volume'), subtitle: Text('1 UT')),
              ElevatedButton(
                  onPressed: () {}, child: const Text('Continuar')),
              OutlinedButton(
                  onPressed: () {}, child: const Text('Continuar')),
            ],
          );
        });

    Future<Size> measure(WidgetTester t, ThemeData theme) async {
      await t.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 300, child: sample()),
          ),
        ),
      ));
      return t.getSize(find.byKey(kSample));
    }

    final base = await measure(
        tester, ThemeProvider.themeFor(ThemeModeUrutau.claro));
    for (final modo in ThemeModeUrutau.values) {
      final s = await measure(tester, ThemeProvider.themeFor(modo));
      expect((s.height - base.height).abs(), lessThanOrEqualTo(1),
          reason: '$modo: altura difere do claro: base=$base modo=$s');
      expect((s.width - base.width).abs(), lessThanOrEqualTo(1),
          reason: '$modo: largura difere do claro: base=$base modo=$s');
    }
  });

  testWidgets('alto contraste ocupa o MESMO espaço que o tema claro',
      (tester) async {
    const kSample = Key('sample');

    Widget sample() => Builder(builder: (c) {
          final t = Theme.of(c).textTheme;
          return Column(
            key: kSample,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Eucalyptus grandis', style: t.bodyLarge),
              Text('Handroanthus heptaphyllus', style: t.bodyMedium),
              Text('Cecropia pachystachya', style: t.bodySmall),
              Text('UT-90', style: t.titleLarge),
              Text('Parcela 90', style: t.titleMedium),
              Text('Pendente', style: t.titleSmall),
              Text('Continuar', style: t.labelLarge),
              const ListTile(
                  title: Text('Fazenda Volume'), subtitle: Text('1 UT')),
              ElevatedButton(
                  onPressed: () {}, child: const Text('Continuar')),
              OutlinedButton(
                  onPressed: () {}, child: const Text('Continuar')),
              TextButton(onPressed: () {}, child: const Text('Continuar')),
            ],
          );
        });

    Future<Size> measure(WidgetTester t, ThemeData theme) async {
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 300, child: sample()),
          ),
        ),
      ));
      return tester.getSize(find.byKey(kSample));
    }

    final claro =
        await measure(tester, ThemeProvider.themeFor(ThemeModeUrutau.claro));
    final hc = await measure(
        tester, ThemeProvider.themeFor(ThemeModeUrutau.altoContraste));

    expect((hc.height - claro.height).abs(), lessThanOrEqualTo(1),
        reason: 'altura difere entre os temas: claro=$claro hc=$hc');
    expect((hc.width - claro.width).abs(), lessThanOrEqualTo(1),
        reason: 'largura difere entre os temas: claro=$claro hc=$hc');
  });
}



