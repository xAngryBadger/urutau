import 'dart:io' if (dart.library.html) '';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' show Value;
import '../data/database.dart';
import '../services/sync_service.dart';
import '../services/export_service.dart';
import '../widgets/low_space_banner.dart';
import '../widgets/arquivo_ausente_badge.dart';
import 'audit_log_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  AppDatabase get _db => context.read<AppDatabase>();
  List<Usuario> _usuarios = [];
  Map<String, List<Parcela>> _parcelasPorUsuario = {};
  Map<String, int> _plantasPorUsuario = {};
  Map<String, int> _unsyncedPorUsuario = {};
  bool _isLoading = true;
  bool _isOnline = true;
  bool _filterPendingOnly = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  // ── Filtro admin (sempre visível como landing) ──
  bool _filterActive = false;
  String? _filterPropUt;
  DateTime? _filterDataInicio;
  DateTime? _filterDataFim;
  String? _filterUsuarioUuid;
  List<String> _talhoes = [];
  List<Parcela>? _parcelasFiltradas;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deletarUsuario(Usuario usuario) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deletar Usuário'),
        content: Text(
          'Tem certeza que deseja deletar "${usuario.nome}"?\n\nTodas as parcelas, plantas e fotos deste usuário serão removidas do dispositivo. Esta ação NÃO pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deletar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _db.deleteUsuarioComDados(usuario.uuid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${usuario.nome}" deletado com sucesso.',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer)),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        duration: const Duration(seconds: 3),
      ),
          );
        }
        await _carregarDados();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Erro ao deletar: $e',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer)),
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        duration: const Duration(seconds: 5),
      ),
          );
        }
      }
    }
  }

  /// Promove ou remove permissão de admin de um usuário.
  Future<void> _toggleAdmin(Usuario usuario) async {
    final novoStatus = !usuario.isAdmin;
    final acao = novoStatus ? 'promover a Admin' : 'remover de Admin';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(novoStatus ? 'Promover a Admin' : 'Remover Admin'),
        content: Text(
          'Deseja $acao o usuário "${usuario.nome}"?\n\n'
          'Nota: o usuário verá a mudança na próxima vez que fizer login.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(novoStatus ? 'Promover' : 'Remover'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _db.updateUsuario(
          UsuariosCompanion(isAdmin: Value(novoStatus)),
          usuario.uuid,
        );
        // Registra no audit log / tenta sincronizar flag com servidor
        final syncService = context.read<SyncService>();
        await syncService.syncAdminFlagToServer(usuario.email, novoStatus);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${usuario.nome}" ${novoStatus ? "agora é admin" : "não é mais admin"}.',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer)),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        duration: const Duration(seconds: 3),
      ),
          );
        }
        await _carregarDados();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro: $e',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer)),
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              duration: const Duration(seconds: 5)),
          );
        }
      }
    }
  }

  /// Deleta usuário e suas parcelas/plantas do PocketBase.
  Future<void> _deletarUsuarioDoServidor(Usuario usuario) async {
    final syncService = context.read<SyncService>();
    if (!syncService.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Servidor não configurado.'), duration: Duration(seconds: 5)),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Theme.of(ctx).colorScheme.error),
            SizedBox(width: 8),
            Expanded(child: Text('Deletar do Servidor')),
          ],
        ),
        content: Text(
          'Isso vai APAGAR "${usuario.nome}" e TODAS as suas parcelas/plantas do PocketBase.\n\n'
          'Esta ação NÃO pode ser desfeita.\n\nContinuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deletar do Servidor'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deletando ${usuario.nome} do servidor...'), duration: const Duration(seconds: 3)),
    );

    try {
      final deleted = await syncService.deleteUsuarioDoServidor(usuario.uuid, usuario.email);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(deleted
                ? '"${usuario.nome}" removido do servidor!'
                : 'Usuário não encontrado no servidor.',
                style: TextStyle(
                    color: deleted
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onTertiaryContainer)),
            backgroundColor: deleted
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.tertiaryContainer,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      // Também remove localmente
      await _db.deleteUsuarioComDados(usuario.uuid);
      await _carregarDados();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer)),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            duration: const Duration(seconds: 5)),
        );
      }
    }
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);

    try {
      // Puxa TUDO do PocketBase (admin precisa ver dados de todos)
      final syncService = context.read<SyncService>();
      final online = syncService.isConfigured && await syncService.hasInternet();
      _isOnline = online;

      if (online) {
        // Puxa usuários do servidor primeiro (para que apareçam no painel)
        try {
          final novosUsuarios = await syncService.pullUsuariosDoServidor();
          if (novosUsuarios > 0) {
            debugPrint('Admin pull: $novosUsuarios novos usuários importados.');
          }
        } catch (e) {
          debugPrint('Erro ao puxar usuários do servidor: $e');
        }
        try {
          final importados = await syncService.pullDadosDoServidor();
          debugPrint('Admin pull: $importados parcelas importadas do servidor.');
        } catch (e) {
          debugPrint('Erro ao puxar dados do servidor: $e');
        }
      }

      final usuarios = await _db.getAllUsuarios();
      debugPrint('_carregarDados: ${usuarios.length} usuários no banco local:');
      for (var u in usuarios) {
        debugPrint('  - ${u.uuid.substring(0, 8)}: ${u.nome} (${u.email})');
      }
      
      final todasParcelas = await _db.getAllParcelas(isAdmin: true);
      // Admin vê APENAS dados sincronizados (presentes no servidor)
      final parcelasServidor = todasParcelas.where((p) => p.synced).toList();
      Map<String, List<Parcela>> parcelasPorUsuario = {};
      Map<String, int> plantasPorUsuario = {};

      for (var usuario in usuarios) {
        final parcelas =
            parcelasServidor.where((p) => p.userId == usuario.uuid).toList();
        parcelasPorUsuario[usuario.uuid] = parcelas;

        int totalPlantas = 0;
        for (var parcela in parcelas) {
          final plantas = await _db.getPlantasByParcela(parcela.uuid);
          totalPlantas += plantas.length;
        }
        plantasPorUsuario[usuario.uuid] = totalPlantas;
      }

       final talhoes = await _db.getAllTalhoes(isAdmin: true);

       // Calculate unsynced parcelas per usuario
       Map<String, int> unsyncedPorUsuario = {};
       for (var usuario in usuarios) {
         final unsyncedCount = todasParcelas.where((p) => p.userId == usuario.uuid && !p.synced).length;
         unsyncedPorUsuario[usuario.uuid] = unsyncedCount;
       }

       setState(() {
         _usuarios = usuarios;
         _parcelasPorUsuario = parcelasPorUsuario;
         _plantasPorUsuario = plantasPorUsuario;
         _unsyncedPorUsuario = unsyncedPorUsuario;
         _talhoes = talhoes;
         _isLoading = false;
       });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e'), duration: const Duration(seconds: 5)),
        );
      }
    }
  }

  List<Usuario> get _filteredUsuarios {
    List<Usuario> usuarios = _usuarios;
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      usuarios = usuarios.where((u) {
        return u.nome.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q);
      }).toList();
    }
    
    // Apply pending-only filter
    if (_filterPendingOnly) {
      usuarios = usuarios.where((u) {
        return (_unsyncedPorUsuario[u.uuid] ?? 0) > 0;
      }).toList();
    }
    
    return usuarios;
  }

  int get _totalParcelas {
    int total = 0;
    for (var parcelas in _parcelasPorUsuario.values) {
      total += parcelas.length;
    }
    return total;
  }

  int get _totalPlantas {
    int total = 0;
    for (var count in _plantasPorUsuario.values) {
      total += count;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final appBarFg =
        Theme.of(context).appBarTheme.foregroundColor ?? cs.onPrimary;
    final syncService = context.watch<SyncService>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Painel Administrativo'),
            FutureBuilder<DateTime?>(
              future: syncService.getLastSyncTime(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data == null) {
                  return Text('Nunca sincronizado',
                      style: TextStyle(fontSize: 10, color: appBarFg.withValues(alpha: 0.8)));
                }
                final lastSync = snapshot.data!;
                final diff = DateTime.now().difference(lastSync);
                final text = diff.inDays > 0
                    ? '${diff.inDays}d ${diff.inHours % 24}h atrás'
                    : diff.inHours > 0
                        ? '${diff.inHours}h ${diff.inMinutes % 60}min atrás'
                        : '${diff.inMinutes}min atrás';
                return Text('Última sync: $text',
                    style: TextStyle(fontSize: 10, color: appBarFg.withValues(alpha: 0.8)));
              },
            ),
          ],
        ),
        leading: null,
        automaticallyImplyLeading: false,
        actions: [
          // Botão sync
          FutureBuilder<bool>(
            future: syncService.isForcedOffline,
            builder: (context, snapshot) {
              if (snapshot.data == true) return const SizedBox.shrink();
              if (syncService.pendingCount > 0)
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Badge(
                    label: Text('${syncService.pendingCount}'),
                    child: IconButton(
                      icon: syncService.isSyncing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cloud_upload),
                      onPressed: syncService.isSyncing ? null : _sync,
                    ),
                  ),
                );
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarDados,
            tooltip: 'Atualizar',
          ),
          PopupMenuButton<String>(
            onSelected: _onMenuSelected,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.file_download),
                  title: Text('Exportar XLSX (tudo)'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              // PDF deprecado — removido (foco em XLSX)
              const PopupMenuItem(
                value: 'export_servidor',
                child: ListTile(
                  leading: Icon(Icons.cloud_download),
                  title: Text('Exportar do Servidor'),
                  subtitle: Text('Puxa dados do PocketBase'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'download_fotos',
                child: ListTile(
                  leading: Icon(Icons.photo_library),
                  title: Text('Baixar fotos (todas)'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'campo',
                child: ListTile(
                  leading: Icon(Icons.terrain),
                  title: Text('Modo Campo'),
                  subtitle: Text('Coletar parcelas em campo'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'sync',
                child: ListTile(
                  leading: Icon(Icons.sync),
                  title: Text('Sincronizar agora'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'audit_log',
                child: ListTile(
                  leading: Icon(Icons.history),
                  title: Text('Registro de Auditoria'),
                  subtitle: Text('Visualizar e exportar ações'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'limpar_tudo',
                child: ListTile(
                  leading: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
                  title: Text('Limpar TUDO',
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  subtitle: Text('Remove todos os dados exceto admin'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Configurações'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Sair'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Barra de progresso de sync
                if (syncService.isSyncing)
                  LinearProgressIndicator(value: syncService.syncProgress > 0 ? syncService.syncProgress : null),
                // Banner offline
                if (!_isOnline)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    child: Row(
                      children: [
                        Icon(Icons.wifi_off, color: Theme.of(context).colorScheme.onTertiaryContainer, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Sem internet — dados podem estar desatualizados',
                            style: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Banner de espaço em disco baixo
                const LowSpaceBanner(),
                _buildResumo(),
                // Filtro sempre visível como landing
                _buildAdminFilterBar(),
                if (_filterActive) _buildAdminFilterTag(),
                _buildSearchBar(),
                Expanded(child: _buildUsuariosList()),
              ],
            ),
      // Admin não cria parcelas — apenas visualiza dados coletados em campo
    );
  }

  Widget _buildResumo() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: cs.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildResumoItem(
            icon: Icons.people,
            label: 'Usuários',
            value: '${_usuarios.length}',
          ),
          _buildResumoItem(
            icon: Icons.map,
            label: 'Parcelas',
            value: '$_totalParcelas',
          ),
          _buildResumoItem(
            icon: Icons.grass,
            label: 'Plantas',
            value: '$_totalPlantas',
          ),
        ],
      ),
    );
  }

  Widget _buildResumoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, color: cs.primary, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: cs.primary,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  // ─────────────────────── FILTRO ADMIN ─────────────────────── //
  Widget _buildAdminFilterBar() {
    final dateFmt = DateFormat('dd/MM/yy');
    return Container(
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.5),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filtrar parcelas',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
           // Usuário
           DropdownButtonFormField<String>(
             decoration: InputDecoration(
               labelText: 'Usuário',
               prefixIcon: const Icon(Icons.person, size: 18),
               contentPadding:
                   const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
               border: OutlineInputBorder(
                   borderRadius: BorderRadius.circular(8)),
               isDense: true,
             ),
             value: _filterUsuarioUuid,
             items: [
               const DropdownMenuItem(
                   value: null, child: Text('Todos os usuários')),
               ..._usuarios.map((u) =>
                   DropdownMenuItem(value: u.uuid, child: Text(u.nome))),
             ],
             onChanged: (v) {
               setState(() => _filterUsuarioUuid = v);
               _applyAdminFilter();
             },
           ),
           const SizedBox(height: 8),
           // Pending only filter
           CheckboxListTile(
             title: const Text('Apenas com pendências'),
             value: _filterPendingOnly,
             onChanged: (bool? value) {
               setState(() {
                 _filterPendingOnly = value ?? false;
               });
               // Clear other filters when toggling pending only
               if (value == true) {
                 setState(() {
                   _filterUsuarioUuid = null;
                   _filterPropUt = null;
                   _filterDataInicio = null;
                   _filterDataFim = null;
                 });
               }
               _applyAdminFilter();
             },
             controlAffinity: ListTileControlAffinity.leading,
             contentPadding: EdgeInsets.zero,
           ),
          const SizedBox(height: 8),
          // Talhão
          if (_talhoes.isNotEmpty)
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Talhão / Propriedade',
                prefixIcon: Icon(Icons.forest, size: 18),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              value: _filterPropUt,
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Todos os talhões')),
                ..._talhoes.map((t) =>
                    DropdownMenuItem(value: t, child: Text(t))),
              ],
              onChanged: (v) {
                setState(() => _filterPropUt = v);
                _applyAdminFilter();
              },
            ),
          const SizedBox(height: 8),
          // Datas
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _filterDataInicio != null
                        ? 'De: ${dateFmt.format(_filterDataInicio!)}'
                        : 'Data início',
                    style: TextStyle(fontSize: 13),
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _filterDataInicio ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _filterDataInicio = picked);
                      _applyAdminFilter();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month, size: 16),
                  label: Text(
                    _filterDataFim != null
                        ? 'Até: ${dateFmt.format(_filterDataFim!)}'
                        : 'Data fim',
                    style: TextStyle(fontSize: 13),
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _filterDataFim ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _filterDataFim = picked);
                      _applyAdminFilter();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.clear_all, size: 18),
              onPressed: _clearAdminFilter,
              label: const Text('Limpar filtros'),
            ),
          ),
          // Botão de seed / forçar download do catálogo
          
        ],
      ),
    );
  }

  Widget _buildAdminFilterTag() {
    final cs = Theme.of(context).colorScheme;
    final parts = <String>[];
    if (_filterUsuarioUuid != null) {
       final nome = _usuarios
           .firstWhere((u) => u.uuid == _filterUsuarioUuid,
orElse: () => _usuarios.isNotEmpty ? _usuarios.first : Usuario(
        id: -1,
        uuid: '',
        nome: 'Nenhum usuário disponível',
        email: '',
        senha: '',
        isAdmin: false,
        ativo: true,
        createdAt: DateTime.now(),
      ))
           .nome;
      parts.add(nome);
    }
    if (_filterPropUt != null) parts.add(_filterPropUt!);
    if (_filterDataInicio != null) {
      parts.add('De ${DateFormat('dd/MM/yy').format(_filterDataInicio!)}');
    }
    if (_filterDataFim != null) {
      parts.add('Até ${DateFormat('dd/MM/yy').format(_filterDataFim!)}');
    }
    final label = parts.isEmpty ? 'Filtro ativo' : parts.join(' • ');

    return Container(
      width: double.infinity,
      color: cs.tertiaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.filter_alt, size: 16, color: cs.onTertiaryContainer),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                  color: cs.onTertiaryContainer,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
          GestureDetector(
            onTap: _clearAdminFilter,
            child: Text('Limpar',
                style: TextStyle(
                    color: cs.onTertiaryContainer,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _applyAdminFilter() async {
    try {
      final results = await _db.searchParcelas(
        isAdmin: true,
        userId: _filterUsuarioUuid,
        propUt: _filterPropUt,
        dataInicio: _filterDataInicio,
        dataFim: _filterDataFim,
      );
      if (mounted) {
        setState(() {
          _parcelasFiltradas = results;
          _filterActive = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao filtrar: $e',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer)),
            backgroundColor: Theme.of(context).colorScheme.errorContainer),
        );
      }
    }
  }

  void _clearAdminFilter() {
    setState(() {
      _filterActive = false;
      _parcelasFiltradas = null;
      _filterUsuarioUuid = null;
      _filterPropUt = null;
      _filterDataInicio = null;
      _filterDataFim = null;
    });
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Semantics(
        label: 'Pesquisar usuário',
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Pesquisar usuário...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onChanged: (v) => setState(() => _searchQuery = v),
        ),
      ),
    );
  }

  Widget _buildUsuariosList() {
    // Quando filtro ativo, recalcula parcelas por usuário com base nos resultados filtrados
    final Map<String, List<Parcela>> parcelasMostradas;
    final Map<String, int> plantasMostradas;

    if (_filterActive && _parcelasFiltradas != null) {
      parcelasMostradas = {};
      plantasMostradas = {};
      for (final p in _parcelasFiltradas!) {
        parcelasMostradas.putIfAbsent(p.userId, () => []).add(p);
      }
      // Contagem de plantas seria incorreta sem consultar, ent\u00e3o mostra o total original
      for (final key in parcelasMostradas.keys) {
        plantasMostradas[key] = _plantasPorUsuario[key] ?? 0;
      }
    } else {
      parcelasMostradas = _parcelasPorUsuario;
      plantasMostradas = _plantasPorUsuario;
    }

    // Filtra usu\u00e1rios: se filtro ativo, s\u00f3 mostra quem tem parcelas filtradas
    List<Usuario> usuarios;
    if (_filterActive && _parcelasFiltradas != null) {
      final uuidsComParcelas = parcelasMostradas.keys.toSet();
      usuarios = _filteredUsuarios.where((u) => uuidsComParcelas.contains(u.uuid)).toList();
    } else {
      usuarios = _filteredUsuarios;
    }

    if (usuarios.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_filterActive ? Icons.filter_alt_off : Icons.person_off, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              _filterActive
                  ? 'Nenhum resultado para o filtro aplicado'
                  : _searchQuery.isEmpty
                      ? 'Nenhum usu\u00e1rio encontrado'
                      : 'Nenhum resultado para \"$_searchQuery\"',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: usuarios.length,
      itemBuilder: (context, index) {
        final cs = Theme.of(context).colorScheme;
        final usuario = usuarios[index];
       final parcelas = parcelasMostradas[usuario.uuid] ?? [];
         final totalPlantas = plantasMostradas[usuario.uuid] ?? 0;
         final unsyncedCount = parcelas.where((p) => !p.synced).length;

         return Card(
           margin: const EdgeInsets.only(bottom: 10),
           child: Semantics(
             label: 'Usuário ${usuario.nome}, ${parcelas.length} parcelas, $unsyncedCount pendentes, $totalPlantas plantas${usuario.isAdmin ? ", administrador" : ""}',
             child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _abrirParcelasUsuario(usuario),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: cs.primary,
                      child: Text(
                        usuario.nome.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  usuario.nome,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (usuario.isAdmin) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.tertiary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'ADMIN',
                                    style: TextStyle(
                                      color: cs.onTertiary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            usuario.email,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                           Row(
                             children: [
                               _infoChip(Icons.map, '${parcelas.length} parcelas'),
                               if (unsyncedCount > 0)
                                 _infoChip(Icons.pending, '$unsyncedCount pendentes', Theme.of(context).colorScheme.tertiary),
                               const SizedBox(width: 12),
                               _infoChip(Icons.grass, '$totalPlantas plantas'),
                             ],
                           ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                    // Ações por usuário (não mostra para admin-principal)
                    if (usuario.uuid != 'admin-principal')
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: cs.onSurfaceVariant, size: 20),
                        padding: EdgeInsets.zero,
                        onSelected: (action) {
                          switch (action) {
                            case 'toggle_admin':
                              _toggleAdmin(usuario);
                              break;
                            case 'delete_server':
                              _deletarUsuarioDoServidor(usuario);
                              break;
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'toggle_admin',
                            child: Semantics(
                              label: usuario.isAdmin ? 'Remover permissão de administrador de ${usuario.nome}' : 'Tornar ${usuario.nome} administrador',
                              button: true,
                              child: ListTile(
                                leading: Icon(
                                  usuario.isAdmin ? Icons.person : Icons.admin_panel_settings,
                                  color: usuario.isAdmin ? cs.tertiary : cs.primary,
                                ),
                                title: Text(usuario.isAdmin ? 'Remover Admin' : 'Tornar Admin'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete_server',
                            child: Semantics(
                              label: 'Deletar ${usuario.nome} do servidor',
                              button: true,
                              child: ListTile(
                                leading: Icon(Icons.cloud_off, color: cs.error),
                                title: Text('Deletar do Servidor'),
                                subtitle: Text('Remove do PocketBase'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _infoChip(IconData icon, String text, [Color? color]) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 12, color: color ?? cs.onSurfaceVariant),
        ),
      ],
    );
  }
  
  void _abrirParcelasUsuario(Usuario usuario) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AdminUserParcelasScreen(
          usuario: usuario,
          parcelas: _parcelasPorUsuario[usuario.uuid] ?? [],
          db: _db,
        ),
      ),
    );
  }

  Future<void> _sync() async {
    final syncService = context.read<SyncService>();
    if (!syncService.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Configure o servidor primeiro nas configurações.'),
      duration: Duration(seconds: 5),
    ),
      );
      return;
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Sincronizando com ${syncService.serverUrl}...',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    try {
      await syncService.syncAll();
    } catch (e) {
      debugPrint('sync_all: falhou com exceção: $e');
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }

    if (mounted) {
      if (syncService.lastError == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sincronização concluída!',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer)),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              syncService.lastError!.length > 80
                  ? '${syncService.lastError!.substring(0, 80)}...'
                  : syncService.lastError!,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer),
            ),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      _carregarDados();
    }
  }

  void _onMenuSelected(String value) {
    switch (value) {
      case 'campo':
        Navigator.of(context).pushNamed('/home');
        break;
      case 'export':
        _exportarXlsx();
        break;
      case 'export_servidor':
        _exportarDoServidor();
        break;
      case 'download_fotos':
        _downloadFotos();
        break;
      case 'sync':
        _sync();
        break;
      case 'audit_log':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AuditLogScreen(database: _db),
          ),
        );
        break;
      case 'limpar_tudo':
        _limparTudo();
        break;
      case 'settings':
        Navigator.of(context).pushNamed('/settings');
        break;
      case 'logout':
        _showLogoutDialog();
        break;
    }
  }

  Future<void> _downloadFotos({String? userId, String? userName}) async {
    final syncService = context.read<SyncService>();
    if (!syncService.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Configure o servidor primeiro.'), duration: Duration(seconds: 5)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Baixando fotos${userName != null ? " de $userName" : ""}...'), duration: const Duration(seconds: 3)),
    );

    final path = await syncService.downloadFotosOrganizadas(
      userId: userId,
      userName: userName,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fotos salvas em:\n$path',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer)),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Nenhuma foto encontrada no servidor ou erro na conexão.',
          style: TextStyle(
              color: Theme.of(context).colorScheme.onTertiaryContainer)),
        backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
        duration: Duration(seconds: 5),
      ),
        );
      }
    }
  }

  Future<void> _exportarXlsx() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Gerando planilha completa...'), duration: Duration(seconds: 3)),
    );

    final exportService = ExportService(_db);
    final ok = await exportService.exportarParcelasXlsx(
      isAdmin: true,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Planilha exportada com sucesso!'
              : 'Nenhuma parcela para exportar.',
              style: TextStyle(
                  color: ok
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onTertiaryContainer)),
          backgroundColor: ok ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.tertiaryContainer,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _exportarDoServidor() async {
    final syncService = context.read<SyncService>();
    if (!syncService.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Configure o servidor primeiro.'), duration: Duration(seconds: 5)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Puxando dados do servidor...'), duration: Duration(seconds: 3)),
    );

    final importados = await syncService.pullDadosDoServidor();

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (importados > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$importados parcelas importadas do servidor. Gerando planilha...',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer)),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Agora exporta normalmente (inclui dados recém-importados)
      await _exportarXlsx();
      _carregarDados(); // Atualiza contadores
    }
  }

  Future<void> _limparTudo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Theme.of(ctx).colorScheme.error),
            SizedBox(width: 8),
            Text('LIMPAR TUDO'),
          ],
        ),
        content: const Text(
          'Isso vai APAGAR:\n'
          '• Todas as parcelas locais\n'
          '• Todas as plantas locais\n'
          '• Todas as fotos locais\n'
          '• Todos os usuários (exceto admin)\n\n'
          'Dados já sincronizados no servidor NÃO serão afetados.\n\n'
          'Tem certeza?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('LIMPAR TUDO'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _db.limparTodosDadosExcetoAdmin();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Todos os dados locais foram limpos! Apenas o admin foi mantido.',
      style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer)),
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      duration: Duration(seconds: 3),
    ),
        );
        _carregarDados();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao limpar dados: $e',
          style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer)),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          duration: const Duration(seconds: 5),
        ),
        );
      }
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair'),
        content: const Text(
          'Os dados locais não sincronizados NÃO serão perdidos. '
          'Deseja sair?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<SyncService>().logout();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TELA DE PARCELAS DE UM USUÁRIO (organizado por UT > dia)
// ============================================================

class _AdminUserParcelasScreen extends StatelessWidget {
  final Usuario usuario;
  final List<Parcela> parcelas;
  final AppDatabase db;
  final Map<String, Future<int>> _plantaCountCache = {};
  final Map<String, Future<int>> _fotoCountCache = {};
  final Map<String, Future<List<FotosParcelaData>>> _fotosCache = {};

  _AdminUserParcelasScreen({
    required this.usuario,
    required this.parcelas,
    required this.db,
  });

  /// Agrupa parcelas por UT (propUt) e dentro de cada UT por dia.
  Map<String, Map<String, List<Parcela>>> _agruparPorUtEDia() {
    final Map<String, Map<String, List<Parcela>>> agrupado = {};
    final sorted = List<Parcela>.from(parcelas)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    for (var parcela in sorted) {
      final ut = parcela.propUt.isNotEmpty ? parcela.propUt : 'Sem UT';
      final dia =
          '${parcela.createdAt.day.toString().padLeft(2, '0')}/${parcela.createdAt.month.toString().padLeft(2, '0')}/${parcela.createdAt.year}';
      agrupado.putIfAbsent(ut, () => {});
      agrupado[ut]!.putIfAbsent(dia, () => []);
      agrupado[ut]![dia]!.add(parcela);
    }
    return agrupado;
  }

  @override
  Widget build(BuildContext context) {
    final porUtDia = _agruparPorUtEDia();
    final uts = porUtDia.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text(usuario.nome),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library),
            tooltip: 'Baixar fotos deste usuário',
            onPressed: () => _downloadFotosUsuario(context),
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Exportar parcelas deste usuário',
            onPressed: () => _exportarUsuario(context),
          ),
        ],
      ),
      body: parcelas.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.forest, size: 80, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma parcela registrada',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: uts.length,
              itemBuilder: (context, utIndex) {
                final ut = uts[utIndex];
                final diasMap = porUtDia[ut]!;
                final dias = diasMap.keys.toList();
                final totalParcelasUT = dias.fold<int>(
                    0, (sum, d) => sum + diasMap[d]!.length);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Cabeçalho do UT ──
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(top: utIndex > 0 ? 16 : 0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.forest,
                              color: Theme.of(context).colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ut,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                Text(
                                  '$totalParcelasUT parcela(s) · ${dias.length} dia(s)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Baixar fotos desta UT
                          IconButton(
                            icon: const Icon(Icons.photo_library_outlined,
                                size: 20),
                            tooltip: 'Baixar fotos desta UT',
                            onPressed: () =>
                                _downloadFotosPorUT(context, ut),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // ── Dias dentro do UT ──
                    ...dias.map((dia) {
                      final parcelasDia = diasMap[dia]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                                top: 4, bottom: 6, left: 8),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today,
                                    size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                const SizedBox(width: 6),
                                Text(
                                  dia,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '(${parcelasDia.length})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...parcelasDia.map(
                            (parcela) =>
                                _buildParcelaCard(context, parcela),
                          ),
                        ],
                      );
                    }),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildParcelaCard(BuildContext context, Parcela parcela) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).pushNamed(
          '/parcela/editar',
          arguments: parcela.uuid,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    parcela.synced ? Icons.cloud_done : Icons.cloud_off,
                    color: parcela.synced ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.tertiary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${parcela.propriedade.isNotEmpty ? "${parcela.propriedade} › " : ""}${parcela.propUt} — P${parcela.idParcela}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              FutureBuilder<int>(
                future: _plantaCountCache.putIfAbsent(parcela.uuid, () => db.getPlantasByParcela(parcela.uuid).then((l) => l.length)),
                builder: (context, snap) {
                  final count = snap.data ?? 0;
                  return Row(
                    children: [
                      _infoChip(context, Icons.grass, '$count plantas'),
                      const SizedBox(width: 12),
                      FutureBuilder<int>(
                        future: _fotoCountCache.putIfAbsent(parcela.uuid, () => db.getFotosByParcela(parcela.uuid).then((l) => l.length)),
                        builder: (context, fotoSnap) {
                          final fotoCount = fotoSnap.data ?? 0;
                          return _infoChip(
                              context,
                              Icons.photo_camera, '$fotoCount fotos');
                        },
                      ),
                      const Spacer(),
                      Text(
                        '${parcela.createdAt.hour.toString().padLeft(2, '0')}:${parcela.createdAt.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (parcela.observacoes != null &&
                  parcela.observacoes!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  parcela.observacoes!,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              // Thumbnails de fotos
              FutureBuilder<List<FotosParcelaData>>(
                future: _fotosCache.putIfAbsent(parcela.uuid, () => db.getFotosByParcela(parcela.uuid)),
                builder: (context, snap) {
                  final fotos = snap.data ?? [];
                  if (fotos.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      height: 64,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: fotos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (ctx, i) {
                final foto = fotos[i];
                return GestureDetector(
                  onTap: () => _showImageViewer(context, fotos, i),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: (!kIsWeb)
                            ? Image.file(
                                File(foto.filePath),
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                cacheWidth: 128,
                              )
                            : Container(
                                width: 64,
                                height: 64,
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: Icon(Icons.image, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                      ),
                      // >>> t9 S1: badge de arquivo ausente no thumbnail
                      if (foto.arquivoAusente) const ArquivoAusenteBadge(),
                    ],
                  ),
                );
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(BuildContext context, IconData icon, String text) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  void _showImageViewer(
      BuildContext context, List<FotosParcelaData> fotos, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenImageViewer(
          fotos: fotos,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Future<void> _downloadFotosPorUT(BuildContext context, String propUt) async {
    final syncService = Provider.of<SyncService>(context, listen: false);
    if (!syncService.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Configure o servidor primeiro.'), duration: Duration(seconds: 5)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Baixando fotos da UT "$propUt"...'), duration: const Duration(seconds: 3)),
    );

    final path = await syncService.downloadFotosOrganizadas(
      userId: usuario.uuid,
      userName: usuario.nome,
      propUt: propUt,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fotos da UT "$propUt" salvas em:\n$path',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer)),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nenhuma foto encontrada para esta UT.',
          style: TextStyle(
              color: Theme.of(context).colorScheme.onTertiaryContainer)),
          backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
          duration: Duration(seconds: 5),
        ),
        );
      }
    }
  }

  Future<void> _downloadFotosUsuario(BuildContext context) async {
    final syncService = Provider.of<SyncService>(context, listen: false);
    if (!syncService.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Configure o servidor primeiro.'), duration: Duration(seconds: 5)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Baixando fotos de ${usuario.nome}...'), duration: const Duration(seconds: 3)),
    );

    final path = await syncService.downloadFotosOrganizadas(
      userId: usuario.uuid,
      userName: usuario.nome,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fotos salvas em:\n$path',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer)),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nenhuma foto encontrada no servidor.',
          style: TextStyle(
              color: Theme.of(context).colorScheme.onTertiaryContainer)),
          backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
          duration: Duration(seconds: 5),
        ),
        );
      }
    }
  }

  Future<void> _exportarUsuario(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exportando parcelas de ${usuario.nome}...'), duration: const Duration(seconds: 3)),
    );

  final exportService = ExportService(db);
  final ok = await exportService.exportarParcelasXlsx(
    userId: usuario.uuid,
    isAdmin: false,
    nomeUsuario: usuario.nome,
  );

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Planilha exportada com sucesso!'
              : 'Nenhuma parcela para exportar.',
              style: TextStyle(
                  color: ok
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onTertiaryContainer)),
          backgroundColor: ok ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.tertiaryContainer,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

/// Visualizador de imagens em tela cheia com PageView (deslizar entre fotos)
class _FullscreenImageViewer extends StatefulWidget {
  final List<FotosParcelaData> fotos;
  final int initialIndex;

  const _FullscreenImageViewer({
    required this.fotos,
    required this.initialIndex,
  });

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / ${widget.fotos.length}',
          style: TextStyle(fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.fotos.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
      itemBuilder: (context, index) {
        final foto = widget.fotos[index];
        if (kIsWeb) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.image, size: 64, color: Colors.white54),
                SizedBox(height: 12),
                Text(
                  'Visualização não disponível na web',
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
          );
        }
        final file = File(foto.filePath);
        if (!file.existsSync()) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image, size: 64, color: Colors.white54),
                  SizedBox(height: 12),
                  Text(
                    'Imagem não encontrada',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            );
          }
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.file(
                file,
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}
