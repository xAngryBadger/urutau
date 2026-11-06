import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/database.dart';
import 'services/backup_service.dart';
import 'services/device_service.dart';
import 'services/sync_service.dart';
import 'services/theme_provider.dart';
import 'services/password_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/parcela_form_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/explorer_screen.dart';
import 'screens/storage_screen.dart';
import 'screens/mrv_projeto_screen.dart';
import 'screens/integrity_error_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Backup automático LOCAL removido (t9): uma cópia dentro do mesmo sandbox
    // do app não sobrevive a celular perdido/quebrado nem à desinstalação —
    // era redundante e enganoso. O backup ÚTIL é o manual/explícito
    // (BackupService.exportBackup, que compartilha o ZIP pra fora do aparelho),
    // usado antes de reinstalar e em ações destrutivas. Ver settings_screen.

    final db = AppDatabase();
    await BackupService.runPendingRestore();
    await BackupService.cleanPreRestoreFiles();
    await _migratePlaintextPasswords(db);
    // RC-13: registra o dispositivo (modelo/SO/versão app) na tabela Dispositivos
    try {
      await DeviceService.registrarDispositivo(db);
    } catch (e) {
      debugPrint('RC-13: falha ao registrar dispositivo: $e');
    }

  String? integrityError;
  try {
    final result = await db.checkIntegrity();
    if (!result.ok) {
      integrityError = result.error;
    }
  } catch (e) {
    integrityError = e.toString();
  }

    final syncService = SyncService(db);
    final themeProvider = ThemeProvider();

    await Future.wait([
      syncService.init(),
      themeProvider.init(),
    ]);

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.exceptionAsString()}');
      appErrorNotifier.value = details.exceptionAsString();
    };

    runApp(
      MultiProvider(
        providers: [
          Provider<AppDatabase>.value(value: db),
          ChangeNotifierProvider.value(value: syncService),
          ChangeNotifierProvider.value(value: themeProvider),
        ],
        child: UrutauApp(integrityError: integrityError),
      ),
    );
  }, (error, stack) {
    debugPrint('Unhandled error: $error\n$stack');
    appErrorNotifier.value = error.toString();
  });
}

/// Erro global da aplicação (fora da árvore de widgets). Um ValueNotifier
/// substitui o antigo GlobalKey<_ErrorBoundaryState>, que era re-anexado em
/// dois lugares durante rebuilds (assert "_children.contains(child)" no debug).
final ValueNotifier<String?> appErrorNotifier = ValueNotifier(null);

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
  const UrutauApp({super.key, this.integrityError});

  final String? integrityError;

  @override
  State<UrutauApp> createState() => _UrutauAppState();
}

class _UrutauAppState extends State<UrutauApp> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    if (widget.integrityError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: themeProvider.theme,
        home: IntegrityErrorScreen(error: widget.integrityError!),
      );
    }

    return MaterialApp(
      navigatorKey: navigatorKey,
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
          builder: (_) => _ErrorBoundary(errorNotifier: appErrorNotifier),
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
          case '/storage':
            return MaterialPageRoute(
              builder: (_) => const StorageScreen(),
            );
          case '/mrv-projeto':
            final syncService = context.read<SyncService>();
            if (!syncService.isAdmin) {
              return MaterialPageRoute(
                builder: (_) => HomeScreen(),
                settings: const RouteSettings(arguments: {'showAdminDenied': true}),
              );
            }
            return MaterialPageRoute(
              builder: (_) => const MrvProjetoScreen(),
            );
          case '/admin':
            final syncService = context.read<SyncService>();
            if (!syncService.isAdmin) {
              return MaterialPageRoute(
                builder: (_) => HomeScreen(),
                settings: const RouteSettings(arguments: {'showAdminDenied': true}),
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

class _ErrorBoundary extends StatelessWidget {
  const _ErrorBoundary({required this.errorNotifier});

  final ValueNotifier<String?> errorNotifier;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: errorNotifier,
      builder: (context, errorMessage, _) {
        if (errorMessage == null) return const SplashScreen();
        return _AppErrorScreen(
          errorMessage: errorMessage,
          onRetry: () => errorNotifier.value = null,
        );
      },
    );
  }
}

class _AppErrorScreen extends StatelessWidget {
  const _AppErrorScreen({required this.errorMessage, required this.onRetry});

  final String errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
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
              errorMessage,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
