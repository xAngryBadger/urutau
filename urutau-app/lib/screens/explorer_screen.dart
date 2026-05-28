import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:provider/provider.dart';
import '../data/database.dart';
import '../services/sync_service.dart';
import '../services/export_service.dart';
import '../services/image_service.dart';
import '../theme/app_theme.dart';

enum _ParcelaOwnership { mine, free, other }

class _OwnershipInfo {
  int mine = 0;
  int free = 0;
  int other = 0;
  int synced = 0;
  int get total => mine + free + other;
}

/// Explorer estilo pasta (Propriedade → UT/Talhão → Parcela).
/// Filtra por utilizador: mostra parcelas próprias (editáveis),
/// livres (claimable) e de outros (bloqueadas).
class ExplorerScreen extends StatefulWidget {
  const ExplorerScreen({super.key});

  @override
  State<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends State<ExplorerScreen> {
  AppDatabase get _db => context.read<AppDatabase>();
  final TextEditingController _searchController = TextEditingController();
  final List<Map<String, String>> _caminho = [];

  List<String> _propriedades = [];
  List<String> _uts = [];
  List<Parcela> _parcelas = [];

  final Map<String, int> _contagemUts = {};
  final Map<String, int> _contagemParcelas = {};
  final Map<String, _OwnershipInfo> _propriedadeInfo = {};
  final Map<String, _OwnershipInfo> _utInfo = {};
  final Map<String, String> _userNames = {};

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refreshNivel();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? get _myUserId => context.read<SyncService>().currentUser?.uuid;

  _ParcelaOwnership _classify(Parcela p) {
    final myId = _myUserId;
    if (myId != null && p.userId == myId) return _ParcelaOwnership.mine;
    if (p.userId.isEmpty) return _ParcelaOwnership.free;
    return _ParcelaOwnership.other;
  }

  // ─── Data Loading ─────────────────────────────────────

  Future<void> _refreshNivel() async {
    setState(() => _loading = true);

    if (_userNames.isEmpty) {
      final users = await _db.getAllUsuarios();
      for (final u in users) {
        _userNames[u.uuid] = u.nome;
      }
    }

    final syncService = context.read<SyncService>();
    final currentUser = syncService.currentUser;
    final userId = currentUser?.uuid;
    final isAdmin = currentUser?.isAdmin ?? false;

    final depth = _caminho.length;

    if (depth == 0) {
      _propriedades =
          await _db.getAllPropriedades(userId: userId, isAdmin: isAdmin);
      _contagemUts.clear();
      _propriedadeInfo.clear();
      for (final prop in _propriedades) {
        final uts = await _db.getAllTalhoes(
            propriedade: prop, userId: userId, isAdmin: isAdmin);
        _contagemUts[prop] = uts.length;
        final parcelas = await _db.getParcelasByHierarchy(
            propriedade: prop, userId: userId, isAdmin: isAdmin);
        _propriedadeInfo[prop] = _summarizeOwnership(parcelas);
      }
    } else if (depth == 1) {
      final prop = _caminho[0]['value']!;
      _uts = await _db.getAllTalhoes(
          propriedade: prop, userId: userId, isAdmin: isAdmin);
      _contagemParcelas.clear();
      _utInfo.clear();
      for (final ut in _uts) {
        final parcelas = await _db.getParcelasByHierarchy(
          propriedade: prop,
          propUt: ut,
          userId: userId,
          isAdmin: isAdmin,
        );
        _contagemParcelas[ut] = parcelas.length;
        _utInfo[ut] = _summarizeOwnership(parcelas);
      }
    } else if (depth == 2) {
      final prop = _caminho[0]['value']!;
      final ut = _caminho[1]['value']!;
      _parcelas = await _db.getParcelasByHierarchy(
        propriedade: prop,
        propUt: ut,
        userId: userId,
        isAdmin: isAdmin,
      );
    }

    if (mounted) setState(() => _loading = false);
  }

  _OwnershipInfo _summarizeOwnership(List<Parcela> parcelas) {
    final info = _OwnershipInfo();
    for (final p in parcelas) {
      switch (_classify(p)) {
        case _ParcelaOwnership.mine:
          info.mine++;
          if (p.synced) info.synced++;
        case _ParcelaOwnership.free:
          info.free++;
        case _ParcelaOwnership.other:
          info.other++;
      }
    }
    return info;
  }

  // ─── Navigation ───────────────────────────────────────

  void _entrar(String tipo, String valor) {
    _caminho.add({'tipo': tipo, 'value': valor});
    _searchController.clear();
    _refreshNivel();
  }

  void _voltar() {
    if (_caminho.isNotEmpty) {
      _caminho.removeLast();
      _searchController.clear();
      _refreshNivel();
    }
  }

  void _irPara(int indice) {
    while (_caminho.length > indice + 1) {
      _caminho.removeLast();
    }
    _searchController.clear();
    _refreshNivel();
  }

  void _irParaRaiz() {
    _caminho.clear();
    _searchController.clear();
    _refreshNivel();
  }

  // ─── Parcela Actions ──────────────────────────────────

  void _openParcela(Parcela p) {
    // Catálogo estático: qualquer parcela pode ser aberta.
    // Se a parcela ainda não tem dono, atribui o utilizador atual automaticamente.
    if (p.userId.isEmpty && _myUserId != null) {
      _db.updateParcela(
        ParcelasCompanion(
          userId: drift.Value(_myUserId!),
          synced: const drift.Value(false),
          updatedAt: drift.Value(DateTime.now()),
        ),
        p.uuid,
      );
    }
    Navigator.of(context)
        .pushNamed('/parcela/editar', arguments: p.uuid)
        .then((_) => _refreshNivel());
  }

  Future<void> _showClaimDialog(Parcela p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.person_add, color: Colors.blue, size: 32),
        title: const Text('Parcela Disponível'),
        content: Text(
          'Parcela ${p.idParcela} está livre.\n'
          'Deseja assumir esta parcela para trabalhar nela?',
        ),
        actions: [
          Semantics(
            label: 'Cancelar',
            button: true,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
          ),
          Semantics(
            label: 'Assumir parcela',
            button: true,
            child: FilledButton.icon(
              icon: const Icon(Icons.check),
              onPressed: () => Navigator.pop(ctx, true),
              label: const Text('Assumir'),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && _myUserId != null) {
      await _db.updateParcela(
        ParcelasCompanion(
          userId: drift.Value(_myUserId!),
          synced: const drift.Value(false),
          updatedAt: drift.Value(DateTime.now()),
        ),
        p.uuid,
      );
      await _refreshNivel();
      if (mounted) {
        Navigator.of(context)
            .pushNamed('/parcela/editar', arguments: p.uuid)
            .then((_) => _refreshNivel());
      }
    }
  }

  void _showLockedDialog(Parcela p) {
    final ownerName = _userNames[p.userId] ?? 'Outro utilizador';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.lock, color: Colors.red[400], size: 32),
        title: const Text('Parcela Bloqueada'),
        content: Text(
          'Esta parcela pertence a "$ownerName".\n\n'
          'Não é possível visualizar ou editar parcelas de outros utilizadores.',
        ),
        actions: [
          Semantics(
            label: 'Entendido',
            button: true,
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Wizard de Criação ────────────────────────────────

  Future<void> _adicionar() async {
    final depth = _caminho.length;
    String? propriedade;
    String? ut;

    if (depth == 0) {
      propriedade = await _askForName(
        'Propriedade',
        hint: 'Ex: GHGH0194',
        existentes: _propriedades,
      );
      if (propriedade == null || propriedade.isEmpty) return;
    } else {
      propriedade = _caminho[0]['value']!;
    }

    if (depth <= 1) {
      final utsExistentes = await _db.getAllTalhoes(propriedade: propriedade);
      if (!mounted) return;
      ut = await _askForName(
        'UT / Talhão',
        hint: 'Ex: UT01',
        existentes: utsExistentes,
      );
      if (ut == null || ut.isEmpty) return;
    } else {
      ut = _caminho[1]['value']!;
    }

    // Número da parcela é definido pelo usuário no formulário (não sugerimos para evitar confusão com dados antigos)
    if (!mounted) return;
    final result = await Navigator.of(context).pushNamed(
      '/parcela/nova',
      arguments: {
        'propriedade': propriedade,
        'propUt': ut,
      },
    );

    if (result == true && mounted) {
      _caminho.clear();
      _caminho.add({'tipo': 'Propriedade', 'value': propriedade});
      _caminho.add({'tipo': 'UT', 'value': ut});
      _refreshNivel();
    }
  }

  Future<String?> _askForName(
    String label, {
    String? hint,
    List<String> existentes = const [],
  }) {
    return showDialog<String?>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: Text('Nome do(a) $label'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: hint ?? label,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
              ),
              if (existentes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Existentes:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: existentes.map((e) {
                        return ActionChip(
                          label: Text(e, style: const TextStyle(fontSize: 12)),
                          onPressed: () => Navigator.pop(ctx, e),
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            Semantics(
              label: 'Cancelar',
              button: true,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
            ),
            Semantics(
              label: 'Confirmar',
              button: true,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: const Text('Confirmar'),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Sync & Cache ─────────────────────────────────────

  /// Mostra parcelas já feitas no servidor. Se estiver dentro de uma UT (_caminho.length==2),
  /// filtra só essa UT ("parcelas desta UT já feitas").
  Future<void> _showParcelasFeitasServidor() async {
    final syncService = context.read<SyncService>();
    if (!syncService.isConfigured || !await syncService.hasInternet()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sem conexão. Verifique a internet.')),
        );
      }
      return;
    }
    if (!mounted) return;
    final filtroUt = _caminho.length >= 2
        ? {'prop': _caminho[0]['value'], 'ut': _caminho[1]['value']}
        : null;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Buscando parcelas no servidor...'),
          ],
        ),
      ),
    );
    List<Map<String, String>> lista =
        await syncService.fetchParcelasFeitasDoServidor();
    if (!mounted) return;
    Navigator.of(context).pop();
    if (filtroUt != null &&
        filtroUt['prop'] != null &&
        filtroUt['ut'] != null) {
      lista = lista.where((m) {
        return m['propriedade'] == filtroUt['prop'] &&
            m['propUt'] == filtroUt['ut'];
      }).toList();
    }
    if (!mounted) return;
    final titulo = filtroUt != null
        ? 'Parcelas já feitas nesta UT (servidor)'
        : 'Parcelas já feitas (servidor)';
    final subtitulo =
        'Conforme o servidor — o que outros utilizadores já concluíram.';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, sc) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.visibility,
                          color: AppTheme.primary, size: 28),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          titulo,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitulo,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Flexible(
              child: lista.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        filtroUt != null
                            ? 'Nenhuma parcela desta UT concluída no servidor.'
                            : 'Nenhuma parcela concluída no servidor.',
                      ),
                    )
                  : ListView.builder(
                      controller: sc,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: lista.length,
                      itemBuilder: (_, i) {
                        final m = lista[i];
                        final uid = m['user'] ?? '';
                        final owner = _userNames[uid] ?? uid;
                        return ListTile(
                          dense: true,
                          title: Text(
                              '${m['propriedade'] ?? ''} · ${m['propUt'] ?? ''} · Parcela ${m['idParcela'] ?? ''}'),
                          subtitle: Text(owner.isNotEmpty ? owner : '—'),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Nova UI de sync: puxa estado do servidor primeiro, lista parcelas com checkbox,
  /// lápis para editar e botão confirmar envio. Conflitos ficam marcados e não são enviados.
  Future<void> _showSyncOptions() async {
    final myId = _myUserId;
    final syncService = context.read<SyncService>();
    if (!syncService.isConfigured) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Configure o servidor nas definições primeiro.')),
        );
      }
      return;
    }
    if (myId == null) return;

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(child: Text('A verificar servidor...')),
            ],
          ),
        ),
      );
    }
    final pending = await _db.getParcelasNaoSincronizadas(userId: myId);
    final conflitosResult = await syncService.fetchConflitos(userId: myId);
    if (!mounted) return;
    Navigator.of(context).pop(); // loading

    final conflictKeys = conflitosResult.conflictKeys;
    final conflitoMessages = conflitosResult.messages;

    if (pending.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Nenhuma parcela concluída para sincronizar.')),
        );
      }
      return;
    }

    // Estado: quais UUIDs estão selecionados para envio (apenas não-conflito)
    final selectableUuids = pending
        .where((p) => !conflictKeys.contains(SyncService.parcelaKey(p)))
        .map((p) => p.uuid)
        .toSet();
    final selectedUuids = Set<String>.from(selectableUuids);

    if (!mounted) return;
    int syncedCount = 0;
    final myParcelas = await _db.getAllParcelas(userId: myId);
    for (final p in myParcelas) {
      if (p.synced) syncedCount++;
    }
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SyncListSheet(
        parcelas: pending,
        conflictKeys: conflictKeys,
        selectedUuids: selectedUuids,
        selectableUuids: selectableUuids,
        accentColor: AppTheme.primary,
        syncedCount: syncedCount,
        onEdit: (p) async {
          Navigator.pop(ctx);
          await Navigator.of(context)
              .pushNamed('/parcela/editar', arguments: p.uuid);
          if (mounted) await _refreshNivel();
        },
        onPull: () {
          Navigator.pop(ctx);
          _doPull();
        },
        onClearCache: syncedCount > 0
            ? () {
                Navigator.pop(ctx);
                _confirmClearSyncedCache(syncedCount);
              }
            : null,
        onConfirm: (selected) async {
          Navigator.pop(ctx);
          if (selected.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Seleccione pelo menos uma parcela.')),
              );
            }
            return;
          }
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const AlertDialog(
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('A enviar...'),
                ],
              ),
            ),
          );
          final result = await syncService.syncSelected(
            uuids: selected,
            conflictKeys: conflictKeys,
            userId: myId,
          );
          if (!mounted) return;
          Navigator.of(context).pop();
          await _refreshNivel();
          if (!mounted) return;
          String msg = '${result.sent} parcela(s) enviada(s).';
          if (result.conflictsBlocked > 0) {
            msg +=
                ' ${result.conflictsBlocked} em conflito no servidor (não enviadas).';
          }
          if (conflitoMessages.isNotEmpty && selected.length < pending.length) {
            msg += ' Parcelas em conflito ficam marcadas com aviso.';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: result.sent > 0 ? Colors.green : Colors.orange,
            ),
          );
        },
      ),
    );
  }

  Widget _syncInfoTile(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Future<void> _confirmClearSyncedCache(int count) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.cleaning_services, color: Colors.red[400], size: 32),
        title: const Text('Limpar cache?'),
        content: Text(
          'Isto removerá $count parcela(s) já sincronizada(s) do '
          'armazenamento local.\n\n'
          'Os dados permanecem seguros no servidor. '
          'Pode recuperá-los puxando do servidor.',
        ),
        actions: [
          Semantics(
            label: 'Cancelar',
            button: true,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
          ),
          Semantics(
            label: 'Limpar cache',
            button: true,
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Limpar'),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && _myUserId != null) {
      final myParcelas = await _db.getAllParcelas(userId: _myUserId);
      int cleared = 0;
      for (final p in myParcelas) {
        if (p.synced) {
          await _db.deleteAllPlantasByParcela(p.uuid);
          await _db.deleteAllFotosByParcela(p.uuid);
          await _db.deleteParcela(p.uuid);
          cleared++;
        }
      }
      await _refreshNivel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$cleared parcela(s) removida(s) do cache local.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _doSync() async {
    final syncService = context.read<SyncService>();
    if (!syncService.isConfigured) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Configure o servidor nas definições primeiro.')),
        );
      }
      return;
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const PopScope(
          canPop: false,
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Sincronizando...', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    await syncService.syncAll();

    if (mounted) Navigator.of(context).pop();
    await _refreshNivel();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(syncService.lastError ?? 'Sincronização concluída!'),
          backgroundColor:
              syncService.lastError != null ? Colors.red : Colors.green,
        ),
      );
    }
  }

  // Pull de parcelas desativado — catálogo é estático/local.
  Future<void> _doPull() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('O catálogo de parcelas é local e já está carregado.')),
      );
    }
    return;
    // --- Funcionalidade online comentada ---
    // ignore: dead_code
    final syncService = context.read<SyncService>();
    if (!syncService.isConfigured) return;
    if (!await syncService.hasInternet()) return;
    try {
      final importados = await syncService.pullDadosDoServidor();
      await _refreshNivel();
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

  Future<void> _exportarXlsx() async {
    final syncService = context.read<SyncService>();
    final user = syncService.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Faça login para exportar.')),
        );
      }
      return;
    }

    // Primeiro: escolher fonte (APP ou Servidor), com explicação
    final fonte = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Exportar planilha'),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Exportar do APP: gera a planilha com os dados que estão neste dispositivo (o que você registou aqui).\n\n'
              'Exportar do Servidor: atualiza primeiro a lista a partir do servidor e depois gera a planilha com esses dados (inclui o que outros utilizadores já enviaram). Requer internet.',
              style: TextStyle(fontSize: 13, height: 1.35),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'app'),
            child: const ListTile(
              leading: Icon(Icons.phone_android),
              title: Text('Exportar do APP'),
              subtitle: Text('Dados que estão neste dispositivo'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'servidor'),
            child: const ListTile(
              leading: Icon(Icons.cloud),
              title: Text('Exportar do Servidor'),
              subtitle: Text('Atualizar do servidor e depois exportar'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
    if (fonte == null || !mounted) return;

    if (fonte == 'servidor') {
      if (!syncService.isConfigured) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Configure o servidor nas definições.')),
          );
        }
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A atualizar lista do servidor...')),
        );
      }
      try {
        await syncService.pullDadosDoServidor(
            userId: user.isAdmin ? null : user.uuid);
        if (mounted) await _refreshNivel();
        if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Erro ao atualizar: $e'),
                backgroundColor: Colors.red),
          );
        }
        return;
      }
    }

    final admin = user.isAdmin;
    final depth = _caminho.length;

    // Opções de export dependem do nível e se é admin
    final options = <Map<String, String>>[];
    if (admin) {
      if (depth >= 1) {
        options
            .add({'key': 'prop', 'label': 'Tudo de ${_caminho[0]['value']}'});
      }
      if (depth >= 2) {
        options.add({'key': 'ut', 'label': 'Tudo de ${_caminho[1]['value']}'});
      }
      options.add({'key': 'all', 'label': 'Tudo (todas propriedades)'});
      options.add({'key': 'mine', 'label': 'Só minhas parcelas'});
    } else {
      if (depth >= 1) {
        options.add(
            {'key': 'prop_mine', 'label': 'Minhas em ${_caminho[0]['value']}'});
      }
      if (depth >= 2) {
        options.add(
            {'key': 'ut_mine', 'label': 'Minhas em ${_caminho[1]['value']}'});
      }
      options.add({'key': 'mine', 'label': 'Todas minhas parcelas'});
    }

    if (options.length == 1) {
      await _doExport(options.first['key']!, user);
      return;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Exportar planilha'),
        children: options
            .map((o) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, o['key']),
                  child: Text(o['label']!),
                ))
            .toList(),
      ),
    );
    if (choice != null && mounted) {
      await _doExport(choice, user);
    }
  }

  Future<void> _exportarFotos() async {
    final syncService = context.read<SyncService>();
    final user = syncService.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Faça login para exportar fotos.')),
        );
      }
      return;
    }
    final admin = user.isAdmin;
    final depth = _caminho.length;

    final options = <Map<String, String>>[];
    if (admin) {
      if (depth >= 1)
        options
            .add({'key': 'prop', 'label': 'Fotos de ${_caminho[0]['value']}'});
      if (depth >= 2)
        options.add({'key': 'ut', 'label': 'Fotos de ${_caminho[1]['value']}'});
      options.add({'key': 'all', 'label': 'Todas as fotos'});
      options.add({'key': 'mine', 'label': 'Só minhas parcelas'});
    } else {
      if (depth >= 1)
        options.add({
          'key': 'prop_mine',
          'label': 'Minhas fotos em ${_caminho[0]['value']}'
        });
      if (depth >= 2)
        options.add({
          'key': 'ut_mine',
          'label': 'Minhas fotos em ${_caminho[1]['value']}'
        });
      options.add({'key': 'mine', 'label': 'Todas as minhas fotos'});
    }

    String? choice;
    if (options.length == 1) {
      choice = options.first['key'];
    } else {
      choice = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Exportar fotos'),
          children: options
              .map((o) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, o['key']),
                    child: Text(o['label']!),
                  ))
              .toList(),
        ),
      );
    }
    if (choice == null || !mounted) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A preparar fotos...')),
      );
    }
    final exportService = ExportService(_db);
    String? prop;
    String? ut;
    String? userId = user.uuid;
    bool isAdmin = false;
    switch (choice) {
      case 'all':
        userId = null;
        isAdmin = true;
        break;
      case 'mine':
        break;
      case 'prop':
        prop = _caminho.isNotEmpty ? _caminho[0]['value'] : null;
        userId = null;
        isAdmin = true;
        break;
      case 'ut':
        prop = _caminho.isNotEmpty ? _caminho[0]['value'] : null;
        ut = _caminho.length > 1 ? _caminho[1]['value'] : null;
        userId = null;
        isAdmin = true;
        break;
      case 'prop_mine':
        prop = _caminho.isNotEmpty ? _caminho[0]['value'] : null;
        break;
      case 'ut_mine':
        prop = _caminho.isNotEmpty ? _caminho[0]['value'] : null;
        ut = _caminho.length > 1 ? _caminho[1]['value'] : null;
        break;
    }
    final (ok, msg) = await exportService.exportarFotosLocais(
      userId: userId,
      isAdmin: isAdmin,
      propriedade: prop,
      propUt: ut,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: ok ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  Future<void> _doExport(String key, Usuario user) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A gerar planilha...')),
      );
    }
    final exportService = ExportService(_db);
    String? prop;
    String? ut;
    String? userId = user.uuid;
    bool admin = false;

    switch (key) {
      case 'all':
        userId = null;
        admin = true;
      case 'mine':
        break;
      case 'prop':
        prop = _caminho.isNotEmpty ? _caminho[0]['value'] : null;
        userId = null;
        admin = true;
      case 'ut':
        prop = _caminho.isNotEmpty ? _caminho[0]['value'] : null;
        ut = _caminho.length > 1 ? _caminho[1]['value'] : null;
        userId = null;
        admin = true;
      case 'prop_mine':
        prop = _caminho.isNotEmpty ? _caminho[0]['value'] : null;
      case 'ut_mine':
        prop = _caminho.isNotEmpty ? _caminho[0]['value'] : null;
        ut = _caminho.length > 1 ? _caminho[1]['value'] : null;
    }

    final ok = await exportService.exportarParcelasXlsx(
      userId: userId,
      isAdmin: admin,
      nomeUsuario: user.nome,
      propriedade: prop,
      propUt: ut,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(ok ? 'Planilha exportada.' : 'Sem parcelas para exportar.'),
          backgroundColor: ok ? Colors.green : Colors.orange,
        ),
      );
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
          Semantics(
            label: 'Cancelar',
            button: true,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
          ),
          Semantics(
            label: 'Sair da conta',
            button: true,
            child: FilledButton(
              onPressed: () async {
                final nav = Navigator.of(context);
                final sync = context.read<SyncService>();
                Navigator.pop(ctx);
                await sync.logout();
                if (mounted) {
                  nav.pushReplacementNamed('/login');
                }
              },
              child: const Text('Sair'),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final syncService = context.watch<SyncService>();
    final depth = _caminho.length;

    return PopScope(
      canPop: _caminho.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _voltar();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: AppTheme.tertiary,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          title: syncService.currentUser != null
              ? Text(
                  syncService.currentUser!.nome,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                )
              : null,
          centerTitle: true,
          leading: _caminho.isNotEmpty
              ? Semantics(
                  label: 'Voltar',
                  button: true,
                  child: IconButton(
                      icon: const Icon(Icons.arrow_back), onPressed: _voltar),
                )
              : null,
          actions: [
            Semantics(
              label: 'Consultar parcelas no servidor',
              button: true,
              child: IconButton(
                icon: const Icon(Icons.visibility, color: Colors.white),
                onPressed: syncService.isConfigured
                    ? (_caminho.length == 2
                        ? _showParcelasFeitasServidor
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Abra uma UT para ver as parcelas já feitas dessa UT.'),
                              ),
                            );
                          })
                    : null,
                tooltip: _caminho.length == 2
                    ? 'Consultar no servidor se outros utilizadores já fizeram parcelas'
                    : 'Disponível apenas dentro de uma UT',
              ),
            ),
            Semantics(
              label: 'Sincronização',
              button: true,
              child: IconButton(
                icon: Badge(
                  isLabelVisible: syncService.pendingCount > 0,
                  label: Text('${syncService.pendingCount}'),
                  child: Icon(
                    syncService.pendingCount > 0
                        ? Icons.cloud_off
                        : Icons.cloud_done,
                    color: Colors.white,
                  ),
                ),
                onPressed: _showSyncOptions,
                tooltip: 'Sincronização',
              ),
            ),
            Semantics(
              label: 'Menu de opções',
              button: true,
              child: PopupMenuButton<String>(
                iconColor: Colors.white,
                onSelected: (v) {
                  switch (v) {
                    case 'export_xlsx':
                      _exportarXlsx();
                      break;
                    case 'export_fotos':
                      _exportarFotos();
                      break;
                    case 'settings':
                      Navigator.of(context).pushNamed('/settings');
                      break;
                    case 'logout':
                      _showLogoutDialog();
                      break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'export_xlsx',
                    child: ListTile(
                      leading: Icon(Icons.table_chart),
                      title: Text('Exportar planilha (XLSX)'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'export_fotos',
                    child: ListTile(
                      leading: Icon(Icons.photo_library),
                      title: Text('Exportar fotos'),
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
            ),
          ],
        ),
        body: Column(
          children: [
            _buildSyncBanner(syncService),
            _buildHeader(depth),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildListView(),
            ),
            _buildAddButton(depth),
          ],
        ),
      ),
    );
  }

  // ─── Sync Banner ──────────────────────────────────────

  Widget _buildSyncBanner(SyncService syncService) {
    if (syncService.isSyncing) {
      return Container(
        width: double.infinity,
        color: AppTheme.primary.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.primary),
            ),
            const SizedBox(width: 12),
            const Text('Sincronizando dados...',
                style: TextStyle(color: AppTheme.primary, fontSize: 13)),
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
                style: TextStyle(color: Colors.red[700], fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: _doSync,
              child: const Text('Tentar', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    if (syncService.pendingCount > 0) {
      return Container(
        width: double.infinity,
        color: Colors.orange[50],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.cloud_off, color: Colors.orange[800], size: 16),
            const SizedBox(width: 8),
            Text(
              '${syncService.pendingCount} parcela(s) pendente(s)',
              style: TextStyle(color: Colors.orange[800], fontSize: 13),
            ),
            const Spacer(),
            TextButton(
              onPressed: _doSync,
              child: const Text('Sincronizar', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ─── Header (Breadcrumbs + Search) ────────────────────

  Widget _buildHeader(int depth) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _breadcrumb(
                    icon: Icons.home,
                    label: 'Propriedades',
                    isActive: depth == 0,
                    onTap: depth > 0 ? _irParaRaiz : null,
                  ),
                  ..._caminho.asMap().entries.map((e) {
                    final i = e.key;
                    final step = e.value;
                    final isLast = i == depth - 1;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Icon(Icons.chevron_right,
                              size: 16, color: Colors.grey[400]),
                        ),
                        _breadcrumb(
                          icon: step['tipo'] == 'Propriedade'
                              ? Icons.forest
                              : Icons.map,
                          label: step['value']!,
                          isActive: isLast,
                          onTap: isLast ? null : () => _irPara(i),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Semantics(
              label: 'Pesquisar ID ou área',
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon:
                      Icon(Icons.search, size: 20, color: Colors.grey[400]),
                  hintText: 'Pesquisar ID ou área...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _breadcrumb({
    required IconData icon,
    required String label,
    required bool isActive,
    VoidCallback? onTap,
  }) {
    return Semantics(
      label: isActive ? label : 'Navegar para $label',
      button: !isActive,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: isActive
              ? BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                )
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 14,
                  color: isActive ? AppTheme.primary : Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? AppTheme.primary : Colors.grey[600],
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Add Button ───────────────────────────────────────

  Widget _buildAddButton(int depth) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: double.infinity,
        child: Semantics(
          label: 'Nova parcela',
          button: true,
          child: ElevatedButton.icon(
            onPressed: _adicionar,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add),
            label: Text(
              depth == 0
                  ? 'Nova Parcela'
                  : depth == 1
                      ? 'Nova Parcela nesta Propriedade'
                      : 'Nova Parcela nesta UT',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  // ─── List Views ───────────────────────────────────────

  Widget _buildListView() {
    final query = _searchController.text.trim().toLowerCase();
    final depth = _caminho.length;
    if (depth == 0) return _buildPropriedadesList(query);
    if (depth == 1) return _buildUtsList(query);
    return _buildParcelasList(query);
  }

  Widget _buildPropriedadesList(String query) {
    final items =
        _propriedades.where((p) => p.toLowerCase().contains(query)).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        if (items.isEmpty)
          _emptyState()
        else
          ...items.asMap().entries.expand((e) {
            final prop = e.value;
            final utCount = _contagemUts[prop] ?? 0;
            final info = _propriedadeInfo[prop];
            return [
              const SizedBox(height: 4),
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey[200]!),
                ),
                child: Semantics(
                  label:
                      'Propriedade $prop, $utCount UT${utCount != 1 ? 's' : ''}',
                  child: ListTile(
                    onTap: () => _entrar('Propriedade', prop),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primary,
                      child: const Icon(Icons.forest,
                          color: Colors.white, size: 20),
                    ),
                    title: Text(prop,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$utCount UT${utCount != 1 ? 's' : ''}',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        if (info != null && info.total > 0) _ownershipBar(info),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
              ),
            ];
          }).skip(1),
      ],
    );
  }

  Widget _buildUtsList(String query) {
    final items = _uts.where((u) => u.toLowerCase().contains(query)).toList();
    if (items.isEmpty) return _emptyState();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) {
        final ut = items[i];
        final count = _contagemParcelas[ut] ?? 0;
        final info = _utInfo[ut];

        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[200]!),
          ),
          child: Semantics(
            label: 'UT $ut, $count parcela${count != 1 ? 's' : ''}',
            child: ListTile(
              onTap: () => _entrar('UT', ut),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: CircleAvatar(
                backgroundColor: AppTheme.tertiaryContainer,
                child: const Icon(Icons.map, color: Colors.white, size: 20),
              ),
              title:
                  Text(ut, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count parcela${count != 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (info != null && info.total > 0) _ownershipBar(info),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        );
      },
    );
  }

  Widget _buildParcelasList(String query) {
    final filtered = _parcelas.where((p) {
      // Inclui "parcela" e número para buscar por "p", "parcela", "parcela 1", etc.
      final s =
          'parcela ${p.idParcela} ${p.idParcela} ${p.observacoes ?? ''} ${p.areaHa ?? ''}'
              .toLowerCase();
      return s.contains(query);
    }).toList();
    if (filtered.isEmpty) return _emptyState();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) {
        final p = filtered[i];
        final hasWork = p.userId.isNotEmpty;
        final badgeColor = hasWork
            ? (p.prontaParaSync ? Colors.green : Colors.orange)
            : Colors.blueGrey;
        final statusLabel = hasWork
            ? (p.prontaParaSync ? 'Concluída' : 'Em progresso')
            : 'Disponível';
        final statusIcon = hasWork
            ? (p.prontaParaSync ? Icons.check_circle : Icons.edit_note)
            : Icons.radio_button_unchecked;

        final parts = <String>[];
        if (p.areaHa != null && p.areaHa! > 0) {
          parts.add('${p.areaHa!.toStringAsFixed(4)} ha');
        }
        if (p.observacoes != null && p.observacoes!.trim().isNotEmpty) {
          parts.add(p.observacoes!);
        }
        final subtitle = parts.join(' · ');

        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: hasWork
                  ? AppTheme.primary.withValues(alpha: 0.3)
                  : Colors.grey[200]!,
            ),
          ),
          child: Semantics(
            label: 'Parcela ${p.idParcela}, $statusLabel',
            button: true,
            child: ListTile(
              onTap: () => _openParcela(p),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: CircleAvatar(
                backgroundColor:
                    hasWork ? AppTheme.primary : Colors.blueGrey[300],
                child: Text(
                  '${p.idParcela}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              title: Row(
                children: [
                  Text('Parcela ${p.idParcela}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border:
                          Border.all(color: badgeColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 10, color: badgeColor),
                        const SizedBox(width: 3),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              subtitle: subtitle.isNotEmpty
                  ? Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              trailing: _buildParcelaTrailing(p),
            ),
          ),
        );
      },
    );
  }

  /// Menu de opções na parcela: Limpar dados / Apagar parcela (só se criador ou admin).
  Widget _buildParcelaTrailing(Parcela p) {
    final myId = _myUserId;
    final isAdmin = context.read<SyncService>().currentUser?.isAdmin ?? false;
    final canEdit = isAdmin || (myId != null && p.createdBy == myId);
    if (!canEdit) return const Icon(Icons.chevron_right);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20),
          padding: EdgeInsets.zero,
          onSelected: (v) async {
            if (v == 'limpar') await _limparDadosParcela(p);
            if (v == 'apagar') await _apagarParcelaSlot(p);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'limpar',
              child: ListTile(
                leading: Icon(Icons.cleaning_services, size: 20),
                title: Text('Limpar dados'),
                subtitle: Text('Remove plantas/fotos; parcela fica disponível'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'apagar',
              child: ListTile(
                leading:
                    Icon(Icons.delete_forever, size: 20, color: Colors.red),
                title:
                    Text('Apagar parcela', style: TextStyle(color: Colors.red)),
                subtitle: Text('Remove o slot (local e servidor)'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        const Icon(Icons.chevron_right),
      ],
    );
  }

  Future<void> _limparDadosParcela(Parcela p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar dados desta parcela?'),
        content: const Text(
          'Plantas, fotos e observações serão removidos.\n'
          'A parcela voltará a ficar disponível no catálogo.',
        ),
        actions: [
          Semantics(
              label: 'Cancelar',
              button: true,
              child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'))),
          Semantics(
              label: 'Limpar dados',
              button: true,
              child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Limpar dados'))),
        ],
      ),
    );
    if (confirm != true) return;
    for (final planta in await _db.getPlantasByParcela(p.uuid)) {
      if (planta.fotoEspeciePath != null) {
        await ImageService.deletePhoto(planta.fotoEspeciePath!);
      }
    }
    for (final foto in await _db.getFotosByParcela(p.uuid)) {
      await ImageService.deletePhoto(foto.filePath);
    }
    await _db.deleteAllPlantasByParcela(p.uuid);
    await _db.deleteAllFotosByParcela(p.uuid);
    await _db.updateParcela(
      ParcelasCompanion(
        userId: const drift.Value(''),
        observacoes: const drift.Value(null),
        latitude: const drift.Value(null),
        longitude: const drift.Value(null),
        synced: const drift.Value(true),
        prontaParaSync: const drift.Value(false),
        updatedAt: drift.Value(DateTime.now()),
      ),
      p.uuid,
    );
    if (mounted) {
      await _refreshNivel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Dados da parcela limpos.'),
            backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _apagarParcelaSlot(Parcela p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_forever, color: Colors.red[700], size: 32),
        title: const Text('Apagar parcela?'),
        content: const Text(
          'O slot será removido localmente e no servidor (se já foi sincronizado). '
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          Semantics(
              label: 'Cancelar',
              button: true,
              child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'))),
          Semantics(
            label: 'Apagar parcela',
            button: true,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apagar'),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final syncService = context.read<SyncService>();
    if (p.uuid.startsWith('pb-') && syncService.isConfigured) {
      try {
        await syncService.deleteParcelaNoServidor(p.uuid);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Erro ao apagar no servidor: $e'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
    for (final planta in await _db.getPlantasByParcela(p.uuid)) {
      if (planta.fotoEspeciePath != null) {
        await ImageService.deletePhoto(planta.fotoEspeciePath!);
      }
    }
    for (final foto in await _db.getFotosByParcela(p.uuid)) {
      await ImageService.deletePhoto(foto.filePath);
    }
    await _db.deleteAllPlantasByParcela(p.uuid);
    await _db.deleteAllFotosByParcela(p.uuid);
    await _db.deleteParcela(p.uuid);
    if (mounted) {
      await _refreshNivel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Parcela apagada.'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _showDesistirDialog(Parcela p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.person_remove, color: Colors.orange[700], size: 32),
        title: const Text('Desistir da parcela?'),
        content: const Text(
          'A parcela ficará disponível para outros utilizadores. '
          'As alterações locais serão enviadas ao sair (user vazio). '
          'Tem certeza?',
        ),
        actions: [
          Semantics(
            label: 'Cancelar',
            button: true,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
          ),
          Semantics(
            label: 'Desistir da parcela',
            button: true,
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Desistir'),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || _myUserId == null) return;
    await _db.updateParcela(
      ParcelasCompanion(
        userId: const drift.Value(''),
        prontaParaSync: const drift.Value(false),
        synced: const drift.Value(false),
        updatedAt: drift.Value(DateTime.now()),
      ),
      p.uuid,
    );
    await context.read<SyncService>().refreshPendingCount();
    if (mounted) await _refreshNivel();
  }

  // ─── Ownership indicator bar ──────────────────────────

  Widget _ownershipBar(_OwnershipInfo info) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          if (info.mine > 0)
            _ownershipChip(
              Icons.person,
              '${info.mine} minha${info.mine != 1 ? 's' : ''}',
              Colors.green[700]!,
            ),
          if (info.free > 0)
            _ownershipChip(
              Icons.person_add,
              '${info.free} livre${info.free != 1 ? 's' : ''}',
              Colors.blue,
            ),
          if (info.other > 0)
            _ownershipChip(
              Icons.lock,
              '${info.other} outra${info.other != 1 ? 's' : ''}',
              Colors.grey,
            ),
        ],
      ),
    );
  }

  Widget _ownershipChip(IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Empty State ──────────────────────────────────────

  Widget _emptyState() {
    final depth = _caminho.length;
    final syncService = context.read<SyncService>();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              depth == 0
                  ? Icons.forest
                  : depth == 1
                      ? Icons.map
                      : Icons.description,
              size: 56,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 12),
            Text(
              depth == 0
                  ? 'Nenhuma propriedade encontrada'
                  : depth == 1
                      ? 'Nenhuma UT nesta propriedade'
                      : 'Nenhuma parcela nesta UT',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Toque no botão abaixo para criar, ou puxe dados do servidor.',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
              textAlign: TextAlign.center,
            ),
            // Botão de pull removido (catálogo é estático)
          ],
        ),
      ),
    );
  }
}

/// Sheet com lista de parcelas a sincronizar: checkbox, lápis, confirmar envio.
/// Parcelas em conflito vêm marcadas com aviso e não podem ser seleccionadas.
class _SyncListSheet extends StatefulWidget {
  final List<Parcela> parcelas;
  final Set<String> conflictKeys;
  final Set<String> selectedUuids;
  final Set<String> selectableUuids;
  final Color accentColor;
  final int syncedCount;
  final void Function(Parcela p) onEdit;
  final VoidCallback? onPull;
  final VoidCallback? onClearCache;
  final void Function(Set<String> selected) onConfirm;

  const _SyncListSheet({
    required this.parcelas,
    required this.conflictKeys,
    required this.selectedUuids,
    required this.selectableUuids,
    required this.accentColor,
    required this.syncedCount,
    required this.onEdit,
    this.onPull,
    this.onClearCache,
    required this.onConfirm,
  });

  @override
  State<_SyncListSheet> createState() => _SyncListSheetState();
}

class _SyncListSheetState extends State<_SyncListSheet> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.selectedUuids);
  }

  @override
  Widget build(BuildContext context) {
    final hasConflict = widget.conflictKeys.isNotEmpty;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, sc) => SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.sync, color: widget.accentColor, size: 28),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Parcelas a sincronizar',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hasConflict
                        ? 'Puxámos o servidor. Parcelas em conflito não podem ser enviadas.'
                        : 'Marque as parcelas que deseja enviar.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: sc,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: widget.parcelas.length,
                itemBuilder: (_, i) {
                  final p = widget.parcelas[i];
                  final key = SyncService.parcelaKey(p);
                  final isConflict = widget.conflictKeys.contains(key);
                  final canSelect = widget.selectableUuids.contains(p.uuid);
                  final checked = _selected.contains(p.uuid);
                  return ListTile(
                    leading: canSelect
                        ? Checkbox(
                            value: checked,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selected.add(p.uuid);
                                } else {
                                  _selected.remove(p.uuid);
                                }
                              });
                            },
                            activeColor: widget.accentColor,
                          )
                        : Icon(Icons.warning_amber,
                            color: Colors.orange[700], size: 24),
                    title: Text(
                      '${p.propriedade} · ${p.propUt} · Parcela ${p.idParcela}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isConflict ? Colors.orange[800] : null,
                      ),
                    ),
                    subtitle: isConflict
                        ? Text(
                            'Conflito no servidor (outro utilizador)',
                            style: TextStyle(
                                fontSize: 11, color: Colors.orange[800]),
                          )
                        : null,
                    trailing: Semantics(
                      label: 'Editar parcela',
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.edit, size: 22),
                        onPressed: () => widget.onEdit(p),
                        tooltip: 'Editar',
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Semantics(
                      label: 'Confirmar envio',
                      button: true,
                      child: FilledButton.icon(
                        onPressed: _selected.isEmpty
                            ? null
                            : () => widget.onConfirm(_selected),
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('Confirmar envio'),
                        style: FilledButton.styleFrom(
                          backgroundColor: widget.accentColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  if (widget.onPull != null || widget.onClearCache != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.onPull != null)
                          Semantics(
                            label: 'Puxar do servidor',
                            button: true,
                            child: TextButton.icon(
                              icon: const Icon(Icons.cloud_download, size: 18),
                              label: const Text('Puxar do servidor'),
                              onPressed: widget.onPull,
                            ),
                          ),
                        if (widget.onClearCache != null &&
                            widget.syncedCount > 0) ...[
                          if (widget.onPull != null) const SizedBox(width: 8),
                          Semantics(
                            label: 'Limpar cache',
                            button: true,
                            child: TextButton.icon(
                              icon: Icon(Icons.cleaning_services,
                                  size: 18, color: Colors.red[400]),
                              label: const Text('Limpar cache'),
                              onPressed: widget.onClearCache,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
