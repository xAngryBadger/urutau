import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' as drift;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../data/database.dart';
import '../data/categoria_helper.dart';
import '../data/especie_item.dart';
import '../services/image_service.dart';
import '../services/species_service.dart';

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
  bool _isEditing = false;
  String? _currentUuid;

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
        });
      }
    });
    _especieFocusNode.addListener(() {
      if (!_especieFocusNode.hasFocus) setState(() => _showSpeciesList = false);
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
    final categoriaColors = {
      0: Colors.grey,
      1: Colors.blue,
      2: Colors.orange,
      3: Colors.green,
    };
    final color = categoriaColors[_categoria] ?? Colors.grey;

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
              if (_categoriaManual)
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: categoriaColors[_categoriaManualSelecionada ?? 0]
                            ?.withAlpha(30) ??
                        Colors.grey.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: categoriaColors[_categoriaManualSelecionada ?? 0]
                                ?.withAlpha(80) ??
                            Colors.grey.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.category,
                          color: categoriaColors[
                                  _categoriaManualSelecionada ?? 0] ??
                              Colors.grey),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Categoria ${_categoriaManualSelecionada ?? '-'}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: categoriaColors[
                                        _categoriaManualSelecionada ?? 0] ??
                                    Colors.grey,
                              ),
                            ),
                            if (_categoriaManualSelecionada != null)
                              Text(
                                descricaoCategoria(
                                    _categoriaManualSelecionada!),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: categoriaColors[
                                              _categoriaManualSelecionada ?? 0]
                                          ?.withAlpha(200) ??
                                      Colors.grey.withAlpha(200),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else if (_categoria > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.category, color: color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Categoria $_categoria',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                            Text(
                              descricaoCategoria(_categoria),
                              style: TextStyle(
                                fontSize: 13,
                                color: color.withAlpha(200),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              Semantics(
                label: 'Selecionar categoria manualmente',
                child: CheckboxListTile(
                  title: const Text('Quero apenas selecionar a categoria'),
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
                Semantics(
                  label: 'Selecione a categoria',
                  child: DropdownButtonFormField<int>(
                    decoration: InputDecoration(
                      labelText: 'Selecione a categoria',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
              const SizedBox(height: 24),
Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(Icons.eco, color: Colors.grey[700]),
          Text('Tipo de nome:',
              style: TextStyle(fontSize: 14, color: Colors.grey[700])),
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
                                color: Colors.orange[700]),
                          )
                        : null,
                  ),
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[a-zA-ZÀ-ÿ0-9\s\-]')),
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
                    if (_especieController.text.trim().isNotEmpty) {
                      setState(() {
                        _filteredSpecies = SpeciesService.filter(
                          _allSpecies,
                          _especieController.text,
                          _useNomePopular,
                        );
                        _showSpeciesList = true;
                      });
                    }
                  },
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe a espécie';
                    if (!RegExp(r'^[a-zA-ZÀ-ÿ0-9\s\-]+$').hasMatch(v)) {
                      return 'Apenas letras, números, espaços e hífens';
                    }
                    return null;
                  },
                ),
              ),
              if (_showSpeciesList && _filteredSpecies.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                                    fontSize: 12, color: Colors.grey[600]),
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
              if (_fotoObrigatoria) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.orange[700], size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Atenção: Foto obrigatória para identificação posterior.',
                          style: TextStyle(
                            color: Colors.orange[800],
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
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        )
                      : const SizedBox.shrink(),
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
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
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
                              ? Colors.orange[300]!
                              : Colors.grey[300]!,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: _fotoObrigatoria
                            ? Colors.orange[50]
                            : Colors.grey[50],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo,
                            size: 40,
                            color: _fotoObrigatoria
                                ? Colors.orange[400]
                                : Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tirar foto da planta',
                            style: TextStyle(
                              color: _fotoObrigatoria
                                  ? Colors.orange[600]
                                  : Colors.grey[500],
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
                  onPressed: _salvarPlanta,
                  icon: const Icon(Icons.check),
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
      imageQuality: 85,
      maxWidth: 2048,
    );

    if (photo != null) {
      final savedPath = await ImageService.savePhotoLocally(photo.path);
      setState(() => _fotoPath = savedPath);
    }
  }

  Future<void> _salvarPlanta() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fotoObrigatoria && _fotoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Foto obrigatória para espécie NI (não identificada)',
          ),
          backgroundColor: Colors.red,
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

    final companion = PlantasCompanion(
      uuid: drift.Value(_currentUuid!),
      parcelaUuid: drift.Value(widget.parcelaUuid),
      especie: drift.Value(_especieController.text.trim()),
      alturaCm: drift.Value(altura),
      dapCm: drift.Value(dap),
      categoria: drift.Value(cat),
      fotoEspeciePath: drift.Value(_fotoPath),
      synced: const drift.Value(false),
    );

    if (_isEditing) {
      await _db.updatePlanta(companion, _currentUuid!);
    } else {
      await _db.insertPlanta(companion);
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
    );

    if (mounted) {
      Navigator.of(context).pop(planta);
    }
  }
}
