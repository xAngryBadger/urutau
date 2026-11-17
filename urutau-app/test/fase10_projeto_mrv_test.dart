// Fase 10: RT-04/RS-04/RS-05/RT-02/RG-03/RG-06-resolucao
import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urutau/data/database.dart';
import 'package:urutau/services/mrv_projeto_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
  });
  tearDown(() => db.close());

  Future<String> _projetoSeed() async {
    await db.into(db.projetosMrv).insert(ProjetosMrvCompanion.insert(
          uuid: 'PROJ-1',
          codigo: 'PRJ-001',
          nome: 'Fazenda Modelo',
          modalidade: 'plantacao',
        ));
    return 'PROJ-1';
  }

  test('RT-04: salvar projeto grava baselineRef/adicionalidadeRef + trilha',
      () async {
    final proj = await _projetoSeed();
    await MrvProjetoService.salvarProjeto(
      db,
      proj,
      baselineRef: jsonEncode({'tipo': 'historico', 'fonte': 'inventario 2023'}),
      adicionalidadeRef:
          jsonEncode({'teste': 'legal', 'evidencia': 'plano de manejo'}),
      status: 'ativo',
    );
    final p = await (db.select(db.projetosMrv)
          ..where((t) => t.uuid.equals(proj)))
        .getSingle();
    expect(p.baselineRef, contains('inventario 2023'));
    expect(p.adicionalidadeRef, contains('plano de manejo'));
    expect(p.status, 'ativo');
    final trilha = await (db.select(db.trilhaAuditoria)).get();
    expect(trilha.any((t) => t.acao == 'update_projeto_mrv'), isTrue);
    expect(await db.verificarCadeiaAuditoria(), isNull);
  });

  test('RS-04/RS-05: desenho amostral upsert com meta de erro e estratos',
      () async {
    final proj = await _projetoSeed();
    final d1 = await MrvProjetoService.salvarDesenhoAmostral(
      db,
      proj,
      areaParcelaM2: 400,
      forma: 'retangular',
      dimensoesM: jsonEncode({'largura': 20, 'comprimento': 20}),
      densidadeParcelasHa: 1.0,
      percentualAmostrado: 5.0,
      nParcelasPrevistas: 40,
      estratos: jsonEncode(['UT-01', 'UT-02', 'idade_5a', 'idade_8a']),
      incertezaAlvo: jsonEncode({'altura_rmse_cm': 8.0, 'biomassa_pct': 12.0}),
    );
    final d2 = await MrvProjetoService.salvarDesenhoAmostral(
      db,
      proj,
      percentualAmostrado: 7.5, // muda só isso
    );
    expect(d1, d2); // upsert: mesma linha
    final todos = await (db.select(db.desenhoAmostral)).get();
    expect(todos, hasLength(1));
    expect(todos.first.percentualAmostrado, 7.5);
    expect(jsonDecode(todos.first.estratos!), hasLength(4)); // RS-05
    expect(jsonDecode(todos.first.incertezaAlvo!)['biomassa_pct'], 12.0); // RS-04
  });

  test('RT-02: campanha de revisita criada, listada e na trilha', () async {
    final proj = await _projetoSeed();
    await db.into(db.periodosMonitoramento).insert(
        PeriodosMonitoramentoCompanion.insert(
            uuid: 'PER-1', projetoUuid: proj, codigo: 'MON-2026', tipo: 'monitoramento'));
    final c = await MrvProjetoService.criarCampanha(
      db,
      projetoUuid: proj,
      periodoUuid: 'PER-1',
      nome: 'Revisita 2026',
      dataInicio: '2026-06-01',
      dataFim: '2026-06-30',
      responsavelUuid: 'u1',
    );
    final lista = await MrvProjetoService.listarCampanhas(db, proj);
    expect(lista, hasLength(1));
    expect(lista.first.uuid, c);
    expect(lista.first.nome, 'Revisita 2026');
    expect(lista.first.periodoUuid, 'PER-1');
    final trilha = await (db.select(db.trilhaAuditoria)).get();
    expect(trilha.any((t) => t.acao == 'create_campanha_revisita'), isTrue);
  });

  test('RG-06: resolver incidente libera o crédito de novo', () async {
    await db.insertParcela(ParcelasCompanion.insert(
      uuid: 'p1',
      propriedade: const drift.Value('Faz X'),
      propUt: 'UT-01',
      idParcela: 1,
      userId: 'u1',
    ));
    await db.into(db.incidentes).insert(IncidentesCompanion.insert(
      uuid: 'inc1',
      tipo: 'integridade_divergente',
      entidadeUuid: const drift.Value('p1'),
      severidade: 'bloqueadora',
      bloqueiaUsoParaCredito: const drift.Value(true),
    ));
    expect(await db.haIncidenteBloqueadorAberto('p1'), isTrue);

    await MrvProjetoService.resolverIncidente(db, 'inc1', 'arquivo restaurado do backup', 'admin1');
    expect(await db.haIncidenteBloqueadorAberto('p1'), isFalse);
    final inc = await (db.select(db.incidentes)).getSingle();
    expect(inc.resolvidoEm, isNotNull);
    expect(inc.resolucao, 'arquivo restaurado do backup');
    final trilha = await (db.select(db.trilhaAuditoria)).get();
    expect(trilha.any((t) => t.acao == 'incidente_resolvido'), isTrue);
    expect(await db.verificarCadeiaAuditoria(), isNull);
  });

  test('RG-03: verificação interna divergente grava + abre incidente bloqueador',
      () async {
    final v = await MrvProjetoService.registrarVerificacaoInterna(
      db,
      amostraOriginalUuid: 'am1',
      amostraVerificacaoUuid: 'am2',
      verificadorUuid: 'ver1',
      conclusao: 'divergente',
      divergencias: jsonEncode({'dap_cm': [22.5, 31.0]}),
    );
    final ver = await (db.select(db.verificacoesInternas)).getSingle();
    expect(ver.uuid, v);
    expect(ver.conclusao, 'divergente');
    // incidente bloqueador global (entidade = verificacao) trava crédito
    expect(await db.haIncidenteBloqueadorAberto('p1'), isTrue);
    final trilha = await (db.select(db.trilhaAuditoria)).get();
    expect(trilha.any((t) => t.acao == 'verificacao_interna'), isTrue);

    // conforme não abre incidente
    await MrvProjetoService.registrarVerificacaoInterna(
      db,
      amostraOriginalUuid: 'am3',
      amostraVerificacaoUuid: 'am4',
      conclusao: 'conforme',
    );
    final incidentes = await db.select(db.incidentes).get();
    expect(incidentes, hasLength(1)); // só o divergente
  });
}
