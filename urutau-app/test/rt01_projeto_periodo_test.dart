// RT-01/RC-11: parcela persiste projeto, período e protocolo (SOP)
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urutau/data/database.dart';

void main() {
  test('parcela grava projetoUuid/periodoUuid/protocoloVersao e relê', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
    addTearDown(db.close);

    await db.insertParcela(ParcelasCompanion.insert(
      uuid: 'p1',
      propriedade: const drift.Value('Faz X'),
      propUt: 'UT-01',
      idParcela: 1,
      userId: 'u1',
      protocoloVersao: const drift.Value('SOP-MRV-V1'),
      projetoUuid: const drift.Value('LEGADO-PROJ'),
      periodoUuid: const drift.Value('LEGADO-PER-0000'),
    ));

    final p = await db.getParcelaByUuid('p1');
    expect(p, isNotNull);
    expect(p!.protocoloVersao, 'SOP-MRV-V1'); // RC-11
    expect(p.projetoUuid, 'LEGADO-PROJ'); // RT-01
    expect(p.periodoUuid, 'LEGADO-PER-0000'); // RT-01

    // update preserva/víncula de novo
    await db.updateParcela(
      ParcelasCompanion(
        projetoUuid: const drift.Value('PROJ-2'),
        periodoUuid: const drift.Value('PER-2026-1'),
      ),
      'p1',
    );
    final p2 = await db.getParcelaByUuid('p1');
    expect(p2!.projetoUuid, 'PROJ-2');
    expect(p2.periodoUuid, 'PER-2026-1');
    expect(p2.protocoloVersao, 'SOP-MRV-V1'); // não some no update
  });
}
