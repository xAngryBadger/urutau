// RC-04 pós-upload: sha256_verificado grava no ativo depois do sync dar certo
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urutau/data/database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('marcarAtivosVerificadosDaParcela liga sha256_verificado só onde há hash',
      () async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
    addTearDown(db.close);

    await db.insertParcela(ParcelasCompanion.insert(
      uuid: 'p1',
      propriedade: const drift.Value('Faz X'),
      propUt: 'UT-01',
      idParcela: 1,
      userId: 'u1',
    ));
    // foto com hash registrado no catálogo
    await db.insertFotoParcela(FotosParcelaCompanion.insert(
      uuid: 'foto-1',
      parcelaUuid: 'p1',
      filePath: '/tmp/f1.jpg',
    ));
    await db.registrarHashDoAtivo(
      ativoUuid: 'legado-ativo-foto-1',
      sha256: 'abc123',
    );
    // ativo sem hash (pendente) — não pode ser marcado
    await db.registrarFotoCatalogo(
      objetoUuid: 'foto-2',
      entidadeTipo: 'parcela',
      entidadeUuid: 'p1',
      caminhoOriginal: '/tmp/f2.jpg',
      capturadoEm: DateTime.now(),
    );

    await db.marcarAtivosVerificadosDaParcela('p1');

    final comHash = await (db.select(db.ativosBrutos)
          ..where((t) => t.uuid.equals('legado-ativo-foto-1')))
        .getSingle();
    expect(comHash.sha256Verificado, isTrue); // pós-upload verificado
    expect(comHash.status, 'presente');

    final semHash = await (db.select(db.ativosBrutos)
          ..where((t) => t.uuid.equals('legado-ativo-foto-2')))
        .getSingle();
    expect(semHash.sha256Verificado, isFalse); // sem hash não marca
  });
}
