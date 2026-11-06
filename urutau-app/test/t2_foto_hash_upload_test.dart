// ============================================================
// t2_foto_hash_upload_test.dart — TAREFA 2 (integridade do hash)
//
// Prova, com bytes de verdade, a invariante do pipeline de foto:
//
//   bytes que ENTRAM (original capturado)
//     == bytes GUARDADOS (cópia local, sem re-encodar)
//     == bytes HASHEADOS (sha256 do catálogo, na origem)
//     == bytes que IRIAM PRO SERVIDOR (upload lê do mesmo caminho)
//
// O upload em sync_service.dart:1890-1907 / 1981-1995 calcula
// ImageService.sha256De(file.path) e envia o MESMO arquivo; o hash do
// catálogo é comparado (RC-04) e a divergência aborta o upload. Este teste
// fecha a mesma garantia pela ponta da captura.
// ============================================================

import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:urutau/services/image_service.dart';

// Fake da plataforma: documents dir aponta pra um temp real, então
// savePhotoLocally realmente COPIA (em vez de cair no fallback do teste).
class _RealTmpPathProvider extends PathProviderPlatform {
  _RealTmpPathProvider(this.dir);
  final String dir;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('T2 — bytes entram = hasheados = upload', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('urutau_t2_');
      PathProviderPlatform.instance = _RealTmpPathProvider(tmp.path);
    });

    tearDown(() async {
      try {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      } catch (_) {}
    });

    test('o arquivo guardado é byte-idêntico ao original (sem compressão)',
        () async {
      final rng = Random(1234);
      final originalBytes = List<int>.generate(9000, (_) => rng.nextInt(256));
      final src = File(p.join(tmp.path, 'captura.jpg'));
      await src.writeAsBytes(originalBytes);

      final r = await ImageService.salvarOriginalComMetadados(src.path);

      // 1) bytes que ENTRAM == bytes GUARDADOS (cópia fiel, nada re-encodado)
      final savedBytes = await File(r.caminho).readAsBytes();
      expect(savedBytes, equals(originalBytes),
          reason: 'D-1: original preservado, byte a byte');
    });

    test('hash do catálogo cobre exatamente os bytes que subiriam', () async {
      final rng = Random(99);
      final originalBytes = List<int>.generate(12000, (_) => rng.nextInt(256));
      final src = File(p.join(tmp.path, 'captura.jpg'));
      await src.writeAsBytes(originalBytes);

      final r = await ImageService.salvarOriginalComMetadados(src.path);

      // bytes que iriam pro servidor: o upload lê do MESMO caminho.
      final uploadBytes = await File(r.caminho).readAsBytes();

      // 2) hash HASHEADO na origem == sha256 dos bytes que sobem
      expect(r.sha256, sha256.convert(uploadBytes).toString(),
          reason: 'hash do catálogo é o hash exato do que sobe');
      expect(r.bytes, uploadBytes.length,
          reason: 'contagem de bytes bate com o arquivo enviado');

      // 3) recheck do upload (sync_service) fecha contra o catálogo (RC-04)
      final recheck = await ImageService.sha256De(r.caminho);
      expect(recheck, r.sha256,
          reason: 'sha256 rechecked no upload == hash do catálogo');

      // e o hash cobre os bytes DE ENTRADA também (entram == que sobem)
      expect(r.sha256, sha256.convert(originalBytes).toString());
    });

    test('se o arquivo muda após a captura, o recheck do upload divergiria',
        () async {
      final src = File(p.join(tmp.path, 'captura.jpg'));
      await src.writeAsBytes(List<int>.filled(4096, 7));

      final r = await ImageService.salvarOriginalComMetadados(src.path);

      // Simula adulteração/compressão do arquivo DEPOIS do hash de origem.
      await File(r.caminho).writeAsBytes(List<int>.filled(4096, 9));

      final recheck = await ImageService.sha256De(r.caminho);
      expect(recheck, isNot(equals(r.sha256)),
          reason: 'o guard do upload detectaria a divergência (não subiria)');
    });
  });
}
