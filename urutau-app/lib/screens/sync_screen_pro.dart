import 'dart:io' if (dart.library.html) '';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/sync_service.dart';
import '../data/database.dart';


class SyncScreenPro extends StatefulWidget {
  const SyncScreenPro({super.key});

  @override
  State<SyncScreenPro> createState() => SyncScreenProState();
}

class SyncScreenProState extends State<SyncScreenPro> {
  AppDatabase get _db => context.read<AppDatabase>();
  final _urlController = TextEditingController();

  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isTestingConnection = false;
  String? _connectionStatus;

  // Stats
  int _pendingCount = 0;
  int _syncedCount = 0;
  int _totalCount = 0;
  DateTime? _lastSync;
  double _storageUsed = 0.0;
  int _totalRecords = 0;

  // Pending items
  List<Parcela> _pendingParcelas = [];
  Set<String> _selectedParcelas = {};
  Set<String> _conflictKeys = {};
  List<String> _conflictMessages = [];
  bool _isCheckingConflicts = false;

  @override
  void initState() {
    super.initState();
    _loadUrl();
    _refreshData();
  }

  void refresh() => _refreshData();

  Future<void> _loadUrl() async {
    final syncService = context.read<SyncService>();
    _urlController.text = syncService.serverUrl ?? '';
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);

    try {
      final syncService = context.read<SyncService>();
      final isAdmin = syncService.isAdmin;
      final userId = isAdmin ? null : syncService.currentUser?.uuid;

      // Get all parcels
      final allParcelas =
          await _db.getAllParcelas(userId: userId, isAdmin: isAdmin);
      final pending =
          allParcelas.where((p) => !p.synced && p.prontaParaSync).toList();
      final synced = allParcelas.where((p) => p.synced).toList();

      // Calculate storage (approximate)
      double storage = 0.0;
      int records = allParcelas.length;

      for (final p in allParcelas) {
        final plantas = await _db.getPlantasByParcela(p.uuid);
        records += plantas.length;

        final fotos = await _db.getFotosByParcela(p.uuid);
      for (final f in fotos) {
        if (f.filePath.isNotEmpty && !kIsWeb) {
          final file = File(f.filePath);
          if (await file.exists()) {
            storage += await file.length() / (1024 * 1024); // MB
          }
        }
      }
      }

      setState(() {
        _pendingParcelas = pending;
        _pendingCount = pending.length;
        _syncedCount = synced.length;
        _totalCount = allParcelas.length;
        _storageUsed = storage;
        _totalRecords = records;
        _isLoading = false;
      });

      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getInt('last_sync_timestamp');
      if (ts != null && mounted) {
        setState(() {
          _lastSync = DateTime.fromMillisecondsSinceEpoch(ts);
        });
      }

      await _checkConflicts();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkConflicts() async {
    if (!mounted) return;
    setState(() => _isCheckingConflicts = true);
    try {
      final syncService = context.read<SyncService>();
      final userId = syncService.currentUser?.uuid;
      if (userId == null ||
          !syncService.isConfigured ||
          !await syncService.hasInternet()) {
        if (mounted) {
          setState(() {
            _conflictKeys = {};
            _conflictMessages = [];
            _isCheckingConflicts = false;
          });
        }
        return;
      }
      final result = await syncService.fetchConflitos(userId: userId);
      if (mounted) {
        setState(() {
          _conflictKeys = result.conflictKeys;
          _conflictMessages = result.messages;
          _isCheckingConflicts = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _conflictKeys = {};
          _conflictMessages = [];
          _isCheckingConflicts = false;
        });
      }
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionStatus = null;
    });

    try {
      final syncService = context.read<SyncService>();
      await syncService.setServerUrl(_urlController.text.trim());
      final hasInternet = await syncService.hasInternet();
      final isConfigured = syncService.isConfigured;

      setState(() {
        _isTestingConnection = false;
        if (isConfigured && hasInternet) {
          _connectionStatus = 'ONLINE';
        } else if (isConfigured && !hasInternet) {
          _connectionStatus = 'OFFLINE';
        } else {
          _connectionStatus = 'ERROR';
        }
      });
    } catch (e) {
      setState(() {
        _isTestingConnection = false;
        _connectionStatus = 'ERROR';
      });
    }
  }

