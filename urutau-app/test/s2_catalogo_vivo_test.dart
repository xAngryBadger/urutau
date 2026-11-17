// ============================================================
// s2_catalogo_vivo_test.dart — S2: catálogo de evidência ao vivo
//
// Fecha o gap write-once (ninguém desligava arquivoAusente/fotoAusente) e
// prova o encontro detector ↔ catálogo:
//   1. foto nova cria linha em ativos_brutos com status 'pendente_hash'
//   2. arquivo some → flag marcada, status 'ausente', LINHA CONTINUA
//   3. arquivo volta → flag limpa, status 'presente'   ← o passo que falhava
// ============================================================

import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:urutau/data/database.dart';

// checkAndFixOrphanedPhotos() consulta getApplicationDocumentsDirectory() —
// em teste, substituir a plataforma (mesmo padrão de photo_evidence_test.dart).
class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async =>
      Directory.systemTemp.path;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PathProviderPlatform.instance = _FakePathProviderPlatform();

  group('S2: catálogo de evidência ao vivo', () {
    late Directory dir;
    late AppDatabase db;
    late String foto1;
    late String foto2;

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('urutau_s2_');
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.customSelect('SELECT 1').get();
      await db.into(db.parcelas).insert(ParcelasCompanion.insert(
        uuid: 'p1',
        propUt: 'UT01',
        idParcela: 1,
        userId: 'u1',
      ));
      foto1 = p.join(dir.path, 'f1.jpg');
      foto2 = p.join(dir.path, 'f2.jpg');
      await File(foto1).writeAsString('jpeg-1');
      await File(foto2).writeAsString('jpeg-2');
    });

    tearDown(() async {
      await db.close();
      try {
        if (await dir.exists()) await dir.delete(recursive: true);
      } catch (_) {}
    });

    test('ciclo completo: nasce pendente → some ausente → volta presente',
        () async {
      // ---------------------------------------------------------- 1. nascer
      await db.insertFotoParcela(FotosParcelaCompanion.insert(
        uuid: 'f1',
        parcelaUuid: 'p1',
        filePath: foto1,
      ));
      var ativos = await db.select(db.ativosBrutos).get();
      expect(ativos.length, 1, reason: 'H4: foto nova cria linha no catálogo');
      expect(ativos.first.uuid, 'legado-ativo-f1');
      expect(ativos.first.entidadeTipo, 'parcela');
      expect(ativos.first.entidadeUuid, 'p1');
      expect(ativos.first.status, 'pendente_hash',
          reason: 'arquivo presente, hash ainda não (S3)');
      expect(ativos.first.sha256, isNull, reason: 'não inventar hash');

      // ------------------------------------------------------ 2. arquivo some
      await File(foto1).delete();
      final (marked, _) = await db.checkAndFixOrphanedPhotos();
      expect(marked, greaterThanOrEqualTo(1));
      final fotoRow = await db
          .customSelect("SELECT arquivo_ausente AS a FROM fotos_parcela WHERE uuid='f1'")
          .get();
      expect(fotoRow.first.data['a'], 1, reason: 'flag marcada (Q2)');

      ativos = await db.select(db.ativosBrutos).get();
      expect(ativos.length, 1, reason: 'S2: a linha CONTINUA — nunca delete');
      expect(ativos.first.status, 'ausente',
          reason: 'S2: catálogo reflete o detector');

      // --------------------------------------------------- 3. arquivo volta
      await File(foto1).writeAsString('jpeg-1-restaurado');
      await db.checkAndFixOrphanedPhotos();
      final fotoRow2 = await db
          .customSelect("SELECT arquivo_ausente AS a FROM fotos_parcela WHERE uuid='f1'")
          .get();
      expect(fotoRow2.first.data['a'], 0,
          reason: 'H5/H3: arquivo de volta LIMPA a flag (era write-once!)');

      ativos = await db.select(db.ativosBrutos).get();
      expect(ativos.length, 1, reason: 'continua uma linha só');
      expect(ativos.first.status, 'presente');
    });

    test('estado normal: zero UPDATE quando nada mudou', () async {
      // foto presente e sem flag: o detector não deve sujar linha nenhuma
      await db.insertFotoParcela(FotosParcelaCompanion.insert(
        uuid: 'f2',
        parcelaUuid: 'p1',
        filePath: foto2,
      ));
      final antes = await db.select(db.ativosBrutos).get();
      final (marked, _) = await db.checkAndFixOrphanedPhotos();
      expect(marked, 0);
      final depois = await db.select(db.ativosBrutos).get();
      expect(depois.length, antes.length);
      expect(depois.first.status, 'pendente_hash',
          reason: 'foto presente já nasce pendente_hash e fica assim');
    });

    test('planta: foto ausente é marcada e a linha sobrevive', () async {
      // planta com foto em caminho inexistente
      await db.into(db.plantas).insert(PlantasCompanion.insert(
        uuid: 'pl1',
        parcelaUuid: 'p1',
        especie: 'Eucalyptus urophylla',
        alturaCm: 145.5,
        categoria: 3,
        fotoEspeciePath: const Value('/sumiu/pl1.jpg'),
      ));
      // catálogo ao vivo para a planta nascida (H4)
      await db.registrarFotoCatalogo(
        objetoUuid: 'pl1',
        entidadeTipo: 'planta',
        entidadeUuid: 'pl1',
        caminhoOriginal: '/sumiu/pl1.jpg',
        capturadoEm: DateTime.now(),
      );

      final (marked, _) = await db.checkAndFixOrphanedPhotos();
      expect(marked, greaterThanOrEqualTo(1));
      final planta = (await db.select(db.plantas).get()).first;
      expect(planta.fotoAusente, isTrue);
      expect(planta.fotoEspeciePath, '/sumiu/pl1.jpg',
          reason: 'path permanece como evidência');

      final ativo = (await db.select(db.ativosBrutos).get())
          .firstWhere((a) => a.entidadeTipo == 'planta');
      expect(ativo.status, 'ausente');
      expect(ativo.entidadeUuid, 'pl1',
          reason: 'D-1: caminho ao vivo usa plantas.uuid, não legado-med-');
    });
  });
}
