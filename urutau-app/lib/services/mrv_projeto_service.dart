import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import 'clock_service.dart';

/// Fase 10 — gestão do projeto MRV no app (admin/verificador):
/// RT-04 (baseline/adicionalidade), RS-04/RS-05 (desenho amostral com
/// metas de erro e estratos), RT-02 (campanhas de revisita), RG-03
/// (verificação interna) e RG-06 (resolução de incidentes — libera crédito).
///
/// Tudo que muda aqui passa pela trilha de auditoria (hash encadeado).
class MrvProjetoService {
  // ── RT-04: projeto com baseline e adicionalidade documentados ──────
  static Future<void> salvarProjeto(
    AppDatabase db,
    String projetoUuid, {
    String? nome,
    String? codigo,
    String? modalidade,
    String? organizacao,
    String? padraoCredito,
    String? metodologiaRef,
    double? areaTotalHa,
    String? bioma,
    String? regiao,
    String? baselineRef, // JSON
    String? adicionalidadeRef, // JSON
    String? notas,
    String? status,
  }) async {
    final existente = await (db.select(db.projetosMrv)
          ..where((t) => t.uuid.equals(projetoUuid)))
        .getSingleOrNull();
    if (existente == null) throw Exception('Projeto não encontrado: $projetoUuid');

    await (db.update(db.projetosMrv)..where((t) => t.uuid.equals(projetoUuid)))
        .write(ProjetosMrvCompanion(
      nome: drift.Value(nome ?? existente.nome),
      codigo: drift.Value(codigo ?? existente.codigo),
      modalidade: drift.Value(modalidade ?? existente.modalidade),
      organizacao: drift.Value(organizacao ?? existente.organizacao),
      padraoCredito: drift.Value(padraoCredito ?? existente.padraoCredito),
      metodologiaRef: drift.Value(metodologiaRef ?? existente.metodologiaRef),
      areaTotalHa: drift.Value(areaTotalHa ?? existente.areaTotalHa),
      bioma: drift.Value(bioma ?? existente.bioma),
      regiao: drift.Value(regiao ?? existente.regiao),
      baselineRef: drift.Value(baselineRef ?? existente.baselineRef), // RT-04
      adicionalidadeRef:
          drift.Value(adicionalidadeRef ?? existente.adicionalidadeRef), // RT-04
      notas: drift.Value(notas ?? existente.notas),
      status: drift.Value(status ?? existente.status),
      updatedAt: drift.Value(DateTime.now()),
    ));
    await db.logTrilha(
      acao: 'update_projeto_mrv',
      entidadeTipo: 'projeto_mrv',
      entidadeUuid: projetoUuid,
      depois: jsonEncode({
        if (baselineRef != null) 'baselineRef': baselineRef,
        if (adicionalidadeRef != null) 'adicionalidadeRef': adicionalidadeRef,
        if (status != null) 'status': status,
      }),
      origem: 'app',
    );
  }

  // ── RS-04/RS-05: desenho amostral com meta de erro + estratos ───────
  static Future<String> salvarDesenhoAmostral(
    AppDatabase db,
    String escopoUuid, {
    String escopoTipo = 'projeto',
    double? areaParcelaM2,
    String? forma,
    double? raioM,
    String? dimensoesM, // JSON
    double? densidadeParcelasHa,
    double? percentualAmostrado,
    String? criterioPosicionamento,
    int? nParcelasPrevistas,
    String? estratos, // JSON — RS-05
    String? incertezaAlvo, // JSON — RS-04 (ex.: {"altura_rmse_cm": 8, "biomassa_pct": 12})
    String? observacoes,
  }) async {
    final existente = await (db.select(db.desenhoAmostral)
          ..where((t) =>
              t.escopoTipo.equals(escopoTipo) & t.escopoUuid.equals(escopoUuid)))
        .getSingleOrNull();

    if (existente == null) {
      final uuid = const Uuid().v4();
      await db.into(db.desenhoAmostral).insert(DesenhoAmostralCompanion.insert(
            uuid: uuid,
            escopoTipo: escopoTipo,
            escopoUuid: escopoUuid,
            areaParcelaM2: drift.Value(areaParcelaM2),
            forma: drift.Value(forma),
            raioM: drift.Value(raioM),
            dimensoesM: drift.Value(dimensoesM),
            densidadeParcelasHa: drift.Value(densidadeParcelasHa),
            percentualAmostrado: drift.Value(percentualAmostrado),
            criterioPosicionamento: drift.Value(criterioPosicionamento),
            nParcelasPrevistas: drift.Value(nParcelasPrevistas),
            estratos: drift.Value(estratos), // RS-05
            incertezaAlvo: drift.Value(incertezaAlvo), // RS-04
            observacoes: drift.Value(observacoes),
          ));
      await db.logTrilha(
        acao: 'create_desenho_amostral',
        entidadeTipo: 'desenho_amostral',
        entidadeUuid: uuid,
        origem: 'app',
      );
      return uuid;
    }

    await (db.update(db.desenhoAmostral)
          ..where((t) => t.uuid.equals(existente.uuid)))
        .write(DesenhoAmostralCompanion(
      areaParcelaM2: drift.Value(areaParcelaM2 ?? existente.areaParcelaM2),
      forma: drift.Value(forma ?? existente.forma),
      raioM: drift.Value(raioM ?? existente.raioM),
      dimensoesM: drift.Value(dimensoesM ?? existente.dimensoesM),
      densidadeParcelasHa:
          drift.Value(densidadeParcelasHa ?? existente.densidadeParcelasHa),
      percentualAmostrado:
          drift.Value(percentualAmostrado ?? existente.percentualAmostrado),
      criterioPosicionamento: drift.Value(
          criterioPosicionamento ?? existente.criterioPosicionamento),
      nParcelasPrevistas:
          drift.Value(nParcelasPrevistas ?? existente.nParcelasPrevistas),
      estratos: drift.Value(estratos ?? existente.estratos), // RS-05
      incertezaAlvo: drift.Value(incertezaAlvo ?? existente.incertezaAlvo), // RS-04
      observacoes: drift.Value(observacoes ?? existente.observacoes),
      updatedAt: drift.Value(DateTime.now()),
    ));
    await db.logTrilha(
      acao: 'update_desenho_amostral',
      entidadeTipo: 'desenho_amostral',
      entidadeUuid: existente.uuid,
      origem: 'app',
    );
    return existente.uuid;
  }

