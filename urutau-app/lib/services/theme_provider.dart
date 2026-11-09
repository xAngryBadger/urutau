import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_tokens.dart';

/// Os três temas do app. Persistido por nome em SharedPreferences.
enum ThemeModeUrutau { claro, altoContraste, kanagawa }

class ThemeProvider extends ChangeNotifier {
  static const _prefKey = 'theme_mode';
  // Toggle antigo (bool). Lido só na migração quando 'theme_mode' não existe.
  static const _legacyHcKey = 'high_contrast';

  ThemeModeUrutau _mode = ThemeModeUrutau.claro;
  ThemeModeUrutau get mode => _mode;

  /// Compat com chamadores antigos e com o seletor de Configurações.
  bool get isHighContrast => _mode == ThemeModeUrutau.altoContraste;

  /// Cache do ThemeData para não reconstruir a cada acesso.
  ThemeData? _cachedTheme;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefKey);
    if (stored != null) {
      _mode = ThemeModeUrutau.values.firstWhere(
        (m) => m.name == stored,
        orElse: () => ThemeModeUrutau.claro,
      );
    } else {
      // Migração: quem tinha o alto contraste ligado continua nele.
      final hc = prefs.getBool(_legacyHcKey) ?? false;
      _mode = hc ? ThemeModeUrutau.altoContraste : ThemeModeUrutau.claro;
    }
    _cachedTheme = themeFor(_mode);
    notifyListeners();
  }

  /// Persiste primeiro (a preferência já está salva quando a rota volta) e
  /// notifica de forma síncrona — o tema aplica antes de qualquer pop.
  Future<void> setMode(ThemeModeUrutau value) async {
    if (_mode == value) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, value.name);
    _mode = value;
    _cachedTheme = themeFor(_mode);
    notifyListeners();
  }

  /// Compat do toggle antigo: true → alto contraste, false → claro.
  Future<void> setHighContrast(bool value) async {
    await setMode(
        value ? ThemeModeUrutau.altoContraste : ThemeModeUrutau.claro);
  }

  ThemeData get theme => _cachedTheme ?? themeFor(_mode);

  static ThemeData themeFor(ThemeModeUrutau m) => switch (m) {
        ThemeModeUrutau.claro => _lightTheme,
        ThemeModeUrutau.altoContraste => _highContrastTheme,
        ThemeModeUrutau.kanagawa => _kanagawaTheme,
      };

  // ──────────────────────────── TEMA CLARO (padrão) ────────────────────────── //
  static final ThemeData _lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppTokens.brandPrimary,
      primary: AppTokens.brandPrimary,
      secondary: AppTokens.brandSecondary,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: AppTokens.brandBackground,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 2,
      backgroundColor: AppTokens.brandPrimary,
      foregroundColor: Colors.white,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: AppTokens.fontTitle,
        fontWeight: FontWeight.w600,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, AppTokens.buttonHeight),
        textStyle: const TextStyle(fontSize: AppTokens.fontBody),
        backgroundColor: AppTokens.brandPrimary,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, AppTokens.buttonHeight),
        textStyle: const TextStyle(fontSize: AppTokens.fontBody),
        backgroundColor: AppTokens.brandPrimary,
        foregroundColor: Colors.white,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceL, vertical: AppTokens.spaceL),
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
      ),
    ),
  );

  // ───────────── TEMA ALTO CONTRASTE (preto/amarelo/branco, AA) ───────────── //
  // Otimizado para leitura sob luz solar direta. Todo componente que antes
  // vazava cor clara (chips, cards, snackbar, diálogo, switch, slider, input)
  // é fixado aqui no par preto/amarelo/branco. Contraste verificado em
  // test/theme_contrast_test.dart (WCAG 2.2 AA).
  static final ThemeData _highContrastTheme = ThemeData(
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: AppTokens.hcPrimary,
      onPrimary: AppTokens.hcOnPrimary,
      primaryContainer: AppTokens.hcSurface2,
      onPrimaryContainer: AppTokens.hcPrimary,
      secondary: AppTokens.hcPrimary,
      onSecondary: AppTokens.hcOnPrimary,
      secondaryContainer: AppTokens.hcSurface2,
      onSecondaryContainer: AppTokens.hcPrimary,
      tertiary: AppTokens.hcPrimary,
      onTertiary: AppTokens.hcOnPrimary,
      tertiaryContainer: AppTokens.hcSurface2,
      onTertiaryContainer: AppTokens.hcPrimary,
      error: Color(0xFFFF6B6B),
      onError: AppTokens.hcOnPrimary,
      errorContainer: Color(0xFF3A0000),
      onErrorContainer: Color(0xFFFFD6D6),
      surface: AppTokens.hcSurface,
      onSurface: AppTokens.hcText,
      surfaceContainerLowest: AppTokens.hcBackground,
      surfaceContainerLow: AppTokens.hcSurface,
      surfaceContainer: AppTokens.hcSurface,
      surfaceContainerHigh: AppTokens.hcSurface2,
      surfaceContainerHighest: AppTokens.hcSurface2,
      surfaceVariant: AppTokens.hcSurface2,
      onSurfaceVariant: AppTokens.hcTextMuted,
      surfaceDim: AppTokens.hcSurface,
      surfaceBright: AppTokens.hcSurface2,
      surfaceTint: AppTokens.hcPrimary,
      inverseSurface: AppTokens.hcText,
      onInverseSurface: AppTokens.hcOnPrimary,
      inversePrimary: AppTokens.hcOnPrimary,
      outline: AppTokens.hcOutline,
      outlineVariant: AppTokens.hcDivider,
      scrim: Colors.black,
      shadow: Colors.black,
    ),
    useMaterial3: true,
    applyElevationOverlayColor: false,
    scaffoldBackgroundColor: AppTokens.hcBackground,
    canvasColor: AppTokens.hcBackground,
    // O tema claro também fixa titleTextStyle com 20/bold, por isso aqui fica
    // igual — os dois temas têm de ter a MESMA métrica de appbar.
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: AppTokens.hcSurface2,
      foregroundColor: AppTokens.hcPrimary,
      titleTextStyle: TextStyle(
        color: AppTokens.hcPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: AppTokens.hcPrimary),
      actionsIconTheme: IconThemeData(color: AppTokens.hcPrimary),
    ),
    // REGRA (regressão medida em test/hc_spacing_test.dart): o alto contraste
    // muda SÓ a cor. Os tamanhos e pesos abaixo são EXACTAMENTE os padrões
    // Material 3 que o tema claro herda — medidos com o probe em
    // test/hc_probe_test.dart. Antes este bloco fixava bodyMedium=15,
    // bodySmall=13, titleLarge=20, labelLarge=16 e pesos bold/w600/w700, o que
    // tornava o texto mais largo e mais alto: o layout "respirava" diferente
    // entre temas. Contraste vem da COR (branco sobre preto = 21:1), não do
    // peso. A altura extra do bold não é necessária para AA.
    textTheme: TextTheme(
      bodyLarge:
          const TextStyle(color: AppTokens.hcText, fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium:
          const TextStyle(color: AppTokens.hcText, fontSize: 14, fontWeight: FontWeight.w400),
      bodySmall:
          const TextStyle(color: AppTokens.hcTextMuted, fontSize: 12, fontWeight: FontWeight.w400),
      titleLarge:
          const TextStyle(color: AppTokens.hcText, fontSize: 22, fontWeight: FontWeight.w400),
      titleMedium:
          const TextStyle(color: AppTokens.hcText, fontSize: 16, fontWeight: FontWeight.w500),
      titleSmall:
          const TextStyle(color: AppTokens.hcText, fontSize: 14, fontWeight: FontWeight.w500),
      labelLarge:
          const TextStyle(color: AppTokens.hcText, fontSize: 14, fontWeight: FontWeight.w500),
      labelMedium:
          const TextStyle(color: AppTokens.hcText, fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall:
          const TextStyle(color: AppTokens.hcText, fontSize: 11, fontWeight: FontWeight.w500),
    ),
    iconTheme: const IconThemeData(color: AppTokens.hcPrimary),
    primaryIconTheme: const IconThemeData(color: AppTokens.hcOnPrimary),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, AppTokens.buttonHeight),
        // fontSize 16 = bodyLarge; peso w500 = labelLarge (padrão M3).
        // ANTES era bold — largura maior, texto embrulhava antes, layout mudava.
        textStyle: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w500),
        backgroundColor: AppTokens.hcPrimary,
        foregroundColor: AppTokens.hcOnPrimary,
        side: const BorderSide(color: AppTokens.hcOutline, width: 2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, AppTokens.buttonHeight),
        textStyle: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w500),
        backgroundColor: AppTokens.hcPrimary,
        foregroundColor: AppTokens.hcOnPrimary,
        side: const BorderSide(color: AppTokens.hcOutline, width: 2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, AppTokens.buttonHeight),
        foregroundColor: AppTokens.hcPrimary,
        textStyle: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w500),
        side: const BorderSide(color: AppTokens.hcOutline, width: 2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppTokens.hcPrimary,
        textStyle: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppTokens.hcSurface,
      border: OutlineInputBorder(
        borderSide: BorderSide(color: AppTokens.hcOutline, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppTokens.hcOutline, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppTokens.hcPrimary, width: 2.5),
      ),
      labelStyle: const TextStyle(color: AppTokens.hcPrimary, fontSize: 16),
      hintStyle: const TextStyle(color: AppTokens.hcTextMuted, fontSize: 16),
    ),
    cardTheme: CardThemeData(
      color: AppTokens.hcSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
        side: const BorderSide(color: AppTokens.hcOutline, width: 1.5),
      ),
    ),
    // thickness = 16 é a ALTURA do Divider (não a espessura da linha), e é o
    // padrão Material 3. Manter em 16 preserva o espaçamento; a espessura
    // visível da linha continua a da borda (hcOutline), que é o que dá
    // contraste. Antes era thickness 2, o que mudava a altura ocupada.
    dividerTheme: const DividerThemeData(
      color: AppTokens.hcDivider,
      thickness: 1,
      space: 16,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppTokens.hcSurface2,
      contentTextStyle: TextStyle(color: AppTokens.hcText, fontSize: 14),
      actionTextColor: AppTokens.hcPrimary,
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: AppTokens.hcSurface2,
      textStyle: TextStyle(color: AppTokens.hcText, fontSize: 14),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppTokens.hcSurface,
      surfaceTintColor: Colors.transparent,
      // 22/w400 = titleLarge do Material 3; 14/w400 = bodyMedium.
      titleTextStyle: TextStyle(
        color: AppTokens.hcPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w400,
      ),
      contentTextStyle: TextStyle(color: AppTokens.hcText, fontSize: 14),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: AppTokens.hcText,
      iconColor: AppTokens.hcPrimary,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppTokens.hcSurface2,
      selectedColor: AppTokens.hcPrimary,
      disabledColor: AppTokens.hcSurface2,
      labelStyle: const TextStyle(color: AppTokens.hcText, fontSize: 14),
      secondaryLabelStyle: const TextStyle(color: AppTokens.hcText),
      brightness: Brightness.dark,
      side: const BorderSide(color: AppTokens.hcOutline, width: 1.5),
      checkmarkColor: AppTokens.hcOnPrimary,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppTokens.hcOnPrimary; // "bola" preta sobre trilha amarela
        }
        return AppTokens.hcTextMuted;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppTokens.hcPrimary;
        }
        return AppTokens.hcSurface2;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppTokens.hcOutline
              : AppTokens.hcTextMuted),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppTokens.hcPrimary,
      inactiveTrackColor: AppTokens.hcDivider,
      thumbColor: AppTokens.hcPrimary,
      overlayColor: AppTokens.hcPrimary.withValues(alpha: 0.2),
      valueIndicatorColor: AppTokens.hcPrimary,
      valueIndicatorTextStyle: const TextStyle(
        color: AppTokens.hcOnPrimary,
        fontWeight: FontWeight.bold,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? AppTokens.hcPrimary
              : Colors.transparent),
      checkColor: WidgetStateProperty.all(AppTokens.hcOnPrimary),
      side: const BorderSide(color: AppTokens.hcOutline, width: 2),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? AppTokens.hcPrimary
              : AppTokens.hcDivider),
    ),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(color: AppTokens.hcPrimary),
      textStyle: TextStyle(color: AppTokens.hcOnPrimary),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppTokens.hcPrimary,
      linearTrackColor: AppTokens.hcSurface2,
      circularTrackColor: AppTokens.hcSurface2,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppTokens.hcSurface2,
      surfaceTintColor: Colors.transparent,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppTokens.hcPrimary,
      unselectedLabelColor: AppTokens.hcTextMuted,
      indicatorColor: AppTokens.hcPrimary,
    ),
  );

  // ─────────────────── TEMA KANAGAWA (escuro, paleta nvim) ─────────────────── //
  static final ThemeData _kanagawaTheme = ThemeData(
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: AppTokens.kwPrimary,
      onPrimary: AppTokens.kwSumiInk,
      primaryContainer: AppTokens.kwWaveBlue1,
      onPrimaryContainer: AppTokens.kwCrystalBlue,
      secondary: AppTokens.kwSecondary,
      onSecondary: AppTokens.kwSumiInk,
      secondaryContainer: AppTokens.kwWaveBlue1,
      onSecondaryContainer: AppTokens.kwLightBlue,
      tertiary: AppTokens.kwCrystalBlue,
      onTertiary: AppTokens.kwSumiInk,
      tertiaryContainer: AppTokens.kwWaveBlue1,
      onTertiaryContainer: AppTokens.kwLightBlue,
      error: AppTokens.kwWaveRed,
      onError: AppTokens.kwSumiInk,
      errorContainer: Color(0xFF3A1B22),
      onErrorContainer: AppTokens.kwSakuraPink,
      surface: AppTokens.kwSurface,
      onSurface: AppTokens.kwFujiWhite,
      surfaceContainerLowest: AppTokens.kwSumiInk,
      surfaceContainerLow: AppTokens.kwSumiInk,
      surfaceContainer: AppTokens.kwSurface,
      surfaceContainerHigh: AppTokens.kwWaveBlue1,
      surfaceContainerHighest: AppTokens.kwWaveBlue1,
      surfaceVariant: AppTokens.kwWaveBlue1,
      onSurfaceVariant: AppTokens.kwFujiWhite,
      surfaceDim: AppTokens.kwSurface,
      surfaceBright: AppTokens.kwWaveBlue1,
      surfaceTint: AppTokens.kwPrimary,
      inverseSurface: AppTokens.kwFujiWhite,
      onInverseSurface: AppTokens.kwSumiInk,
      inversePrimary: AppTokens.kwSumiInk,
      outline: AppTokens.kwPrimary,
      outlineVariant: AppTokens.kwSecondary,
      scrim: Colors.black,
      shadow: Colors.black,
    ),
    useMaterial3: true,
    applyElevationOverlayColor: false,
    scaffoldBackgroundColor: AppTokens.kwSumiInk,
    canvasColor: AppTokens.kwSumiInk,
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: AppTokens.kwSurface,
      foregroundColor: AppTokens.kwFujiWhite,
      titleTextStyle: TextStyle(
        color: AppTokens.kwFujiWhite,
        fontSize: AppTokens.fontTitle,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: AppTokens.kwDragonBlue),
      actionsIconTheme: IconThemeData(color: AppTokens.kwDragonBlue),
    ),
    // Mesma regra do alto contraste (ver nota em _highContrastTheme): mudar
    // SÓ a cor. Os tamanhos/pesos são os padrões Material 3; antes este bloco
    // fixava 15/13/20/16 e pesos bold/w600/w700, o que fazia o texto embrulhar
    // noutro ponto e mudava o espaçamento do app.
    textTheme: const TextTheme(
      bodyLarge:
          TextStyle(color: AppTokens.kwFujiWhite, fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium:
          TextStyle(color: AppTokens.kwFujiWhite, fontSize: 14, fontWeight: FontWeight.w400),
      bodySmall:
          TextStyle(color: AppTokens.kwFujiWhite, fontSize: 12, fontWeight: FontWeight.w400),
      titleLarge:
          TextStyle(color: AppTokens.kwFujiWhite, fontSize: 22, fontWeight: FontWeight.w400),
      titleMedium:
          TextStyle(color: AppTokens.kwFujiWhite, fontSize: 16, fontWeight: FontWeight.w500),
      titleSmall:
          TextStyle(color: AppTokens.kwFujiWhite, fontSize: 14, fontWeight: FontWeight.w500),
      labelLarge:
          TextStyle(color: AppTokens.kwSumiInk, fontSize: 14, fontWeight: FontWeight.w500),
      labelMedium:
          TextStyle(color: AppTokens.kwSumiInk, fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall:
          TextStyle(color: AppTokens.kwSumiInk, fontSize: 11, fontWeight: FontWeight.w500),
    ),
    iconTheme: const IconThemeData(color: AppTokens.kwDragonBlue),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, AppTokens.buttonHeight),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        backgroundColor: AppTokens.kwPrimary,
        foregroundColor: AppTokens.kwSumiInk,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, AppTokens.buttonHeight),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        backgroundColor: AppTokens.kwPrimary,
        foregroundColor: AppTokens.kwSumiInk,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, AppTokens.buttonHeight),
        foregroundColor: AppTokens.kwDragonBlue,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        side: const BorderSide(color: AppTokens.kwPrimary, width: 1.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppTokens.kwDragonBlue,
        textStyle: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.bold),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppTokens.kwWaveBlue1,
      border: OutlineInputBorder(
        borderSide: BorderSide(color: AppTokens.kwPrimary, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppTokens.kwSecondary, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppTokens.kwPrimary, width: 2.5),
      ),
      labelStyle: const TextStyle(color: AppTokens.kwDragonBlue, fontSize: 16),
      hintStyle: const TextStyle(color: AppTokens.kwLightBlue, fontSize: 16),
    ),
    cardTheme: CardThemeData(
      color: AppTokens.kwSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
        side: const BorderSide(color: AppTokens.kwDragonBlue, width: 1),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppTokens.kwDragonBlue,
      thickness: 1,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppTokens.kwSurface,
      contentTextStyle: TextStyle(color: AppTokens.kwFujiWhite, fontSize: 14),
      actionTextColor: AppTokens.kwLightBlue,
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: AppTokens.kwSurface,
      textStyle: TextStyle(color: AppTokens.kwFujiWhite, fontSize: 14),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppTokens.kwSurface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: const TextStyle(
        color: AppTokens.kwDragonBlue,
        fontSize: 22,
        fontWeight: FontWeight.w400,
      ),
      contentTextStyle: TextStyle(color: AppTokens.kwFujiWhite, fontSize: 14),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: AppTokens.kwFujiWhite,
      iconColor: AppTokens.kwDragonBlue,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppTokens.kwWaveBlue1,
      selectedColor: AppTokens.kwDragonBlue,
      disabledColor: AppTokens.kwWaveBlue1,
      labelStyle: const TextStyle(color: AppTokens.kwFujiWhite, fontSize: 14),
      secondaryLabelStyle: const TextStyle(color: AppTokens.kwFujiWhite),
      brightness: Brightness.dark,
      side: const BorderSide(color: AppTokens.kwSecondary, width: 1),
      checkmarkColor: AppTokens.kwSumiInk,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppTokens.kwSumiInk;
        }
        return AppTokens.kwFujiWhite;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppTokens.kwPrimary;
        }
        return AppTokens.kwWaveBlue1;
      }),
      trackOutlineColor: WidgetStateProperty.all(AppTokens.kwSecondary),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppTokens.kwPrimary,
      inactiveTrackColor: AppTokens.kwWaveBlue1,
      thumbColor: AppTokens.kwPrimary,
      overlayColor: AppTokens.kwPrimary.withValues(alpha: 0.2),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? AppTokens.kwPrimary
              : Colors.transparent),
      checkColor: WidgetStateProperty.all(AppTokens.kwSumiInk),
      side: const BorderSide(color: AppTokens.kwDragonBlue, width: 2),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? AppTokens.kwPrimary
              : AppTokens.kwSecondary),
    ),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(color: AppTokens.kwDragonBlue),
      textStyle: TextStyle(color: AppTokens.kwSumiInk, fontWeight: FontWeight.bold),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppTokens.kwPrimary,
      linearTrackColor: AppTokens.kwWaveBlue1,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppTokens.kwSurface,
      surfaceTintColor: Colors.transparent,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppTokens.kwFujiWhite,
      unselectedLabelColor: AppTokens.kwSecondary,
      indicatorColor: AppTokens.kwDragonBlue,
    ),
  );
}
