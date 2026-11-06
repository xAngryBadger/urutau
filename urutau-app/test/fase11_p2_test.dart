// Fase 11 (P2): RT-03 risco de reversão, RG-05 compétences, v32
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

  test('v32: projetos_mrv tem risco_reversao e fonte_fogo_historico', () async {
    final cols = await db
        .customSelect('PRAGMA table_info(projetos_mrv)')
        .get();
    final nomes = cols.map((r) => r.data['name'] as String).toList();
    expect(nomes, containsAll(['risco_reversao', 'fonte_fogo_historico']));
  });

  test('RT-03: salvar risco de reversão grava no projeto + trilha', () async {
    await db.into(db.projetosMrv).insert(ProjetosMrvCompanion.insert(
          uuid: 'PROJ-1',
          codigo: 'PRJ-001',
          nome: 'Fazenda Modelo',
          modalidade: 'plantacao',
        ));
    await MrvProjetoService.salvarRiscoReversao(
      db,
      'PROJ-1',
      risco: 'alto',
      fonteFogoHistorico: 'alerta satelite 2026-08 (ULTRA run #12)',
    );
    final p = await (db.select(db.projetosMrv)
          ..where((t) => t.uuid.equals('PROJ-1')))
        .getSingle();
    expect(p.riscoReversao, 'alto');
    expect(p.fonteFogoHistorico, contains('ULTRA run #12'));
    final trilha = await db.select(db.trilhaAuditoria).get();
    expect(trilha.any((t) => t.acao == 'update_risco_reversao'), isTrue);
    expect(await db.verificarCadeiaAuditoria(), isNull);
  });

  test('RG-05: competência registrada, listada e expiração detectada', () async {
    await MrvProjetoService.registrarCompetencia(
      db,
      usuarioUuid: 'u1',
      tipoTreinamento: 'SOP-MRV-V1 campo',
      validoAte: '2020-01-01', // expirado
    );
    await MrvProjetoService.registrarCompetencia(
      db,
      usuarioUuid: 'u1',
      tipoTreinamento: 'Segurança drone',
      validoAte: '2099-01-01', // vigente
    );
    final todas = await MrvProjetoService.listarCompetencias(db, 'u1');
    expect(todas, hasLength(2));
    final expiradas = await MrvProjetoService.competenciasExpiradas(db, 'u1');
    expect(expiradas, hasLength(1));
    expect(expiradas.first.tipoTreinamento, 'SOP-MRV-V1 campo');
    final trilha = await db.select(db.trilhaAuditoria).get();
    expect(trilha.where((t) => t.acao == 'create_competencia'), hasLength(2));
    expect(await db.verificarCadeiaAuditoria(), isNull);
  });
}
