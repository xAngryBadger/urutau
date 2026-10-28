// ============================================================
// s3_hash_test.dart — hash na origem (RC-04) + catálogo (S3)
//
// Com a D-1 aplicada (picker sem re-encodar), o arquivo guardado é o
// ORIGINAL — hash aqui é hash do bruto. Divergência nunca sobrescreve:
// abre incidente e o valor original permanece como evidência.
// ============================================================

import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:urutau/data/database.dart';
import 'package:urutau/services/image_service.dart';

void main() {
  group('S3: hash na origem e catálogo', () {
    late Directory dir;
    late AppDatabase db;

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('urutau_s3_');
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.customSelect('SELECT 1').get();
    });

    tearDown(() async {
      await db.close();
      try {
        if (await dir.exists()) await dir.delete(recursive: true);
      } catch (_) {}
    });

    test('sha256De: mesmo arquivo => mesmo hash; inexistente => null',
        () async {
      final f = File(p.join(dir.path, 'a.jpg'));
      await f.writeAsBytes([1, 2, 3, 4]);
      final h1 = await ImageService.sha256De(f.path);
      final h2 = await ImageService.sha256De(f.path);
      expect(h1, isNotNull);
      expect(h1, h2, reason: 'hash determinístico');
      expect(h1!.length, 64, reason: 'sha256 hex lowercase 64 chars');
      expect(await ImageService.sha256De(p.join(dir.path, 'nao-existe.jpg')),
          isNull);
    });

    test('salvarOriginalComMetadados devolve hash+bytes do original', () async {
      final f = File(p.join(dir.path, 'orig.jpg'));
      await f.writeAsBytes(List<int>.filled(2048, 7));
      final r = await ImageService.salvarOriginalComMetadados(f.path);
      expect(r.sha256, await ImageService.sha256De(r.caminho));
      expect(r.bytes, greaterThanOrEqualTo(2048));
      // o arquivo salvo TEM o mesmo conteúdo do original (cópia, sem re-encodar)
      expect(File(r.caminho).lengthSync(), 2048);
    });

    test('registrarHashDoAtivo grava status presente; divergência abre incidente',
        () async {
      // cria um ativo no catálogo (caminho do S2)
      await db.into(db.ativosBrutos).insert(AtivosBrutosCompanion.insert(
        uuid: 'ativo-x',
        entidadeTipo: 'planta',
        entidadeUuid: 'planta-x',
        papel: const Value('bruto'),
        caminhoOriginal: const Value('/caminho/x.jpg'),
        status: const Value('pendente_hash'),
      ));

      await db.registrarHashDoAtivo(
        ativoUuid: 'ativo-x',
        sha256: 'hash-certo',
        bytes: 100,
        papel: 'bruto',
      );
      final a = (await db.select(db.ativosBrutos).get()).first;
      expect(a.sha256, 'hash-certo');
      expect(a.status, 'presente');

      // divergência: NÃO sobrescreve, abre incidente
      final antes = await db.select(db.incidentes).get();
      await db.registrarHashDoAtivo(
        ativoUuid: 'ativo-x',
        sha256: 'hash-outro',
        papel: 'bruto',
      );
      final a2 = (await db.select(db.ativosBrutos).get()).first;
      expect(a2.sha256, 'hash-certo', reason: 'nunca overwrite');
      final incidentes = await db.select(db.incidentes).get();
      expect(incidentes.length, antes.length + 1);
      expect(incidentes.last.tipo, 'hash_divergente');
    });

    test('verificarIntegridadeAtivos conta ok/divergente/ilegível', () async {
      final okFile = File(p.join(dir.path, 'ok.jpg'));
      await okFile.writeAsBytes([1, 2, 3]);
      final hashOk = await ImageService.sha256De(okFile.path);

      await db.into(db.ativosBrutos).insert(AtivosBrutosCompanion.insert(
        uuid: 'at-ok',
        entidadeTipo: 'planta',
        entidadeUuid: 'pl1',
        caminhoOriginal: Value(okFile.path),
        sha256: Value(hashOk),
        papel: const Value('bruto'),
      ));
      await db.into(db.ativosBrutos).insert(AtivosBrutosCompanion.insert(
        uuid: 'at-div',
        entidadeTipo: 'planta',
        entidadeUuid: 'pl2',
        caminhoOriginal: Value(okFile.path),
        sha256: const Value('hash-errado'),
        papel: const Value('bruto'),
      ));
      await db.into(db.ativosBrutos).insert(AtivosBrutosCompanion.insert(
        uuid: 'at-gone',
        entidadeTipo: 'planta',
        entidadeUuid: 'pl3',
        caminhoOriginal: const Value('/nao/existe.jpg'),
        sha256: const Value('qualquer'),
        papel: const Value('bruto'),
      ));

      final r = await db.verificarIntegridadeAtivos();
      expect(r.verificados, 2);
      expect(r.divergentes, 1);
      expect(r.ilegiveis, 1);
    });
  });
}
