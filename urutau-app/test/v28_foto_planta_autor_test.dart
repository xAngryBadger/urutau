// v28 MRV: cada foto/medição com GPS + dono (promessa do pitch ao cliente)
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urutau/data/database.dart';

void main() {
  group('v28: fotos e plantas com GPS/dono', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.customSelect('SELECT 1').get();
    });

    tearDown(() async => db.close());

    test('foto nasce com latitude/longitude/autorUuid', () async {
      await db.insertParcela(ParcelasCompanion.insert(
        uuid: 'p1',
        propriedade: drift.Value('Faz X'),
        propUt: 'UT01',
        idParcela: 1,
        userId: 'u1',
      ));
      await db.insertFotoParcela(FotosParcelaCompanion(
        uuid: drift.Value('f1'),
        parcelaUuid: drift.Value('p1'),
        filePath: drift.Value('/tmp/f1.jpg'),
        latitude: drift.Value(-23.5),
        longitude: drift.Value(-46.6),
        autorUuid: drift.Value('u1'),
      ));
      final f = await (db.select(db.fotosParcela)..where((t) => t.uuid.equals('f1'))).getSingle();
      expect(f.latitude, -23.5);
      expect(f.longitude, -46.6);
      expect(f.autorUuid, 'u1');
    });

    test('planta nasce com autorUuid', () async {
      await db.insertParcela(ParcelasCompanion.insert(
        uuid: 'p1',
        propriedade: drift.Value('Faz X'),
        propUt: 'UT01',
        idParcela: 1,
        userId: 'u1',
      ));
      await db.insertPlanta(PlantasCompanion.insert(
        uuid: 'pl1',
        parcelaUuid: 'p1',
        especie: 'Ipê',
        alturaCm: 150,
        categoria: 1,
        autorUuid: drift.Value('u1'),
      ));
      final p = await (db.select(db.plantas)..where((t) => t.uuid.equals('pl1'))).getSingle();
      expect(p.autorUuid, 'u1');
    });

    test('updateFotoParcelaCampos aplica GPS/dono vindos do servidor (fotos_meta)', () async {
      await db.insertParcela(ParcelasCompanion.insert(
        uuid: 'p1',
        propriedade: drift.Value('Faz X'),
        propUt: 'UT01',
        idParcela: 1,
        userId: 'u1',
      ));
      await db.insertFotoParcela(FotosParcelaCompanion(
        uuid: drift.Value('f1'),
        parcelaUuid: drift.Value('p1'),
        filePath: drift.Value('/tmp/f1.jpg'),
      ));
      await db.updateFotoParcelaCampos('f1',
          latitude: -22.9, longitude: -47.1, autorUuid: 'u9');
      final f = await (db.select(db.fotosParcela)..where((t) => t.uuid.equals('f1'))).getSingle();
      expect(f.latitude, -22.9);
      expect(f.longitude, -47.1);
      expect(f.autorUuid, 'u9');
    });
  });
}
