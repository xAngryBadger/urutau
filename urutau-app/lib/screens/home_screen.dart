import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../data/database.dart';
import '../services/sync_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppDatabase get _db => context.read<AppDatabase>();

  // ── Estado do filtro ──
  bool _filterActive = false;
  String? _filterPropUt;
  DateTime? _filterDataInicio;
  DateTime? _filterDataFim;
  List<Parcela>? _filteredParcelas;
  List<String> _talhoes = [];
  bool _showFilterBar = false;

  @override
  void initState() {
    super.initState();
    _loadTalhoes();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final syncService = context.read<SyncService>();
      syncService.autoSync();
    });
  }

  Future<void> _loadTalhoes() async {
    final syncService = context.read<SyncService>();
    final talhoes = await _db.getAllTalhoes(
      userId: syncService.currentUser?.uuid,
      isAdmin: syncService.isAdmin,
    );
    if (mounted) setState(() => _talhoes = talhoes);
  }

  Future<void> _applyFilter() async {
    final syncService = context.read<SyncService>();
    final results = await _db.searchParcelas(
      userId: syncService.isAdmin ? null : syncService.currentUser?.uuid,
      isAdmin: syncService.isAdmin,
      propUt: _filterPropUt,
      dataInicio: _filterDataInicio,
      dataFim: _filterDataFim,
    );
    if (mounted) {
      setState(() {
        _filteredParcelas = results;
        _filterActive = true;
        _showFilterBar = false;
      });
    }
  }

  void _clearFilter() {
    setState(() {
      _filterActive = false;
      _filteredParcelas = null;
      _filterPropUt = null;
      _filterDataInicio = null;
      _filterDataFim = null;
      _showFilterBar = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final syncService = context.watch<SyncService>();

    return Scaffold(
      appBar: AppBar(
    title: Semantics(
      label: 'Urutau - ${syncService.currentUser?.nome ?? "app florestal"}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('Urutau'),
          if (syncService.currentUser != null)
            Text(
              syncService.currentUser!.nome,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
        ],
      ),
    ),
    centerTitle: true,
    actions: [
          // Indicador de sincronização
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: Icon(
                _showFilterBar
                    ? Icons.filter_alt
                    : (_filterActive ? Icons.filter_alt : Icons.filter_alt_outlined),
                color: _filterActive ? Colors.amber : null,
              ),
              tooltip: 'Filtrar por data ou talhão',
              onPressed: () => setState(() => _showFilterBar = !_showFilterBar),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: syncService.pendingCount > 0
                ? Badge(
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
                      onPressed: syncService.isSyncing ? null : () => _sync(),
                      tooltip: 'Sincronizar dados',
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.cloud_done),
                    onPressed: null,
                    tooltip: 'Tudo sincronizado',
                    color: Colors.green[200],
                  ),
          ),
          PopupMenuButton<String>(
            onSelected: _onMenuSelected,
            itemBuilder: (context) => [
              // Admin fora do fluxo utilizador (injetado fora do app)
              const PopupMenuItem(
                value: 'pull_meus',
                child: ListTile(
                  leading: Icon(Icons.cloud_download),
                  title: Text('Puxar do servidor'),
                  subtitle: Text('Baixar minhas parcelas sincronizadas'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'download_fotos',
                child: ListTile(
                  leading: Icon(Icons.photo_library),
                  title: Text('Baixar minhas fotos'),
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
      body: Column(
        children: [
          // Banner de status
          _buildStatusBanner(syncService),
          // Barra de filtro (colapsável)
          if (_showFilterBar) _buildFilterBar(syncService),
          // Tag de filtro ativo
          if (_filterActive) _buildFilterTag(),
          // Parcelas incompletas (rascunhos) — retomar sem perder dados
          _buildIncompletasCard(syncService),
          // Lista de parcelas
          Expanded(
            child: StreamBuilder<List<Parcela>>(
              stream: _db.watchAllParcelas(
                userId: syncService.currentUser?.uuid,
                isAdmin: syncService.isAdmin,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Se filtro ativo, usa lista filtrada; senão usa stream
                final parcelas = _filterActive
                    ? (_filteredParcelas ?? [])
                    : (snapshot.data ?? []);

                if (parcelas.isEmpty) {
                  return _buildEmptyState(
                      filterActive: _filterActive);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: parcelas.length,
                  itemBuilder: (context, index) {
                    return _buildParcelaCard(parcelas[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Semantics(
        label: 'Criar nova parcela',
        button: true,
        child: FloatingActionButton.extended(
          onPressed: () => Navigator.of(context).pushNamed('/parcela/nova'),
          icon: const Icon(Icons.add),
          label: const Text('Nova Parcela'),
        ),
      ),
    );
  }

  Widget _buildStatusBanner(SyncService syncService) {
    if (syncService.isSyncing) {
      return Container(
        width: double.infinity,
        color: Colors.blue[50],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Sincronizando dados...',
              style: TextStyle(color: Colors.blue[800]),
            ),
          ],
        ),
      );
    }

    if (syncService.lastError != null) {
      return Container(
        width: double.infinity,
        color: Colors.red[50],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[700], size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                syncService.lastError!,
                style: TextStyle(color: Colors.red[700], fontSize: 13),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: _sync,
              tooltip: 'Tentar novamente',
            ),
          ],
        ),
      );
    }

    if (syncService.pendingCount > 0) {
      return Container(
        width: double.infinity,
        color: Colors.orange[50],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.cloud_off, color: Colors.orange[800], size: 18),
            const SizedBox(width: 8),
            Text(
              '${syncService.pendingCount} parcela(s) pendente(s)',
              style: TextStyle(color: Colors.orange[800]),
            ),
            const Spacer(),
            TextButton(
              onPressed: _sync,
              child: const Text('Sincronizar'),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildFilterBar(SyncService syncService) {
    final dateFmt = DateFormat('dd/MM/yy');
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filtrar parcelas',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          // Talhão dropdown
          if (_talhoes.isNotEmpty)
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Talhão / Propriedade',
                prefixIcon: const Icon(Icons.forest, size: 18),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              value: _filterPropUt,
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos os talhões')),
                ..._talhoes.map((t) => DropdownMenuItem(value: t, child: Text(t))),
              ],
              onChanged: (v) => setState(() => _filterPropUt = v),
            ),
          const SizedBox(height: 8),
          // Intervalo de datas
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _filterDataInicio != null
                        ? 'De: ${dateFmt.format(_filterDataInicio!)}'
                        : 'Data início',
                    style: const TextStyle(fontSize: 13),
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _filterDataInicio ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _filterDataInicio = picked);
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
                    style: const TextStyle(fontSize: 13),
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _filterDataFim ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _filterDataFim = picked);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar'),
                  onPressed: _applyFilter,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _clearFilter,
                child: const Text('Limpar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTag() {
    final parts = <String>[];
    if (_filterPropUt != null) parts.add(_filterPropUt!);
    if (_filterDataInicio != null) {
      final fmt = DateFormat('dd/MM/yy');
      parts.add('De ${fmt.format(_filterDataInicio!)}');
    }
    if (_filterDataFim != null) {
      final fmt = DateFormat('dd/MM/yy');
      parts.add('Até ${fmt.format(_filterDataFim!)}');
    }
    final label = parts.isEmpty ? 'Filtro ativo' : parts.join(' • ');

    return Container(
      width: double.infinity,
      color: Colors.amber[50],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.filter_alt, size: 16, color: Colors.amber),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.amber[900],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: _clearFilter,
            child: Text(
              'Limpar',
              style: TextStyle(
                color: Colors.amber[800],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncompletasCard(SyncService syncService) {
    final myId = syncService.currentUser?.uuid;
    if (myId == null || myId.isEmpty) return const SizedBox.shrink();
    return FutureBuilder<List<Parcela>>(
      future: _db.getParcelasIncompletas(myId),
      builder: (context, snapshot) {
        final list = snapshot.data ?? [];
        if (list.isEmpty) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Material(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (list.length == 1) {
                  Navigator.of(context).pushNamed('/parcela/editar', arguments: list.first.uuid);
                } else {
                  showModalBottomSheet(
                    context: context,
                    builder: (ctx) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Retomar parcela incompleta',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          ...list.map((p) => ListTile(
                            leading: const Icon(Icons.edit_note, color: Colors.blue),
                            title: Text('${p.propriedade} · ${p.propUt} · Parcela ${p.idParcela}'),
                            onTap: () {
                              Navigator.pop(ctx);
                              Navigator.of(context).pushNamed('/parcela/editar', arguments: p.uuid);
                            },
                          )),
                        ],
                      ),
                    ),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.edit_note, color: Colors.blue[700], size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        list.length == 1
                            ? '1 parcela incompleta — toque para retomar'
                            : '${list.length} parcelas incompletas — toque para retomar',
                        style: TextStyle(
                          color: Colors.blue[900],
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.blue[700]),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({bool filterActive = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            filterActive ? Icons.search_off : Icons.forest,
            size: 100,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          Text(
            filterActive ? 'Nenhuma parcela encontrada' : 'Nenhuma parcela cadastrada',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            filterActive
                ? 'Tente alterar ou limpar os filtros'
                : 'Toque em "Nova Parcela" para começar',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          if (filterActive) ...[            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.clear),
              label: const Text('Limpar filtro'),
              onPressed: _clearFilter,
            ),
          ],
        ],
      ),
    );
  }
  Widget _buildParcelaCard(Parcela parcela) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).pushNamed(
          '/parcela/editar',
          arguments: parcela.uuid,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Ícone de sincronização
                  Icon(
                    parcela.synced ? Icons.cloud_done : Icons.cloud_off,
                    color: parcela.synced ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${parcela.propUt} — Parcela ${parcela.idParcela}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey[400],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Info das plantas
              FutureBuilder<List<Planta>>(
                future: _db.getPlantasByParcela(parcela.uuid),
                builder: (context, snap) {
                  final count = snap.data?.length ?? 0;
                  return Row(
                    children: [
                      _infoChip(Icons.grass, '$count plantas'),
                      const SizedBox(width: 12),
                      FutureBuilder<List<FotosParcelaData>>(
                        future: _db.getFotosByParcela(parcela.uuid),
                        builder: (context, fotoSnap) {
                          final fotoCount = fotoSnap.data?.length ?? 0;
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _infoChip(Icons.photo_camera, '$fotoCount fotos'),
                              // [GPS DESATIVADO - MANUTENÇÃO]
                              // if (parcela.latitude != null) ...[
                              //   const SizedBox(width: 12),
                              //   _infoChip(Icons.location_on, 'GPS'),
                              // ],
                            ],
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
              if (parcela.observacoes != null &&
                  parcela.observacoes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  parcela.observacoes!,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 4),
              Text(
                _formatDate(parcela.createdAt),
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _sync() async {
    final syncService = context.read<SyncService>();
    if (!syncService.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configure o servidor primeiro nas configurações.'),
        ),
      );
      return;
    }

    final myId = syncService.currentUser?.uuid ?? '';
    final incompletas = myId.isEmpty ? <Parcela>[] : await _db.getParcelasIncompletas(myId);
    if (!mounted) return;
    final pendingBefore = syncService.pendingCount;

    // Diálogo de confirmação antes de sincronizar
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cloud_upload, color: Color(0xFF304d36)),
            SizedBox(width: 8),
            Expanded(child: Text('Sincronizar parcelas?')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pendingBefore > 0
                  ? '$pendingBefore parcela(s) concluída(s) pronta(s) para envio.'
                  : 'Nenhuma parcela concluída pendente de envio.',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            if (incompletas.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.save_as, size: 18, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Você tem ${incompletas.length} parcela(s) incompleta(s). '
                      'Só são enviadas parcelas que você marcou como "Concluir parcela". '
                      'As incompletas ficam só no dispositivo até concluir.',
                      style: TextStyle(fontSize: 13, color: Colors.blue[900]),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.edit_note, size: 18, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'Revise seus dados antes de enviar. Após sincronizar, as alterações ficam no servidor.',
                  style: TextStyle(fontSize: 13),
                )),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.wifi, size: 18, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'Recomenda-se usar uma conexão Wi-Fi estável para evitar falhas.',
                  style: TextStyle(fontSize: 13),
                )),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Revisar dados'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.cloud_upload),
            onPressed: () => Navigator.pop(ctx, true),
            label: const Text('Enviar agora'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    // Mostra diálogo de progresso
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

    await syncService.syncAll();

    // Fecha diálogo
    if (mounted) {
      Navigator.of(context).pop();
    }

    if (mounted) {
      if (syncService.lastError == null) {
        final sent = pendingBefore; // quantidade que estava pendente
        String msg = sent > 0
            ? 'Enviadas $sent parcela(s) concluída(s).'
            : 'Sincronização concluída.';
        if (incompletas.isNotEmpty) {
          msg += ' ${incompletas.length} parcela(s) incompleta(s) permanecem só no dispositivo (conclua-as para enviar).';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              syncService.lastError!.length > 80
                  ? '${syncService.lastError!.substring(0, 80)}...'
                  : syncService.lastError!,
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _onMenuSelected(String value) {
    switch (value) {
      case 'sync':
        _sync();
        break;
      case 'pull_meus':
        _pullMeusDados();
        break;
      case 'download_fotos':
        _downloadMinhasFotos();
        break;
      case 'settings':
        Navigator.of(context).pushNamed('/settings');
        break;
      case 'logout':
        _showLogoutDialog();
        break;
    }
  }

  Future<void> _pullMeusDados() async {
    final syncService = context.read<SyncService>();
    if (!syncService.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configure o servidor primeiro.')),
      );
      return;
    }
    if (!await syncService.hasInternet()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sem conexão com a internet.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Baixando suas parcelas do servidor...')),
    );

    try {
      final importados = await syncService.pullDadosDoServidor(
        userId: syncService.currentUser?.uuid,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(importados > 0
                ? '$importados parcela(s) importada(s) do servidor.'
                : 'Nenhuma parcela nova encontrada.'),
            backgroundColor: importados > 0 ? Colors.green : Colors.blue,
          ),
        );
        _loadTalhoes();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _downloadMinhasFotos() async {
    final syncService = context.read<SyncService>();
    if (!syncService.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configure o servidor primeiro.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Baixando suas fotos do servidor...')),
    );

    final path = await syncService.downloadFotosOrganizadas(
      userId: syncService.currentUser?.uuid,
      userName: syncService.currentUser?.nome,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fotos salvas em:\n$path'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nenhuma foto encontrada ou erro na conexão.'),
            backgroundColor: Colors.orange,
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
