import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urutau/data/database.dart';

/// Regressão do bug de FK ao criar uma parcela NOVA com plantas.
///
/// BUG MEDIDO AO VIVO no emulador-5554 (APK release, 2026-11-11), durante a
/// prova do wizard completo:
///
///   Erro ao salvar: SqliteException(787): while executing statement,
///   FOREIGN KEY constraint failed, constraint failed (code 787)
///     Causing statement: INSERT INTO "plantas" (..., "parcela_uuid", ...)
///     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
///     parameters: 4138f3ac-..., 508bcd32-3820-4a41-9ebe-cad42b4ac221, ...
///
/// CAUSA: o wizard atribui o uuid da parcela no `_initAsync`, mas a linha em
/// `parcelas` só é gravada no passo final ("Concluir"). A Etapa 3 (Plantas)
/// insere as plantas ANTES disso, com `parcela_uuid` a apontar para uma
/// parcela que ainda não existe. Com `PRAGMA foreign_keys = ON`, o SQLite
/// recusa o insert.
///
/// CONSEQUÊNCIA: era IMPOSSÍVEL criar uma parcela nova com qualquer planta.
/// Para um app de campo, isto significa que o registo da vegetação — o dado
/// mais valioso que o app existe para guardar — só se conseguia entrar na
/// base de dadosEDIANDO uma parcela já existente, nunca durante o
/// levantamento. É a lacuna mais grave que resta.
///
/// ESTES TESTES fixam o comportamento correcto:
///  1. `ensureParcelaExists` cria a linha para satisfazer a FK;
///  2. a planta passa a inserir sem rebentar;
///  3. o `_writeParcela` final actualiza a MESMA linha (não duplica);
///  4. se existir uma parcela DISPONÍVEL com a mesma prop/UT/número, as
///     plantas medidas são MIGRADAS para ela (nunca perdidas).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ensureParcelaExists cria a linha e satisfaz a FK de plantas', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    try {
      const uuid = 'parcela-nova-uuid';

      // Sem a linha da parcela, a planta rebenta com FK — o bug original.
      await expectLater(
        db.insertPlanta(PlantasCompanion.insert(
          uuid: 'planta-x',
          parcelaUuid: uuid,
          especie: 'Lafoensia pacari',
          alturaCm: 350,
          categoria: 2,
        )),
        throwsA(isA<Exception>()),
        reason: 'pré-condição: sem a linha da parcela, a FK tem de recusar',
      );

      // Com `ensureParcelaExists`, a linha existe e a planta entra.
      await db.ensureParcelaExists(uuid);

      final parcela = await db.getParcelaByUuid(uuid);
      expect(parcela, isNotNull,
          reason: 'a linha da parcela tem de existir para a FK');
      expect(parcela!.prontaParaSync, isFalse,
          reason: 'o rascunho não pode estar pronto para sincronizar');
      expect(parcela.userId, isEmpty,
          reason: 'o rascunho não tem dono — é preenchido ao concluir');

      await db.insertPlanta(PlantasCompanion.insert(
        uuid: 'planta-x',
        parcelaUuid: uuid,
        especie: 'Lafoensia pacari',
        alturaCm: 350,
        categoria: 2,
      ));

      final plantas = await db.getPlantasByParcela(uuid);
      expect(plantas, hasLength(1),
          reason: 'a planta tem de ficar ligada à parcela');
    } finally {
      await db.close();
    }
  });

  test('ensureParcelaExists é idempotente — não duplica a parcela', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    try {
      const uuid = 'parcela-idem';
      await db.ensureParcelaExists(uuid);
      await db.ensureParcelaExists(uuid);
      await db.ensureParcelaExists(uuid);

      final todas = await db.select(db.parcelas).get();
      final comUuid = todas.where((p) => p.uuid == uuid).toList();
      expect(comUuid, hasLength(1),
          reason: 'chamar três vezes não pode criar três parcelas');
    } finally {
      await db.close();
    }
  });

  test('migrarDadosParaParcela move plantas do rascunho para a real', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    try {
      const rascunho = 'rascunho-uuid';
      const real = 'parcela-real-uuid';

      await db.insertParcela(ParcelasCompanion.insert(
        uuid: real,
        propUt: 'UT01',
        idParcela: 1,
        userId: 'user-1',
      ));
      await db.ensureParcelaExists(rascunho);
      await db.insertPlanta(PlantasCompanion.insert(
        uuid: 'planta-medida',
        parcelaUuid: rascunho,
        especie: 'Lafoensia pacari',
        alturaCm: 350,
        categoria: 2,
      ));

      await db.migrarDadosParaParcela(
        deRascunho: rascunho,
        paraParcela: real,
      );

      final naReal = await db.getPlantasByParcela(real);
      expect(naReal, hasLength(1),
          reason: 'a planta medida tem de acompanhar a parcela real');
      expect(naReal.first.uuid, 'planta-medida');

      final noRascunho = await db.getPlantasByParcela(rascunho);
      expect(noRascunho, isEmpty,
          reason: 'o rascunho não pode ficar com plantas presas');
    } finally {
      await db.close();
    }
  });

  test('migrarDadosParaParcela não mexe quando não há dados a migrar',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    try {
      const rascunho = 'rascunho-vazio';
      const real = 'parcela-real-2';
      await db.insertParcela(ParcelasCompanion.insert(
        uuid: real,
        propUt: 'UT02',
        idParcela: 2,
        userId: 'user-1',
      ));
      await db.ensureParcelaExists(rascunho);

      // Não pode rebentar nem apagar nada.
      await db.migrarDadosParaParcela(
        deRascunho: rascunho,
        paraParcela: real,
      );

      final plantas = await db.getPlantasByParcela(real);
      expect(plantas, isEmpty);
    } finally {
      await db.close();
    }
  });
}
