import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      Future.delayed(const Duration(milliseconds: 1500), _navigate);
    });
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    final syncService = context.read<SyncService>();
    final user = syncService.currentUser;
    if (user != null) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
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
