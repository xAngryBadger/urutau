import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';

/// Configuration for golden tests.
class GoldenTestConfig {
  const GoldenTestConfig({
    required this.width,
    required this.theme,
    required this.textScale,
    required this.nameSuffix,
  });

  final double width;
  final ThemeData theme;
  final double textScale;
  final String nameSuffix;

  String get testName => '${width.toInt()}w_${theme.brightness.name}_${textScale.toStringAsFixed(1)}x';
}

/// Light theme for golden tests.
ThemeData _createLightTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF5A6B5C),
    brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: const Color(0xFFF9F6F0),
);

/// Dark theme for golden tests.
ThemeData _createDarkTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF5A6B5C),
    brightness: Brightness.dark,
  ),
  scaffoldBackgroundColor: const Color(0xFF1A1C18),
);

/// Returns the list of test configurations for 3 widths × 2 themes × 2 scales = 12 configurations.
List<GoldenTestConfig> getGoldenTestConfigs() {
  final lightTheme = _createLightTheme();
  final darkTheme = _createDarkTheme();
  
  return [
    // Mobile width (360)
    GoldenTestConfig(
      width: 360,
      theme: lightTheme,
      textScale: 1.0,
      nameSuffix: 'mobile_light_100',
    ),
    GoldenTestConfig(
      width: 360,
      theme: lightTheme,
      textScale: 1.3,
      nameSuffix: 'mobile_light_130',
    ),
    GoldenTestConfig(
      width: 360,
      theme: darkTheme,
      textScale: 1.0,
      nameSuffix: 'mobile_dark_100',
    ),
    GoldenTestConfig(
      width: 360,
      theme: darkTheme,
      textScale: 1.3,
      nameSuffix: 'mobile_dark_130',
    ),
    // Tablet width (600)
    GoldenTestConfig(
      width: 600,
      theme: lightTheme,
      textScale: 1.0,
      nameSuffix: 'tablet_light_100',
    ),
    GoldenTestConfig(
      width: 600,
      theme: lightTheme,
      textScale: 1.3,
      nameSuffix: 'tablet_light_130',
    ),
    GoldenTestConfig(
      width: 600,
      theme: darkTheme,
      textScale: 1.0,
      nameSuffix: 'tablet_dark_100',
    ),
    GoldenTestConfig(
      width: 600,
      theme: darkTheme,
      textScale: 1.3,
      nameSuffix: 'tablet_dark_130',
    ),
    // Desktop width (900)
    GoldenTestConfig(
      width: 900,
      theme: lightTheme,
      textScale: 1.0,
      nameSuffix: 'desktop_light_100',
    ),
    GoldenTestConfig(
      width: 900,
      theme: lightTheme,
      textScale: 1.3,
      nameSuffix: 'desktop_light_130',
    ),
    GoldenTestConfig(
      width: 900,
      theme: darkTheme,
      textScale: 1.0,
      nameSuffix: 'desktop_dark_100',
    ),
    GoldenTestConfig(
      width: 900,
      theme: darkTheme,
      textScale: 1.3,
      nameSuffix: 'desktop_dark_130',
    ),
  ];
}

/// Runs a golden test for each configuration.
void runGoldenTests({
  required String testName,
  required Widget Function(GoldenTestConfig config) builder,
  String goldenDir = 'goldens',
}) {
  for (final config in getGoldenTestConfigs()) {
    testWidgets('$testName (${config.testName})', (WidgetTester tester) async {
      final widget = builder(config);
      
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: Size(config.width, 800),
            textScaler: TextScaler.linear(config.textScale),
            platformBrightness: config.theme.brightness,
          ),
          child: Theme(
            data: config.theme,
            child: MaterialApp(
              theme: config.theme,
              darkTheme: config.theme,
              home: Scaffold(body: widget),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final goldenFile = File('$goldenDir/${testName}_${config.nameSuffix}.png');
      
      if (goldenFile.existsSync()) {
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('$goldenDir/${testName}_${config.nameSuffix}.png'),
        );
      } else {
        // Generate golden file on first run
        await goldenFile.parent.create(recursive: true);
        final image = await _takeScreenshot(tester);
        await goldenFile.writeAsBytes(image);
        print('Generated golden: ${goldenFile.path}');
      }
    });
  }
}

/// Creates a test app wrapper with proper theme and media query.
Widget createTestApp({
  required Widget child,
  required GoldenTestConfig config,
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: Size(config.width, 800),
      textScaler: TextScaler.linear(config.textScale),
      platformBrightness: config.theme.brightness,
    ),
    child: Theme(
      data: config.theme,
      child: MaterialApp(
        theme: config.theme,
        darkTheme: config.theme,
        home: Scaffold(body: child),
      ),
    ),
  );
}

/// Takes a screenshot of the current widget tree.
Future<List<int>> _takeScreenshot(WidgetTester tester) async {
  // Find a RepaintBoundary to capture
  final renderObject = find.byType(RepaintBoundary).evaluate().first.renderObject;
  final repaintBoundary = renderObject as RenderRepaintBoundary;
  final image = await repaintBoundary.toImage(pixelRatio: 2.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}