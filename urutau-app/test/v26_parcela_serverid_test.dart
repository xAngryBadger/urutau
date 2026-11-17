// ============================================================
// v26_parcela_serverid_test.dart — backfill t14 (v26)
//
// A coluna plantas.parcela_server_id espelha o id do servidor da parcela
// dona. Backfill: 'pb-<serverId>' -> '<serverId>'; uuid local (não
// sincronizado) fica NULL — NUNCA inventado.
// ============================================================

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urutau/data/database.dart';

void main() {
  group('t14 v26: parcela_server_id', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.customSelect('SELECT 1').get();
      await db.into(db.parcelas).insert(ParcelasCompanion.insert(
        uuid: 'pb-abc123',
        propUt: 'UT01',
        idParcela: 1,
        userId: 'u1',
      ));
      // parcela-mãe para o uuid local (FK ligada no beforeOpen do app)
      await db.into(db.parcelas).insert(ParcelasCompanion.insert(
        uuid: 'uuid-local-999',
        propUt: 'UT02',
        idParcela: 2,
        userId: 'u1',
      ));
    });

    tearDown(() async => await db.close());

    test('backfill: pb-<id> vira <id>; uuid local fica NULL', () async {
      await db.into(db.plantas).insert(PlantasCompanion.insert(
        uuid: 'pl-sync',
        parcelaUuid: 'pb-abc123',
        especie: 'Eucalyptus urophylla',
        alturaCm: 145.5,
        categoria: 3,
      ));
      await db.into(db.plantas).insert(PlantasCompanion.insert(
        uuid: 'pl-local',
        parcelaUuid: 'uuid-local-999',
        especie: 'Cecropia hololeuca',
        alturaCm: 210,
        categoria: 3,
      ));

      // mesma expressão do gatilho de migração (onUpgrade from<26)
      await db.customStatement(
        "UPDATE plantas SET parcela_server_id = "
        "  CASE WHEN parcela_uuid LIKE 'pb-%' "
        "    THEN substr(parcela_uuid, 4) ELSE NULL END "
        "WHERE parcela_server_id IS NULL");

      final porUuid = <String, String?>{
        for (final p in await db.select(db.plantas).get())
          p.uuid: p.parcelaServerId,
      };
      expect(porUuid['pl-sync'], 'abc123',
          reason: 'uuid pb-<id> mapeia para o server id');
      expect(porUuid['pl-local'], isNull,
          reason: 'uuid local não sincronizado fica NULL — nunca inventado');
    });

    test('registrarParcelaServerId preenche NULL e nunca sobrescreve',
        () async {
      await db.into(db.plantas).insert(PlantasCompanion.insert(
        uuid: 'pl1',
        parcelaUuid: 'uuid-local-999',
        especie: 'NI',
        alturaCm: 32,
        categoria: 1,
      ));
      await db.registrarParcelaServerId('pl1', 'srv-parcela-1');
      await db.registrarParcelaServerId('pl1', 'srv-parcela-2');

      final p = (await db.select(db.plantas).get()).first;
      expect(p.parcelaServerId, 'srv-parcela-1',
          reason: 'nunca sobrescreve — id errado ligaria à parcela errada');
    });
  });
}
