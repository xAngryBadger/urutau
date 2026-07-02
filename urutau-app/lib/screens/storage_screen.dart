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
                        Icons.storage, () => _confirmCleanup('Banco de Dados')),
                    _buildCategoryCard('Fotos', _breakdown!['fotos'] ?? 0,
                        Icons.image, () => _confirmCleanup('Fotos sincronizadas')),
                    _buildCategoryCard('Backups', _breakdown!['backups'] ?? 0,
                        Icons.backup, () => _confirmCleanup('Backups >30 dias')),
                    _buildCategoryCard('Arquivos Temporários', _breakdown!['temp'] ?? 0,
                        Icons.cleaning_services, () => _confirmCleanup('Temp')),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Total usado: ${_formatBytes(_totalSize)} — '
                    '${_freeSpace.toStringAsFixed(1)} GB livres',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewCard() {
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
              backgroundColor: Colors.grey.shade200,
              color: usedPercent > 80 ? Colors.red : Colors.green,
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
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(_formatBytes(size)),
        trailing: TextButton(
          onPressed: size > 0 ? onClean : null,
          child: Text('Limpar', style: TextStyle(color: size > 0 ? Colors.red : Colors.grey)),
        ),
      ),
    );
  }

  void _confirmCleanup(String category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Limpar $category?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performCleanup(category);
            },
            child: const Text('Limpar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _performCleanup(String category) async {
    try {
      Set<String>? protectedPaths;
      if (category == 'fotos') {
        final db = context.read<AppDatabase>();
        final allPaths = await db.getAllPhotoPaths();
        protectedPaths = allPaths.map((e) => e.path).toSet();
      }
      await StorageService.cleanCategory(category, protectedPaths: protectedPaths);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$category limpo'), backgroundColor: Colors.green),
        );
        await _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}