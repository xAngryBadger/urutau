// ============================================================
// mrv_legado_guard_test.dart — regressão do guard do placeholder LEGADO
//
// PATCH NAO APLICADO. Destino: urutau-app/test/mrv_legado_guard_test.dart
// Task t9 (dev-mrv) · autorizado pelo capitão.
//
// BUG QUE ESTE TESTE FECHA:
// O statement 20.2 de sqlV20 era
//   "UPDATE parcelas SET projeto_id = 'LEGADO-PROJ-0000' WHERE projeto_id IS NULL"
// sem guard. Ele roda em onCreate E em beforeOpen (toda abertura) via aplicarBase.
// Na migração isso é correto — nenhum projeto real existe. Mas quando projetos
// reais nascerem, parcela legitimamente sem projeto seria sugada para o
// placeholder LEGADO PARA SEMPRE, silenciosamente.
//
// FIX: ... AND (SELECT COUNT(*) FROM projetos_mrv) = 1
//
// Premissa verificada no device real: projetos_mrv tem EXATAMENTE 1 registro
// (LEGADO-PROJ-0000) — confirmado pelo dev-codigo no device-db.sqlite.
//
// RODAR COM:   flutter test test/mrv_legado_guard_test.dart
// ============================================================

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urutau/data/database.dart';
import 'package:urutau/data/migrations/mrv_migration.dart';

void main() {
  group('guard do placeholder LEGADO', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));

    tearDown(() async => await db.close());

    test('C1: só o placeholder existe → parcela NULL é preenchida', () async {
      // nasce com o scaffold (LEGADO-PROJ-0000), sem parcela
      await db.customSelect('SELECT 1').get();
      await db.into(db.parcelas).insert(ParcelasCompanion.insert(
        uuid: 'g1', propUt: 'UT01', idParcela: 1, userId: 'u1',
      ));

      await db.customStatement(
        "UPDATE parcelas SET projeto_id = 'LEGADO-PROJ-0000' "
        'WHERE projeto_id IS NULL AND (SELECT COUNT(*) FROM projetos_mrv) = 1');

      final r = await db
          .customSelect("SELECT projeto_id AS p FROM parcelas WHERE uuid='g1'")
          .get();
      expect(r.first.data['p'], 'LEGADO-PROJ-0000',
          reason: 'com um único projeto (o placeholder), preencher é correto');
    });

    test('C2: projeto real nasce → parcela NULL NÃO é sugada', () async {
      await db.customSelect('SELECT 1').get();
      // segundo projeto: agora existem 2
      await db.into(db.projetosMrv).insert(ProjetosMrvCompanion.insert(
        uuid: 'PROJ-REAL-1',
        codigo: 'REAL-1',
        nome: 'Projeto real',
        modalidade: 'restauracao',
      ));
      await db.into(db.parcelas).insert(ParcelasCompanion.insert(
        uuid: 'g2', propUt: 'UT02', idParcela: 1, userId: 'u1',
      ));

      final antes = await db.customSelect(
          "SELECT COUNT(*) AS c FROM parcelas WHERE projeto_id IS NULL").get();
      expect(antes.first.data['c'], 1, reason: 'parcela nasce sem projeto');

      await db.customStatement(
        "UPDATE parcelas SET projeto_id = 'LEGADO-PROJ-0000' "
        'WHERE projeto_id IS NULL AND (SELECT COUNT(*) FROM projetos_mrv) = 1');

      final r = await db
          .customSelect("SELECT projeto_id AS p FROM parcelas WHERE uuid='g2'")
          .get();
      expect(r.first.data['p'], isNull,
          reason: 'com 2+ projetos o guard TRAVA: a parcela continua sem projeto, '
              'e a aplicação é quem decide — não o placeholder');
    });

    test('C3: idempotente — rodar 3x não muda nada', () async {
      await db.customSelect('SELECT 1').get();
      await db.into(db.parcelas).insert(ParcelasCompanion.insert(
        uuid: 'g3', propUt: 'UT03', idParcela: 1, userId: 'u1',
      ));

      for (var i = 0; i < 3; i++) {
        await db.customStatement(
          "UPDATE parcelas SET projeto_id = 'LEGADO-PROJ-0000' "
          'WHERE projeto_id IS NULL AND (SELECT COUNT(*) FROM projetos_mrv) = 1');
      }

      final total = await db
          .customSelect("SELECT COUNT(*) AS c FROM parcelas WHERE uuid='g3'")
          .get();
      expect(total.first.data['c'], 1, reason: 'não duplica linha');

      final legado = await db.customSelect(
          "SELECT COUNT(*) AS c FROM parcelas WHERE uuid='g3' AND projeto_id='LEGADO-PROJ-0000'")
          .get();
      expect(legado.first.data['c'], 1);
    });

    test('C4: o statement da lista sqlV20 tem o guard', () async {
      // Falha se alguém remover o guard de sqlV20.
      final comGuard = MrvMigration.sqlV20.any((s) =>
          s.contains('SET projeto_id') &&
          s.contains('(SELECT COUNT(*) FROM projetos_mrv) = 1'));
      expect(comGuard, true,
          reason: 'o statement 20.2 em sqlV20 perdeu o guard — ver '
              'impl-migracao-drift.md §10.5');
    });
  });
}
