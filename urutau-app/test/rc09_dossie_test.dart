// RC-09: dossiê por parcela — ZIP com PDF + dados + manifesto de hashes
import 'dart:convert';
import 'dart:io' as io;

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urutau/data/database.dart';
import 'package:urutau/services/dossie_service.dart';
import 'package:urutau/services/mrv_calc_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dossiê gera ZIP com manifesto íntegro (hash de cada arquivo bate)', () async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
    addTearDown(db.close);

    await db.insertParcela(ParcelasCompanion.insert(
      uuid: 'p1',
      propriedade: const drift.Value('Faz Modelo'),
      propUt: 'UT-01',
      idParcela: 7,
      userId: 'u1',
      latitude: const drift.Value(-15.8),
      longitude: const drift.Value(-47.9),
    ));
    await db.insertPlanta(PlantasCompanion.insert(
      uuid: 'pl1',
      parcelaUuid: 'p1',
      especie: 'Eucalipto',
      alturaCm: 1500,
      dapCm: const drift.Value(22.5),
      categoria: 1,
    ));
    // foto falsa (arquivo não precisa existir no disco; hash vem do catálogo)
    await db.insertFotoParcela(FotosParcelaCompanion.insert(
      uuid: 'f1',
      parcelaUuid: 'p1',
      filePath: '/tmp/inexistente/foto1.jpg',
    ));
    // cálculo persistido com hashes (RQ-04)
    final r = MrvCalcService.calcularParcela(
      plantas: [
        Planta(
          id: 1,
          uuid: 'pl1',
          parcelaUuid: 'p1',
          especie: 'Eucalipto',
          alturaCm: 1500,
          dapCm: 22.5,
          categoria: 1,
          synced: false,
          fotoEspeciePath: null,
          fotoAusente: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          deletedAt: null,
          serverPlantaId: null,
          parcelaServerId: null,
          arquivoEstado: 'capturado',
          enviadoVerificadoEm: null,
        ),
      ],
      areaM2: 400,
    );
    await MrvCalcService.persistirCalculo(
        db: db, parcelaUuid: 'p1', resultado: r, areaM2: 400);
    await db.logTrilha(
        acao: 'create', entidadeTipo: 'parcela', entidadeUuid: 'p1', origem: 'app');

    final zipPath = await DossieService.gerarDossieParcela(
      db,
      'p1',
      serverChainStatus: null,
    );
    final zipFile = io.File(zipPath);
    expect(await zipFile.exists(), isTrue);

    final zip = ZipDecoder().decodeBytes(await zipFile.readAsBytes());
    final nomes = zip.map((f) => f.name).toList();
    expect(nomes, containsAll(['manifesto.json', 'dados.json', 'dossie.pdf']));

    // manifesto: hash de cada arquivo bate com o conteúdo real do zip
    final manifestoFile = zip.firstWhere((f) => f.name == 'manifesto.json');
    final manifesto =
        jsonDecode(utf8.decode(manifestoFile.content as List<int>)) as Map<String, dynamic>;
    final arquivos = manifesto['arquivos'] as Map<String, dynamic>;
    for (final f in zip) {
      if (f.name == 'manifesto.json') continue; // o manifesto não se auto-hasha
      final esperado = arquivos[f.name]['sha256'] as String;
      final real = sha256.convert(f.content as List<int>).toString();
      expect(real, esperado, reason: 'hash divergente em ${f.name}');
    }

    // dados.json traz cálculo com hashes e a trilha
    final dadosFile = zip.firstWhere((f) => f.name == 'dados.json');
    final dados =
        jsonDecode(utf8.decode(dadosFile.content as List<int>)) as Map<String, dynamic>;
    final calcs = dados['calculos_mrv'] as List;
    expect(calcs, hasLength(1));
    expect(calcs.first['insumos_hash'], isNotNull);
    expect((calcs.first['resultado'] as Map)['resultado_hash'], isNotNull);
    expect(dados['trilha'], hasLength(1));
    expect(dados['verificacao']['cadeia_local'], 'INTEGRA');

    // PDF começa com %PDF
    final pdf = zip.firstWhere((f) => f.name == 'dossie.pdf');
    final head = utf8.decode((pdf.content as List<int>).sublist(0, 5));
    expect(head, '%PDF-');
  });
}
