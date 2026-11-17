import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';

class LowSpaceBanner extends StatefulWidget {
  const LowSpaceBanner({super.key});

  @override
  State<LowSpaceBanner> createState() => _LowSpaceBannerState();
}

class _LowSpaceBannerState extends State<LowSpaceBanner> {
  final _freeSpaceNotifier = ValueNotifier<double>(-1);
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshFreeSpace();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshFreeSpace());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _freeSpaceNotifier.dispose();
    super.dispose();
  }

  Future<void> _refreshFreeSpace() async {
    final free = await StorageService.getFreeSpaceGB();
    if (mounted) _freeSpaceNotifier.value = free;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: _freeSpaceNotifier,
      builder: (context, freeGB, _) {
        if (freeGB < 0 || freeGB >= 1.0) return const SizedBox.shrink();
        // Pares do tema: container + on-container (antes red[100]/amber[100]
        // com texto [900] — invisível nos temas escuros).
        final cs = Theme.of(context).colorScheme;
        final critico = freeGB < 0.2;
        final bg = critico ? cs.errorContainer : cs.tertiaryContainer;
        final fg = critico ? cs.onErrorContainer : cs.onTertiaryContainer;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: bg,
          child: Row(
            children: [
              Icon(critico ? Icons.error_outline : Icons.warning_amber,
                  size: 18, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${freeGB.toStringAsFixed(1)} GB livres — '
                  '${critico ? 'crítico' : 'pouco espaço'}',
                  style: TextStyle(
                    fontSize: 13,
                    color: fg,
                  ),
                ),
              ),
              TextButton(
                onPressed: _refreshFreeSpace,
                child: const Text('Atualizar', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        );
      },
    );
  }
}