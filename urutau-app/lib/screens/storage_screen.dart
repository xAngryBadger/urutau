import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/database.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';

class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  Map<String, int>? _breakdown;
  int _totalSize = 0;
  double _freeSpace = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    final breakdown = await StorageService.getStorageBreakdown();
    final free = await StorageService.getFreeSpaceGB();
    final total = breakdown.values.fold(0, (a, b) => a + b);
    setState(() {
      _breakdown = breakdown;
      _totalSize = total;
      _freeSpace = free;
      _isLoading = false;
    });
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final syncService = context.watch<SyncService>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Armazenamento')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildOverviewCard(),
                  const SizedBox(height: 16),
                  if (_breakdown != null) ...[
                    _buildCategoryCard('Banco de Dados', _breakdown!['database'] ?? 0,
                        Icons.storage, () => _confirmCleanup('database', 'Banco de Dados')),
                    _buildCategoryCard('Fotos sincronizadas', _breakdown!['fotos'] ?? 0,
                        Icons.image, () => _confirmCleanup('fotos', 'Fotos sincronizadas')),
                    _buildCategoryCard('Backups >30 dias', _breakdown!['backups'] ?? 0,
                        Icons.backup, () => _confirmCleanup('backups', 'Backups >30 dias')),
                    _buildCategoryCard('Arquivos Temporários', _breakdown!['temp'] ?? 0,
                        Icons.cleaning_services, () => _confirmCleanup('temp', 'Arquivos Temporários')),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Total usado: ${_formatBytes(_totalSize)} — '
                    '${_freeSpace.toStringAsFixed(1)} GB livres',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewCard() {
    final cs = Theme.of(context).colorScheme;
    final usedPercent = _freeSpace > 0
        ? (_totalSize / (1024 * 1024 * 1024) / (_totalSize / (1024 * 1024 * 1024) + _freeSpace) * 100)
            .clamp(0, 100)
        : 50.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Visão Geral', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: usedPercent / 100,
              backgroundColor: cs.surfaceContainerHighest,
              color: usedPercent > 80 ? cs.error : cs.primary,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text('${_formatBytes(_totalSize)} usado de ${_formatBytes((_totalSize + (_freeSpace * 1024 * 1024 * 1024).toInt()))}'),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(String label, int size, IconData icon, VoidCallback onClean) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(_formatBytes(size)),
        trailing: TextButton(
          onPressed: size > 0 ? onClean : null,
          child: Text('Limpar', style: TextStyle(color: size > 0 ? cs.error : cs.onSurfaceVariant)),
        ),
      ),
    );
  }

  void _confirmCleanup(String categoryKey, String categoryLabel) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Limpar $categoryLabel?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performCleanup(categoryKey, categoryLabel);
            },
            child: Text('Limpar',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _performCleanup(String categoryKey, String categoryLabel) async {
    try {
      Set<String>? protectedPaths;
      if (categoryKey == 'fotos') {
        final db = context.read<AppDatabase>();
        final allPaths = await db.getAllPhotoPaths();
        protectedPaths = allPaths.map((e) => e.path).toSet();
      }
      await StorageService.cleanCategory(categoryKey, protectedPaths: protectedPaths);
      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$categoryLabel limpo',
                style: TextStyle(color: cs.onPrimaryContainer)),
            backgroundColor: cs.primaryContainer,
          ),
        );
        await _refresh();
      }
    } catch (e) {
      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e', style: TextStyle(color: cs.onErrorContainer)),
            backgroundColor: cs.errorContainer,
          ),
        );
      }
    }
  }
}