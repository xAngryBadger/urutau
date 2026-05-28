import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/backup_service.dart';
import '../services/sync_service.dart';
import '../services/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _serverUrlController = TextEditingController();
  bool _isSaving = false;
  bool _isTesting = false;
  String? _testResult;
  bool? _testOk;

  @override
  void initState() {
    super.initState();
    final syncService = context.read<SyncService>();
    _serverUrlController.text = syncService.serverUrl ?? '';
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncService = context.watch<SyncService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Servidor
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.dns),
                      SizedBox(width: 8),
                      Text(
                        'Servidor PocketBase',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
        Semantics(
          label: 'URL do servidor',
          child: TextField(
          controller: _serverUrlController,
          decoration: InputDecoration(
            labelText: 'URL do Servidor',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          keyboardType: TextInputType.url,
        ),
        ),
        const SizedBox(height: 12),

        // Botões Salvar e Testar
        Row(
          children: [
            Expanded(
              child: Semantics(
                label: 'Salvar URL do servidor',
                button: true,
                child: FilledButton.icon(
                          onPressed: _isSaving ? null : _saveServerUrl,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save),
              label: const Text('Salvar'),
            ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                label: 'Testar conexão com servidor',
                button: true,
                child: OutlinedButton.icon(
                          onPressed: _isTesting ? null : _testConnection,
                          icon: _isTesting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.wifi_find),
          label: const Text('Testar'),
          ),
        ),
      ),
    ],
  ),

                  // Resultado do teste
                  if (_testResult != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _testOk == true
                            ? Colors.green[50]
                            : Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _testOk == true
                              ? Colors.green[300]!
                              : Colors.red[300]!,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _testOk == true
                                ? Icons.check_circle
                                : Icons.error,
                            color: _testOk == true
                                ? Colors.green[700]
                                : Colors.red[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _testOk == true
                                  ? 'Conexão OK! Servidor acessível.'
                                  : _testResult!,
                              style: TextStyle(
                                color: _testOk == true
                                    ? Colors.green[800]
                                    : Colors.red[800],
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Status de sincronização
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.sync),
                      SizedBox(width: 8),
                      Text(
                        'Sincronização',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      syncService.pendingCount > 0
                          ? Icons.cloud_off
                          : Icons.cloud_done,
                      color: syncService.pendingCount > 0
                          ? Colors.orange
                          : Colors.green,
                    ),
                    title: Text(
                      syncService.pendingCount > 0
                          ? '${syncService.pendingCount} parcela(s) pendente(s)'
                          : 'Tudo sincronizado',
                    ),
                    subtitle: syncService.lastError != null
                        ? Text(
                            syncService.lastError!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          )
                        : null,
                  ),
                  if (syncService.pendingCount > 0) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: syncService.isSyncing ? null : _forceSync,
                        icon: syncService.isSyncing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.sync),
                        label: Text(syncService.isSyncing
                            ? 'Sincronizando...'
                            : 'Sincronizar agora'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ────────── BACKUP / RESTAURAR ──────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.backup),
                      SizedBox(width: 8),
                      Text(
                        'Backup / Restaurar',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Exporte um backup antes de desinstalar; após reinstalar, use Restaurar e escolha o ficheiro. O Android também pode restaurar dados automaticamente se o backup estiver ativo.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final msg = await BackupService.exportBackup();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(msg)),
                          );
                        }
                      },
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Exportar backup local'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.any,
                          allowMultiple: false,
                        );
                        if (result == null || result.files.isEmpty || !context.mounted) return;
                        final file = result.files.single;
                        String msg;
                        if (file.path != null && file.path!.isNotEmpty) {
                          msg = await BackupService.prepareRestore(file.path!);
                        } else if (file.bytes != null && file.bytes!.isNotEmpty) {
                          msg = await BackupService.prepareRestoreFromBytes(file.bytes!);
                        } else {
                          msg = 'Não foi possível aceder ao ficheiro.';
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(msg), duration: const Duration(seconds: 6)),
                          );
                        }
                      },
                      icon: const Icon(Icons.restore),
                      label: const Text('Restaurar de backup'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ────────── ACESSIBILIDADE ──────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.accessibility_new),
                      SizedBox(width: 8),
                      Text(
                        'Acessibilidade',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, _) {
                      return SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.contrast),
                        title: const Text('Modo Alto Contraste'),
                        value: themeProvider.isHighContrast,
                        onChanged: (val) async => await themeProvider.setHighContrast(val),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Informações do app
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info),
                      SizedBox(width: 8),
                      Text(
                        'Sobre',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Monitoramento Florestal'),
                    subtitle: Text('Versão 1.0.0'),
                  ),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Banco de dados'),
                    subtitle: Text('SQLite (Drift) — dados locais'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Usuário local'),
                    subtitle: Text(
                      syncService.currentUser?.nome ?? 'Não logado',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testConnection() async {
    final url = _serverUrlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _testOk = false;
        _testResult = 'Informe a URL do servidor primeiro.';
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
      _testOk = null;
    });

    try {
      final syncService = context.read<SyncService>();
      final result = await syncService.testConnection(url);
      if (mounted) {
        setState(() {
          _testOk = result == 'OK';
          _testResult = result;
        });
      }
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  Future<void> _saveServerUrl() async {
    final url = _serverUrlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a URL do servidor')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await context.read<SyncService>().setServerUrl(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('URL do servidor salva!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _forceSync() async {
    await context.read<SyncService>().syncAll();
    if (mounted) {
      final syncService = context.read<SyncService>();
      if (syncService.lastError == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sincronização concluída!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
