import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF5A6B5C);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFDDE4DD);
  static const Color onPrimaryContainer = Color(0xFF1B2E1D);
  static const Color secondary = Color(0xFFC4A47C);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFFADEC0);
  static const Color onSecondaryContainer = Color(0xFF2C1F0F);
  static const Color tertiary = Color(0xFF6B8F6B);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFD4E8D4);
  static const Color onTertiaryContainer = Color(0xFF234023);
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF410002);
  static const Color surface = Color(0xFFF9F6F0);
  static const Color onSurface = Color(0xFF1A1C18);
  static const Color onSurfaceVariant = Color(0xFF43483F);
  static const Color outlineVariant = Color(0xFFC3C8BB);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF3F0EA);
  static const Color surfaceContainerHighest = Color(0xFFE3E0DA);

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: onSurfaceVariant,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    color: onSurface,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    color: onSurface,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: onSurface,
  );
}
