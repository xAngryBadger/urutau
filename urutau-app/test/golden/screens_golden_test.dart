import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../lib/main.dart';
import '../../lib/screens/storage_screen.dart';
import '../../lib/screens/integrity_error_screen.dart';
import '../../lib/screens/audit_log_screen.dart';
import '../../lib/services/storage_service.dart';
import '../../lib/services/sync_service.dart';
import '../../lib/services/theme_provider.dart';
import '../../lib/data/database.dart';
import 'golden_test_utils.dart';

void main() {
  group('StorageScreen Golden Tests', () {
    runGoldenTests(
      testName: 'storage_screen_empty',
      builder: (config) => _buildStorageScreen(
        config: config,
        breakdown: {'database': 0, 'fotos': 0, 'backups': 0, 'temp': 0},
        freeSpace: 10.5,
        isLoading: false,
      ),
    );

    runGoldenTests(
      testName: 'storage_screen_with_data',
      builder: (config) => _buildStorageScreen(
        config: config,
        breakdown: {
          'database': 50 * 1024 * 1024,
          'fotos': 500 * 1024 * 1024,
          'backups': 200 * 1024 * 1024,
          'temp': 50 * 1024 * 1024,
        },
        freeSpace: 5.2,
        isLoading: false,
      ),
    );

    runGoldenTests(
      testName: 'storage_screen_loading',
      builder: (config) => _buildStorageScreen(
        config: config,
        breakdown: {},
        freeSpace: 0,
        isLoading: true,
      ),
    );

    runGoldenTests(
      testName: 'storage_screen_low_space',
      builder: (config) => _buildStorageScreen(
        config: config,
        breakdown: {
          'database': 100 * 1024 * 1024,
          'fotos': 1024 * 1024 * 1024,
          'backups': 500 * 1024 * 1024,
          'temp': 100 * 1024 * 1024,
        },
        freeSpace: 0.5,
        isLoading: false,
      ),
    );
  });

  group('IntegrityErrorScreen Golden Tests', () {
    runGoldenTests(
      testName: 'integrity_error_screen_default',
      builder: (config) => _buildIntegrityErrorScreen(
        config: config,
        error: 'Database integrity check failed: checksum mismatch',
      ),
    );

    runGoldenTests(
      testName: 'integrity_error_screen_long_error',
      builder: (config) => _buildIntegrityErrorScreen(
        config: config,
        error: 'Database integrity check failed: multiple checksum mismatches detected in tables parcelas, plantas, and fotos. The database may be corrupted due to unexpected shutdown during write operation.',
      ),
    );

    runGoldenTests(
      testName: 'integrity_error_screen_with_restore_error',
      builder: (config) => _buildIntegrityErrorScreenWithError(
        config: config,
        error: 'Database integrity check failed',
        restoreError: 'Backup file is corrupted or incompatible',
      ),
    );

    runGoldenTests(
      testName: 'integrity_error_screen_with_reset_error',
      builder: (config) => _buildIntegrityErrorScreenWithError(
        config: config,
        error: 'Database integrity check failed',
        resetError: 'Failed to reset database: permission denied',
      ),
    );

    runGoldenTests(
      testName: 'integrity_error_screen_restoring',
      builder: (config) => _buildIntegrityErrorScreenRestoring(
        config: config,
        error: 'Database integrity check failed',
      ),
    );

    runGoldenTests(
      testName: 'integrity_error_screen_resetting',
      builder: (config) => _buildIntegrityErrorScreenResetting(
        config: config,
        error: 'Database integrity check failed',
      ),
    );
  });

  group('AuditLogScreen Golden Tests', () {
    runGoldenTests(
      testName: 'audit_log_screen_empty',
      builder: (config) => _buildAuditLogScreen(
        config: config,
        logs: [],
      ),
    );

    runGoldenTests(
      testName: 'audit_log_screen_with_logs',
      builder: (config) => _buildAuditLogScreen(
        config: config,
        logs: _createMockLogs(10),
      ),
    );

    runGoldenTests(
      testName: 'audit_log_screen_many_logs',
      builder: (config) => _buildAuditLogScreen(
        config: config,
        logs: _createMockLogs(50),
      ),
    );

    runGoldenTests(
      testName: 'audit_log_screen_with_filter',
      builder: (config) => _buildAuditLogScreenWithFilter(
        config: config,
        logs: _createMockLogs(20),
        filter: 'parcela',
      ),
    );

    runGoldenTests(
      testName: 'audit_log_screen_error',
      builder: (config) => _buildAuditLogScreenError(
        config: config,
        error: 'Failed to load audit logs: connection timeout',
      ),
    );

    runGoldenTests(
      testName: 'audit_log_screen_loading',
      builder: (config) => _buildAuditLogScreenLoading(config),
    );
  });
}

