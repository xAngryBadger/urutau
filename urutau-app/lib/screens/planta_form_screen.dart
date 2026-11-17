import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' as drift;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../data/database.dart';
import '../data/categoria_helper.dart';
import '../theme/app_tokens.dart';
import '../data/especie_item.dart';
import '../services/image_service.dart';
import '../services/species_service.dart';
import '../services/sync_service.dart';
import '../widgets/arquivo_ausente_badge.dart';

class PlantaFormScreen extends StatefulWidget {
  final String parcelaUuid;
  final Planta? existingPlanta;

  const PlantaFormScreen({
    super.key,
    required this.parcelaUuid,
    this.existingPlanta,
  });

  @override
  State<PlantaFormScreen> createState() => _PlantaFormScreenState();
}

class _PlantaFormScreenState extends State<PlantaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  AppDatabase get _db => context.read<AppDatabase>();
  final _especieController = TextEditingController();
  final _alturaController = TextEditingController();
  final _dapController = TextEditingController();
  final _uuid = const Uuid();

  int _categoria = 0;
  bool _categoriaManual = false;
  int? _categoriaManualSelecionada;
  bool _mostrarDAP = false;
  bool _fotoObrigatoria = false;
  String? _fotoPath;
  String? _fotoSha256; // S3: hash do original na origem (RC-04)
  int? _fotoBytes; // S3: bytes do original
  bool _isEditing = false;
  String? _currentUuid;
  bool _isSaving = false;

  bool _useNomePopular = true;
  List<EspecieItem> _allSpecies = [];
  List<EspecieItem> _filteredSpecies = [];
  bool _showSpeciesList = false;
  final _especieFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    SpeciesService.loadSpecies().then((list) {
      if (mounted) {
        setState(() {
          _allSpecies = list;
          _filteredSpecies = list;
          // BUG-FIX (UX-APP-CAMPO): se o usuário já estava digitando/quando
          // a lista chega depois do foco, mostrar as sugestões já vale.
          if (_especieFocusNode.hasFocus ||
              _especieController.text.trim().isNotEmpty) {
            _filteredSpecies = SpeciesService.filter(
              _allSpecies,
              _especieController.text,
              _useNomePopular,
            );
            _showSpeciesList = _filteredSpecies.isNotEmpty;
          }
        });
      }
    });
    // BUG-FIX (UX-APP-CAMPO): as sugestões precisam aparecer na PRIMEIRA
    // interação. Antes a lista só era ligada no onChanged com texto não
    // vazio (e no onTap somente quando o campo JÁ tinha texto) — ao tocar o
    // campo vazio nada aparecia e a lista effectively só surgia numa
    // interação posterior ("só no 2º clique"). Agora: ganhar foco MOSTRA a
    // lista (filtrada pelo texto atual; campo vazio = catálogo inteiro) e
    // perder foco esconde.
    _especieFocusNode.addListener(() {
      if (!mounted) return;
      if (_especieFocusNode.hasFocus) {
        setState(() {
          _filteredSpecies = SpeciesService.filter(
            _allSpecies,
            _especieController.text,
            _useNomePopular,
          );
          _showSpeciesList = _filteredSpecies.isNotEmpty;
        });
      } else {
        setState(() => _showSpeciesList = false);
      }
    });
    if (widget.existingPlanta != null) {
      final p = widget.existingPlanta!;
      _isEditing = true;
      _currentUuid = p.uuid;
      _especieController.text = p.especie;
      _alturaController.text = p.alturaCm.toString();
      if (p.dapCm != null) {
        _dapController.text = p.dapCm.toString();
      }
      _fotoPath = p.fotoEspeciePath;
      if (p.alturaCm == 0 && p.categoria >= 1 && p.categoria <= 3) {
        _categoriaManual = true;
        _categoriaManualSelecionada = p.categoria;
      }
      _updateCategoria();
    } else {
      _currentUuid = _uuid.v4();
    }
  }

  @override
  void dispose() {
    _especieFocusNode.dispose();
    _especieController.dispose();
    _alturaController.dispose();
    _dapController.dispose();
    super.dispose();
  }

  void _updateCategoria() {
    final altura =
        double.tryParse(_alturaController.text.replaceAll(',', '.')) ?? 0;
    final dap = double.tryParse(_dapController.text.replaceAll(',', '.'));

    setState(() {
      _mostrarDAP = dapObrigatorio(altura);
      _fotoObrigatoria = fotoEspecieObrigatoria(_especieController.text);
      if (altura > 0) {
        _categoria = calcularCategoria(altura, _mostrarDAP ? dap : null);
      } else {
        _categoria = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Planta' : 'Adicionar Planta'),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 4),
Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(Icons.eco, color: Theme.of(context).colorScheme.onSurfaceVariant),
          Text('Tipo de nome:',
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ChoiceChip(
            label: const Text('Nome popular'),
            selected: _useNomePopular,
            onSelected: (v) => setState(() {
              _useNomePopular = true;
              _filteredSpecies = SpeciesService.filter(
                _allSpecies,
                _especieController.text,
                true,
              );
            }),
          ),
          ChoiceChip(
            label: const Text('Nome científico'),
            selected: !_useNomePopular,
            onSelected: (v) => setState(() {
              _useNomePopular = false;
              _filteredSpecies = SpeciesService.filter(
                _allSpecies,
                _especieController.text,
                        false,
                      );
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 8),
Semantics(
          label: 'Buscar espécie',
          child: TextFormField(
          controller: _especieController,
          focusNode: _especieFocusNode,
          autocorrect: false,
          textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Espécie *',
                    hintText: _useNomePopular
                        ? 'Digite ou escolha (ex: fedego, NI)'
                        : 'Digite ou escolha nome científico',
                    prefixIcon: const Icon(Icons.eco),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: _fotoObrigatoria
                        ? Tooltip(
                            message: 'Foto obrigatória para NI',
                            child: Icon(Icons.warning_amber,
                                color: Theme.of(context).colorScheme.tertiary),
                          )
                        : null,
                  ),
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [
          FilteringTextInputFormatter.allow(
              RegExp(r"[a-zA-ZÀ-ÿ0-9\s\-.()'-]")),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _filteredSpecies = SpeciesService.filter(
                        _allSpecies,
                        v,
                        _useNomePopular,
                      );
                      _showSpeciesList = v.trim().isNotEmpty;
                    });
                    _updateCategoria();
                  },
                  onTap: () {
                    // BUG-FIX (UX-APP-CAMPO): mostrar também com o campo
                    // vazio (catálogo inteiro) — sem esperar o 2º clique.
                    setState(() {
                      _filteredSpecies = SpeciesService.filter(
                        _allSpecies,
                        _especieController.text,
                        _useNomePopular,
                      );
                      _showSpeciesList = _filteredSpecies.isNotEmpty;
                    });
                  },
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe a espécie';
        if (!RegExp(r"^[a-zA-ZÀ-ÿ0-9\s\-.()'-]+$").hasMatch(v)) {
          return 'Apenas letras, números, espaços, hífens, pontos e parênteses';
                    }
                    // RC-12: entrada fechada no catálogo oficial — só aceita
                    // item do catálogo (match normalizado) ou NI. Espécie
                    // legada já existente continua válida sem alteração.
                    final norm = SpeciesService.normalize(v.trim());
                    if (norm == 'ni') return null;
                    final legacy = widget.existingPlanta?.especie;
                    if (legacy != null &&
                        SpeciesService.normalize(legacy) == norm) {
                      return null;
                    }
                    final noCatalogo = _allSpecies.any((e) =>
                        SpeciesService.normalize(e.nomePopular) == norm ||
                        SpeciesService.normalize(e.nomeCientifico) == norm);
                    if (!noCatalogo) {
                      return 'Espécie fora do catálogo oficial. Escolha na lista acima ou use NI.';
                    }
                    return null;
                  },
                ),
              ),
              if (_showSpeciesList && _filteredSpecies.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  // Material (não Container colorido) como ancestral dos
                  // ListTiles: o ink/splash do toque fica visível e o
                  // debugCheckHasMaterial do ListTile passa.
                  child: Material(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _filteredSpecies.length,
                        itemBuilder: (_, i) {
                          final e = _filteredSpecies[i];
                          final nomeExibir = e.nomeCientifico.isNotEmpty
                              ? e.nomeCientifico
                              : e.nomePopular;
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.eco, size: 20),
                            title: Text(
                              nomeExibir,
                              style: const TextStyle(fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: !_useNomePopular &&
                                    e.nomePopular.isNotEmpty &&
                                    e.nomePopular != e.nomeCientifico
                                ? Text(
                                    e.nomePopular,
                                    style: TextStyle(
                                        fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            onTap: () {
                              _especieController.text = nomeExibir;
                              setState(() {
                                _showSpeciesList = false;
                                _filteredSpecies = [];
                              });
                              _updateCategoria();
                              FocusScope.of(context).unfocus();
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              if (_fotoObrigatoria) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.tertiary),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Theme.of(context).colorScheme.onTertiaryContainer, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Atenção: Foto obrigatória para identificação posterior.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onTertiaryContainer,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (!_categoriaManual)
                Semantics(
                  label: 'Altura da árvore',
                  child: TextFormField(
                    controller: _alturaController,
                    decoration: InputDecoration(
                      labelText: 'Altura (cm) *',
                      hintText: 'Ex: 120',
                      prefixIcon: const Icon(Icons.height),
                      suffixText: 'cm',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
onChanged: (_) => _updateCategoria(),
                     validator: (v) {
                       if (v == null || v.isEmpty) return 'Informe a altura';
                       final val = double.tryParse(v.replaceAll(',', '.'));
                       if (val == null || val <= 0) return 'Valor inválido';
                       return null;
                     },
                     textInputAction: TextInputAction.next,
                   ),
                ),
              const SizedBox(height: 16),
              if (!_categoriaManual)
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  child: _mostrarDAP
                      ? Column(
                          children: [
Semantics(
                               label: 'Diâmetro à altura do peito',
                               child: TextFormField(
                                 controller: _dapController,
                                 decoration: InputDecoration(
                                   labelText: 'DAP (cm) *',
                                   hintText: 'Diâmetro à altura do peito',
                                   prefixIcon: const Icon(Icons.straighten),
                                   suffixText: 'cm',
                                   border: OutlineInputBorder(
                                     borderRadius: BorderRadius.circular(12),
                                   ),
                                   helperText:
                                       'Obrigatório para plantas com altura ≥ 50cm',
                                 ),
                                 keyboardType: TextInputType.number,
                                 inputFormatters: [
                                   FilteringTextInputFormatter.allow(
                                       RegExp(r'[0-9.,]')),
                                 ],
                                 onChanged: (_) => _updateCategoria(),
                                 validator: (v) {
                                   if (!_mostrarDAP) return null;
                                   if (v == null || v.isEmpty) {
                                     return 'DAP obrigatório para altura ≥ 50cm';
                                   }
                                   final val =
                                       double.tryParse(v.replaceAll(',', '.'));
                                   if (val == null || val <= 0) {
                                     return 'Valor inválido';
                                   }
                                   return null;
                                 },
                                 textInputAction: TextInputAction.done,
                               ),
                             ),
                            const SizedBox(height: 16),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              // Categoria DEPOIS de altura/DAP (é derivada deles) e
              // DISCRETA: linha de texto pequena + escape manual compacto.
              const SizedBox(height: 4),
              Text(
                _categoriaManual
                    ? 'Categoria: ${_categoriaManualSelecionada != null ? rotuloChipCategoria(_categoriaManualSelecionada!) : '—'}'
                    : (_categoria > 0
                        ? 'Categoria calculada: ${rotuloChipCategoria(_categoria)}'
                        : 'Categoria: calculada pela altura/DAP'),
                style: TextStyle(
                  fontSize: AppTokens.fontCaption,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Semantics(
                label: 'Selecionar categoria manualmente',
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: Text(
                    'Quero apenas selecionar a categoria',
                    style: TextStyle(fontSize: AppTokens.fontSmall),
                  ),
                  value: _categoriaManual,
                  onChanged: (val) {
                    setState(() {
                      _categoriaManual = val ?? false;
                      if (!_categoriaManual) _categoriaManualSelecionada = null;
                    });
                  },
                ),
              ),
              if (_categoriaManual)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Selecione a categoria',
                      isDense: true,
                    ),
                    value: _categoriaManualSelecionada,
                    items: [1, 2, 3]
                        .map((cat) => DropdownMenuItem(
                              value: cat,
                              child: Text('Categoria $cat'),
                            ))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _categoriaManualSelecionada = val;
                      });
                    },
                    validator: (v) {
                      if (v == null) return 'Selecione a categoria';
                      return null;
                    },
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                _fotoObrigatoria
                    ? 'Foto da Espécie (obrigatória) *'
                    : 'Foto da Espécie (opcional)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              if (_fotoPath != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ImageService.buildImage(
                        _fotoPath!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        cacheWidth: kIsWeb ? null : 600,
                      ),
                    ),
                    // >>> t9 S1: badge se a foto salva desta planta está ausente
                    if (_fotoPath == widget.existingPlanta?.fotoEspeciePath &&
                        (widget.existingPlanta?.fotoAusente ?? false))
                      const ArquivoAusenteBadge(),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: Icon(Icons.cancel, color: Theme.of(context).colorScheme.error),
                        onPressed: () {
                          setState(() => _fotoPath = null);
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Semantics(
                  label: 'Tirar foto da planta',
                  button: true,
                  child: InkWell(
                    onTap: _tirarFoto,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _fotoObrigatoria
                              ? Theme.of(context).colorScheme.tertiary
                              : Theme.of(context).colorScheme.outlineVariant,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: _fotoObrigatoria
                            ? Theme.of(context).colorScheme.tertiaryContainer
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo,
                            size: 40,
                            color: _fotoObrigatoria
                                ? Theme.of(context).colorScheme.tertiary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tirar foto da planta',
                            style: TextStyle(
                              color: _fotoObrigatoria
                                  ? Theme.of(context).colorScheme.onTertiaryContainer
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 32),
              Semantics(
                label: 'Salvar planta',
                button: true,
      child: FilledButton.icon(
        onPressed: _isSaving ? null : _salvarPlanta,
        icon: _isSaving
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
            : const Icon(Icons.check),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _isEditing ? 'Atualizar Planta' : 'Adicionar Planta',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _tirarFoto() async {
    final picker = ImagePicker();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Câmera'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Galeria'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    );

    if (source == null) return;

    final photo = await picker.pickImage(
      source: source,
      // D-1 (decisão do Badger): o ORIGINAL sobe — sem re-encodar no picker.
    );

    if (photo != null) {
      // >>> t14 S3: inicio — original preservado (D-1) + hash na origem
      final salvo = await ImageService.salvarOriginalComMetadados(photo.path);
      setState(() => _fotoPath = salvo.caminho);
      _fotoSha256 = salvo.sha256;
      _fotoBytes = salvo.bytes;
      // <<< t14 S3: fim
    }
  }

  Future<void> _salvarPlanta() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    if (_fotoObrigatoria && _fotoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Foto obrigatória para espécie NI (não identificada)',
              style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (_fotoObrigatoria && _fotoPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Foto obrigatória para espécie NI (não identificada)',
            ),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      double altura = 0;
      double? dap;
      int cat = 0;
      if (_categoriaManual) {
        cat = _categoriaManualSelecionada ?? 0;
      } else {
        altura = double.parse(_alturaController.text.replaceAll(',', '.'));
        dap = _mostrarDAP
            ? double.tryParse(_dapController.text.replaceAll(',', '.'))
            : null;
        cat = calcularCategoria(altura, dap);
      }

      // v28 MRV: dono da medição (pitch: "cada medição tem ... dono")
      final autor = context.read<SyncService>().currentUser?.uuid;
      final companion = PlantasCompanion(
        uuid: drift.Value(_currentUuid!),
        parcelaUuid: drift.Value(widget.parcelaUuid),
        especie: drift.Value(_especieController.text.trim()),
        alturaCm: drift.Value(altura),
        dapCm: drift.Value(dap),
        categoria: drift.Value(cat),
        fotoEspeciePath: drift.Value(_fotoPath),
        synced: const drift.Value(false),
        updatedAt: drift.Value(DateTime.now()),
        autorUuid: _isEditing
            ? const drift.Value.absent()
            : drift.Value(autor),
      );

      if (_isEditing) {
        await _db.updatePlanta(companion, _currentUuid!);
        await _db.logAudit('update', entityType: 'planta', entityUuid: _currentUuid!, newValue: 'updated');
      } else {
        await _db.insertPlanta(companion);
        await _db.logAudit('create', entityType: 'planta', entityUuid: _currentUuid!, newValue: 'created');
      }

      if (_fotoPath != null) {
        final ativoUuid = 'legado-ativo-$_currentUuid';
        await _db.registrarFotoCatalogo(
          objetoUuid: _currentUuid!,
          entidadeTipo: 'planta',
          entidadeUuid: _currentUuid!,
          caminhoOriginal: _fotoPath!,
          capturadoEm: DateTime.now(),
        );
        if (_fotoSha256 != null) {
          await _db.registrarHashDoAtivo(
            ativoUuid: ativoUuid,
            sha256: _fotoSha256!,
            bytes: _fotoBytes,
            papel: 'bruto',
          );
        }
      }

      final planta = Planta(
        id: 0,
        uuid: _currentUuid!,
        parcelaUuid: widget.parcelaUuid,
        especie: _especieController.text.trim(),
        alturaCm: altura,
        dapCm: dap,
        categoria: cat,
        fotoEspeciePath: _fotoPath,
        synced: false,
        createdAt: _isEditing && widget.existingPlanta != null
            ? widget.existingPlanta!.createdAt
            : DateTime.now(),
        updatedAt: DateTime.now(),
        fotoAusente: false,
      );

      if (mounted) {
        Navigator.of(context).pop(planta);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e',
            style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Tentar novamente',
              textColor: Theme.of(context).colorScheme.onErrorContainer,
              onPressed: () => _salvarPlanta(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
