import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/database.dart';
import 'services/backup_service.dart';
import 'services/sync_service.dart';
import 'services/theme_provider.dart';
import 'services/password_service.dart';
import 'services/secure_storage_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/parcela_form_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/explorer_screen.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    final db = AppDatabase();
    await BackupService.runPendingRestore();
    await _migratePlaintextPasswords(db);

    final syncService = SyncService(db);
    final themeProvider = ThemeProvider();

    await Future.wait([
      syncService.init(),
      themeProvider.init(),
    ]);

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.exceptionAsString()}');
      _errorStateKey.currentState?.setError(details.exceptionAsString());
    };

    runApp(
      MultiProvider(
        providers: [
          Provider<AppDatabase>.value(value: db),
          ChangeNotifierProvider.value(value: syncService),
          ChangeNotifierProvider.value(value: themeProvider),
        ],
        child: const UrutauApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('Unhandled error: $error\n$stack');
    _errorStateKey.currentState?.setError(error.toString());
  });
}

final GlobalKey<_ErrorBoundaryState> _errorStateKey = GlobalKey();

Future<void> _migratePlaintextPasswords(AppDatabase db) async {
  try {
    final users = await db.getAllUsuarios();
    for (final user in users) {
      if (!PasswordService.isHashed(user.senha)) {
        final hashed = PasswordService.hashPassword(user.senha);
        await db.atualizarSenha(user.uuid, hashed);
      }
    }
  } catch (_) {}
}

class UrutauApp extends StatefulWidget {
  const UrutauApp({super.key});

  @override
  State<UrutauApp> createState() => _UrutauAppState();
}

class _UrutauAppState extends State<UrutauApp> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    final isHighContrast = themeProvider.isHighContrast;
    return MaterialApp(
      title: 'Urutau',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.theme,
      themeAnimationDuration: Duration.zero,
      themeAnimationCurve: Curves.easeInOut,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
  case '/':
        return MaterialPageRoute(
          builder: (_) => _ErrorBoundary(key: _errorStateKey),
        );
          case '/login':
            return MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            );
          case '/home':
            return MaterialPageRoute(
              builder: (_) => const HomeScreen(),
            );
          case '/explorer':
            return MaterialPageRoute(
              builder: (_) => const ExplorerScreen(),
            );
          case '/parcela/nova':
            final args = settings.arguments;
            if (args is Map<String, dynamic>) {
              return MaterialPageRoute(
                builder: (_) => ParcelaFormScreen(
                  prefilledPropriedade: args['propriedade'] as String?,
                  prefilledPropUt: args['propUt'] as String?,
                  prefilledNextParcela: args['nextParcela'] as int?,
                ),
              );
            }
            return MaterialPageRoute(
              builder: (_) => const ParcelaFormScreen(),
            );
          case '/parcela/editar':
            final args = settings.arguments;
            if (args is String) {
              return MaterialPageRoute(
                builder: (_) => ParcelaFormScreen(parcelaUuid: args),
              );
            }
            if (args is Map<String, dynamic>) {
              final uuid = args['uuid'] as String? ?? args['parcelaUuid'] as String?;
              final readOnly = args['readOnly'] == true;
              return MaterialPageRoute(
                builder: (_) => ParcelaFormScreen(parcelaUuid: uuid, readOnly: readOnly),
              );
            }
            return MaterialPageRoute(
              builder: (_) => const ParcelaFormScreen(),
            );
          case '/settings':
            return MaterialPageRoute(
              builder: (_) => const SettingsScreen(),
            );
          case '/admin':
            final syncService = context.read<SyncService>();
            if (!syncService.isAdmin) {
              return MaterialPageRoute(
                builder: (_) => const LoginScreen(),
              );
            }
            return MaterialPageRoute(
              builder: (_) => const AdminScreen(),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            );
        }
      },
    );
  }
}

class _ErrorBoundary extends StatefulWidget {
  const _ErrorBoundary({super.key});

  @override
  State<_ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<_ErrorBoundary> {
  String? _errorMessage;

  void setError(String message) {
    if (mounted) {
      setState(() => _errorMessage = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Material(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 24),
              const Text(
                'Algo deu errado',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () {
                  setState(() => _errorMessage = null);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }
    return const SplashScreen();
  }
}
