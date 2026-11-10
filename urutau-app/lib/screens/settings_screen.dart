import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database.dart';
import '../services/backup_service.dart';
import '../services/sync_service.dart';
import '../services/theme_provider.dart';

const String kForcedOfflineKey = 'forced_offline_mode';
const String kWizardModeKey = 'wizard_mode_enabled';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _serverUrlController = TextEditingController();
  bool _isSaving = false;
  bool _isTesting = false;
  bool _isScanningPhotos = false;
  String? _testResult;
  bool? _testOk;

  bool _forcedOffline = false;
  bool _wizardMode = true; // UX-APP-CAMPO: default ligado

  @override
  void initState() {
    super.initState();
    final syncService = context.read<SyncService>();
    _serverUrlController.text = syncService.serverUrl ?? '';
    _loadForcedOffline();
    _loadWizardMode();
  }

  Future<void> _loadWizardMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // UX-APP-CAMPO: modo wizard é o padrão; desligado = form clássico.
      _wizardMode = prefs.getBool(kWizardModeKey) ?? true;
    });
  }

  Future<void> _loadForcedOffline() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _forcedOffline = prefs.getBool(kForcedOfflineKey) ?? false;
    });
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncService = context.watch<SyncService>();
    final cs = Theme.of(context).colorScheme;

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
                      textInputAction: TextInputAction.done,
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
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: cs.onPrimary,
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
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
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
                            ? cs.primaryContainer
                            : cs.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _testOk == true ? cs.primary : cs.error,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _testOk == true ? Icons.check_circle : Icons.error,
                            color: _testOk == true ? cs.primary : cs.error,
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
                                    ? cs.onPrimaryContainer
                                    : cs.onErrorContainer,
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
                          ? cs.tertiary
                          : cs.primary,
                    ),
                    title: Text(
                      syncService.pendingCount > 0
                          ? '${syncService.pendingCount} parcela(s) pendente(s)'
                          : 'Tudo sincronizado',
                    ),
                    subtitle: syncService.lastError != null
                        ? Text(
                            syncService.lastError!,
                            style: TextStyle(
                              color: cs.error,
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
                  Text(
                    'Backup LOCAL = ficheiro ZIP com o banco (SQLite) e as fotos. '
                    'Use "Exportar backup local" e GUARDE o ficheiro fora do celular '
                    '(Downloads/Drive): uma cópia que fica só no aparelho desaparece '
                    'se ele for perdido, quebrado ou o app desinstalado. '
                    'Para voltar, use "Restaurar" e escolha o ficheiro — substitui os dados atuais.',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final msg = await BackupService.exportBackup();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(msg),
                                duration: const Duration(seconds: 3)),
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
                        if (result == null ||
                            result.files.isEmpty ||
                            !context.mounted) return;
                        final file = result.files.single;
                        String msg;
                        if (file.path != null && file.path!.isNotEmpty) {
                          msg = await BackupService.prepareRestore(file.path!);
                        } else if (file.bytes != null &&
                            file.bytes!.isNotEmpty) {
                          msg = await BackupService.prepareRestoreFromBytes(
                              file.bytes!);
                        } else {
                          msg = 'Não foi possível aceder ao ficheiro.';
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(msg),
                                duration: const Duration(seconds: 6)),
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

          // ────────── INTEGRIDADE DAS FOTOS ──────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.photo_library),
                      SizedBox(width: 8),
                      Text(
                        'Integridade das Fotos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          _isScanningPhotos ? null : _verifyPhotoIntegrity,
                      icon: _isScanningPhotos
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                      label: Text(
                        _isScanningPhotos
                            ? 'Verificando...'
                            : 'Verificar integridade das fotos',
                      ),
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
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SegmentedButton<ThemeModeUrutau>(
                            segments: const [
                              ButtonSegment(
                                value: ThemeModeUrutau.claro,
                                label: Text('Claro'),
                              ),
                              ButtonSegment(
                                value: ThemeModeUrutau.altoContraste,
                                label: Text('Alto contraste'),
                              ),
                              ButtonSegment(
                                value: ThemeModeUrutau.kanagawa,
                                label: Text('Kanagawa'),
                              ),
                            ],
                            selected: {themeProvider.mode},
                            onSelectionChanged: (sel) async =>
                                await themeProvider.setMode(sel.first),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Claro = tema padrão. Alto contraste = preto/amarelo/'
                            'branco com contraste AA, para uso sob sol. '
                            'Kanagawa = paleta escura do kanagawa.nvim. '
                            'A escolha fica guardada.',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ────────── FORMULÁRIO DE CAMPO (UX-APP-CAMPO) ──────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.view_carousel),
                      SizedBox(width: 8),
                      Text(
                        'Formulário de Campo',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.segment),
                    title: const Text('Modo wizard'),
                    subtitle: const Text(
                      'Formulário da parcela em 4 etapas com swipe '
                      '(Local, Plantas, Fotos, Revisar). '
                      'Desligado = formulário clássico de sempre.',
                    ),
                    value: _wizardMode,
                    onChanged: (val) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool(kWizardModeKey, val);
                      setState(() => _wizardMode = val);
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ────────── FOTOS (integridade) ──────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.image),
                      SizedBox(width: 8),
                      Text(
                        'Fotos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'As fotos são guardadas e enviadas como o ORIGINAL capturado, '
                    'sem compressão. O hash SHA-256 é calculado sobre exatamente '
                    'o arquivo que sobe — a evidência não é alterada. '
                    'Não há opção de comprimir: comprimir mudaria os bytes e o '
                    'hash deixaria de ser do original.',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ────────── ARMAZENAMENTO ──────────
          Card(
            child: ListTile(
              leading: const Icon(Icons.storage),
              title: const Text('Gerenciar Armazenamento'),
              subtitle: const Text('Ver uso de disco e limpar arquivos'),
              onTap: () => Navigator.pushNamed(context, '/storage'),
            ),
          ),

          // ────────── PROJETO MRV (admin) — RT-04/RS-04/RS-05/RT-02/RG-03/RG-06 ──────────
          if (context.read<SyncService>().isAdmin) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.eco),
                title: const Text('Projeto MRV'),
                subtitle: const Text(
                    'Baseline/adicionalidade, desenho amostral, campanhas, incidentes e verificação interna'),
                onTap: () => Navigator.pushNamed(context, '/mrv-projeto'),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // ────────── MODO OFFLINE FORÇADO ──────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.wifi_off),
                      SizedBox(width: 8),
                      Text(
                        'Modo Offline Forçado',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.wifi_off),
                    title: const Text('Modo Offline Forçado'),
                    subtitle: const Text(
                      'Esconde configurações de servidor e sincronização. '
                      'O app funciona 100% local.',
                    ),
                    value: _forcedOffline,
                    onChanged: (val) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool(kForcedOfflineKey, val);
                      setState(() => _forcedOffline = val);
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Reinicie o app para aplicar completamente.',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
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
        const SnackBar(
            content: Text('Informe a URL do servidor'),
            duration: Duration(seconds: 5)),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await context.read<SyncService>().setServerUrl(url);

      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('URL do servidor salva!',
                style: TextStyle(color: cs.onPrimaryContainer)),
            backgroundColor: cs.primaryContainer,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e', style: TextStyle(color: cs.onErrorContainer)),
            backgroundColor: cs.errorContainer,
            duration: const Duration(seconds: 5),
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
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sincronização concluída!',
                style: TextStyle(color: cs.onPrimaryContainer)),
            backgroundColor: cs.primaryContainer,
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (syncService.lastError != null && syncService.lastError!.contains('planta(s) falharam')) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(syncService.lastError!,
                style: TextStyle(color: cs.onTertiaryContainer)),
            backgroundColor: cs.tertiaryContainer,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _verifyPhotoIntegrity() async {
    setState(() => _isScanningPhotos = true);
    try {
      final db = context.read<AppDatabase>();
      final allPaths = await db.getAllPhotoPaths();
      final missing = <({String path, String uuid, String source})>[];
      for (final entry in allPaths) {
        if (!File(entry.path).existsSync()) {
          missing.add(entry);
        }
      }

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Verificação de Fotos'),
          content: Text(
            missing.isEmpty
                ? 'Todas as ${allPaths.length} fotos estão presentes.'
                : '${missing.length} de ${allPaths.length} fotos ausentes.',
          ),
          actions: [
            if (missing.isNotEmpty)
              TextButton.icon(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _cleanMissingPhotoRefs(missing);
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Limpar referências ausentes'),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isScanningPhotos = false);
    }
  }

  Future<void> _cleanMissingPhotoRefs(
    List<({String path, String uuid, String source})> missing,
  ) async {
    final db = context.read<AppDatabase>();
    for (final entry in missing) {
      if (entry.source == 'foto') {
        await db.cleanMissingFotoParcela(entry.uuid);
      } else {
        await db.cleanMissingFotoPlanta(entry.uuid);
      }
    }

    if (mounted) {
      final cs = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${missing.length} referência(s) ausente(s) removida(s)',
              style: TextStyle(color: cs.onPrimaryContainer)),
          backgroundColor: cs.primaryContainer,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
