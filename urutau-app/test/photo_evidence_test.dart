import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:urutau/data/database.dart';

// checkAndFixOrphanedPhotos() consulta getApplicationDocumentsDirectory()
// (path_provider). Em teste, substituímos a plataforma por um fake.
class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async =>
      Directory.systemTemp.path;

  // Qualquer outro método eventualmente chamado cai no noSuchMethod
  // (a classe continua concreta porque noSuchMethod está definido).
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Q2 — regressão: foto com arquivo ausente NUNca tem sua linha deletada.
// O bug apagava a linha de fotos_parcela (evidência) e zerava
// fotoEspeciePath da planta. Depois do fix, ambos são MARCADOS como ausentes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PathProviderPlatform.instance = _FakePathProviderPlatform();

  group('Q2 checkAndFixOrphanedPhotos', () {
    test('foto ausente é MARCADA, não deletada; planta mantém o path',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      // Parcela-mãe (FK está ligado no beforeOpen do app).
      await db.into(db.parcelas).insert(ParcelasCompanion.insert(
        uuid: 'p1',
        propUt: 'UT 01',
        idParcela: 1,
        userId: 'u1',
      ));

      // Foto de parcela com caminho inexistente.
      await db.into(db.fotosParcela).insert(FotosParcelaCompanion.insert(
        uuid: 'f1',
        parcelaUuid: 'p1',
        filePath: '/caminho/inexistente/foto_parcela.jpg',
      ));

      // Planta com foto de espécie em caminho inexistente.
      await db.into(db.plantas).insert(PlantasCompanion.insert(
        uuid: 'pl1',
        parcelaUuid: 'p1',
        especie: 'Cabraleia canjerana',
        alturaCm: 300,
        categoria: 1,
        fotoEspeciePath: const Value('/caminho/inexistente/foto_planta.jpg'),
      ));

      final (marked, _) = await db.checkAndFixOrphanedPhotos();
      expect(marked, 2, reason: 'duas referências marcadas como ausentes');

      // Linha de foto CONTINUA no banco, marcada.
      final fotos = await db.select(db.fotosParcela).get();
      expect(fotos.length, 1, reason: 'Q2: linha de foto jamais é deletada');
      expect(fotos.first.arquivoAusente, isTrue);
      expect(fotos.first.filePath, '/caminho/inexistente/foto_parcela.jpg');

      // Planta mantém o PATH original (evidência) + marca ausência.
      final plantas = await db.select(db.plantas).get();
      expect(plantas.length, 1);
      expect(plantas.first.fotoAusente, isTrue);
      expect(plantas.first.fotoEspeciePath,
          '/caminho/inexistente/foto_planta.jpg');

      await db.close();
    });

    test('foto existente NÃO é marcada como ausente', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      final tmp = '${Directory.systemTemp.path}/q2_test_foto.jpg';
      await File(tmp).writeAsString('fake-jpeg');

      await db.into(db.parcelas).insert(ParcelasCompanion.insert(
        uuid: 'p1',
        propUt: 'UT 01',
        idParcela: 1,
        userId: 'u1',
      ));
      await db.into(db.fotosParcela).insert(FotosParcelaCompanion.insert(
        uuid: 'f1',
        parcelaUuid: 'p1',
        filePath: tmp,
      ));

      final (marked, _) = await db.checkAndFixOrphanedPhotos();
      expect(marked, 0);

      final fotos = await db.select(db.fotosParcela).get();
      expect(fotos.first.arquivoAusente, isFalse);

      await File(tmp).delete();
      await db.close();
    });
  });
}
