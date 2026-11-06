import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;

import '../data/database.dart';
import '../services/mrv_projeto_service.dart';
import '../services/sync_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/urutau_section_card.dart';

/// Fase 10 — painel do Projeto MRV (admin/verificador):
/// RT-04 baseline/adicionalidade · RS-04/RS-05 desenho amostral ·
/// RT-02 campanhas de revisita · RG-03 verificação interna · RG-06 incidentes.
/// Toda escrita passa por MrvProjetoService, que loga na trilha de auditoria.
class MrvProjetoScreen extends StatefulWidget {
  const MrvProjetoScreen({super.key});

  @override
  State<MrvProjetoScreen> createState() => _MrvProjetoScreenState();
}

class _MrvProjetoScreenState extends State<MrvProjetoScreen> {
  late AppDatabase _db;
  List<ProjetosMrvData> _projetos = [];
  String? _projetoUuid;

  // RT-04
  final _nomeController = TextEditingController();
  final _codigoController = TextEditingController();
  final _baselineController = TextEditingController();
  final _adicionalidadeController = TextEditingController();
  final _notasController = TextEditingController();

  // RS-04/RS-05
  final _areaParcelaController = TextEditingController();
  final _densidadeController = TextEditingController();
  final _pctAmostradoController = TextEditingController();
  final _nPrevistasController = TextEditingController();
  final _estratosController = TextEditingController();
  final _incertezaController = TextEditingController();

  // RT-02
  List<PeriodosMonitoramentoData> _periodos = [];
  String? _periodoCampanhaUuid;
  final _campanhaNomeController = TextEditingController();
  List<Campanha> _campanhas = [];

  // RG-06
  List<Incidente> _incidentesAbertos = [];

  // RG-03
  final _amostraOriginalController = TextEditingController();
  final _amostraVerifController = TextEditingController();
  final _divergenciasController = TextEditingController();
  String _conclusao = 'conforme';

  // RT-03
  String _riscoReversao = 'baixo';
  final _fonteFogoController = TextEditingController();

  // RG-05
  final _treinamentoTipoController = TextEditingController();
  final _treinamentoValidadeController = TextEditingController();
  List<Competencia> _competencias = [];

  bool _carregando = true;
  String? _mensagem;

  @override
  void initState() {
    super.initState();
    _db = context.read<AppDatabase>();
    _carregar();
  }

