// RC-13/RC-14: dispositivo registrado e ativo nasce com dispositivo + EXIF
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urutau/data/database.dart';
import 'package:urutau/services/device_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('DeviceService: uuid estável, registra na tabela e é idempotente', () async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
    addTearDown(db.close);

    final u1 = await DeviceService.registrarDispositivo(db);
    final u2 = await DeviceService.registrarDispositivo(db);
    expect(u1, u2); // mesmo uuid nas duas chamadas
    expect(await DeviceService.uuidAtual(), u1);

    final todos = await db.select(db.dispositivos).get();
    expect(todos, hasLength(1)); // idempotente: não duplica
    expect(todos.first.uuid, u1);
    expect(todos.first.identificador, isNotEmpty);
    expect(todos.first.so, isNotEmpty);
    expect(todos.first.versaoApp, DeviceService.appVersion);
  });

  test('ativo novo nasce com dispositivoUuid e exifPreservado=true (RC-13/14)',
      () async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
    addTearDown(db.close);

    final disp = await DeviceService.registrarDispositivo(db);
    await db.registrarFotoCatalogo(
      objetoUuid: 'foto-1',
      entidadeTipo: 'parcela',
      entidadeUuid: 'p1',
      caminhoOriginal: '/tmp/foto1.jpg',
      capturadoEm: DateTime.now(),
    );

    final ativo = await (db.select(db.ativosBrutos)
          ..where((t) => t.uuid.equals('legado-ativo-foto-1')))
        .getSingle();
    expect(ativo.dispositivoUuid, disp); // RC-13: quem registrou
    expect(ativo.exifPreservado, isTrue); // RC-14: bytes originais (copy)
  });
}