  Future<void> _syncAll() async {
    final nonConflicted = _pendingParcelas
        .where((p) => !_conflictKeys.contains(SyncService.parcelaKey(p)))
        .map((p) => p.uuid)
        .toSet();
    if (nonConflicted.isEmpty && _conflictKeys.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Todas as parcelas pendentes têm conflitos. Resolva antes de sincronizar.'),
            backgroundColor: AppTheme.tertiary,
          ),
        );
      }
      return;
    }
    await _syncParcelas(nonConflicted);
  }

  Future<void> _syncSelected() async {
    if (_selectedParcelas.isEmpty) return;
    final nonConflicted = _selectedParcelas.where((uuid) {
      final p = _pendingParcelas.where((p) => p.uuid == uuid).firstOrNull;
      if (p == null) return false;
      return !_conflictKeys.contains(SyncService.parcelaKey(p));
    }).toSet();
    if (nonConflicted.isEmpty && _selectedParcelas.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Parcelas selecionadas têm conflitos. Resolva antes de sincronizar.'),
            backgroundColor: AppTheme.tertiary,
          ),
        );
      }
      return;
    }
    await _syncParcelas(nonConflicted);
  }

  Future<void> _syncParcelas(Set<String> uuids) async {
    setState(() => _isSyncing = true);

    try {
      final syncService = context.read<SyncService>();
      int success = 0;
      int failed = 0;

      for (final uuid in uuids) {
        try {
          await syncService.syncSingleParcela(uuid);
          success++;
        } catch (e) {
          failed++;
        }
      }

      await _refreshData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sincronizado: $success | Falhas: $failed'),
            backgroundColor:
                failed > 0 ? AppTheme.tertiary : AppTheme.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  void _toggleSelection(String uuid) {
    setState(() {
      if (_selectedParcelas.contains(uuid)) {
        _selectedParcelas.remove(uuid);
      } else {
        _selectedParcelas.add(uuid);
      }
    });
  }

  Future<void> _deleteParcela(String uuid) async {
    try {
      final syncService = context.read<SyncService>();

      await _db.softDeleteParcela(uuid,
          deletedBy: syncService.currentUser?.uuid);

      try {
        await syncService.deleteParcela(uuid);
      } catch (_) {}

      _selectedParcelas.remove(uuid);

      await _refreshData();
      await syncService.refreshPendingCount();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parcela deletada'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao deletar: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  String _getStatusColor() {
    if (_connectionStatus == 'ONLINE') return '#006e1c';
    if (_connectionStatus == 'OFFLINE') return '#ba1a1a';
    return '#717a6d';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshData,
              color: AppTheme.primary,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Configuration Section
                    _buildConfigSection(),
                    const SizedBox(height: 24),

                    // Sync Status Section
                    _buildSyncStatusSection(),
                    const SizedBox(height: 24),

                    // Conflict Warnings
                    if (_conflictMessages.isNotEmpty) ...[
                      _buildConflictSection(),
                      const SizedBox(height: 24),
                    ],

                    // Pending Queue
                    _buildPendingQueue(),
                    const SizedBox(height: 24),

                    // Technical Metadata
                    _buildTechnicalMetadata(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildConfigSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.only(bottom: 8),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppTheme.outlineVariant),
            ),
          ),
          child: Text(
            'CONFIGURAÇÃO',
            style: AppTheme.labelSmall,
          ),
        ),
        const SizedBox(height: 16),

        // Config Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            border: Border(
              left: BorderSide(color: AppTheme.outlineVariant, width: 1),
              right: BorderSide(color: AppTheme.outlineVariant, width: 1),
              bottom: BorderSide(color: AppTheme.outlineVariant, width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // URL Field
              Text(
                'URL DO SERVIDOR',
                style: AppTheme.labelSmall,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  hintText: 'https://api.floresta.gov/v1',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                ),
              ),
              const SizedBox(height: 16),

              // Test Connection Button
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _isTestingConnection ? null : _testConnection,
                    child: _isTestingConnection
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('TESTAR CONEXÃO'),
                  ),
                  const SizedBox(width: 16),
                  if (_connectionStatus != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      color: _connectionStatus == 'ONLINE'
                          ? AppTheme.secondary.withOpacity(0.1)
                          : _connectionStatus == 'OFFLINE'
                              ? AppTheme.error.withOpacity(0.1)
                              : AppTheme.surfaceContainerHighest,
                      child: Text(
                        _connectionStatus!,
                        style: AppTheme.labelSmall.copyWith(
                          color: _connectionStatus == 'ONLINE'
                              ? AppTheme.secondary
                              : _connectionStatus == 'OFFLINE'
                                  ? AppTheme.error
                                  : AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSyncStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.only(bottom: 8),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppTheme.outlineVariant),
            ),
          ),
          child: Text(
            'DATA TRANSMISSION',
            style: AppTheme.labelSmall,
          ),
        ),
        const SizedBox(height: 16),

        // Stats Grid
        Row(
          children: [
            // Pending Card (2/3 width)
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryContainer,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ESTADO DO BANCO LOCAL',
                      style: AppTheme.labelSmall.copyWith(
                        color: AppTheme.onPrimaryContainer.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_pendingCount PARCELAS PENDENTES',
                      style: AppTheme.headlineMedium.copyWith(
                        color: AppTheme.onPrimary,
                        fontSize: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _isSyncing || _pendingCount == 0 ? null : _syncAll,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.onPrimary,
                          foregroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isSyncing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                'SINCRONIZAR TUDO',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                      ),
                    ),
                    if (_selectedParcelas.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _isSyncing ? null : _syncSelected,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.onPrimary,
                            side: const BorderSide(color: AppTheme.onPrimary),
                          ),
                          child: Text(
                              'SINCRONIZAR SELECIONADAS (${_selectedParcelas.length})'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Last Sync Card (1/3 width)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceContainerLowest,
                  border: Border(
                    left: BorderSide(color: AppTheme.outlineVariant),
                    right: BorderSide(color: AppTheme.outlineVariant),
                    bottom: BorderSide(color: AppTheme.outlineVariant),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.cloud_done,
                      size: 48,
                      color: AppTheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'ÚLTIMA SINCRONIZAÇÃO',
                      style: AppTheme.labelSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _lastSync != null
                          ? DateFormat('yyyy-MM-dd HH:mm').format(_lastSync!)
                          : 'Never',
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConflictSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: 8),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppTheme.error),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber, color: AppTheme.error, size: 18),
              const SizedBox(width: 8),
              Text(
                'CONFLITOS DETECTADOS (${_conflictMessages.length})',
                style: AppTheme.labelSmall.copyWith(color: AppTheme.error),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppTheme.errorContainer,
            border: Border(
              left: BorderSide(color: AppTheme.error, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'As parcelas abaixo já existem no servidor com outro utilizador. Elas serão bloqueadas do sync até resolver o conflito.',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.error),
              ),
              const SizedBox(height: 12),
              ..._conflictMessages.map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ',
                            style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.error,
                                fontWeight: FontWeight.w700)),
                        Expanded(
                            child: Text(m,
                                style: AppTheme.bodySmall
                                    .copyWith(color: AppTheme.error))),
                      ],
                    ),
                  )),
              const SizedBox(height: 8),
              Text(
                'Sugestão: altere o número da parcela ou contacte o administrador.',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.error,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPendingQueue() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.only(bottom: 8),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppTheme.outlineVariant),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FILA DE SINCRONIZAÇÃO',
                style: AppTheme.labelSmall,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: AppTheme.tertiary.withOpacity(0.1),
                child: Text(
                  'PENDENTES',
                  style: AppTheme.labelSmall.copyWith(
                    color: AppTheme.tertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Pending List
        if (_pendingParcelas.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceContainerLowest,
              border: Border(
                left: BorderSide(color: AppTheme.outlineVariant),
                right: BorderSide(color: AppTheme.outlineVariant),
                bottom: BorderSide(color: AppTheme.outlineVariant),
              ),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.cloud_done,
                    size: 48,
                    color: AppTheme.secondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tudo sincronizado!',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ..._pendingParcelas.map((p) {
            final isConflict =
                _conflictKeys.contains(SyncService.parcelaKey(p));
            return _PendingItem(
              parcela: p,
              isSelected: _selectedParcelas.contains(p.uuid),
              isConflict: isConflict,
              onToggle: isConflict ? () {} : () => _toggleSelection(p.uuid),
              onDelete: () => _deleteParcela(p.uuid),
            );
          }),
      ],
    );
  }

  Widget _buildTechnicalMetadata() {
    return Row(
      children: [
        // Storage
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceContainerLow,
              border: Border(
                left: BorderSide(color: AppTheme.outlineVariant),
                right: BorderSide(color: AppTheme.outlineVariant),
                bottom: BorderSide(color: AppTheme.outlineVariant),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ARMAZENAMENTO',
                  style: AppTheme.labelSmall,
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _storageUsed.toStringAsFixed(1),
                      style: AppTheme.headlineMedium.copyWith(
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'MB',
                      style: AppTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Records
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceContainerLow,
              border: Border(
                left: BorderSide(color: AppTheme.outlineVariant),
                right: BorderSide(color: AppTheme.outlineVariant),
                bottom: BorderSide(color: AppTheme.outlineVariant),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REGISTROS',
                  style: AppTheme.labelSmall,
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _totalRecords.toString(),
                      style: AppTheme.headlineMedium.copyWith(
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'REGISTROS',
                      style: AppTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PendingItem extends StatelessWidget {
  final Parcela parcela;
  final bool isSelected;
  final bool isConflict;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _PendingItem({
    required this.parcela,
    required this.isSelected,
    this.isConflict = false,
    required this.onToggle,
    required this.onDelete,
  });

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            const Text('Deletar Parcela', style: TextStyle(color: Colors.red)),
        icon: const Icon(Icons.delete_forever, color: Colors.red),
        content: Text(
          'Deseja deletar a parcela ${parcela.propriedade ?? ""}/${parcela.propUt ?? ""} - P${parcela.idParcela}?\n\n'
          'Todos os dados (plantas, fotos) serão perdidos!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Não'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sim, Deletar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        border: Border(
          left: BorderSide(color: AppTheme.outlineVariant),
          right: BorderSide(color: AppTheme.outlineVariant),
          bottom: BorderSide(color: AppTheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: isConflict ? false : isSelected,
            onChanged: isConflict ? null : (_) => onToggle(),
            activeColor: AppTheme.primary,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
          ),
          Container(
            width: 4,
            height: 64,
            color: isConflict ? AppTheme.error : AppTheme.tertiary,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isConflict)
                          Row(
                            children: [
                              Icon(Icons.warning_amber,
                                  size: 14, color: AppTheme.error),
                              const SizedBox(width: 4),
                              Text(
                                'CONFLITO',
                                style: AppTheme.labelSmall.copyWith(
                                    color: AppTheme.error,
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        Text(
                          'Parcel ID',
                          style: AppTheme.labelSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${parcela.propriedade ?? ''}/${parcela.propUt ?? ''} - P${parcela.idParcela}',
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Last Modified',
                        style: AppTheme.labelSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM dd, HH:mm')
                            .format(parcela.updatedAt ?? parcela.createdAt),
                        style: AppTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: () => _confirmDelete(context),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            tooltip: 'Deletar parcela',
          ),
        ],
      ),
    );
  }
}
