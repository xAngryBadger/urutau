import 'package:flutter/foundation.dart';
import 'dart:async'; // t16 D-1: unawaited
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database.dart';
import '../services/backup_service.dart';
import '../services/dossie_service.dart';
import '../services/export_service.dart';
import '../services/image_service.dart';
import '../services/mrv_calc_service.dart';
import '../services/species_service.dart';
import '../services/sync_service.dart';
import '../services/storage_service.dart';
import 'planta_form_screen.dart';
import '../theme/app_tokens.dart';
import '../widgets/arquivo_ausente_badge.dart';
import '../widgets/status_badge.dart';
import '../widgets/urutau_section_card.dart';
import '../widgets/wizard/plantas_agrupadas.dart';
import '../widgets/wizard/planta_card.dart';
import '../widgets/wizard/wizard_stepper.dart';
import '../widgets/wizard/wizard_step_page.dart';

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

  late SharedPreferences _prefs;

  List<String> _propriedadesSugestoes = [];
  List<String> _utSugestoes = [];

  List<Planta> _plantas = [];
  List<FotosParcelaData> _fotos = [];
  final List<String> _novasFotosPaths = []; // Fotos adicionadas nesta sessão
  // S3: hash e bytes dos originais guardados (para o catálogo)
  final Map<String, String?> _hashesNovasFotos = {};
  final Map<String, int?> _bytesNovasFotos = {};
  bool _isLoading = false;
  bool _isEditing = false;
  bool _isExportandoDossie = false;
  String? _currentUuid;
  // RT-01: vínculo projeto/período (RC-11: protocoloVersao é fixo no save)
  List<ProjetosMrvData> _projetos = [];
  List<PeriodosMonitoramentoData> _periodos = [];
  String? _projetoUuid;
  String? _periodoUuid;
  // RS-06: parcela substituída por sensoriamento remoto (drone/satélite)
  bool _substituidaPorSensoriamento = false;
  final _fonteSensoriamentoController = TextEditingController();
  // RQ-03: cache de densidades por espécie vindas do catálogo
  Map<String, double> _densidadesCache = {};
  // Rastreia a última planta adicionada/editada (destaque na cascata).
  String? _ultimaPlantaUuid;
  bool _prontaParaSync =
      false; // carregado ao editar; rascunho até marcar concluída
  bool _popGuard = false;
  // BUG-FIX: depois de Concluir/Guardar rascunho o pop deve passar direto —
  // o PopScope não pode sequestrar a saída com "Sair sem salvar?" (o dado
  // JÁ foi salvo) nem oferecer reverter a parcela pra rascunho.
  bool _canPop = false;

  // ── UX-APP-CAMPO: wizard de 4 etapas com swipe ──────────────────────
  /// Flag "modo wizard" (Configurações). Default LIGADO: desligado mantém o
  /// formulário clássico de hoje, idêntico.
  static const String kWizardModeKey = 'wizard_mode_enabled';
  bool _wizardMode = true;
  final PageController _pageController = PageController();
  int _stepAtual = 0; // 0-based: 0 Local · 1 Plantas · 2 Fotos · 3 Revisar
  // Um Form por etapa: os validators de campo ficam na etapa 1 (Local).
  final List<GlobalKey<FormState>> _formEtapas =
      List.generate(4, (_) => GlobalKey<FormState>());
  // nome popular por nome científico (catálogo) — 2ª linha do card da planta
  Map<String, String> _nomesPopulares = {};

  /// Sai da tela liberando o PopScope (chamar sempre após salvar).
  void _popAposSalvar([Object? result]) {
    if (!mounted) return;
    setState(() => _canPop = true);
    Navigator.of(context).pop(result);
  }

  // RC-10: GPS da parcela (obrigatório ao concluir — MRV exige geo auditável)
  double? _latitude;
  double? _longitude;
  double? _acuraciaM;
  int? _satelites;
  DateTime? _fixEm;
  bool _isGettingLocation = false;
  String? _gpsErro;

  // RS-01/RS-02: unidade amostral (área em m², forma, raio, marcador físico)
  final _areaController = TextEditingController();
  final _raioController = TextEditingController();
  final _marcadorController = TextEditingController();
  String _unidadeForma = 'circular'; // circular | retangular | quadrada
  // v28 MRV: fix GPS por foto tirada na câmera (path -> [lat, long]).
  // Galeria não tem fix próprio: herda o fix da parcela no sync.
  final Map<String, List<double>> _gpsFotos = {};
  // RG-02: fluxo de verificação — pendente -> revisado -> aprovado
  String _statusVerificacao = 'pendente';

  /// Área da parcela em m²: se circular, deriva de π·raio²; senão, lê o campo.
  double? get _areaM2Calculada {
    if (_unidadeForma == 'circular') {
      final r = double.tryParse(_raioController.text.replaceAll(',', '.'));
      if (r == null || r <= 0) return null;
      return 3.141592653589793 * r * r;
    }
    return double.tryParse(_areaController.text.replaceAll(',', '.'));
  }

  /// RQ-03: densidades do catálogo de espécies (chave = nome em lowercase,
  /// cobrindo nome popular e científico).
  Future<Map<String, double>> _densidadesCatalogo() async {
    final map = <String, double>{};
    final especies = await (_db.select(_db.especiesCatalogo)
          ..where((t) => t.densidadeBasica.isNotNull()))
        .get();
    for (final e in especies) {
      final d = e.densidadeBasica!;
      map[e.nomeCientifico.toLowerCase().trim()] = d;
      final pop = e.nomePopular;
      if (pop != null && pop.isNotEmpty) {
        map[pop.toLowerCase().trim()] = d;
      }
    }
    return map;
  }

  /// RQ-01..03: estimativa de carbono ao vivo (só quando há plantas + área).
  Map<String, dynamic>? get _estimativaMrv {
    final area = _areaM2Calculada;
    if (_plantas.isEmpty || area == null || area <= 0) return null;
    return MrvCalcService.calcularParcela(
      plantas: _plantas,
      areaM2: area,
      densidadesPorEspecie: _densidadesCache,
    );
  }

  @override
  void initState() {
    super.initState();
    _initAsync();
  }

  Future<void> _initAsync() async {
    _prefs = await SharedPreferences.getInstance();
    // UX-APP-CAMPO: modo wizard (default ligado) — escolhe qual formulário
    // renderizar; os dados gravados são os mesmos nos dois caminhos.
    _wizardMode = _prefs.getBool(kWizardModeKey) ?? true;
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
    // RT-01: listas de projeto/período (sempre existem: há o LEGADO seed)
    _projetos = await _db.select(_db.projetosMrv).get();
    _periodos = await _db.select(_db.periodosMonitoramento).get();
    _densidadesCache = await _densidadesCatalogo(); // RQ-03
    _projetoUuid ??= _projetos.isNotEmpty ? _projetos.first.uuid : null;
    _periodoUuid ??= _periodos.isNotEmpty ? _periodos.first.uuid : null;
    // UX-APP-CAMPO: nome popular por científico (catálogo) para o card da
    // planta no wizard. Cache estático do SpeciesService — sem I/O extra.
    try {
      final especies = await SpeciesService.loadSpecies();
      _nomesPopulares = {
        for (final e in especies)
          if (e.nomePopular.isNotEmpty &&
              e.nomePopular != e.nomeCientifico)
            e.nomeCientifico.trim().toLowerCase(): e.nomePopular,
      };
    } catch (_) {
      _nomesPopulares = {};
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
      _latitude = parcela.latitude;
      _longitude = parcela.longitude;
      // RS-01/RS-02
      if (parcela.unidadeForma != null) _unidadeForma = parcela.unidadeForma!;
      if (parcela.raioM != null) {
        _raioController.text = parcela.raioM!.toStringAsFixed(2);
      }
      if (parcela.areaM2 != null && _unidadeForma != 'circular') {
        _areaController.text = parcela.areaM2!.toStringAsFixed(1);
      }
      if (parcela.marcador != null) _marcadorController.text = parcela.marcador!;
      // RT-01: projeto/período gravados na parcela
      _projetoUuid = parcela.projetoUuid;
      _periodoUuid = parcela.periodoUuid;
      // RS-06: substituição por sensoriamento
      if (parcela.substitutaDe != null) {
        _substituidaPorSensoriamento = true;
        _fonteSensoriamentoController.text = parcela.substitutaDe!;
      }
      // RG-02: 'ativa' (legado) vira 'pendente' no fluxo de verificação
      final sv = parcela.statusParcela;
      if (sv == 'revisado' || sv == 'aprovado' || sv == 'pendente') {
        _statusVerificacao = sv!;
      } else {
        _statusVerificacao = 'pendente';
      }
      // Metadados do fix vêm do geoJson (RC-10)
      if (parcela.geoJson != null) {
        try {
          final g = jsonDecode(parcela.geoJson!) as Map<String, dynamic>;
          _acuraciaM = (g['acuracia_m'] as num?)?.toDouble();
          _satelites = (g['n_satelites'] as num?)?.toInt();
          final fix = g['fix_em'] as String?;
          if (fix != null) _fixEm = DateTime.tryParse(fix);
        } catch (_) {
          // geoJson malformado: mantém lat/long plano
        }
      }
    }
    _plantas = await _db.getPlantasByParcela(_currentUuid!);
    _fotos = await _db.getFotosByParcela(_currentUuid!);
    if (mounted) setState(() => _isLoading = false);
    if (mounted &&
        parcela != null &&
        parcela.synced &&
        parcela.prontaParaSync) {
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
        icon: Icon(Icons.info_outline, color: Theme.of(ctx).colorScheme.tertiary, size: 32),
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
            icon: Icon(Icons.person_add, color: Theme.of(ctx).colorScheme.primary, size: 32),
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

  /// RC-10: captura o fix GPS atual com metadados (acurácia, satélites,
  /// instante do fix, datum WGS84). Usado ao concluir a parcela.
  Future<void> _getLocation() async {
    setState(() {
      _isGettingLocation = true;
      _gpsErro = null;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('GPS desligado. Ligue o GPS do aparelho e tente de novo.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Permissão de localização negada. Libere nas configurações do app.');
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20),
      );
      if (!mounted) return;
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _acuraciaM = pos.accuracy;
        // RC-14: geolocator não expõe nº de satélites — fica null e o geoJson
        // registra a fonte pra não parecer dado medido
        _satelites = null;
        _fixEm = pos.timestamp;
        _isGettingLocation = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _gpsErro = e.toString();
          _isGettingLocation = false;
        });
      }
    }
  }

  /// geoJson no formato exigido pelo catálogo MRV (RC-10):
  /// {"tipo":"Point","coordenadas":[long,lat],"crs":"WGS84",
  ///  "acuracia_m":…,"n_satelites":…,"fix_em":"ISO","fonte":"geolocator"}
  String? get _geoJson {
    if (_latitude == null || _longitude == null) return null;
    return jsonEncode({
      'tipo': 'Point',
      'coordenadas': [_longitude, _latitude],
      'crs': 'WGS84',
      'acuracia_m': _acuraciaM,
      'n_satelites': _satelites,
      // RC-14: quando null, diz a fonte — o número não foi medido
      'n_satelites_fonte': _satelites == null ? 'indisponivel_geolocator' : 'fix',
      'fix_em': _fixEm?.toIso8601String(),
      'fonte': 'geolocator',
    });
  }

  @override
  void dispose() {
    _propriedadeController.dispose();
    _propUtController.dispose();
    _idParcelaController.dispose();
    _observacoesController.dispose();
    _areaController.dispose();
    _raioController.dispose();
    _marcadorController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  bool get _hasUnsavedData {
    if (_propriedadeController.text.isNotEmpty ||
        _propUtController.text.isNotEmpty ||
        _idParcelaController.text.isNotEmpty ||
        _plantas.isNotEmpty ||
        _novasFotosPaths.isNotEmpty ||
        _observacoesController.text.trim().isNotEmpty) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_popGuard) return;
        _popGuard = true;
        if (_hasUnsavedData || (_isEditing && !_prontaParaSync)) {
          final choice = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              icon: Icon(Icons.warning_amber,
                  color: Theme.of(ctx).colorScheme.tertiary, size: 32),
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
                  child: Text('Descartar',
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                ),
              ],
            ),
          );
          if (choice == 'draft') {
            if (_formularioValido()) {
              await _writeParcela(prontaParaSync: false);
              if (mounted) {
                await context.read<SyncService>().refreshPendingCount();
              }
            }
            if (mounted) _popAposSalvar(true);
          } else if (choice == 'discard') {
            if (_isEditing && _currentUuid != null) {
              await _limparDadosParcela(_currentUuid!);
            }
            // >>> t16 D-1 (H5): descarte da sessão — path ainda 'capturado',
            // nunca subiu: limpar é seguro (não há evidência a perder), mas
            // passa pelo guard por uniformidade.
            for (final path in _novasFotosPaths) {
              await ImageService.limparFotoConfirmada(
                path: path,
                arquivoEstado: 'capturado',
              );
            }
            // <<< t16 D-1: fim
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
            if (mounted) _popAposSalvar(true);
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
                label: 'Exportar ZIP',
                button: true,
                child: IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: _exportZip,
                  tooltip: 'Exportar ZIP (dados + fotos)',
                ),
              ),
              Semantics(
                label: 'Excluir parcela',
                button: true,
                child: IconButton(
                  icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                  onPressed: _confirmDelete,
                  tooltip: 'Excluir parcela',
                ),
              ),
            ],
            // RC-09: dossiê de auditoria — disponível em edição e em
            // somente-leitura (o verificador também precisa do rastro)
            Semantics(
              label: 'Exportar dossiê de auditoria',
              button: true,
              child: IconButton(
                icon: const Icon(Icons.folder_zip),
                onPressed:
                    (_isLoading || _isExportandoDossie) ? null : _exportarDossie,
                tooltip: 'Dossiê de auditoria (PDF + manifesto de hashes)',
              ),
            ),
          ],
        ),
        body: SafeArea(
          bottom: true,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: _wizardMode ? _buildWizard() : _buildClassico(),
                ),
        ),
      ),
    );
  }

  // ==========================================
  // UX-APP-CAMPO: CAMINHO CLÁSSICO (flag desligada)
  // Exatamente o formulário de hoje — só a renderização mudou de lugar.
  // ==========================================
  Widget _buildClassico() {
    return Form(
      key: _formKey,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
                        // ==========================================
                        // SEÇÃO 1: Identificação (Hierarquia)
                        // ==========================================
                        const SizedBox(height: 12),
                        _gpsCard(),
                        const SizedBox(height: 12),

                        // --- Propriedade (com autocomplete) ---
                        _propriedadeField(),
                        const SizedBox(height: 16),

                        // --- UT / Talhão (com autocomplete) ---
                        _utField(),
                        const SizedBox(height: 16),

                        // --- Número da Parcela (livre: o usuário define na hora) ---
                        _numeroField(),

                        const SizedBox(height: 16),

                        // ==========================================
                        // SEÇÃO 1b: Unidade amostral (RS-01/RS-02)
                        // ==========================================
                        _unidadeAmostralCard(),

                        const SizedBox(height: 16),

                        // ==========================================
                        // RG-02: Status de verificação (pendente → revisado → aprovado)
                        // Só admin altera; demais usuários veem o status atual.
                        // ==========================================
                        _verificacaoCard(),

                        const SizedBox(height: 16),

                        // ==========================================
                        // SEÇÃO 2: Anotações (antigo Observações) — PRIMEIRO
                        // ==========================================
                        _anotacoesField(),

                        const SizedBox(height: 32),

                        // ==========================================
                        // SEÇÃO 3: Plantas
                        // ==========================================
                        _plantasSecao(wizard: false),

                        // RQ-01..03: estimativa de carbono ao vivo
                        if (_estimativaMrv != null) ...[
                          const SizedBox(height: 16),
                          _estimativaMrvCard(),
                        ],

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
                        _avisoNaoSincronizada(),

                        // ==========================================
                        // BOTÕES: Sair e guardar (rascunho) | Concluir
                        // ==========================================
                        _botoesAcao(),
                        const SizedBox(height: 32),
                      ],
                    ),
    );
  }

  // ==========================================
  // SEÇÕES EXTRAÍDAS (compartilhadas clássico ↔ wizard)
  // ==========================================

  /// RC-10: card do GPS da parcela.
  Widget _gpsCard() {
    return UrutauSectionCard(
      icon: Icons.location_on,
      // Sem "(obrigatória ao concluir)" no título: quem tentar concluir sem
      // GPS já é travado com o aviso explícito (MRV exige geo auditável).
      title: 'Localização GPS',
      accent: _latitude != null ? AppTokens.success : Theme.of(context).colorScheme.onSurfaceVariant,
      background:
          _latitude != null ? AppTokens.successBg : AppTokens.neutralBg,
      headerTrailing: [
        if (_isGettingLocation)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          TextButton(
            onPressed: widget.readOnly ? null : _getLocation,
            child: Text(_latitude != null ? 'Atualizar' : 'Capturar GPS'),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_latitude != null) ...[
            Text(
              '${_latitude!.toStringAsFixed(6)}, '
              '${_longitude!.toStringAsFixed(6)}'
              '${_acuraciaM != null ? '  ·  ±${_acuraciaM!.round()} m' : ''}'
              '${_fixEm != null ? '  ·  ${_dataHoraCurta(_fixEm!)}' : ''}',
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: AppTokens.fontSmall),
            ),
            Text(
              'WGS84 · GPS do aparelho',
              style: TextStyle(
                  fontSize: AppTokens.fontCaption,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ] else ...[
            Text(
              'Nenhum ponto capturado.',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
          if (_gpsErro != null) ...[
            const SizedBox(height: 4),
            Text(_gpsErro!,
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
    );
  }

  /// Data/hora curtas pt-BR para o card de GPS ("06/11 19:05").
  String _dataHoraCurta(DateTime dt) {
    final d = dt.toLocal();
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(d.day)}/${dois(d.month)} ${dois(d.hour)}:${dois(d.minute)}';
  }

  Widget _propriedadeField() {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: _propriedadeController.text),
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
      fieldViewBuilder: (context, textController, focusNode, onSubmitted) {
        return Semantics(
          label: 'Propriedade',
          textField: true,
          child: TextFormField(
            enabled: !widget.readOnly,
            controller: textController,
            focusNode: focusNode,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Propriedade *',
              hintText: 'Ex: Fazenda São João',
              prefixIcon: const Icon(Icons.home_work),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: _propriedadesSugestoes.isNotEmpty
                  ? const Icon(Icons.arrow_drop_down, size: 20)
                  : null,
            ),
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Campo obrigatório' : null,
            onFieldSubmitted: (_) => onSubmitted(),
          ),
        );
      },
    );
  }

  Widget _utField() {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: _propUtController.text),
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
      fieldViewBuilder: (context, textController, focusNode, onSubmitted) {
        return Semantics(
          label: 'UT ou Talhão',
          textField: true,
          child: TextFormField(
            enabled: !widget.readOnly,
            controller: textController,
            focusNode: focusNode,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'UT / Talhão *',
              hintText: 'Ex: UT 01, Talhão A',
              prefixIcon: const Icon(Icons.park),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: _utSugestoes.isNotEmpty
                  ? const Icon(Icons.arrow_drop_down, size: 20)
                  : null,
            ),
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Campo obrigatório' : null,
            onFieldSubmitted: (_) => onSubmitted(),
          ),
        );
      },
    );
  }

  Widget _numeroField() {
    return Semantics(
      label: 'Número da parcela',
      textField: true,
      child: TextFormField(
        controller: _idParcelaController,
        enabled: !widget.readOnly,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: 'Número da parcela *',
          hintText: 'Você define (ex: 1, 2, 3...)',
          helperText: 'Número que você dá a esta parcela no campo.',
          prefixIcon: const Icon(Icons.tag),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        keyboardType: TextInputType.number,
        validator: (v) {
          if (v == null || v.isEmpty) return 'Campo obrigatório';
          if (int.tryParse(v) == null) return 'Número inválido';
          return null;
        },
      ),
    );
  }

  /// RS-01/RS-02: forma, raio/área, marcador, RS-06 e projeto/período.
  Widget _unidadeAmostralCard() {
    return UrutauSectionCard(
      icon: Icons.square_foot,
      title: 'Unidade amostral (obrigatória ao concluir)',
      accent: AppTokens.accentTeal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _unidadeForma,
            decoration: InputDecoration(
              labelText: 'Forma da parcela',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            items: const [
              DropdownMenuItem(
                  value: 'circular', child: Text('Circular (raio)')),
              DropdownMenuItem(
                  value: 'quadrada', child: Text('Quadrada (área direta)')),
              DropdownMenuItem(
                  value: 'retangular',
                  child: Text('Retangular (área direta)')),
            ],
            onChanged: widget.readOnly
                ? null
                : (v) => setState(() {
                      if (v != null) _unidadeForma = v;
                    }),
          ),
          const SizedBox(height: 8),
          if (_unidadeForma == 'circular')
            // Clássico: campo inline como sempre (rebuild da tela a cada
            // tecla mantém o card MRV ao vivo atualizado). Wizard: campo com
            // estado próprio — não reconstruí o formulário inteiro por tecla.
            if (_wizardMode)
              _RaioField(
                controller: _raioController,
                enabled: !widget.readOnly,
              )
            else
              TextFormField(
                controller: _raioController,
                enabled: !widget.readOnly,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Raio (m) *',
                  hintText: 'ex: 10',
                  prefixIcon: const Icon(Icons.radio_button_checked),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  helperText: _raioController.text.isEmpty
                      ? null
                      : 'Área = π·r² = ${_areaM2Calculada?.toStringAsFixed(1) ?? '?'} m²',
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (_unidadeForma != 'circular') {
                    return null;
                  }
                  final r = double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (r == null || r <= 0) {
                    return 'Informe o raio em metros';
                  }
                  return null;
                },
              )
          else
            TextFormField(
              controller: _areaController,
              enabled: !widget.readOnly,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Área da parcela (m²) *',
                hintText: 'ex: 400 (20×20 m)',
                prefixIcon: const Icon(Icons.crop_free),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) {
                if (_unidadeForma == 'circular') {
                  return null;
                }
                final a = double.tryParse((v ?? '').replaceAll(',', '.'));
                if (a == null || a <= 0) {
                  return 'Informe a área em m²';
                }
                return null;
              },
            ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _marcadorController,
            enabled: !widget.readOnly,
            decoration: InputDecoration(
              labelText: 'Marcador físico (opcional)',
              hintText: 'ex: estaca PVC nº 7, plaqueta A-12',
              prefixIcon: const Icon(Icons.push_pin),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          // RS-06: substituição por sensoriamento remoto
          CheckboxListTile(
            value: _substituidaPorSensoriamento,
            onChanged: widget.readOnly
                ? null
                : (v) => setState(
                    () => _substituidaPorSensoriamento = v ?? false),
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
                'Substituída por sensoriamento remoto (drone/satélite)'),
          ),
          if (_substituidaPorSensoriamento)
            TextFormField(
              controller: _fonteSensoriamentoController,
              enabled: !widget.readOnly,
              decoration: InputDecoration(
                labelText: 'Fonte do sensoriamento',
                hintText:
                    'ex: voo drone 2026-09-12, cena Sentinel-2 2026-08-30',
                prefixIcon: const Icon(Icons.satellite_alt),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          // RT-01: projeto MRV + período de monitoramento
          if (_projetos.isNotEmpty || _periodos.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (_projetos.isNotEmpty)
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _projetoUuid,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Projeto MRV',
                        prefixIcon: const Icon(Icons.folder),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _projetos
                          .map((p) => DropdownMenuItem(
                                value: p.uuid,
                                child: Text('${p.nome} (${p.codigo})',
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: widget.readOnly
                          ? null
                          : (v) => setState(() => _projetoUuid = v),
                    ),
                  ),
                if (_projetos.isNotEmpty && _periodos.isNotEmpty)
                  const SizedBox(width: 8),
                if (_periodos.isNotEmpty)
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _periodoUuid,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Período',
                        prefixIcon: const Icon(Icons.calendar_month),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _periodos
                          .map((p) => DropdownMenuItem(
                                value: p.uuid,
                                child: Text(p.codigo,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: widget.readOnly
                          ? null
                          : (v) => setState(() => _periodoUuid = v),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// RG-02: status de verificação (só admin altera).
  Widget _verificacaoCard() {
    return Builder(
      builder: (ctx) {
        final admin =
            ctx.read<SyncService>().currentUser?.isAdmin ?? false;
        return UrutauSectionCard(
          icon: Icons.verified_user,
          title: 'Verificação (só admin altera)',
          accent: AppTokens.statusColor(_statusVerificacao),
          headerTrailing: [
            StatusBadge(status: _statusVerificacao, compact: true),
          ],
          child: DropdownButtonFormField<String>(
            initialValue: _statusVerificacao,
            decoration: InputDecoration(
              labelText: 'Status de verificação',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusM)),
            ),
            items: const [
              DropdownMenuItem(value: 'pendente', child: Text('Pendente')),
              DropdownMenuItem(value: 'revisado', child: Text('Revisado')),
              DropdownMenuItem(
                  value: 'aprovado', child: Text('Aprovado')),
            ],
            onChanged: (admin && !widget.readOnly)
                ? (v) => setState(() {
                      if (v != null) {
                        _statusVerificacao = v;
                      }
                    })
                : null,
          ),
        );
      },
    );
  }

  Widget _anotacoesField() {
    return Semantics(
      label: 'Anotações',
      textField: true,
      child: TextFormField(
        controller: _observacoesController,
        enabled: !widget.readOnly,
        textInputAction: TextInputAction.newline,
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
    );
  }

  Widget _emptyPlantas() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.grass, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            'Nenhuma planta adicionada',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  /// Lista de plantas + adicionar. Cascata por espécie com filtro rápido
  /// (UX-APP-CAMPO) nos dois modos; o destaque vai pra última adicionada.
  Widget _plantasSecao({required bool wizard}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Plantas (${_plantas.length})', Icons.grass),
        const SizedBox(height: 12),
        if (_plantas.isEmpty) _emptyPlantas(),
        PlantasAgrupadas(
          plantas: _plantas,
          nomesPopulares: _nomesPopulares,
          ultimaUuid: _ultimaPlantaUuid,
          onEditar: widget.readOnly ? null : (p) => _editPlanta(p),
          onRemover: widget.readOnly ? null : (p) => _removePlanta(p),
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
      ],
    );
  }

  /// RQ-01..03: card da estimativa de carbono ao vivo.
  /// No wizard aparece SOMENTE na etapa Revisar (spec UX-APP-CAMPO).
  Widget _estimativaMrvCard() {
    return UrutauSectionCard(
      icon: Icons.co2,
      title: 'Estimativa de carbono (MRV)',
      accent: AppTokens.mrvGreen,
      background: AppTokens.mrvGreenBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${(_estimativaMrv!['tco2e_ha'] as double).toStringAsFixed(1)} tCO₂e/ha'
            '  ·  ${(_estimativaMrv!['tco2e_total'] as double).toStringAsFixed(2)} tCO₂e na parcela'
            '  ·  ${_estimativaMrv!['n_com_dap']}/${_estimativaMrv!['n_individuos']} com DAP',
            style: const TextStyle(fontSize: 14),
          ),
          // RS-03: margem de certeza (promessa do pitch)
          Builder(
            builder: (_) {
              final pct = _estimativaMrv!['incerteza_pct'];
              if (pct is! double) {
                return Text(
                  'Incerteza: n < 2 — não calculável',
                  style: TextStyle(
                      fontSize: AppTokens.fontSmall, color: Theme.of(context).colorScheme.onSurfaceVariant),
                );
              }
              return Text(
                '± ${pct.toStringAsFixed(1)}% (IC 95%, n=${_estimativaMrv!['n_com_dap']})'
                '  ·  IC = ${(_estimativaMrv!['tco2e_ha'] as double).toStringAsFixed(1)} ± ${(_estimativaMrv!['ic95_tco2e_ha'] as double).toStringAsFixed(1)} tCO₂e/ha',
                style: const TextStyle(
                    fontSize: AppTokens.fontSmall,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.mrvGreen),
              );
            },
          ),
          Text(
            'Equação: Chave et al. 2014 (pantropical) · '
            'FC 0,47 · 44/12 · AGB aérea apenas',
            style: TextStyle(
                fontSize: AppTokens.fontCaption, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          // RQ-04: rastro do cálculo (hash do resultado)
          if (_estimativaMrv!['resultado_hash'] is String)
            Text(
              'Rastro do cálculo: #${(_estimativaMrv!['resultado_hash'] as String).substring(0, 12)}…',
              style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: AppTokens.fontCaption,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }

  Widget _fotosTitulo() {
    return _sectionTitle(
      'Fotos da parcela (${_fotos.length + _novasFotosPaths.length})',
      Icons.photo_camera,
    );
  }

  Widget _avisoNaoSincronizada() {
    if (!(_prontaParaSync == false && _isEditing && !widget.readOnly)) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.tertiary),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              color: Theme.of(context).colorScheme.onTertiaryContainer,
              size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Esta parcela não será sincronizada até marcar como concluída.',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }

  /// Botões do caminho clássico: Guardar rascunho + Concluir.
  Widget _botoesAcao() {
    if (widget.readOnly) return const SizedBox.shrink();
    return Column(
      children: [
        Semantics(
          label: 'Salvar rascunho',
          button: true,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _salvarRascunho,
            icon: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
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
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
                : const Icon(Icons.check_circle),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _isEditing ? 'Concluir alterações' : 'Concluir parcela',
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
    );
  }

  // ==========================================
  // UX-APP-CAMPO: WIZARD DE 4 ETAPAS COM SWIPE
  // ==========================================

  Widget _buildWizard() {
    return Column(
      children: [
        WizardStepper(etapaAtual: _stepAtual, onEtapaTap: _irParaEtapa),
        const Divider(height: 1),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: _onPaginaMudou,
            children: [
              _etapaLocal(),
              _etapaFotos(),
              _etapaPlantas(),
              _etapaRevisar(),
            ],
          ),
        ),
        _wizardNav(),
      ],
    );
  }

  /// Etapa 1 — Local: GPS, propriedade, UT, número, unidade amostral,
  /// projeto/período e RS-06. É a única etapa com validators de campo.
  Widget _etapaLocal() {
    return Form(
      key: _formEtapas[0],
      child: WizardStepPage(children: [
        _gpsCard(),
        const SizedBox(height: AppTokens.spaceM),
        _propriedadeField(),
        const SizedBox(height: AppTokens.spaceL),
        _utField(),
        const SizedBox(height: AppTokens.spaceL),
        _numeroField(),
        const SizedBox(height: AppTokens.spaceL),
        _unidadeAmostralCard(),
      ]),
    );
  }

  /// Etapa 2 — Plantas: lista + adicionar/editar.
  Widget _etapaPlantas() {
    return Form(
      key: _formEtapas[1],
      child: WizardStepPage(children: [
        _plantasSecao(wizard: true),
      ]),
    );
  }

  /// Etapa 3 — Fotos: grid plural, com contador no título.
  Widget _etapaFotos() {
    return Form(
      key: _formEtapas[2],
      child: WizardStepPage(children: [
        _fotosTitulo(),
        const SizedBox(height: AppTokens.spaceM),
        _buildFotosGrid(),
        const SizedBox(height: AppTokens.spaceL),
        _addFotoButtonPlural(),
        const SizedBox(height: AppTokens.spaceS),
        Text(
          'Você pode adicionar várias fotos — câmera ou galeria '
          '(seleção múltipla).',
          style: TextStyle(
              fontSize: AppTokens.fontCaption, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ]),
    );
  }

  /// Etapa 4 — Revisar: anotações, verificação (admin), resumo, estimativa
  /// MRV (SÓ aqui) e os botões Concluir / Guardar rascunho.
  Widget _etapaRevisar() {
    return Form(
      key: _formEtapas[3],
      child: WizardStepPage(children: [
        _anotacoesField(),
        const SizedBox(height: AppTokens.spaceM),
        _verificacaoCard(),
        const SizedBox(height: AppTokens.spaceM),
        _resumoCard(),
        if (_estimativaMrv != null) ...[
          const SizedBox(height: AppTokens.spaceM),
          _estimativaMrvCard(),
        ],
        _avisoNaoSincronizada(),
        const SizedBox(height: AppTokens.spaceL),
        _botoesRevisar(),
      ]),
    );
  }

  Widget _botoesRevisar() {
    if (widget.readOnly) return const SizedBox.shrink();
    return Column(
      children: [
        Semantics(
          label: 'Salvar parcela',
          button: true,
          child: FilledButton.icon(
            onPressed: _isLoading ? null : _salvar,
            icon: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
                : const Icon(Icons.check_circle),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _isEditing ? 'Concluir alterações' : 'Concluir parcela',
                style: const TextStyle(fontSize: 15),
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppTokens.mrvGreen,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          label: 'Salvar rascunho',
          button: true,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _salvarRascunho,
            icon: const Icon(Icons.save_as),
            label: const Text('Guardar rascunho'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _addFotoButtonPlural() {
    return Semantics(
      label: 'Adicionar fotos da parcela',
      button: true,
      child: OutlinedButton.icon(
        onPressed: _tirarFotoParcela,
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Adicionar fotos'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, AppTokens.buttonHeight),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _wizardNav() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppTokens.spaceL, AppTokens.spaceS, AppTokens.spaceL,
          AppTokens.spaceM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _stepAtual > 0 ? _voltarEtapa : null,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Voltar'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (_stepAtual < 3) ...[
            const SizedBox(width: AppTokens.spaceM),
            Expanded(
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _continuar,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continuar'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Resumo somente-leitura da parcela (etapa Revisar).
  Widget _resumoCard() {
    String projetoSel = '—';
    for (final p in _projetos) {
      if (p.uuid == _projetoUuid) {
        projetoSel = '${p.nome} (${p.codigo})';
        break;
      }
    }
    String periodoSel = '—';
    for (final p in _periodos) {
      if (p.uuid == _periodoUuid) {
        periodoSel = p.codigo;
        break;
      }
    }
    final area = _areaM2Calculada;
    final forma = switch (_unidadeForma) {
      'circular' => 'Circular',
      'quadrada' => 'Quadrada',
      'retangular' => 'Retangular',
      _ => _unidadeForma,
    };
    return UrutauSectionCard(
      icon: Icons.fact_check,
      title: 'Resumo da parcela',
      accent: AppTokens.accentTeal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _resumoLinha(
            'Propriedade / UT',
            '${_propriedadeController.text.trim().isEmpty ? '—' : _propriedadeController.text.trim()}'
            ' · '
            '${_propUtController.text.trim().isEmpty ? '—' : _propUtController.text.trim()}',
          ),
          _resumoLinha(
            'Número',
            _idParcelaController.text.trim().isEmpty
                ? '—'
                : _idParcelaController.text.trim(),
          ),
          _resumoLinha(
            'GPS',
            _latitude != null
                ? '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}'
                    '${_acuraciaM != null ? ' (±${_acuraciaM!.toStringAsFixed(1)} m)' : ''}'
                : 'não capturado (obrigatório ao concluir)',
          ),
          _resumoLinha(
            'Unidade amostral',
            area != null && area > 0
                ? '$forma · ${area.toStringAsFixed(1)} m²'
                : 'não informada',
          ),
          _resumoLinha('Projeto / Período', '$projetoSel · $periodoSel'),
          if (_substituidaPorSensoriamento)
            _resumoLinha(
              'RS-06',
              _fonteSensoriamentoController.text.trim().isEmpty
                  ? 'substituída por sensoriamento (fonte não informada)'
                  : _fonteSensoriamentoController.text.trim(),
            ),
          _resumoLinha(
            'Plantas / Fotos',
            '${_plantas.length} planta(s) · '
            '${_fotos.length + _novasFotosPaths.length} foto(s)',
          ),
        ],
      ),
    );
  }

  Widget _resumoLinha(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 122,
            child: Text(
              label,
              style: TextStyle(
                  fontSize: AppTokens.fontSmall, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: AppTokens.spaceS),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(
                  fontSize: AppTokens.fontSmall,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ── Navegação do wizard ──────────────────────────────────────────────

  Future<void> _continuar() async {
    final erro = _erroAoAvancarDe(_stepAtual);
    if (erro != null) {
      // mensagens atuais inline (etapa Local) + o motivo no snackbar
      _formEtapas[0].currentState?.validate();
      _mostrarSnackErro(erro);
      return;
    }
    await _pageController.animateToPage(
      _stepAtual + 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _voltarEtapa() async {
    if (_stepAtual == 0) return;
    await _pageController.animateToPage(
      _stepAtual - 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _irParaEtapa(int destino) async {
    if (destino == _stepAtual) return;
    if (destino < _stepAtual) {
      // voltar sempre permitido (swipe para trás já é livre)
      await _pageController.animateToPage(
        destino,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
      return;
    }
    // avançar pelo stepper: todas as etapas intermediárias precisam valer
    for (var s = _stepAtual; s < destino; s++) {
      final erro = _erroAoAvancarDe(s);
      if (erro != null) {
        _formEtapas[0].currentState?.validate();
        _mostrarSnackErro(erro);
        return;
      }
    }
    await _pageController.animateToPage(
      destino,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _onPaginaMudou(int i) {
    if (i > _stepAtual) {
      // swipe pra frente em etapa inválida: não avança + snackbar
      final erro = _erroAoAvancarDe(_stepAtual);
      if (erro != null) {
        _pageController.animateToPage(
          _stepAtual,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
        _mostrarSnackErro(erro);
        return;
      }
    }
    setState(() => _stepAtual = i);
  }

  /// Motivo (mensagem atual) que impede avançar da etapa [step]; null = ok.
  /// Ordem do wizard: 0 Local · 1 Fotos · 2 Plantas · 3 Revisar.
  /// Só Local (validators) e Plantas (≥1 planta) travam — como no clássico.
  String? _erroAoAvancarDe(int step) {
    switch (step) {
      case 0:
        return _erroEtapaLocal();
      case 2:
        return _plantas.isEmpty
            ? 'Adicione pelo menos 1 planta para concluir a parcela.'
            : null;
      default:
        return null; // Fotos e Revisar não travam o avanço
    }
  }

  /// Espelho EXPLÍCITO dos validators da etapa Local (mensagens atuais),
  /// usado pelas travas do wizard e pelos saves quando o Form da etapa
  /// não está montado.
  String? _erroEtapaLocal() {
    final prop = _propriedadeController.text.trim();
    if (prop.isEmpty) return 'Propriedade: Campo obrigatório';
    final ut = _propUtController.text.trim();
    if (ut.isEmpty) return 'UT / Talhão: Campo obrigatório';
    final numTxt = _idParcelaController.text.trim();
    if (numTxt.isEmpty) return 'Número da parcela: Campo obrigatório';
    if (int.tryParse(numTxt) == null) {
      return 'Número da parcela: Número inválido';
    }
    if (_unidadeForma == 'circular') {
      final r = double.tryParse(_raioController.text.replaceAll(',', '.'));
      if (r == null || r <= 0) return 'Raio: Informe o raio em metros';
    } else {
      final a = double.tryParse(_areaController.text.replaceAll(',', '.'));
      if (a == null || a <= 0) return 'Área: Informe a área em m²';
    }
    return null;
  }

  /// Validação do formulário nos dois caminhos. Clássico: exatamente o
  /// `_formKey.currentState!.validate()` de sempre. Wizard: na etapa Local o
  /// Form está montado (mostra os erros inline); nas demais etapas usa a
  /// checagem explícita equivalente a `_erroEtapaLocal()`.
  bool _formularioValido() {
    if (!_wizardMode) {
      return _formKey.currentState?.validate() ?? false;
    }
    if (_stepAtual == 0) {
      final st = _formEtapas[0].currentState;
      if (st != null) return st.validate();
    }
    return _erroEtapaLocal() == null;
  }

  void _mostrarSnackErro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTokens.danger,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// RC-09: gera o ZIP do dossiê (PDF + dados.json + manifesto.json +
  /// fotos) e abre o compartilhador.
  Future<void> _exportarDossie() async {
    final uuid = _currentUuid;
    if (uuid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Salve a parcela antes de gerar o dossiê.')),
      );
      return;
    }
    setState(() => _isExportandoDossie = true);
    try {
      final sync = context.read<SyncService>();
      final zipPath = await DossieService.gerarDossieParcela(
        _db,
        uuid,
        serverChainStatus: sync.lastServerChainStatus,
      );
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(zipPath)],
        text: 'Dossiê MRV — parcela (PDF + manifesto de hashes)',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao gerar dossiê: $e')),
      );
    } finally {
      if (mounted) setState(() => _isExportandoDossie = false);
    }
  }

  Widget _sectionTitle(String title, IconData icon) =>
      SectionTitle(title: title, icon: icon);

  Widget _buildPlantaCard(int index, Planta planta) {
    final cs = Theme.of(context).colorScheme;
    final categoriaColors = {
      1: cs.primary,
      2: cs.tertiary,
      3: cs.secondary,
    };
    final color = categoriaColors[planta.categoria] ?? cs.onSurfaceVariant;

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
              Icon(Icons.photo, color: cs.primary, size: 20),
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
                icon: Icon(Icons.delete, size: 20, color: cs.error),
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
            arquivoAusente: _fotos[index].arquivoAusente,
            onDelete: () => _removeFotoSalva(index),
            mostrarEstado: _wizardMode,
            verificada: _fotos[index].enviadoVerificadoEm != null,
          );
        }

        // Novas fotos
        final novaIndex = index - _fotos.length;
        if (novaIndex < _novasFotosPaths.length) {
          return _buildFotoTile(
            imagePath: _novasFotosPaths[novaIndex],
            onDelete: () => _removeNovaFoto(novaIndex),
            mostrarEstado: _wizardMode,
            verificada: false,
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
    bool arquivoAusente = false,
    // UX-APP-CAMPO (wizard): mini-badge de estado do arquivo no rodapé do
    // tile — 'verificada' (hash conferido no servidor) ou 'pendente'.
    bool mostrarEstado = false,
    bool verificada = false,
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
        // >>> t9 S1: badge quando o arquivo não está mais no disco
        if (arquivoAusente) const ArquivoAusenteBadge(),
        if (mostrarEstado)
          Positioned(
            left: 4,
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (verificada ? AppTokens.mrvGreen : AppTokens.warning)
                    .withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(AppTokens.radiusS),
              ),
              child: Text(
                verificada ? 'hash verificada' : 'hash pendente',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: AppTokens.fontCaption,
                  fontWeight: FontWeight.w600,
                  color: Colors.white, // overlay (badge sobre a foto)
                ),
              ),
            ),
          ),
        Positioned(
          top: 4,
          right: 4,
          child: Semantics(
            label: 'Remover foto',
            button: true,
            child: IconButton(
              icon: Icon(Icons.cancel, color: Theme.of(context).colorScheme.error),
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
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 2),
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo, size: 36, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 8),
              Text(
                'Adicionar foto',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
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
      setState(() {
        _plantas.add(result);
        _ultimaPlantaUuid = result.uuid;
      });
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
          _ultimaPlantaUuid = result.uuid;
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
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
                foregroundColor: Theme.of(ctx).colorScheme.onError),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (planta.fotoEspeciePath != null) {
        await ImageService.limparFotoConfirmada(
          path: planta.fotoEspeciePath!,
          arquivoEstado: planta.arquivoEstado ?? 'capturado',
          onLimpo: () => _db.logAudit(
            'arquivo_local_limpo',
            entityType: 'planta',
            entityUuid: planta.uuid,
          ),
        );
      }
      await _db.deletePlanta(planta.uuid);
      // Audit log for planta deletion
      await _db.logAudit('delete', entityType: 'planta', entityUuid: planta.uuid, newValue: 'deleted');
      setState(() => _plantas.removeWhere((p) => p.uuid == planta.uuid));
    }
  }

  Future<void> _tirarFotoParcela() async {
    final picker = ImagePicker();

    // Verifica espaço em disco antes de abrir câmera/galeria
    final freeGB = await StorageService.getFreeSpaceGB();
    if (StorageService.isCritical(freeGB)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Espaço insuficiente (${freeGB.toStringAsFixed(2)} GB). Libere espaço antes de fotografar.',
              style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

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
        // D-1 (decisão do Badger): o ORIGINAL sobe — sem re-encodar no
        // picker. Comprimir é perda e não tem como descomprimir sem perder;
        // o original é a evidência (RC-02/RC-04).
      );
      for (final photo in photos) {
        final savedPath = await _saveAndCompressPhoto(photo.path);
        if (savedPath != null) {
          setState(() => _novasFotosPaths.add(savedPath));
        }
      }
    } else {
      // Câmera (uma foto por vez)
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        // D-1 (decisão do Badger): o ORIGINAL sobe — sem re-encodar no
        // picker. Comprimir é perda e não tem como descomprimir sem perder;
        // o original é a evidência (RC-02/RC-04).
      );
      if (photo != null) {
        final savedPath = await _saveAndCompressPhoto(photo.path);
        if (savedPath != null) {
          // v28 MRV: foto de câmera carrega o fix GPS próprio (best-effort)
          final fix = await _fixRapido();
          if (fix != null) _gpsFotos[savedPath] = fix;
          setState(() => _novasFotosPaths.add(savedPath));
        }
      }
    }
  }

  /// Fix GPS rápido best-effort para foto de câmera (não trava o fluxo).
  Future<List<double>?> _fixRapido() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return [pos.latitude, pos.longitude];
    } catch (_) {
      return null;
    }
  }

  /// Salva a foto localmente.
  ///
  /// D-1 (decisão do Badger): o ORIGINAL é a evidência e sobe como original —
  /// sem re-encodar. Comprime agora custaria perda sem retorno. Hash e bytes
  /// ficam em _hashesNovasFotos/_bytesNovasFotos para o catálogo (S3).
  Future<String?> _saveAndCompressPhoto(String photoPath) async {
    try {
      // >>> t14 S3: inicio
      final salvo = await ImageService.salvarOriginalComMetadados(photoPath);
      try {
        await ImageService.generateThumbnail(io.File(salvo.caminho));
      } catch (e) {
        debugPrint('Thumbnail generation failed (non-critical): $e');
      }
      _hashesNovasFotos[salvo.caminho] = salvo.sha256;
      _bytesNovasFotos[salvo.caminho] = salvo.bytes;
      return salvo.caminho;
      // <<< t14 S3: fim
    } catch (e) {
      debugPrint('Erro ao salvar foto: $e');
      return null;
    }
  }

  void _removeFotoSalva(int index) {
    setState(() {
      final foto = _fotos.removeAt(index);
      _db.deleteFotoParcela(foto.uuid);
      // >>> t16 D-1 (H5): guard — 'capturado' não sobe; remoção local de
      // foto ainda não verificada é permitida (sem evidência no servidor).
      unawaited(ImageService.limparFotoConfirmada(
        path: foto.filePath,
        arquivoEstado: 'capturado',
      ));
      // <<< t16 D-1: fim
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
    if (!_formularioValido()) return;
    setState(() => _isLoading = true);
    try {
      final syncService = context.read<SyncService>();
      final currentUser = syncService.currentUser;
      if (currentUser == null) {
        throw Exception('Usuário não identificado. Faça login novamente.');
      }
      await _writeParcela(prontaParaSync: false);
      // Audit log for parcela creation (draft)
      await _db.logAudit('create', entityType: 'parcela', entityUuid: _currentUuid!, newValue: 'draft');
      if (mounted) {
        await context.read<SyncService>().refreshPendingCount();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rascunho guardado. Pode retomar depois.',
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer)),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            duration: Duration(seconds: 4),
          ),
        );
        _popAposSalvar(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro: $e', style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              duration: const Duration(seconds: 4)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Conclui a parcela: exige pelo menos 1 planta; fica pronta para sincronizar.
  Future<void> _salvar() async {
    if (!_formularioValido()) return;
    if (_plantas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Adicione pelo menos 1 planta para concluir a parcela.',
              style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }
    // RC-10: geo obrigatória ao concluir (MRV — parcela sem GPS não é auditável)
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Capture o GPS da parcela antes de concluir. Sem localização, '
              'a parcela não é auditável (MRV).',
              style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          duration: Duration(seconds: 6),
        ),
      );
      return;
    }
    // RS-01: área da unidade amostral obrigatória ao concluir
    if ((_areaM2Calculada ?? 0) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Informe a área da parcela (m²) antes de concluir. '
              'Sem área não dá pra calcular carbono por hectare (MRV).',
              style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          duration: Duration(seconds: 6),
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
      // Audit log for parcela creation/update
      final action = _isEditing ? 'update' : 'create';
      await _db.logAudit(action, entityType: 'parcela', entityUuid: _currentUuid!, newValue: action);
      if (mounted) {
        await context.read<SyncService>().refreshPendingCount();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Parcela concluída. Pode sincronizar quando tiver rede.',
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer)),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            duration: Duration(seconds: 4),
          ),
        );
        _popAposSalvar(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao salvar: $e', style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              duration: const Duration(seconds: 5)),
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
      // Q3 item 7: chave de negócio nasce com a parcela (RS-02). Mesmo
      // formato do backfill v19 ('<propUt>-P<idParcela>') para o catálogo
      // MRV e a auditoria terem identidade legível desde o insert.
      parcelaIdText: drift.Value('$ut-P$idParcela'),
      observacoes: drift.Value(_observacoesController.text.trim().isEmpty
          ? null
          : _observacoesController.text.trim()),
      userId: drift.Value(currentUser.uuid),
      // RC-10: grava lat/long + geoJson completo (acurácia, fix, datum)
      latitude: drift.Value(_latitude),
      longitude: drift.Value(_longitude),
      geoJson: drift.Value(_geoJson),
      // RS-01/RS-02: unidade amostral
      areaM2: drift.Value(_areaM2Calculada),
      unidadeForma: drift.Value(_unidadeForma),
      raioM: _unidadeForma == 'circular'
          ? drift.Value(
              double.tryParse(_raioController.text.replaceAll(',', '.')))
          : const drift.Value(null),
      marcador: drift.Value(_marcadorController.text.trim().isEmpty
          ? null
          : _marcadorController.text.trim()),
      // RC-11: SOP aplicado nesta medição (semeado como SOP-MRV-V1)
      protocoloVersao: const drift.Value('SOP-MRV-V1'),
      // RT-01: projeto + período de monitoramento
      projetoUuid: drift.Value(_projetoUuid),
      periodoUuid: drift.Value(_periodoUuid),
      // RS-06: rastreio de substituição por sensoriamento remoto
      substitutaDe: drift.Value(_substituidaPorSensoriamento
          ? (_fonteSensoriamentoController.text.trim().isEmpty
              ? 'sensoriamento remoto (fonte não informada)'
              : _fonteSensoriamentoController.text.trim())
          : null),
      // RG-02: ao concluir, parcela nasce 'pendente' de verificação;
      // admin avança para revisado/aprovado depois.
      statusParcela: drift.Value(prontaParaSync &&
              !const ['revisado', 'aprovado'].contains(_statusVerificacao)
          ? 'pendente'
          : _statusVerificacao),
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
    final autorUuid = context.read<SyncService>().currentUser?.uuid;
    for (final path in _novasFotosPaths) {
      final fotoUuid = _uuid.v4();
      // v28 MRV: foto nasce com GPS (próprio da câmera, senão o da parcela)
      // e dono — pitch promete hash + GPS + timestamp + dono em cada foto.
      final fixFoto = _gpsFotos[path];
      await _db.insertFotoParcela(FotosParcelaCompanion(
        uuid: drift.Value(fotoUuid),
        parcelaUuid: drift.Value(_currentUuid!),
        filePath: drift.Value(path),
        latitude: drift.Value(fixFoto != null ? fixFoto[0] : _latitude),
        longitude: drift.Value(fixFoto != null ? fixFoto[1] : _longitude),
        autorUuid: drift.Value(autorUuid),
      ));
      // >>> t14 S3 (H5): inicio — completa a linha que o S2 criou
      final hash = _hashesNovasFotos[path];
      if (hash != null) {
        await _db.registrarHashDoAtivo(
          ativoUuid: 'legado-ativo-$fotoUuid',
          sha256: hash,
          bytes: _bytesNovasFotos[path],
          papel: 'bruto', // D-1: o arquivo guardado É o original
        );
      }
      // <<< t14 S3: fim
    }

    // RQ-01..03: ao concluir (prontaParaSync), calcula e persiste o carbono
    // da parcela em calculos_mrv + resultados_amostra.
    final area = _areaM2Calculada;
    if (prontaParaSync && area != null && area > 0 && _plantas.isNotEmpty) {
      _densidadesCache = await _densidadesCatalogo();
      final resultado = MrvCalcService.calcularParcela(
        plantas: _plantas,
        areaM2: area,
        densidadesPorEspecie: _densidadesCache,
      );
      await MrvCalcService.persistirCalculo(
        db: _db,
        parcelaUuid: _currentUuid!,
        resultado: resultado,
        areaM2: area,
      );
    }
  }

  /// Limpa dados da parcela (plantas, fotos, obs) e reseta para disponível.
  /// RC-06/RC-07 (MRV): soft-delete — as linhas ficam no DB (deletedAt) e a
  /// ação entra na trilha encadeada. Arquivos de foto não são hard-deletados.
  Future<void> _limparDadosParcela(String uuid) async {
    final p = await _db.getParcelaByUuid(uuid);
    if (p == null) return;

    // Pre-backup de segurança antes de qualquer operação
    try {
      await BackupService.exportBackup();
    } catch (_) {
      // Non-critical — continue
    }

    try {
      await _db.transaction(() async {
        for (final foto in await _db.getFotosByParcela(uuid)) {
          await ImageService.limparFotoConfirmada(
            path: foto.filePath,
            arquivoEstado: foto.arquivoEstado ?? 'capturado',
            onLimpo: () => _db.logAudit(
              'arquivo_local_limpo',
              entityType: 'foto',
              entityUuid: foto.uuid,
            ),
          );
        }
        await _db.softDeleteDadosParcela(uuid);
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
      });
    } catch (e) {
      debugPrint('Erro ao limpar dados da parcela: $e');
      rethrow;
    }
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
            child: Text('Limpar dados', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirm == true && _currentUuid != null) {
      await _limparDadosParcela(_currentUuid!);
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  Future<void> _exportZip() async {
    if (_currentUuid == null) return;

    final exportService = ExportService(_db);
    final parcela = await _db.getParcelaByUuid(_currentUuid!);
    if (parcela == null) return;

    final fotos = await _db.getFotosByParcela(_currentUuid!);
    final fotoPaths = fotos.map((f) => f.filePath).toList();

    // Mostra diálogo de progresso
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
            Text('Preparando ZIP...'),
          ],
        ),
      ),
    );

    try {
      final zipPath = await exportService.exportParcelaZip(
        parcela: parcela,
        fotoPaths: fotoPaths,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Fecha loading

      // Compartilha
      await Share.shareXFiles([XFile(zipPath)], text: 'Parcela ${parcela.idParcela}');

      // Clean up temp zip file after a short delay
      Future.delayed(const Duration(seconds: 10), () {
        try {
          final zipFile = io.File(zipPath);
          if (zipFile.existsSync()) {
            zipFile.deleteSync();
          }
        } catch (_) {}
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ZIP exportado com sucesso!',
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer)),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Fecha loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao exportar: $e', style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}

/// UX-APP-CAMPO (performance): campo de raio com estado PRÓPRIO — o
/// helperText "Área = π·r²" recalcula a cada tecla sem rebuildar a tela
/// inteira (no caminho wizard o form não passa por setState a cada tecla).
/// A área derivada é lida ao vivo pelo mesmo controller que a tela usa.
class _RaioField extends StatefulWidget {
  final TextEditingController controller;
  final bool enabled;

  const _RaioField({required this.controller, required this.enabled});

  @override
  State<_RaioField> createState() => _RaioFieldState();
}

class _RaioFieldState extends State<_RaioField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  double? get _areaM2 {
    final r =
        double.tryParse(widget.controller.text.replaceAll(',', '.'));
    if (r == null || r <= 0) return null;
    return 3.141592653589793 * r * r;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Raio (m) *',
        hintText: 'ex: 10',
        prefixIcon: const Icon(Icons.radio_button_checked),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        helperText: widget.controller.text.isEmpty
            ? null
            : 'Área = π·r² = ${_areaM2?.toStringAsFixed(1) ?? '?'} m²',
      ),
      validator: (v) {
        final r = double.tryParse((v ?? '').replaceAll(',', '.'));
        if (r == null || r <= 0) {
          return 'Informe o raio em metros';
        }
        return null;
      },
    );
  }
}
