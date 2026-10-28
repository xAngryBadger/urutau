// ============================================================
// q3_upsert_local_test.dart — Fase 2 do motor: ponte local→servidor
//
// O upsert em si (getFullList → update/create por uuid_local,
// last-writer-wins) vive dentro de _syncParcela e depende de um PocketBase
// vivo — sua prova é o teste de integração documentado no relatório
// (impl-sync-implementado.md, protocolo contra PB local com o seed script).
// O que dá para provar sem servidor é o lado local: a ponte
// server_planta_id nasce NULL e é preenchida pelo helper do push.
// ============================================================

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urutau/data/database.dart';

void main() {
  group('Q3 motor Fase 2 (lado local)', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.customSelect('SELECT 1').get();
      await db.into(db.parcelas).insert(ParcelasCompanion.insert(
        uuid: 'p1',
        propUt: 'UT01',
        idParcela: 1,
        userId: 'u1',
      ));
      await db.into(db.plantas).insert(PlantasCompanion.insert(
        uuid: 'pl1',
        parcelaUuid: 'p1',
        especie: 'Eucalyptus urophylla',
        alturaCm: 145.5,
        categoria: 3,
      ));
    });

    tearDown(() async => await db.close());

    test('serverPlantaId nasce NULL (planta ainda não sincronizada)', () async {
      final planta = (await db.select(db.plantas).get()).first;
      expect(planta.serverPlantaId, isNull);
      expect(planta.updatedAt, isNotNull,
          reason: 'updatedAt existe desde v18 e alimenta o last-writer-wins');
    });

    test('atualizarServerPlantaId preenche a ponte após o upsert',
        () async {
      await db.atualizarServerPlantaId('pl1', 'abc123def456');
      final planta = (await db.select(db.plantas).get()).first;
      expect(planta.serverPlantaId, 'abc123def456');
    });

    test('ponte só é escrita para a planta certa', () async {
      await db.into(db.plantas).insert(PlantasCompanion.insert(
        uuid: 'pl2',
        parcelaUuid: 'p1',
        especie: 'Cecropia hololeuca',
        alturaCm: 210,
        categoria: 3,
      ));
      await db.atualizarServerPlantaId('pl1', 'srv-1');
      final porUuid = <String, String?>{
        for (final p in await db.select(db.plantas).get()) p.uuid: p.serverPlantaId
      };
      expect(porUuid['pl1'], 'srv-1');
      expect(porUuid['pl2'], isNull);
    });
  });
}
