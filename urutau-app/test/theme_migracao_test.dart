// ============================================================
// theme_migracao_test.dart — t18: remoção do tema Kanagawa.
//
// Ponto perigoso da remoção: quem tem `theme_mode = 'kanagawa'` (ou
// qualquer valor desconhecido) nas SharedPreferences NÃO pode crashar nem
// ficar sem tema. ThemeProvider.init() usa firstWhere com
// orElse: () => ThemeModeUrutau.claro, e _cachedTheme é sempre
// themeFor(_mode) — este teste fixa as duas coisas.
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urutau/services/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pref antiga "kanagawa" arranca em CLARO, sem crash e com tema válido',
      () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'kanagawa'});
    final p = ThemeProvider();
    await p.init();
    expect(p.mode, ThemeModeUrutau.claro,
        reason: 'valor removido tem de cair no orElse -> claro');
    expect(p.theme, isNotNull);
    expect(identical(p.theme, ThemeProvider.themeFor(ThemeModeUrutau.claro)),
        isTrue,
        reason: '_cachedTheme tem de ser o tema claro (cache coeso com o modo)');
    expect(p.isHighContrast, isFalse);
  });

  test('pref com valor completamente desconhecido também cai em claro',
      () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'tema-do-futuro'});
    final p = ThemeProvider();
    await p.init();
    expect(p.mode, ThemeModeUrutau.claro);
    expect(p.theme, isNotNull);
  });

  test('prefs válidas continuam a funcionar (claro e alto contraste)', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'altoContraste'});
    final p = ThemeProvider();
    await p.init();
    expect(p.mode, ThemeModeUrutau.altoContraste);
    expect(p.isHighContrast, isTrue);
    expect(identical(p.theme, ThemeProvider.themeFor(ThemeModeUrutau.altoContraste)),
        isTrue);

    SharedPreferences.setMockInitialValues({'theme_mode': 'claro'});
    final p2 = ThemeProvider();
    await p2.init();
    expect(p2.mode, ThemeModeUrutau.claro);
  });

  test('sem pref usa a migração legada (high_contrast bool)', () async {
    SharedPreferences.setMockInitialValues({'high_contrast': true});
    final p = ThemeProvider();
    await p.init();
    expect(p.mode, ThemeModeUrutau.altoContraste);
  });

  test('enum ficou com exactamente dois valores', () {
    expect(ThemeModeUrutau.values, [ThemeModeUrutau.claro, ThemeModeUrutau.altoContraste]);
  });
}
