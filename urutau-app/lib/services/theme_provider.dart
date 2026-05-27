import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      seedColor: const Color(0xFF5A6B5C),
      primary: const Color(0xFF5A6B5C),
      secondary: const Color(0xFFC4A47C),
      brightness: Brightness.light,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFF9F6F0),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 2,
      backgroundColor: Color(0xFF5A6B5C),
      foregroundColor: Colors.white,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        textStyle: const TextStyle(fontSize: 16),
        backgroundColor: const Color(0xFF5A6B5C),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 52),
        textStyle: const TextStyle(fontSize: 16),
        backgroundColor: const Color(0xFF5A6B5C),
        foregroundColor: Colors.white,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );

  // ────────────────── TEMA ALTO CONTRASTE (preto + amarelo) ────────────────── //
  // Otimizado para leitura sob luz solar direta
  static final ThemeData _highContrastTheme = ThemeData(
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFFFD600),       // Amarelo vibrante
      onPrimary: Color(0xFF000000),
      primaryContainer: Color(0xFF332B00),
      onPrimaryContainer: Color(0xFFFFD600),
      secondary: Color(0xFFFFC107),     // Âmbar
      onSecondary: Color(0xFF000000),
      secondaryContainer: Color(0xFF332800),
      onSecondaryContainer: Color(0xFFFFC107),
      error: Color(0xFFFF4444),
      onError: Color(0xFF000000),
      surface: Color(0xFF0A0A0A),
      onSurface: Color(0xFFFFFFFF),
      surfaceContainerHighest: Color(0xFF1A1A1A),
      onSurfaceVariant: Color(0xFFDDDDDD),
      outline: Color(0xFFFFD600),
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFF000000),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Color(0xFF1A1500),
      foregroundColor: Color(0xFFFFD600),
      titleTextStyle: TextStyle(
        color: Color(0xFFFFD600),
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: Color(0xFFFFD600)),
      actionsIconTheme: IconThemeData(color: Color(0xFFFFD600)),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFFFFFFFF), fontSize: 16),
      bodyMedium: TextStyle(color: Color(0xFFF0F0F0), fontSize: 15),
      bodySmall: TextStyle(color: Color(0xFFDDDDDD), fontSize: 13),
      titleLarge: TextStyle(
        color: Color(0xFFFFFFFF),
        fontWeight: FontWeight.bold,
        fontSize: 20,
      ),
      titleMedium: TextStyle(
        color: Color(0xFFFFFFFF),
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      labelLarge: TextStyle(
        color: Color(0xFF000000),
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        backgroundColor: const Color(0xFFFFD600),
        foregroundColor: const Color(0xFF000000),
        side: const BorderSide(color: Color(0xFFFFD600), width: 2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        backgroundColor: const Color(0xFFFFD600),
        foregroundColor: const Color(0xFF000000),
        side: const BorderSide(color: Color(0xFFFFD600), width: 2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFFFFD600),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
        borderSide: BorderSide(color: Color(0xFFFFD600), width: 2),
      ),
      labelStyle: TextStyle(color: Color(0xFFFFD600), fontSize: 15),
      hintStyle: TextStyle(color: Color(0xFF777777)),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF141200),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF332B00), width: 1),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFF332B00)),
    iconTheme: const IconThemeData(color: Color(0xFFFFD600)),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF1A1500),
      contentTextStyle: TextStyle(color: Color(0xFFFFFFFF)),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: Color(0xFF1A1500),
      textStyle: TextStyle(color: Color(0xFFFFFFFF), fontSize: 15),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Color(0xFF141200),
      titleTextStyle: TextStyle(
        color: Color(0xFFFFD600),
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: Color(0xFFFFFFFF),
      iconColor: Color(0xFFFFD600),
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