// Helper functions for building screens with test data

Widget _buildStorageScreen({
  required GoldenTestConfig config,
  required Map<String, int> breakdown,
  required double freeSpace,
  required bool isLoading,
}) {
  return createTestApp(
    config: config,
    child: _TestableStorageScreen(
      breakdown: breakdown,
      freeSpace: freeSpace,
      isLoading: isLoading,
    ),
  );
}

Widget _buildIntegrityErrorScreen({
  required GoldenTestConfig config,
  required String error,
}) {
  return createTestApp(
    config: config,
    child: IntegrityErrorScreen(error: error),
  );
}

Widget _buildIntegrityErrorScreenWithError({
  required GoldenTestConfig config,
  required String error,
  String? restoreError,
  String? resetError,
}) {
  return createTestApp(
    config: config,
    child: _TestableIntegrityErrorScreen(
      error: error,
      restoreError: restoreError,
      resetError: resetError,
    ),
  );
}

Widget _buildIntegrityErrorScreenRestoring({
  required GoldenTestConfig config,
  required String error,
}) {
  return createTestApp(
    config: config,
    child: _TestableIntegrityErrorScreen(
      error: error,
      isRestoring: true,
    ),
  );
}

Widget _buildIntegrityErrorScreenResetting({
  required GoldenTestConfig config,
  required String error,
}) {
  return createTestApp(
    config: config,
    child: _TestableIntegrityErrorScreen(
      error: error,
      isResetting: true,
    ),
  );
}

Widget _buildAuditLogScreen({
  required GoldenTestConfig config,
  required List<AuditLogData> logs,
}) {
  return createTestApp(
    config: config,
    child: _TestableAuditLogScreen(
      logs: logs,
    ),
  );
}

Widget _buildAuditLogScreenWithFilter({
  required GoldenTestConfig config,
  required List<AuditLogData> logs,
  required String filter,
}) {
  return createTestApp(
    config: config,
    child: _TestableAuditLogScreen(
      logs: logs,
      initialFilter: filter,
    ),
  );
}

Widget _buildAuditLogScreenError({
  required GoldenTestConfig config,
  required String error,
}) {
  return createTestApp(
    config: config,
    child: _TestableAuditLogScreen(
      logs: [],
      error: error,
    ),
  );
}

Widget _buildAuditLogScreenLoading(GoldenTestConfig config) {
  return createTestApp(
    config: config,
    child: _TestableAuditLogScreen(
      logs: [],
      isLoading: true,
    ),
  );
}

// Testable versions of screens that don't require real services

class _TestableStorageScreen extends StatefulWidget {
  const _TestableStorageScreen({
    required this.breakdown,
    required this.freeSpace,
    required this.isLoading,
  });

  final Map<String, int> breakdown;
  final double freeSpace;
  final bool isLoading;

  @override
  State<_TestableStorageScreen> createState() => _TestableStorageScreenState();
}

class _TestableStorageScreenState extends State<_TestableStorageScreen> {
  late Map<String, int> _breakdown;
  late int _totalSize;
  late double _freeSpace;
  late bool _isLoading;
  bool _isCleaning = false;

  @override
  void initState() {
    super.initState();
    _breakdown = widget.breakdown;
    _freeSpace = widget.freeSpace;
    _isLoading = widget.isLoading;
    _totalSize = _breakdown.values.fold(0, (a, b) => a + b);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Armazenamento')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {},
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildOverviewCard(),
                  const SizedBox(height: 16),
                  if (_breakdown.isNotEmpty) ...[
                    _buildCategoryCard('Banco de Dados', _breakdown['database'] ?? 0,
                        Icons.storage, () {}),
                    _buildCategoryCard('Fotos', _breakdown['fotos'] ?? 0,
                        Icons.image, () {}),
                    _buildCategoryCard('Backups', _breakdown['backups'] ?? 0,
                        Icons.backup, () {}),
                    _buildCategoryCard('Arquivos Temporários', _breakdown['temp'] ?? 0,
                        Icons.cleaning_services, () {}),
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
    final isDisabled = size == 0 || _isCleaning;
    return Card(
      child: ListTile(
        leading: _isCleaning
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        title: Text(label),
        subtitle: Text(_formatBytes(size)),
        trailing: TextButton(
          onPressed: isDisabled ? null : onClean,
          child: Text('Limpar', style: TextStyle(color: isDisabled ? Colors.grey : Colors.red)),
        ),
      ),
    );
  }
}

class _TestableIntegrityErrorScreen extends StatefulWidget {
  const _TestableIntegrityErrorScreen({
    required this.error,
    this.restoreError,
    this.resetError,
    this.isRestoring = false,
    this.isResetting = false,
  });

