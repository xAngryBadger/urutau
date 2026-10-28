// ============================================================
// s1_catalogo_leitura_test.dart — S1: leitura das marcações do Q2
//
// O fix Q2 (43a165e) corrigiu o DADO (linha sobrevive marcada) — sem estas
// queries o resultado era invisível. S1 acrescenta os leitores; este teste
// prova que eles filtram certo (só marcadas, nunca soft-deletadas).
// ============================================================

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urutau/data/database.dart';

void main() {
  group('S1: queries do catálogo de evidência', () {
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
      // 2 fotos de parcela: 1 presente, 1 com arquivo ausente
      await db.into(db.fotosParcela).insert(FotosParcelaCompanion.insert(
        uuid: 'f-ok',
        parcelaUuid: 'p1',
        filePath: '/d/ok.jpg',
      ));
      await db.into(db.fotosParcela).insert(FotosParcelaCompanion.insert(
        uuid: 'f-ausente',
        parcelaUuid: 'p1',
        filePath: '/d/perdida.jpg',
        arquivoAusente: const Value(true),
      ));
      // foto ausente MAS soft-deletada: não pode aparecer
      await db.into(db.fotosParcela).insert(FotosParcelaCompanion.insert(
        uuid: 'f-ausente-del',
        parcelaUuid: 'p1',
        filePath: '/d/perdida2.jpg',
        arquivoAusente: const Value(true),
        deletedAt: Value(DateTime.now()),
      ));
      // 2 plantas: 1 com foto presente, 1 com foto ausente
      await db.into(db.plantas).insert(PlantasCompanion.insert(
        uuid: 'pl-ok',
        parcelaUuid: 'p1',
        especie: 'Eucalyptus urophylla',
        alturaCm: 145.5,
        categoria: 3,
        fotoEspeciePath: const Value('/d/pl1.jpg'),
      ));
      await db.into(db.plantas).insert(PlantasCompanion.insert(
        uuid: 'pl-ausente',
        parcelaUuid: 'p1',
        especie: 'Cecropia hololeuca',
        alturaCm: 210,
        categoria: 3,
        fotoEspeciePath: const Value('/d/pl2.jpg'),
        fotoAusente: const Value(true),
      ));
      // planta ausente MAS soft-deletada: não pode aparecer
      await db.into(db.plantas).insert(PlantasCompanion.insert(
        uuid: 'pl-ausente-del',
        parcelaUuid: 'p1',
        especie: 'NI',
        alturaCm: 32,
        categoria: 1,
        fotoAusente: const Value(true),
        deletedAt: Value(DateTime.now()),
      ));
    });

    tearDown(() async => await db.close());

    test('getFotosComArquivoAusente devolve só as marcadas e vivas', () async {
      final r = await db.getFotosComArquivoAusente();
      expect(r.length, 1);
      expect(r.first.uuid, 'f-ausente');
    });

    test('getPlantasComFotoAusente devolve só as marcadas e vivas', () async {
      final r = await db.getPlantasComFotoAusente();
      expect(r.length, 1);
      expect(r.first.uuid, 'pl-ausente');
    });

    test('countFotosComArquivoAusente conta sem carregar linhas', () async {
      expect(await db.countFotosComArquivoAusente(), 1);
    });
  });
}
