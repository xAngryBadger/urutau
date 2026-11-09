import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urutau/data/database.dart';

/// Regressão do remap de UUID local → PocketBase record ID.
///
/// BUG MEDIDO em produção (logcat do emulador):
///   SqliteException(787): FOREIGN KEY constraint failed
///   UPDATE "plantas" SET "parcela_uuid" = ? WHERE "parcela_uuid" = ?,
///   parameters: pb-5n492rvsaw0uwvg, demo-50
///
/// `remapParcelaUuid` gravava os FILHOS antes do PAI, e com
/// `PRAGMA foreign_keys = ON` (database.dart) o SQLite recusa a duas ordens
/// possíveis: filhos primeiro → o pai ainda não tem o UUID novo; pai primeiro
/// → os filhos ficam órfãos. A consequência é a pior possível: a parcela fica
/// marcada como sincronizada mas mantém o UUID local, e o sync seguinte cria
/// um registo DUPLICADO no servidor.
///
/// Estes testes fixam o comportamento correcto e detectam a regressão.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('remapParcelaUuid renomeia a parcela e cascata para plantas', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    try {
      await db.insertParcela(ParcelasCompanion.insert(
        uuid: 'demo-50',
        propUt: 'UT-90',
        idParcela: 90,
        userId: 'user-1',
      ));
      await db.insertPlanta(PlantasCompanion.insert(
        uuid: 'planta-1',
        parcelaUuid: 'demo-50',
        especie: 'Eucalyptus grandis',
        alturaCm: 737,
        dapCm: const Value(21.0),
        categoria: 2,
      ));

      await db.remapParcelaUuid('demo-50', 'pb-5n492rvsaw0uwvg');

      final parcela = await db.getParcelaByUuid('pb-5n492rvsaw0uwvg');
      expect(parcela, isNotNull,
          reason: 'a parcela tem de passar a responder pelo ID do servidor');

      final plantas =
          await db.getPlantasByParcela('pb-5n492rvsaw0uwvg');
      expect(plantas, hasLength(1),
          reason: 'as plantas têm de ser cascateadas para o UUID novo');
      expect(plantas.first.uuid, 'planta-1');

      // Nenhum resíduo do UUID antigo: se sobrar, o pull/sync duplica.
      final orfas = await db.getPlantasByParcela('demo-50');
      expect(orfas, isEmpty,
          reason: 'nenhuma planta pode ficar presa ao UUID local antigo');
    } finally {
      await db.close();
    }
  });

  test('remapParcelaUuid preserva os dados MRV ligados à parcela', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    try {
      await db.insertParcela(ParcelasCompanion.insert(
        uuid: 'demo-50',
        propUt: 'UT-90',
        idParcela: 90,
        userId: 'user-1',
      ));
      await db.insertPlanta(PlantasCompanion.insert(
        uuid: 'planta-1',
        parcelaUuid: 'demo-50',
        especie: 'Handroanthus heptaphyllus',
        alturaCm: 774,
        dapCm: const Value(34.0),
        categoria: 3,
      ));

      await db.remapParcelaUuid('demo-50', 'pb-servidor-1');

      final plantas = await db.getPlantasByParcela('pb-servidor-1');
      expect(plantas.single.especie, 'Handroanthus heptaphyllus');
      expect(plantas.single.alturaCm, 774);
      expect(plantas.single.dapCm, 34);
      expect(plantas.single.categoria, 3);
    } finally {
      await db.close();
    }
  });

  test('remapUsuarioUuid reaponha parcelas e utilizador num só passo',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    try {
      await db.insertUsuario(UsuariosCompanion.insert(
        uuid: 'local-uuid',
        nome: 'Convidado',
        email: 'convidado@urutau.local',
        senha: 'hash:convidado',
        isAdmin: const Value(false),
      ));
      await db.insertParcela(ParcelasCompanion.insert(
        uuid: 'p1',
        propUt: 'UT-77',
        idParcela: 7,
        userId: 'local-uuid',
      ));
      await db.insertPlanta(PlantasCompanion.insert(
        uuid: 'pl-p1',
        parcelaUuid: 'p1',
        especie: 'Cecropia pachystachya',
        alturaCm: 811,
        categoria: 1,
      ));

      await db.remapUsuarioUuid('local-uuid', 'uuid-do-servidor');

      expect((await db.getUsuarioByUuid('uuid-do-servidor'))!.email,
          'convidado@urutau.local');
      // Query directa: getParcelasNaoSincronizadas filtra por pronta_para_sync,
      // que não é o que está a ser testado aqui.
      final todas =
          await (db.select(db.parcelas)..where((t) => t.uuid.equals('p1')))
              .get();
      expect(todas.single.userId, 'uuid-do-servidor',
          reason: 'a parcela tem de acompanhar o novo UUID do dono');
      // A planta continua ligada à parcela (que não foi renomeada aqui).
      final plantas = await db.getPlantasByParcela('p1');
      expect(plantas, hasLength(1));
    } finally {
      await db.close();
    }
  });
}


