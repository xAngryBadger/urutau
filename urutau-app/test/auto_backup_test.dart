// ============================================================
// auto_backup_test.dart — t19 fase 2: backup automático antes de update.
//
// Prova o guarda da fase 2:
//   A. versionCode subiu (3 -> 4) => dispara backup; o ZIP capturado no sink
//      "externo" (Downloads) restaura tudo (round-trip: wipe -> restore ->
//      COUNT(*) bate e fotos voltam).
//   B. mesma versão (4 -> 4) => NÃO dispara.
//   C. primeiro boot com banco existente (update de versão pré-feature,
//      sem lastVersionCode) => dispara.
//   D. instalação nova (sem banco, sem lastVersionCode) => NÃO dispara, só marca.
//   E. sink externo falha => fallback dentro do sandbox (backups/), ainda marca.
// ============================================================

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:urutau/data/database.dart';
import 'package:urutau/services/auto_backup_service.dart';
import 'package:urutau/services/backup_service.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);
  final String root;
  @override
  Future<String?> getTemporaryPath() async => p.join(root, 'tmp');
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getApplicationSupportPath() async => p.join(root, 'support');
  @override
  Future<String?> getApplicationLibraryPath() async => p.join(root, 'lib');
  @override
  Future<String?> getExternalStoragePath() async => null;
  @override
  Future<List<String>?> getExternalCachePaths() async => null;
  @override
  Future<List<String>?> getExternalStoragePaths({StorageDirectory? type}) async => null;
  @override
  Future<String?> getDownloadsPath() async => null; // força fallback no teste E
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late String dbPath;
  late String fotosPath;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('urutau_ab_');
    PathProviderPlatform.instance = _FakePathProvider(dir.path);
    SharedPreferences.setMockInitialValues({});
    dbPath = p.join(dir.path, 'urutau.sqlite');
    fotosPath = p.join(dir.path, 'fotos');

    final db = AppDatabase.forTesting(NativeDatabase(File(dbPath)));
    await db.customSelect('SELECT 1').get();
    await db.customStatement(
        "INSERT INTO usuarios (uuid, nome, email, senha) VALUES ('u-ab-1','AB','ab@x.local','salt:hash')");
    await db.customStatement(
        "INSERT INTO parcelas (uuid, prop_ut, id_parcela, user_id) VALUES ('p-ab-1','P1 - UT1',1,'u-ab-1')");
    await db.customStatement(
        "INSERT INTO plantas (uuid, parcela_uuid, especie, altura_cm, categoria) VALUES ('pl-ab-1','p-ab-1','Eucalyptus',10.5,1)");
    await db.customStatement(
        "INSERT INTO fotos_parcela (uuid, parcela_uuid, file_path) VALUES ('f-ab-1','p-ab-1','fotos/foto1.jpg')");
    await db.close();

    final fotos = Directory(fotosPath);
    await fotos.create(recursive: true);
    await File(p.join(fotosPath, 'foto1.jpg')).writeAsBytes([9, 8, 7, 6]);
  });

  tearDown(() async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  });

  Map<String, int> counts(String path) {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      int c(String sql) => db.select(sql).first['c'] as int;
      return {
        'usuarios': c("SELECT COUNT(*) c FROM usuarios WHERE uuid='u-ab-1'"),
        'parcelas': c("SELECT COUNT(*) c FROM parcelas WHERE uuid='p-ab-1'"),
        'plantas': c("SELECT COUNT(*) c FROM plantas WHERE uuid='pl-ab-1'"),
        'fotos_parcela': c("SELECT COUNT(*) c FROM fotos_parcela WHERE uuid='f-ab-1'"),
      };
    } finally {
      db.dispose();
    }
  }

  int fotosNoDisco() {
    final d = Directory(fotosPath);
    if (!d.existsSync()) return 0;
    return d.listSync(recursive: true).whereType<File>().length;
  }

  group('t19 fase 2: backup automático no versionCode novo', () {
    test('A. versionCode 3->4 dispara backup e o ZIP restaura tudo', () async {
      final antes = counts(dbPath);
      expect(fotosNoDisco(), 1);
      SharedPreferences.setMockInitialValues({'auto_backup_last_version_code': 3});

      final capturado = <String, List<int>>{};
      final fez = await AutoBackupService.backupIfVersionChanged(
        versionCode: 4,
        saveExternal: (fileName, bytes) async {
          capturado[fileName] = bytes;
          return '/Download/Urutau/$fileName'; // simula MediaStore
        },
      );

      expect(fez, true, reason: 'versionCode subiu tem de disparar backup');
      expect(capturado.length, 1);
      expect(capturado.keys.single, contains('v4'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('auto_backup_last_version_code'), 4);

      // o ZIP capturado tem banco + fotos + manifesto
      final zip = capturado.values.single;
      expect(zip[0], 0x50, reason: 'ZIP começa com PK');
      expect(utf8.decode(zip.sublist(0, 2)), 'PK');

      // round-trip do backup automático: apaga tudo e restaura do ZIP
      for (final sufixo in ['', '-wal', '-shm']) {
        final f = File(dbPath + sufixo);
        if (await f.exists()) await f.delete();
      }
      await Directory(fotosPath).delete(recursive: true);

      final msg = await BackupService.prepareRestoreFromBytes(zip);
      expect(msg, contains('Restauração marcada'));
      await BackupService.runPendingRestore();

      expect(counts(dbPath), antes, reason: 'COUNT(*) depois de restaurar o backup automático tem de bater');
      expect(fotosNoDisco(), 1, reason: 'a foto tem de voltar do ZIP para o disco');
      expect(await File(p.join(fotosPath, 'foto1.jpg')).readAsBytes(), [9, 8, 7, 6]);
    });

    test('B. mesma versão (4->4) não dispara', () async {
      SharedPreferences.setMockInitialValues({'auto_backup_last_version_code': 4});
      var chamadas = 0;
      final fez = await AutoBackupService.backupIfVersionChanged(
        versionCode: 4,
        saveExternal: (f, b) async {
          chamadas++;
          return '/x/$f';
        },
      );
      expect(fez, false);
      expect(chamadas, 0);
    });

    test('C. update de versão pré-feature (sem lastVersionCode, com banco) dispara', () async {
      SharedPreferences.setMockInitialValues({}); // sem chave = app antigo
      final capturado = <String, List<int>>{};
      final fez = await AutoBackupService.backupIfVersionChanged(
        versionCode: 4,
        saveExternal: (f, b) async {
          capturado[f] = b;
          return '/Download/Urutau/$f';
        },
      );
      expect(fez, true, reason: 'banco existente + sem versão registada = update: tem de fazer backup');
      expect(capturado.length, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('auto_backup_last_version_code'), 4);
    });

    test('D. instalação nova (sem banco, sem lastVersionCode) só marca, sem backup', () async {
      // apaga o banco da fixture
      for (final sufixo in ['', '-wal', '-shm']) {
        final f = File(dbPath + sufixo);
        if (await f.exists()) await f.delete();
      }
      SharedPreferences.setMockInitialValues({});
      var chamadas = 0;
      final fez = await AutoBackupService.backupIfVersionChanged(
        versionCode: 4,
        saveExternal: (f, b) async {
          chamadas++;
          return '/x/$f';
        },
      );
      expect(fez, false);
      expect(chamadas, 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('auto_backup_last_version_code'), 4,
          reason: 'instalação nova marca a versão para a próxima comparar');
    });

    test('E. sink externo falha => fallback no sandbox (backups/) e marca versão', () async {
      SharedPreferences.setMockInitialValues({'auto_backup_last_version_code': 3});
      // sem saveExternal injetado: canal não existe no teste -> getDownloadsPath null -> null
      final fez = await AutoBackupService.backupIfVersionChanged(versionCode: 4);
      expect(fez, true);
      final fallback = File(p.join(dir.path, 'backups', 'urutau_backup_auto_v4.zip'));
      expect(fallback.existsSync(), true,
          reason: 'fallback tem de gravar em <docs>/backups/');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('auto_backup_last_version_code'), 4);
    });
  });
}
