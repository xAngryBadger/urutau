import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:image_picker/image_picker.dart';
// [GPS DESATIVADO - MANUTENÇÃO] Reativar quando integrar com app de mapas
// import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../data/database.dart';
import '../services/image_service.dart';
import '../services/sync_service.dart';
import 'planta_form_screen.dart';

class ParcelaFormScreen extends StatefulWidget {
  final String? parcelaUuid; // null = nova, preenchido = edição
  final String? prefilledPropriedade;
  final String? prefilledPropUt;
  final int? prefilledNextParcela;
  final bool readOnly;

  const ParcelaFormScreen({
    super.key,
    this.parcelaUuid,
    this.prefilledPropriedade,
    this.prefilledPropUt,
    this.prefilledNextParcela,
    this.readOnly = false,
  });

  @override
  State<ParcelaFormScreen> createState() => _ParcelaFormScreenState();
}

class _ParcelaFormScreenState extends State<ParcelaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  AppDatabase get _db => context.read<AppDatabase>();
  final _propriedadeController = TextEditingController();
  final _propUtController = TextEditingController();
  final _idParcelaController = TextEditingController();
  final _observacoesController = TextEditingController();
  final _uuid = const Uuid();

  List<String> _propriedadesSugestoes = [];
  List<String> _utSugestoes = [];

  List<Planta> _plantas = [];
  List<FotosParcelaData> _fotos = [];
  final List<String> _novasFotosPaths = []; // Fotos adicionadas nesta sessão
  bool _isLoading = false;
  bool _isEditing = false;
  String? _currentUuid;
  bool _prontaParaSync =
      false; // carregado ao editar; rascunho até marcar concluída
  bool _popGuard = false;

  // [GPS DESATIVADO - MANUTENÇÃO] Reativar quando integrar com app de mapas
  // double? _latitude;
  // double? _longitude;
  // bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    if (widget.parcelaUuid != null) {
      _isEditing = true;
      _currentUuid = widget.parcelaUuid;
      _loadParcela();
    } else {
      _currentUuid = _uuid.v4();
      // Pré-preencher do Explorer
      if (widget.prefilledPropriedade != null) {
        _propriedadeController.text = widget.prefilledPropriedade!;
      }
      if (widget.prefilledPropUt != null) {
        _propUtController.text = widget.prefilledPropUt!;
      }
      if (widget.prefilledNextParcela != null) {
        _idParcelaController.text = widget.prefilledNextParcela.toString();
      }
    }
    _loadSugestoes();
  }

  Future<void> _loadSugestoes() async {
    final syncService = context.read<SyncService>();
    final user = syncService.currentUser;
    final isAdmin = user?.isAdmin ?? false;
    final props = await _db.getAllPropriedades(
      userId: user?.uuid,
      isAdmin: isAdmin,
    );
    if (mounted) {
      setState(() => _propriedadesSugestoes = props);
    }
    // Carregar UTs para a propriedade atual
    if (_propriedadeController.text.isNotEmpty) {
      await _loadUtSugestoes(_propriedadeController.text);
    }
  }

  Future<void> _loadUtSugestoes(String propriedade) async {
    final syncService = context.read<SyncService>();
    final user = syncService.currentUser;
    final isAdmin = user?.isAdmin ?? false;
    final uts = await _db.getAllTalhoes(
      userId: user?.uuid,
      isAdmin: isAdmin,
      propriedade: propriedade,
    );
    if (mounted) {
      setState(() => _utSugestoes = uts);
    }
  }

  Future<void> _loadParcela() async {
    setState(() => _isLoading = true);
    final parcela = await _db.getParcelaByUuid(_currentUuid!);
    if (parcela != null) {
      _propriedadeController.text = parcela.propriedade;
      _propUtController.text = parcela.propUt;
      _idParcelaController.text = parcela.idParcela.toString();
      _observacoesController.text = parcela.observacoes ?? '';
      _prontaParaSync = parcela.prontaParaSync;
      // [GPS DESATIVADO] _latitude = parcela.latitude;
      // [GPS DESATIVADO] _longitude = parcela.longitude;
    }
    _plantas = await _db.getPlantasByParcela(_currentUuid!);
    _fotos = await _db.getFotosByParcela(_currentUuid!);
    if (mounted) setState(() => _isLoading = false);
    if (mounted && parcela != null && parcela.synced && parcela.prontaParaSync) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _showEditarSyncedAviso());
    }
  }

  /// Aviso ao editar parcela já concluída e sincronizada.
  Future<void> _showEditarSyncedAviso() async {
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.info_outline, color: Colors.orange[700], size: 32),
        title: const Text('Parcela já sincronizada'),
        content: const Text(
          'Esta parcela já foi concluída e sincronizada com o servidor.\n\n'
          'Deseja realmente editá-la? As alterações poderão ser enviadas de novo ao sincronizar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sim, editar'),
          ),
        ],
      ),
    );
    if (confirm != true && mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Navega para a próxima parcela no mesmo UT (por número).
  /// Se a próxima for de outro utilizador, avança até encontrar uma disponível ou sugere criar nova.
  Future<void> _goToNextParcela() async {
    final prop = _propriedadeController.text.trim();
    final ut = _propUtController.text.trim();
    if (prop.isEmpty || ut.isEmpty) return;
    final currentId = int.tryParse(_idParcelaController.text.trim());
    if (currentId == null) return;

    final syncService = context.read<SyncService>();
    final myId = syncService.currentUser?.uuid;

    final parcelas =
        await _db.getParcelasByHierarchy(propriedade: prop, propUt: ut);
    // Próxima por idParcela (lista já vem ordenada por idParcela)
    Parcela? nextToOpen;
    int? nextSuggestedId;
    for (final p in parcelas) {
      if (p.idParcela > currentId) {
        final isMine = myId != null && p.userId == myId;
        final isFree = p.userId.isEmpty;
        if (isMine || isFree) {
          nextToOpen = p;
          break;
        }
      }
    }
    if (nextToOpen == null) {
      final last = await _db.getLastParcela(propriedade: prop, propUt: ut);
      nextSuggestedId = (last?.idParcela ?? currentId) + 1;
    }

    if (!mounted) return;
    if (nextToOpen != null) {
      // Se a parcela é livre, confirmar antes de abrir (tomar para si)
      final isFree = nextToOpen.userId.isEmpty;
      if (isFree) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.person_add, color: Colors.blue, size: 32),
            title: const Text('Parcela Disponível'),
            content: Text(
              'Parcela ${nextToOpen!.idParcela} está livre.\n'
              'Deseja assumir esta parcela para trabalhar nela?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.check),
                onPressed: () => Navigator.pop(ctx, true),
                label: const Text('Assumir'),
              ),
            ],
          ),
        );
        if (confirm != true || !mounted) return;
        await _db.updateParcela(
          ParcelasCompanion(
            userId: drift.Value(myId!),
            synced: const drift.Value(false),
            updatedAt: drift.Value(DateTime.now()),
          ),
          nextToOpen.uuid,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        '/parcela/editar',
        arguments: nextToOpen.uuid,
      );
    } else {
      final create = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Próxima parcela'),
          content: Text(
            nextSuggestedId != null
                ? 'Não há mais parcelas editáveis nesta UT.\n\n'
                    'Deseja criar a Parcela $nextSuggestedId?'
                : 'Não há parcelas nesta UT para abrir.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Ficar aqui'),
            ),
            if (nextSuggestedId != null)
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Criar Parcela $nextSuggestedId'),
              ),
          ],
        ),
      );
      if (create == true && nextSuggestedId != null) {
        Navigator.of(context).pushReplacementNamed(
          '/parcela/nova',
          arguments: {
            'propriedade': prop,
            'propUt': ut,
          },
        );
      }
    }
  }

  // [GPS DESATIVADO - MANUTENÇÃO]
  // Reativar _getLocation() quando integrar com app de mapas /
  // arquivo georreferenciado. Colunas latitude/longitude permanecem no DB.

  @override
  void dispose() {
    _propriedadeController.dispose();
    _propUtController.dispose();
    _idParcelaController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  bool get _hasUnsavedData {
    if (_propriedadeController.text.isNotEmpty ||
        _propUtController.text.isNotEmpty ||
        _idParcelaController.text.isNotEmpty ||
        _plantas.isNotEmpty ||
        _novasFotosPaths.isNotEmpty) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_popGuard) return;
        _popGuard = true;
        if (_hasUnsavedData || (_isEditing && !_prontaParaSync)) {
          final choice = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              icon: const Icon(Icons.warning_amber,
                  color: Colors.orange, size: 32),
              title: const Text('Sair sem salvar?'),
              content: const Text(
                'Você tem dados não salvos nesta parcela.\n\n'
                'Escolha uma opção:',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'stay'),
                  child: const Text('Continuar editando'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'draft'),
                  child: const Text('Guardar rascunho'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'discard'),
                  child: const Text('Descartar',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
          if (choice == 'draft') {
            if (_formKey.currentState?.validate() ?? false) {
              await _writeParcela(prontaParaSync: false);
              if (mounted) {
                await context.read<SyncService>().refreshPendingCount();
              }
            }
            if (mounted) Navigator.of(context).pop(true);
          } else if (choice == 'discard') {
            if (_isEditing && _currentUuid != null) {
              await _limparDadosParcela(_currentUuid!);
              if (mounted) {
                setState(() {
                  _propriedadeController.clear();
                  _propUtController.clear();
                  _idParcelaController.clear();
                  _observacoesController.clear();
                  _plantas = [];
                  _fotos = [];
                  _novasFotosPaths.clear();
                  _isEditing = false;
                });
              }
            }
            if (mounted) Navigator.of(context).pop(true);
          }
        } else {
          Navigator.of(context).pop(false);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Editar Parcela' : 'Nova Parcela'),
          actions: [
            if (_isEditing) ...[
              Semantics(
                label: 'Próxima parcela',
                button: true,
                child: IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: _goToNextParcela,
                  tooltip: 'Próxima parcela (mesmo UT)',
                ),
              ),
              Semantics(
                label: 'Excluir parcela',
                button: true,
                child: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: _confirmDelete,
                  tooltip: 'Excluir parcela',
                ),
              ),
            ],
          ],
        ),
        body: SafeArea(
          bottom: true,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: [
                        // ==========================================
                        // SEÇÃO 1: Identificação (Hierarquia)
                        // ==========================================
                        const SizedBox(height: 12),
                        // [GPS DESATIVADO - MANUTENÇÃO] Botão de GPS comentado
                        // Reativar quando integrar com app de mapas

                        // --- Propriedade (com autocomplete) ---
                        Autocomplete<String>(
                          initialValue: TextEditingValue(
                              text: _propriedadeController.text),
                          optionsBuilder: (textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return _propriedadesSugestoes;
                            }
                            return _propriedadesSugestoes.where((p) => p
                                .toLowerCase()
                                .contains(textEditingValue.text.toLowerCase()));
                          },
                          onSelected: (value) {
                            _propriedadeController.text = value;
                            _loadUtSugestoes(value);
                          },
                          fieldViewBuilder: (context, textController, focusNode,
                              onSubmitted) {
                            return Semantics(
                              label: 'Propriedade',
                              textField: true,
                              child: TextFormField(
                                enabled: !widget.readOnly,
                                controller: textController,
                                focusNode: focusNode,
                                decoration: InputDecoration(
                                  labelText: 'Propriedade *',
                                  hintText: 'Ex: Fazenda São João',
                                  prefixIcon: const Icon(Icons.home_work),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  suffixIcon: _propriedadesSugestoes.isNotEmpty
                                      ? const Icon(Icons.arrow_drop_down,
                                          size: 20)
                                      : null,
                                ),
                                textCapitalization: TextCapitalization.words,
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Campo obrigatório'
                                    : null,
                                onFieldSubmitted: (_) => onSubmitted(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // --- UT / Talhão (com autocomplete) ---
                        Autocomplete<String>(
                          initialValue:
                              TextEditingValue(text: _propUtController.text),
                          optionsBuilder: (textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return _utSugestoes;
                            }
                            return _utSugestoes.where((u) => u
                                .toLowerCase()
                                .contains(textEditingValue.text.toLowerCase()));
                          },
                          onSelected: (value) {
                            _propUtController.text = value;
                          },
                          fieldViewBuilder: (context, textController, focusNode,
                              onSubmitted) {
                            return Semantics(
                              label: 'UT ou Talhão',
                              textField: true,
                              child: TextFormField(
                                enabled: !widget.readOnly,
                                controller: textController,
                                focusNode: focusNode,
                                decoration: InputDecoration(
                                  labelText: 'UT / Talhão *',
                                  hintText: 'Ex: UT 01, Talhão A',
                                  prefixIcon: const Icon(Icons.park),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  suffixIcon: _utSugestoes.isNotEmpty
                                      ? const Icon(Icons.arrow_drop_down,
                                          size: 20)
                                      : null,
                                ),
                                textCapitalization: TextCapitalization.words,
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Campo obrigatório'
                                    : null,
                                onFieldSubmitted: (_) => onSubmitted(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // --- Número da Parcela (livre: o usuário define na hora) ---
                        Semantics(
                          label: 'Número da parcela',
                          textField: true,
                          child: TextFormField(
                            controller: _idParcelaController,
                            enabled: !widget.readOnly,
                            decoration: InputDecoration(
                              labelText: 'Número da parcela *',
                              hintText: 'Você define (ex: 1, 2, 3...)',
                              helperText:
                                  'Número que você dá a esta parcela no campo.',
                              prefixIcon: const Icon(Icons.tag),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.isEmpty)
                                return 'Campo obrigatório';
                              if (int.tryParse(v) == null)
                                return 'Número inválido';
                              return null;
                            },
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ==========================================
                        // SEÇÃO 2: Anotações (antigo Observações) — PRIMEIRO
                        // ==========================================
                        Semantics(
                          label: 'Anotações',
                          textField: true,
                          child: TextFormField(
                            controller: _observacoesController,
                            enabled: !widget.readOnly,
                            decoration: InputDecoration(
                              labelText: 'Anotações (opcional)',
                              hintText: 'Anotações sobre a parcela...',
                              prefixIcon: const Icon(Icons.edit_note),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            maxLines: 3,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // ==========================================
                        // SEÇÃO 3: Plantas
                        // ==========================================
                        _sectionTitle(
                          'Plantas (${_plantas.length})',
                          Icons.grass,
                        ),
                        const SizedBox(height: 12),

                        if (_plantas.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.grass,
                                    size: 48, color: Colors.grey[300]),
                                const SizedBox(height: 8),
                                Text(
                                  'Nenhuma planta adicionada',
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),

                        ..._plantas.asMap().entries.map(
                              (entry) =>
                                  _buildPlantaCard(entry.key, entry.value),
                            ),

                        const SizedBox(height: 12),

                        Semantics(
                          label: 'Adicionar planta',
                          button: true,
                          child: OutlinedButton.icon(
                            onPressed: widget.readOnly ? null : _addPlanta,
                            icon: const Icon(Icons.add),
                            label: const Text('Adicionar Planta'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // ==========================================
                        // SEÇÃO 3: Fotos da Parcela (2-4)
                        // ==========================================
                        _sectionTitle(
                          'Fotos da Parcela (${_fotos.length + _novasFotosPaths.length})',
                          Icons.photo_camera,
                        ),
                        const SizedBox(height: 12),

                        _buildFotosGrid(),

                        const SizedBox(height: 24),
                        if (!_prontaParaSync && _isEditing && !widget.readOnly)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.orange.shade700, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Esta parcela não será sincronizada até marcar como concluída.',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange.shade900),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // ==========================================
                        // BOTÕES: Sair e guardar (rascunho) | Concluir
                        // ==========================================
                        if (!widget.readOnly) ...[
                          Semantics(
                            label: 'Salvar rascunho',
                            button: true,
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _salvarRascunho,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.save_as),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Guardar rascunho',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Semantics(
                            label: 'Salvar parcela',
                            button: true,
                            child: FilledButton.icon(
                              onPressed: _isLoading ? null : _salvar,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.check_circle),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _isEditing
                                      ? 'Concluir alterações'
                                      : 'Concluir parcela',
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(double.infinity, 56),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildPlantaCard(int index, Planta planta) {
    final categoriaColors = {
      1: Colors.blue,
      2: Colors.orange,
      3: Colors.green,
    };
    final color = categoriaColors[planta.categoria] ?? Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Text(
            'C${planta.categoria}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          '${index + 1}. ${planta.especie}',
          style: const TextStyle(fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        subtitle: Text(
          'Alt: ${planta.alturaCm}cm'
          '${planta.dapCm != null ? ' | DAP: ${planta.dapCm}cm' : ''}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (planta.fotoEspeciePath != null)
              const Icon(Icons.photo, color: Colors.green, size: 20),
            Semantics(
              label: 'Editar planta',
              button: true,
              child: IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => _editPlanta(planta),
              ),
            ),
            Semantics(
              label: 'Remover planta',
              button: true,
              child: IconButton(
                icon: Icon(Icons.delete, size: 20, color: Colors.red[300]),
                onPressed: () => _removePlanta(planta),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFotosGrid() {
    final totalFotos = _fotos.length + _novasFotosPaths.length;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: totalFotos + 1,
      itemBuilder: (context, index) {
        // Fotos já salvas no banco
        if (index < _fotos.length) {
          return _buildFotoTile(
            imagePath: _fotos[index].filePath,
            onDelete: () => _removeFotoSalva(index),
          );
        }

        // Novas fotos
        final novaIndex = index - _fotos.length;
        if (novaIndex < _novasFotosPaths.length) {
          return _buildFotoTile(
            imagePath: _novasFotosPaths[novaIndex],
            onDelete: () => _removeNovaFoto(novaIndex),
          );
        }

        // Botão adicionar
        return _buildAddFotoButton();
      },
    );
  }

  Widget _buildFotoTile({
    required String imagePath,
    required VoidCallback onDelete,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ImageService.buildImage(
            imagePath,
            fit: BoxFit.cover,
            cacheWidth: kIsWeb ? null : 400,
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Semantics(
            label: 'Remover foto',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              onPressed: onDelete,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.8),
                padding: const EdgeInsets.all(4),
                minimumSize: const Size(28, 28),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddFotoButton() {
    return Semantics(
      label: 'Adicionar foto da parcela',
      button: true,
      child: InkWell(
        onTap: _tirarFotoParcela,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!, width: 2),
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[50],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo, size: 36, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'Adicionar foto',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // AÇÕES
  // ==========================================

  Future<void> _addPlanta() async {
    final result = await Navigator.of(context).push<Planta>(
      MaterialPageRoute(
        builder: (_) => PlantaFormScreen(parcelaUuid: _currentUuid!),
      ),
    );

    if (result != null) {
      setState(() => _plantas.add(result));
    }
  }

  Future<void> _editPlanta(Planta planta) async {
    final result = await Navigator.of(context).push<Planta>(
      MaterialPageRoute(
        builder: (_) => PlantaFormScreen(
          parcelaUuid: _currentUuid!,
          existingPlanta: planta,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        final index = _plantas.indexWhere((p) => p.uuid == result.uuid);
        if (index != -1) {
          _plantas[index] = result;
        }
      });
    }
  }

  Future<void> _removePlanta(Planta planta) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover planta?'),
        content: Text('Remover "${planta.especie}" da lista?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (planta.fotoEspeciePath != null) {
        await ImageService.deletePhoto(planta.fotoEspeciePath!);
      }
      await _db.deletePlanta(planta.uuid);
      setState(() => _plantas.removeWhere((p) => p.uuid == planta.uuid));
    }
  }

  Future<void> _tirarFotoParcela() async {
    final picker = ImagePicker();

    // Escolher origem
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: 'Tirar foto com câmera',
            button: true,
            child: ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Câmera'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
          ),
          Semantics(
            label: 'Escolher foto da galeria',
            button: true,
            child: ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeria (múltiplas)'),
              subtitle: const Text('Selecione várias fotos de uma vez'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
          ),
        ],
      ),
    );

    if (source == null) return;

    if (source == 'gallery') {
      // Seleção múltipla da galeria
      final photos = await picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 2048,
      );
      for (final photo in photos) {
        final savedPath = await ImageService.savePhotoLocally(photo.path);
        setState(() => _novasFotosPaths.add(savedPath));
      }
    } else {
      // Câmera (uma foto por vez)
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 2048,
      );
      if (photo != null) {
        final savedPath = await ImageService.savePhotoLocally(photo.path);
        setState(() => _novasFotosPaths.add(savedPath));
      }
    }
  }

  void _removeFotoSalva(int index) {
    setState(() {
      final foto = _fotos.removeAt(index);
      _db.deleteFotoParcela(foto.uuid);
      ImageService.deletePhoto(foto.filePath);
    });
  }

  void _removeNovaFoto(int index) {
    setState(() {
      final path = _novasFotosPaths.removeAt(index);
      ImageService.deletePhoto(path);
    });
  }

  /// Guarda rascunho: sai sem descartar; parcela NÃO será sincronizada até marcar concluída.
  Future<void> _salvarRascunho() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final syncService = context.read<SyncService>();
      final currentUser = syncService.currentUser;
      if (currentUser == null) {
        throw Exception('Usuário não identificado. Faça login novamente.');
      }
      await _writeParcela(prontaParaSync: false);
      if (mounted) {
        await context.read<SyncService>().refreshPendingCount();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rascunho guardado. Pode retomar depois.'),
            backgroundColor: Colors.blue,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Conclui a parcela: exige pelo menos 1 planta; fica pronta para sincronizar.
  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_plantas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Adicione pelo menos 1 planta para concluir a parcela.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final syncService = context.read<SyncService>();
      final currentUser = syncService.currentUser;
      if (currentUser == null) {
        throw Exception('Usuário não identificado. Faça login novamente.');
      }
      await _writeParcela(prontaParaSync: true);
      if (mounted) {
        await context.read<SyncService>().refreshPendingCount();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Parcela concluída. Pode sincronizar quando tiver rede.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _writeParcela({required bool prontaParaSync}) async {
    final currentUser = context.read<SyncService>().currentUser!;
    final prop = _propriedadeController.text.trim();
    final ut = _propUtController.text.trim();
    final idParcela = int.tryParse(_idParcelaController.text.trim()) ?? 0;

    if (!_isEditing) {
      final existente = await _db.findParcelaDisponivel(prop, ut, idParcela);
      if (existente != null) {
        _currentUuid = existente.uuid;
        _isEditing = true;
      }
    }

    // Ao renomear (editar prop/UT/número): evitar duplicado com outra parcela.
    if (_isEditing) {
      final outra = await _db.findOutraParcelaComMesmoId(
        propriedade: prop,
        propUt: ut,
        idParcela: idParcela,
        excludeUuid: _currentUuid!,
      );
      if (outra != null) {
        throw Exception(
          'Já existe outra parcela com esta propriedade, UT e número. '
          'Escolha outro número ou outra UT.',
        );
      }
    }

    final parcela = ParcelasCompanion(
      uuid: drift.Value(_currentUuid!),
      propriedade: drift.Value(prop),
      propUt: drift.Value(ut),
      idParcela: drift.Value(idParcela),
      observacoes: drift.Value(_observacoesController.text.trim().isEmpty
          ? null
          : _observacoesController.text.trim()),
      userId: drift.Value(currentUser.uuid),
      prontaParaSync: drift.Value(prontaParaSync),
      synced: const drift.Value(false),
      updatedAt: drift.Value(DateTime.now()),
      createdBy: _isEditing
          ? const drift.Value.absent()
          : drift.Value(currentUser.uuid),
    );
    if (_isEditing) {
      await _db.updateParcela(parcela, _currentUuid!);
    } else {
      await _db.insertParcela(parcela);
    }
    for (final path in _novasFotosPaths) {
      await _db.insertFotoParcela(FotosParcelaCompanion(
        uuid: drift.Value(_uuid.v4()),
        parcelaUuid: drift.Value(_currentUuid!),
        filePath: drift.Value(path),
      ));
    }
  }

  /// Limpa dados da parcela (plantas, fotos, obs) e reseta para disponível.
  Future<void> _limparDadosParcela(String uuid) async {
    final p = await _db.getParcelaByUuid(uuid);
    if (p == null) return;
    for (final planta in await _db.getPlantasByParcela(uuid)) {
      if (planta.fotoEspeciePath != null) {
        await ImageService.deletePhoto(planta.fotoEspeciePath!);
      }
    }
    for (final foto in await _db.getFotosByParcela(uuid)) {
      await ImageService.deletePhoto(foto.filePath);
    }
    await _db.deleteAllPlantasByParcela(uuid);
    await _db.deleteAllFotosByParcela(uuid);
    await _db.updateParcela(
      ParcelasCompanion(
        userId: const drift.Value(''),
        observacoes: const drift.Value(null),
        latitude: const drift.Value(null),
        longitude: const drift.Value(null),
      synced: const drift.Value(false),
      prontaParaSync: const drift.Value(false),
        updatedAt: drift.Value(DateTime.now()),
      ),
      uuid,
    );
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar dados desta parcela?'),
        content: const Text(
          'Plantas, fotos e observações serão removidos.\n'
          'A parcela voltará a ficar disponível no catálogo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Limpar dados', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && _currentUuid != null) {
      await _limparDadosParcela(_currentUuid!);
      if (mounted) Navigator.of(context).pop(true);
    }
  }
}