  // ── RT-02: campanha de revisita vinculada a projeto + período ───────
  static Future<String> criarCampanha(
    AppDatabase db, {
    required String projetoUuid,
    required String periodoUuid,
    required String nome,
    String? dataInicio,
    String? dataFim,
    String? responsavelUuid,
    String? protocoloUuid,
  }) async {
    final uuid = const Uuid().v4();
    await db.into(db.campanhas).insert(CampanhasCompanion.insert(
          uuid: uuid,
          projetoUuid: projetoUuid,
          periodoUuid: periodoUuid,
          nome: nome,
          dataInicio: drift.Value(dataInicio),
          dataFim: drift.Value(dataFim),
          responsavelUuid: drift.Value(responsavelUuid),
          protocoloUuid: drift.Value(protocoloUuid ?? 'SOP-MRV-V1'),
          status: const drift.Value('planejada'),
        ));
    await db.logTrilha(
      acao: 'create_campanha_revisita',
      entidadeTipo: 'campanha',
      entidadeUuid: uuid,
      depois: jsonEncode({'nome': nome, 'periodoUuid': periodoUuid}),
      origem: 'app',
    );
    return uuid;
  }

  static Future<List<Campanha>> listarCampanhas(
      AppDatabase db, String projetoUuid) async {
    return (db.select(db.campanhas)
          ..where((t) =>
              t.projetoUuid.equals(projetoUuid) & t.deletedAt.isNull())
          ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  // ── RG-06: resolver incidente → libera crédito ──────────────────────
  static Future<void> resolverIncidente(
    AppDatabase db,
    String incidenteUuid,
    String resolucao,
    String usuarioUuid,
  ) async {
    final agora = await ClockService.agoraConfiavel();
    await (db.update(db.incidentes)..where((t) => t.uuid.equals(incidenteUuid)))
        .write(IncidentesCompanion(
      resolucao: drift.Value(resolucao),
      resolvidoEm: drift.Value(agora),
      updatedAt: drift.Value(DateTime.now()),
    ));
    await db.logTrilha(
      acao: 'incidente_resolvido',
      entidadeTipo: 'incidente',
      entidadeUuid: incidenteUuid,
      depois: resolucao,
      usuarioUuid: usuarioUuid,
      origem: 'app',
    );
  }

  // ── RG-03: verificação interna (re-amostragem por supervisor) ───────
  static Future<String> registrarVerificacaoInterna(
    AppDatabase db, {
    required String amostraOriginalUuid,
    required String amostraVerificacaoUuid,
    String? verificadorUuid,
    required String conclusao, // conforme | divergente | inconclusiva
    String? divergencias, // JSON
    String? observacoes,
  }) async {
    final uuid = const Uuid().v4();
    await db.into(db.verificacoesInternas).insert(VerificacoesInternasCompanion.insert(
          uuid: uuid,
          amostraOriginalUuid: amostraOriginalUuid,
          amostraVerificacaoUuid: amostraVerificacaoUuid,
          verificadorUuid: drift.Value(verificadorUuid),
          conclusao: drift.Value(conclusao),
          divergencias: drift.Value(divergencias),
          observacoes: drift.Value(observacoes),
        ));
    await db.logTrilha(
      acao: 'verificacao_interna',
      entidadeTipo: 'verificacao_interna',
      entidadeUuid: uuid,
      depois: jsonEncode({
        'conclusao': conclusao,
        'amostraOriginalUuid': amostraOriginalUuid,
        'amostraVerificacaoUuid': amostraVerificacaoUuid,
      }),
      usuarioUuid: verificadorUuid,
      origem: 'app',
    );
    // divergente abre incidente bloqueador GLOBAL (RG-06) — crédito trava
    // ate resolver (entidadeUuid null = vale para qualquer entidade)
    if (conclusao == 'divergente') {
      await db.into(db.incidentes).insert(IncidentesCompanion.insert(
            uuid: const Uuid().v4(),
            tipo: 'verificacao_interna_divergente',
            entidadeTipo: const drift.Value('verificacao_interna'),
            severidade: 'bloqueadora',
            bloqueiaUsoParaCredito: const drift.Value(true),
            descricao: drift.Value(
                'verificação interna divergente na amostra $amostraOriginalUuid: ${divergencias ?? ''}'),
          ));
    }
    return uuid;
  }
}