  @override
  void dispose() {
    for (final c in [
      _nomeController, _codigoController, _baselineController,
      _adicionalidadeController, _notasController, _areaParcelaController,
      _densidadeController, _pctAmostradoController, _nPrevistasController,
      _estratosController, _incertezaController, _campanhaNomeController,
      _amostraOriginalController, _amostraVerifController,
      _divergenciasController, _fonteFogoController,
      _treinamentoTipoController, _treinamentoValidadeController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    _projetos = await _db.select(_db.projetosMrv).get();
    _projetoUuid ??= _projetos.isNotEmpty ? _projetos.first.uuid : null;
    await _carregarProjeto();
    setState(() => _carregando = false);
  }

  Future<void> _carregarProjeto() async {
    final p = _projetoUuid;
    if (p == null) return;
    final proj = await (db_selectProjeto(p));
    if (proj != null) {
      _nomeController.text = proj.nome;
      _codigoController.text = proj.codigo;
      _baselineController.text = proj.baselineRef ?? '';
      _adicionalidadeController.text = proj.adicionalidadeRef ?? '';
      _notasController.text = proj.notas ?? '';
    }
    final desenho = await (_db.select(_db.desenhoAmostral)
          ..where((t) =>
              t.escopoTipo.equals('projeto') & t.escopoUuid.equals(p)))
        .getSingleOrNull();
    _areaParcelaController.text = desenho?.areaParcelaM2?.toString() ?? '';
    _densidadeController.text =
        desenho?.densidadeParcelasHa?.toString() ?? '';
    _pctAmostradoController.text =
        desenho?.percentualAmostrado?.toString() ?? '';
    _nPrevistasController.text =
        desenho?.nParcelasPrevistas?.toString() ?? '';
    _estratosController.text = desenho?.estratos ?? '';
    _incertezaController.text = desenho?.incertezaAlvo ?? '';

    _periodos = await (_db.select(_db.periodosMonitoramento)
          ..where((t) => t.projetoUuid.equals(p)))
        .get();
    _periodoCampanhaUuid ??=
        _periodos.isNotEmpty ? _periodos.first.uuid : null;
    _campanhas = await MrvProjetoService.listarCampanhas(_db, p);
    // todos os abertos (globais entidade=null + do projeto)
    _incidentesAbertos = await (_db.select(_db.incidentes)
          ..where((t) => t.resolvidoEm.isNull()))
        .get();
    // RT-03
    _riscoReversao = proj?.riscoReversao ?? 'baixo';
    _fonteFogoController.text = proj?.fonteFogoHistorico ?? '';
    // RG-05
    _competencias = await MrvProjetoService.todasCompetencias(_db);
  }

  Future<ProjetosMrvData?> db_selectProjeto(String uuid) {
    return (_db.select(_db.projetosMrv)..where((t) => t.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  Future<void> _salvarProjeto() async {
    final p = _projetoUuid;
    if (p == null) return;
    await MrvProjetoService.salvarProjeto(
      _db,
      p,
      nome: _nomeController.text.trim(),
      codigo: _codigoController.text.trim(),
      baselineRef: _baselineController.text.trim().isEmpty
          ? null
          : _baselineController.text.trim(),
      adicionalidadeRef: _adicionalidadeController.text.trim().isEmpty
          ? null
          : _adicionalidadeController.text.trim(),
      notas: _notasController.text.trim().isEmpty
          ? null
          : _notasController.text.trim(),
    );
    setState(() => _mensagem = 'Projeto salvo (trilha registrada).');
  }

  Future<void> _salvarDesenho() async {
    final p = _projetoUuid;
    if (p == null) return;
    double? _d(String s) =>
        s.trim().isEmpty ? null : double.tryParse(s.trim().replaceAll(',', '.'));
    await MrvProjetoService.salvarDesenhoAmostral(
      _db,
      p,
      areaParcelaM2: _d(_areaParcelaController.text),
      forma: 'retangular',
      dimensoesM: _areaParcelaController.text.trim().isEmpty
          ? null
          : jsonEncode({'largura': 20, 'comprimento': 20}),
      densidadeParcelasHa: _d(_densidadeController.text),
      percentualAmostrado: _d(_pctAmostradoController.text),
      nParcelasPrevistas: int.tryParse(_nPrevistasController.text.trim()),
      estratos: _estratosController.text.trim().isEmpty
          ? null
          : _estratosController.text.trim(),
      incertezaAlvo: _incertezaController.text.trim().isEmpty
          ? null
          : _incertezaController.text.trim(),
    );
    setState(() => _mensagem = 'Desenho amostral salvo (trilha registrada).');
  }

  Future<void> _criarCampanha() async {
    final p = _projetoUuid;
    final per = _periodoCampanhaUuid;
    final nome = _campanhaNomeController.text.trim();
    if (p == null || per == null || nome.isEmpty) {
      setState(() => _mensagem = 'Informe projeto, período e nome da campanha.');
      return;
    }
    final user = context.read<SyncService>().currentUser;
    await MrvProjetoService.criarCampanha(
      _db,
      projetoUuid: p,
      periodoUuid: per,
      nome: nome,
      responsavelUuid: user?.uuid,
    );
    _campanhaNomeController.clear();
    await _carregarProjeto();
    setState(() => _mensagem = 'Campanha de revisita criada (trilha registrada).');
  }

  Future<void> _resolverIncidente(Incidente inc) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resolver incidente'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Resolução (o que foi feito)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Resolver')),
        ],
      ),
    );
    if (ok != true) return;
    final user = context.read<SyncService>().currentUser;
    await MrvProjetoService.resolverIncidente(
        _db, inc.uuid, controller.text.trim(), user?.uuid ?? 'desconhecido');
    await _carregarProjeto();
    setState(() => _mensagem =
        'Incidente resolvido — crédito liberado (trilha registrada).');
  }

  Future<void> _salvarRisco() async {
    final p = _projetoUuid;
    if (p == null) return;
    await MrvProjetoService.salvarRiscoReversao(
      _db,
      p,
      risco: _riscoReversao,
      fonteFogoHistorico: _fonteFogoController.text.trim().isEmpty
          ? null
          : _fonteFogoController.text.trim(),
    );
    setState(() => _mensagem = 'Risco de reversão salvo (trilha registrada).');
  }

  Future<void> _registrarCompetencia() async {
    final tipo = _treinamentoTipoController.text.trim();
    if (tipo.isEmpty) {
      setState(() => _mensagem = 'Informe o tipo de treinamento.');
      return;
    }
    final user = context.read<SyncService>().currentUser;
    await MrvProjetoService.registrarCompetencia(
      _db,
      usuarioUuid: user?.uuid ?? 'desconhecido',
      tipoTreinamento: tipo,
      validoAte: _treinamentoValidadeController.text.trim().isEmpty
          ? null
          : _treinamentoValidadeController.text.trim(),
    );
    _treinamentoTipoController.clear();
    _treinamentoValidadeController.clear();
    await _carregarProjeto();
    setState(() => _mensagem = 'Competência registrada (trilha registrada).');
  }

  Future<void> _registrarVerificacao() async {
    final orig = _amostraOriginalController.text.trim();
    final ver = _amostraVerifController.text.trim();
    if (orig.isEmpty || ver.isEmpty) {
      setState(() => _mensagem = 'Informe as duas amostras (original e verificação).');
      return;
    }
    final user = context.read<SyncService>().currentUser;
    await MrvProjetoService.registrarVerificacaoInterna(
      _db,
      amostraOriginalUuid: orig,
      amostraVerificacaoUuid: ver,
      verificadorUuid: user?.uuid,
      conclusao: _conclusao,
      divergencias: _divergenciasController.text.trim().isEmpty
          ? null
          : _divergenciasController.text.trim(),
    );
    _amostraOriginalController.clear();
    _amostraVerifController.clear();
    _divergenciasController.clear();
    await _carregarProjeto();
    setState(() => _mensagem = _conclusao == 'divergente'
        ? 'Verificação DIVERGENTE registrada — incidente bloqueador aberto, crédito travado.'
        : 'Verificação interna registrada (trilha registrada).');
  }

  InputDecoration _dec(String label, String hint) => InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projeto MRV')),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carregar,
              child: ListView(
                padding: const EdgeInsets.all(AppTokens.spaceL),
                children: [
                  if (_mensagem != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTokens.mrvGreenBg,
                        borderRadius: BorderRadius.circular(AppTokens.radiusM),
                      ),
                      child: Text(_mensagem!),
                    ),
                  ],
                  DropdownButtonFormField<String>(
                    value: _projetoUuid,
                    isExpanded: true,
                    decoration: _dec('Projeto', ''),
                    items: _projetos
                        .map((p) => DropdownMenuItem(
                              value: p.uuid,
                              child: Text('${p.nome} (${p.codigo})',
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) async {
                      setState(() => _projetoUuid = v);
                      await _carregarProjeto();
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── RT-04 ──
                  UrutauSectionCard(
                    icon: Icons.eco,
                    title: 'Projeto (RT-04: baseline + adicionalidade)',
                    child: Column(
                      children: [
                        TextField(
                            controller: _nomeController,
                            decoration: _dec('Nome', 'ex: Fazenda Modelo')),
                        const SizedBox(height: 8),
                        TextField(
                            controller: _codigoController,
                            decoration: _dec('Código', 'ex: PRJ-001')),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _baselineController,
                          maxLines: 2,
                          decoration: _dec('Baseline (JSON)',
                              '{"tipo":"historico","fonte":"..."}'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _adicionalidadeController,
                          maxLines: 2,
                          decoration: _dec('Adicionalidade (JSON)',
                              '{"teste":"legal","evidencia":"..."}'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _notasController,
                          maxLines: 2,
                          decoration: _dec('Notas', ''),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _salvarProjeto,
                            icon: const Icon(Icons.save),
                            label: const Text('Salvar projeto'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── RS-04/RS-05 ──
                  UrutauSectionCard(
                    icon: Icons.grid_on,
                    title: 'Desenho amostral (RS-04 meta de erro · RS-05 estratos)',
                    child: Column(
                      children: [
                        Row(children: [
                          Expanded(
                              child: TextField(
                                  controller: _areaParcelaController,
                                  keyboardType: TextInputType.number,
                                  decoration:
                                      _dec('Área parcela m²', '400'))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: TextField(
                                  controller: _densidadeController,
                                  keyboardType: TextInputType.number,
                                  decoration:
                                      _dec('Densidade parc/ha', '1.0'))),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                              child: TextField(
                                  controller: _pctAmostradoController,
                                  keyboardType: TextInputType.number,
                                  decoration: _dec('% amostrado', '5.0'))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: TextField(
                                  controller: _nPrevistasController,
                                  keyboardType: TextInputType.number,
                                  decoration:
                                      _dec('Nº parcelas previstas', '40'))),
                        ]),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _estratosController,
                          decoration: _dec('Estratos (JSON lista)',
                              '["UT-01","UT-02","idade_5a"]'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _incertezaController,
                          decoration: _dec('Incerteza alvo (JSON)',
                              '{"altura_rmse_cm":8,"biomassa_pct":12}'),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _salvarDesenho,
                            icon: const Icon(Icons.save),
                            label: const Text('Salvar desenho amostral'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── RT-02 ──
                  UrutauSectionCard(
                    icon: Icons.calendar_month,
                    title: 'Campanhas de revisita (RT-02)',
                    child: Column(
                      children: [
                        ..._campanhas.map((c) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.calendar_month),
                              title: Text(c.nome),
                              subtitle: Text(
                                  '${c.status} · período ${c.periodoUuid.substring(0, 8)}…'),
                            )),
                        Row(children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _periodoCampanhaUuid,
                              isExpanded: true,
                              decoration: _dec('Período', ''),
                              items: _periodos
                                  .map((p) => DropdownMenuItem(
                                        value: p.uuid,
                                        child: Text(p.codigo,
                                            overflow: TextOverflow.ellipsis),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(
                                  () => _periodoCampanhaUuid = v),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                                controller: _campanhaNomeController,
                                decoration: _dec('Nome', 'Revisita 2026')),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _criarCampanha,
                            icon: const Icon(Icons.add_circle),
                            tooltip: 'Criar campanha',
                          ),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── RG-06 ──
                  UrutauSectionCard(
                    icon: Icons.warning,
                    title: 'Incidentes abertos (RG-06)',
                    child: _incidentesAbertos.isEmpty
                        ? const Text('Nenhum incidente aberto. Crédito liberado.')
                        : Column(
                            children: _incidentesAbertos
                                .map((i) => ListTile(
                                      dense: true,
                                      leading: Icon(
                                        Icons.warning,
                                        color: i.bloqueiaUsoParaCredito
                                            ? AppTokens.danger
                                            : AppTokens.warning,
                                      ),
                                      title: Text(i.tipo ?? i.uuid),
                                      subtitle: Text(
                                          '${i.severidade} · ${i.bloqueiaUsoParaCredito ? 'BLOQUEIA CRÉDITO' : 'não bloqueia'}'),
                                      trailing: TextButton(
                                        onPressed: () => _resolverIncidente(i),
                                        child: const Text('Resolver'),
                                      ),
                                    ))
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // ── RT-03 (P2) ──
                  UrutauSectionCard(
                    icon: Icons.local_fire_department,
                    title: 'Risco de reversão (RT-03) — fonte: ULTRA/satélite',
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: _riscoReversao,
                          decoration: _dec('Risco de reversão', ''),
                          items: const [
                            DropdownMenuItem(
                                value: 'baixo', child: Text('baixo')),
                            DropdownMenuItem(
                                value: 'medio', child: Text('médio')),
                            DropdownMenuItem(
                                value: 'alto', child: Text('alto')),
                          ],
                          onChanged: (v) =>
                              setState(() => _riscoReversao = v ?? 'baixo'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _fonteFogoController,
                          decoration: _dec('Fonte histórico de fogo',
                              'ex: alerta satelite 2026-08, ULTRA run #12'),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _salvarRisco,
                            icon: const Icon(Icons.save),
                            label: const Text('Salvar risco de reversão'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── RG-05 (P2) ──
                  UrutauSectionCard(
                    icon: Icons.school,
                    title: 'Competências / treinamento (RG-05)',
                    child: Column(
                      children: [
                        ..._competencias.map((c) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.badge),
                              title: Text(c.tipoTreinamento),
                              subtitle: Text(
                                  'validade: ${c.validoAte ?? 'sem limite'} · usuário ${c.usuarioUuid.substring(0, 8)}…'),
                            )),
                        Row(children: [
                          Expanded(
                            child: TextField(
                                controller: _treinamentoTipoController,
                                decoration: _dec(
                                    'Tipo', 'ex: SOP-MRV-V1 campo')),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                                controller: _treinamentoValidadeController,
                                decoration: _dec(
                                    'Válido até', 'AAAA-MM-DD')),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _registrarCompetencia,
                            icon: const Icon(Icons.add_circle),
                            tooltip: 'Registrar compétence',
                          ),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── RG-03 ──
                  UrutauSectionCard(
                    icon: Icons.fact_check,
                    title: 'Verificação interna (RG-03: re-amostragem)',
                    child: Column(
                      children: [
                        TextField(
                            controller: _amostraOriginalController,
                            decoration: _dec(
                                'Amostra original (uuid)', 'legado-amostra-…')),
                        const SizedBox(height: 8),
                        TextField(
                            controller: _amostraVerifController,
                            decoration: _dec(
                                'Amostra de verificação (uuid)', '')),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _conclusao,
                          decoration: _dec('Conclusão', ''),
                          items: const [
                            DropdownMenuItem(
                                value: 'conforme', child: Text('conforme')),
                            DropdownMenuItem(
                                value: 'divergente',
                                child: Text('divergente (trava crédito)')),
                            DropdownMenuItem(
                                value: 'inconclusiva',
                                child: Text('inconclusiva')),
                          ],
                          onChanged: (v) =>
                              setState(() => _conclusao = v ?? 'conforme'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _divergenciasController,
                          maxLines: 2,
                          decoration: _dec('Divergências (JSON)', ''),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _registrarVerificacao,
                            icon: const Icon(Icons.fact_check),
                            label: const Text('Registrar verificação'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
