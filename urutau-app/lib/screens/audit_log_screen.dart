import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../data/database.dart';

class AuditLogScreen extends StatefulWidget {
  final AppDatabase database;

  const AuditLogScreen({super.key, required this.database});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  List<AuditLogData> _logs = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _error = '';
  String _filter = '';
  int _page = 0;
  static const _pageSize = 100;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs({bool append = false}) async {
    if (!append) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    } else {
      setState(() => _isLoadingMore = true);
    }
    try {
      final logs = await widget.database.getAuditLog(
        limit: _pageSize,
        offset: _page * _pageSize,
      );
      if (mounted) {
        setState(() {
          if (append) {
            _logs.addAll(logs);
          } else {
            _logs = logs;
          }
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
      // Only increment page on successful load
      if (append && logs.isNotEmpty) {
        _page++;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _error = 'Erro ao carregar logs: $e';
        });
      }
    }
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
            onPressed: _exportCsv,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: () => _loadLogs(),
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
            onChanged: (v) => setState(() => _filter = v.toLowerCase()),
          ),
        ),
        if (_error.isNotEmpty)
          Container(
            width: double.infinity,
            color: Colors.red[50],
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error,
                    style: TextStyle(color: Colors.red[700], fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: () => _loadLogs(),
                  child: const Text('Tentar novamente', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildLogList(dateFmt),
        ),
      ],
    );
  }

  Widget _buildLogList(DateFormat dateFmt) {
    return RefreshIndicator(
      onRefresh: () => _loadLogs(),
      child: ListView.builder(
        itemCount: _logs.length + 1,
        itemBuilder: (context, index) {
          if (index == _logs.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: _isLoadingMore
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: () {
                          _loadLogs(append: true);
                        },
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
            onTap: () => _showDetail(log),
          );
        },
      ),
    );
  }

  void _showDetail(AuditLogData log) {
    final dateFmt = DateFormat('dd/MM/yy HH:mm');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${log.action} — ${log.entityType}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ID: ${log.id}'),
              Text('Entidade: ${log.entityType}'),
              Text('ID Entidade: ${log.entityUuid}'),
              Text('Usuário: ${log.userId}'),
              Text('Data: ${dateFmt.format(log.createdAt)}'),
              const Divider(),
              const Text('Valor Antigo:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(log.oldValue ?? '(vazio)'),
              const SizedBox(height: 8),
              const Text('Valor Novo:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(log.newValue ?? '(vazio)'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
        ],
      ),
    );
  }

  Future<void> _exportCsv() async {
    final buffer = StringBuffer();
    buffer.writeln('id;action;entity_type;entity_id;user_id;created_at;old_value;new_value');
    for (final log in _logs) {
      buffer.writeln(
        '${log.id};${log.action};${log.entityType};'
        '${log.entityUuid};${log.userId};${log.createdAt.toIso8601String()};'
        '"${(log.oldValue ?? '').toString().replaceAll('"', '""')}";'
        '"${(log.newValue ?? '').toString().replaceAll('"', '""')}"',
      );
    }

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/audit_log_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(buffer.toString());

    await Share.shareXFiles([XFile(file.path)], text: 'Log de Auditoria');
  }
}