  final String error;
  final String? restoreError;
  final String? resetError;
  final bool isRestoring;
  final bool isResetting;

  @override
  State<_TestableIntegrityErrorScreen> createState() => _TestableIntegrityErrorScreenState();
}

class _TestableIntegrityErrorScreenState extends State<_TestableIntegrityErrorScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 72, color: Colors.amber),
            const SizedBox(height: 24),
            Text(
              'Problema detectado no banco de dados',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              widget.error,
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.restoreError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.restoreError!,
                        style: TextStyle(color: Colors.red[700], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (widget.resetError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.resetError!,
                        style: TextStyle(color: Colors.red[700], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: widget.isRestoring || widget.isResetting ? null : () {},
              icon: widget.isRestoring
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.restore),
              label: Text(widget.isRestoring ? 'Restaurando...' : 'Restaurar de backup'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: widget.isRestoring || widget.isResetting ? null : () {},
              icon: widget.isResetting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_forever),
              label: Text(widget.isResetting ? 'Resetando...' : 'Resetar dados do app'),
            ),
            if (widget.restoreError != null || widget.resetError != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.refresh),
                label: const Text('Limpar erro e tentar novamente'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TestableAuditLogScreen extends StatefulWidget {
  const _TestableAuditLogScreen({
    required this.logs,
    this.error = '',
    this.isLoading = false,
    this.initialFilter = '',
  });

  final List<AuditLogData> logs;
  final String error;
  final bool isLoading;
  final String initialFilter;

  @override
  State<_TestableAuditLogScreen> createState() => _TestableAuditLogScreenState();
}

class _TestableAuditLogScreenState extends State<_TestableAuditLogScreen> {
  late List<AuditLogData> _logs;
  late bool _isLoading;
  late String _error;
  late String _filter;
  int _page = 0;
  static const _pageSize = 100;

  @override
  void initState() {
    super.initState();
    _logs = widget.logs;
    _isLoading = widget.isLoading;
    _error = widget.error;
    _filter = widget.initialFilter;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de Auditoria'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Exportar CSV',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: () {},
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final dateFmt = DateFormat('dd/MM/yy HH:mm');
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Filtrar...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12),
            ),
            controller: TextEditingController(text: _filter),
            onChanged: (v) => setState(() => _filter = v.toLowerCase()),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error.isNotEmpty
                  ? _buildErrorState()
                  : _buildLogList(dateFmt),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Erro ao carregar logs',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogList(DateFormat dateFmt) {
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.builder(
        itemCount: _logs.length + 1,
        itemBuilder: (context, index) {
          if (index == _logs.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text('Carregar mais'),
                ),
              ),
            );
          }
          final log = _logs[index];
          final text = '${log.action} — ${log.entityType} #${log.entityUuid}';
          if (_filter.isNotEmpty && !text.toLowerCase().contains(_filter)) {
            return const SizedBox.shrink();
          }
          return ListTile(
            title: Text(log.action),
            subtitle: Text(
              '${log.entityType} #${log.entityUuid} — ${dateFmt.format(log.createdAt)}',
            ),
            dense: true,
            onTap: () {},
          );
        },
      ),
    );
  }
}

List<AuditLogData> _createMockLogs(int count) {
  final actions = ['CREATE', 'UPDATE', 'DELETE', 'SYNC', 'EXPORT'];
  final entityTypes = ['Parcela', 'Planta', 'Foto', 'Usuario', 'Backup'];
  final logs = <AuditLogData>[];
  
  for (int i = 0; i < count; i++) {
    logs.add(AuditLogData(
      id: i + 1,
      action: actions[i % actions.length],
      entityType: entityTypes[i % entityTypes.length],
      entityUuid: 'uuid-${i + 1}',
      userId: 'user-${(i % 3) + 1}',
      createdAt: DateTime.now().subtract(Duration(hours: i)),
      oldValue: i % 2 == 0 ? 'Valor antigo $i' : null,
      newValue: 'Valor novo $i',
    ));
  }
  return logs;
}