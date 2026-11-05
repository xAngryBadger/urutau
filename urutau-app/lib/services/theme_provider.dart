import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_tokens.dart';

class ThemeProvider extends ChangeNotifier {
  static const _prefKey = 'high_contrast';

  bool _isHighContrast = false;
  bool get isHighContrast => _isHighContrast;

  /// Cache current theme to avoid rebuilding ThemeData on every access.
  ThemeData? _cachedTheme;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isHighContrast = prefs.getBool(_prefKey) ?? false;
    _cachedTheme = _isHighContrast ? _highContrastTheme : _lightTheme;
    notifyListeners();
  }

  /// Persists first so that when user navigates back the preference is already saved.
  /// Notifies synchronously so the theme applies before any route pop (avoids "turns off on back").
  Future<void> setHighContrast(bool value) async {
    if (_isHighContrast == value) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
    _isHighContrast = value;
    _cachedTheme = _isHighContrast ? _highContrastTheme : _lightTheme;
    notifyListeners();
  }

  ThemeData get theme => _cachedTheme ?? (_isHighContrast ? _highContrastTheme : _lightTheme);

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

  // ────────────────── TEMA ALTO CONTRASTE (preto + amarelo) ────────────────── //
  // Otimizado para leitura sob luz solar direta
  static final ThemeData _highContrastTheme = ThemeData(
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: AppTokens.hcPrimary,       // Amarelo vibrante
      onPrimary: AppTokens.hcOnPrimary,
      primaryContainer: AppTokens.hcOutline,
      onPrimaryContainer: AppTokens.hcPrimary,
      secondary: Color(0xFFFFC107),     // Âmbar
      onSecondary: AppTokens.hcOnPrimary,
      secondaryContainer: Color(0xFF332800),
      onSecondaryContainer: AppTokens.hcPrimary,
      error: Color(0xFFFF4444),
      onError: AppTokens.hcOnPrimary,
      surface: Color(0xFF0A0A0A),
      onSurface: AppTokens.hcText,
      surfaceContainerHighest: Color(0xFF1A1A1A),
      onSurfaceVariant: Color(0xFFDDDDDD),
      outline: AppTokens.hcPrimary,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: AppTokens.hcBackground,
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: AppTokens.hcSurface2,
      foregroundColor: AppTokens.hcPrimary,
      titleTextStyle: TextStyle(
        color: AppTokens.hcPrimary,
        fontSize: AppTokens.fontTitle,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: AppTokens.hcPrimary),
      actionsIconTheme: IconThemeData(color: AppTokens.hcPrimary),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppTokens.hcText, fontSize: AppTokens.fontBody),
      bodyMedium: TextStyle(color: Color(0xFFF0F0F0), fontSize: 15),
      bodySmall: TextStyle(color: Color(0xFFDDDDDD), fontSize: AppTokens.fontSmall),
      titleLarge: TextStyle(
        color: AppTokens.hcText,
        fontWeight: FontWeight.bold,
        fontSize: AppTokens.fontTitle,
      ),
      titleMedium: TextStyle(
        color: AppTokens.hcText,
        fontWeight: FontWeight.w600,
        fontSize: AppTokens.fontBody,
      ),
      labelLarge: TextStyle(
        color: AppTokens.hcOnPrimary,
        fontWeight: FontWeight.bold,
        fontSize: AppTokens.fontBody,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, AppTokens.buttonHeight),
        textStyle: const TextStyle(
            fontSize: AppTokens.fontBody, fontWeight: FontWeight.bold),
        backgroundColor: AppTokens.hcPrimary,
        foregroundColor: AppTokens.hcOnPrimary,
        side: const BorderSide(color: AppTokens.hcPrimary, width: 2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, AppTokens.buttonHeight),
        textStyle: const TextStyle(
            fontSize: AppTokens.fontBody, fontWeight: FontWeight.bold),
        backgroundColor: AppTokens.hcPrimary,
        foregroundColor: AppTokens.hcOnPrimary,
        side: const BorderSide(color: AppTokens.hcPrimary, width: 2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppTokens.hcPrimary,
        textStyle: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.bold),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFF111111),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFFB8960A), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF8B7200), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppTokens.hcPrimary, width: 2),
      ),
      labelStyle: TextStyle(color: AppTokens.hcPrimary, fontSize: 15),
      hintStyle: TextStyle(color: Color(0xFF777777)),
      contentPadding: EdgeInsets.symmetric(
          horizontal: AppTokens.spaceL, vertical: AppTokens.spaceL),
    ),
    cardTheme: CardThemeData(
      color: AppTokens.hcSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusM),
        side: const BorderSide(color: AppTokens.hcOutline, width: 1),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppTokens.hcOutline),
    iconTheme: const IconThemeData(color: AppTokens.hcPrimary),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppTokens.hcSurface2,
      contentTextStyle: TextStyle(color: AppTokens.hcText),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: AppTokens.hcSurface2,
      textStyle: TextStyle(color: AppTokens.hcText, fontSize: 15),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppTokens.hcSurface,
      titleTextStyle: TextStyle(
        color: AppTokens.hcPrimary,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: AppTokens.hcText,
      iconColor: AppTokens.hcPrimary,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFFFFD600);
        }
        return const Color(0xFF555555);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFF332B00);
        }
        return const Color(0xFF222222);
      }),
    ),
  );
}
