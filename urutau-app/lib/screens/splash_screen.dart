import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database.dart';
import '../services/sync_service.dart';

/// Splash screen com imagem completa do Urutau.
/// Exibida por ~2.5 segundos antes de navegar ao destino adequado.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runStartupMaintenance().then((_) => _navigate());
    });
  }

  Future<void> _runStartupMaintenance() async {
    try {
      final db = context.read<AppDatabase>();
      final result = await db.checkAndFixOrphanedPhotos();
      if (result.$1 > 0 || result.$2 > 0) {
        debugPrint('Startup maintenance: fixed ${result.$1} orphaned DB refs, found ${result.$2} unreferenced files');
      }
    } catch (e) {
      debugPrint('Startup maintenance failed (non-critical): $e');
    }
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    try {
      final syncService = context.read<SyncService>();
      final user = syncService.currentUser;
      if (user != null) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      // If anything goes wrong, go to login as fallback
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        child: Image.asset(
          'assets/images/urutau_real.png',
          fit: BoxFit.cover,
          errorBuilder: (ctx, error, stackTrace) {
            return const Center(
              child: Icon(
                Icons.forest,
                size: 120,
                color: Color(0xFF5A6B5C),
              ),
            );
          },
        ),
      ),
    );
  }
}
