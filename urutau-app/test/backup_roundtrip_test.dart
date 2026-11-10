// ============================================================
// backup_roundtrip_test.dart — BURACO 3 da bateria adversária
// (docs/adversario-handshake.md §3): round-trip real do backup.
//
// Cobre, com o BackupService REAL (só path_provider e
// SharedPreferences mockados para um diretório temporário):
//   1. round-trip: export -> wipe -> restore -> COUNT(*) bate e fotos voltam
//   2. ZIP corrompido (truncado) -> falha limpa, banco intacto
//   3. F-3b CORRIGIDO (t19): ficheiro raw que não é ZIP nem SQLite é
//      REJEITADO limpo em prepareRestoreFromBytes (backup_service.dart
//      _stagePendingDb: cabeçalho + integrity_check + tabelas) — banco intacto
//   4. manifesto com schemaVersion futuro -> rejeitado limpo
//   5. schema antigo (v31) -> restaura, migra para v32 no reabrir
//   6. F-3a CORRIGIDO (t19): manifesto v31 (<= schema real 32) é ACEITE
//   7. restaurar com o app ABERTO: prepareRestore enquanto a conexão drift
//      está viva não corrompe nada; a aplicação só acontece no boot
//   8. trava F-3a: BackupService.currentSchemaVersion == AppDatabase.schemaVersion
// ============================================================

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:urutau/data/database.dart';
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
  Future<String?> getDownloadsPath() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late String dbPath;
  late String fotosPath;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('urutau_rt_');
    PathProviderPlatform.instance = _FakePathProvider(dir.path);
    SharedPreferences.setMockInitialValues({});
    dbPath = p.join(dir.path, 'urutau.sqlite');
    fotosPath = p.join(dir.path, 'fotos');

    final db = AppDatabase.forTesting(NativeDatabase(File(dbPath)));
    await db.customSelect('SELECT 1').get();
    await db.customStatement(
        "INSERT INTO usuarios (uuid, nome, email, senha) VALUES ('u-adv-1','Adv A','adv@x.local','salt:hash')");
    await db.customStatement(
        "INSERT INTO parcelas (uuid, prop_ut, id_parcela, user_id) VALUES ('p-adv-1','P1 - UT1',1,'u-adv-1'),('p-adv-2','P1 - UT1',2,'u-adv-1')");
    await db.customStatement(
        "INSERT INTO plantas (uuid, parcela_uuid, especie, altura_cm, categoria) VALUES ('pl-adv-1','p-adv-1','Eucalyptus',10.5,1),('pl-adv-2','p-adv-1','Eucalyptus',11.0,2),('pl-adv-3','p-adv-2','Pinus',9.0,1)");
    await db.customStatement(
        "INSERT INTO fotos_parcela (uuid, parcela_uuid, file_path) VALUES ('f-adv-1','p-adv-1','fotos/foto1.jpg'),('f-adv-2','p-adv-2','fotos/foto2.jpg')");
    await db.close();

    final fotos = Directory(fotosPath);
    await fotos.create(recursive: true);
    await File(p.join(fotosPath, 'foto1.jpg')).writeAsBytes([1, 2, 3, 4]);
    await File(p.join(fotosPath, 'foto2.jpg')).writeAsBytes([5, 6, 7, 8]);
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
        'usuarios': c("SELECT COUNT(*) c FROM usuarios WHERE uuid='u-adv-1'"),
        'parcelas': c("SELECT COUNT(*) c FROM parcelas WHERE uuid IN ('p-adv-1','p-adv-2')"),
        'plantas': c("SELECT COUNT(*) c FROM plantas WHERE uuid LIKE 'pl-adv-%'"),
        'fotos_parcela': c("SELECT COUNT(*) c FROM fotos_parcela WHERE uuid LIKE 'f-adv-%'"),
        'total_parcelas': c('SELECT COUNT(*) c FROM parcelas'),
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

  Future<List<int>> exportaZip() async {
    // Share.shareXFiles lança MissingPluginException no teste -> o catch do
    // exportBackup devolve 'Erro ao exportar...', MAS o ZIP já foi gravado no
    // diretório de documentos (fake) e não é apagado. É esse o ficheiro real.
    await BackupService.exportBackup();
    final zip = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.zip'))
        .toList();
    expect(zip, isNotEmpty, reason: 'exportBackup tem de gravar o ZIP no disco');
    return zip.first.readAsBytesSync();
  }

  Future<void> wipe() async {
    for (final sufixo in ['', '-wal', '-shm']) {
      final f = File(dbPath + sufixo);
      if (await f.exists()) await f.delete();
    }
    final fotos = Directory(fotosPath);
    if (fotos.existsSync()) await fotos.delete(recursive: true);
    final pend = File(p.join(dir.path, 'restore_pending.sqlite'));
    if (await pend.exists()) await pend.delete();
  }

  List<int> rebuildZip(List<int> zipBytes,
      {int? schemaVersion, int? userVersion}) {
    final entrada = ZipDecoder().decodeBytes(zipBytes);
    final saida = Archive();
    for (final f in entrada) {
      if (f.name == 'manifest.json' && schemaVersion != null) {
        final m =
            jsonDecode(String.fromCharCodes(f.content as List<int>))
                as Map<String, dynamic>;
        m['schemaVersion'] = schemaVersion;
        final b = utf8.encode(jsonEncode(m));
        final nf = ArchiveFile('manifest.json', b.length, b);
        nf.compress = true;
        saida.addFile(nf);
      } else if (f.name == 'urutau.sqlite' && userVersion != null) {
        final inner = File(p.join(dir.path, 'inner.sqlite'));
        inner.writeAsBytesSync(f.content as List<int>);
        final d = sqlite3.open(inner.path);
        d.execute('PRAGMA user_version = $userVersion');
        d.dispose();
        final b = inner.readAsBytesSync();
        inner.deleteSync();
        final nf = ArchiveFile('urutau.sqlite', b.length, b);
        nf.compress = true;
        saida.addFile(nf);
      } else {
        saida.addFile(f);
      }
    }
    return ZipEncoder().encode(saida)!;
  }

  group('buraco 3: round-trip do backup', () {
    test('1. export -> wipe -> restore: COUNT(*) bate e as fotos voltam', () async {
      final antes = counts(dbPath);
      final fotosAntes = fotosNoDisco();
      expect(fotosAntes, 2);

      final zipBytes = await exportaZip();

      // O ZIP contém banco + manifesto + fotos?
      final arch = ZipDecoder().decodeBytes(zipBytes);
      expect(arch.findFile('urutau.sqlite'), isNotNull);
      final manifest = jsonDecode(String.fromCharCodes(
          arch.findFile('manifest.json')!.content as List<int>));
      expect(manifest['parcelaCount'], antes['total_parcelas'],
          reason: 'manifesto conta parcelas não apagadas (inclui catálogo seed: 72 + 2)');
      expect(manifest['photoCount'], 2);
      expect(arch.where((f) => f.name.startsWith('fotos/')).length, 2,
          reason: 'as fotos têm de estar DENTRO do ZIP');

      await wipe();
      expect(File(dbPath).existsSync(), isFalse);
      expect(fotosNoDisco(), 0);

      final msg = await BackupService.prepareRestoreFromBytes(zipBytes);
      expect(msg, contains('Restauração marcada'));
      await BackupService.runPendingRestore();

      final depois = counts(dbPath);
      expect(depois, antes,
          reason: 'COUNT(*) depois do restore tem de bater com o de antes');
      expect(fotosNoDisco(), fotosAntes);
      expect(await File(p.join(fotosPath, 'foto1.jpg')).readAsBytes(), [1, 2, 3, 4]);
      expect(await File(p.join(fotosPath, 'foto2.jpg')).readAsBytes(), [5, 6, 7, 8]);

      // O banco restaurado abre com o drift (migrações/beforeOpen rodam sem erro).
      final db2 = AppDatabase.forTesting(NativeDatabase(File(dbPath)));
      await db2.customSelect('SELECT 1').get();
      await db2.close();
    });

    test('2. ZIP corrompido (truncado a meio) falha limpo e não toca no banco',
        () async {
      final antes = counts(dbPath);
      final zipBytes = await exportaZip();
      final truncado = zipBytes.sublist(0, zipBytes.length ~/ 2);

      final msg = await BackupService.prepareRestoreFromBytes(truncado);
      expect(msg, isNot(contains('Restauração marcada')),
          reason: 'ZIP corrompido não pode ser aceite');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('pending_restore'), isNot(true));
      expect(
          File(p.join(dir.path, 'restore_pending.sqlite')).existsSync(), isFalse,
          reason: 'nada pode ficar pendente depois de falhar');
      expect(counts(dbPath), antes, reason: 'o banco atual tem de continuar intacto');
    });

    test('3. F-3b corrigido (t19): raw que não é ZIP nem SQLite é rejeitado limpo', () async {
      final antes = counts(dbPath);
      // backup_service.dart _stagePendingDb: valida cabeçalho SQLite +
      // integrity_check + tabelas ANTES de gravar o pending.
      final bytes = utf8.encode('isto nao e um zip nem um banco sqlite');
      final msg = await BackupService.prepareRestoreFromBytes(bytes);
      expect(msg, contains('não é um backup válido'),
          reason: 'F-3b fix: raw inválido tem de ser rejeitado');
      expect(msg, isNot(contains('Restauração marcada')));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('pending_restore'), isNot(true));
      expect(File(p.join(dir.path, 'restore_pending.sqlite')).existsSync(), isFalse,
          reason: 'nada pode ficar pendente depois de falhar');
      expect(counts(dbPath), antes, reason: 'o banco atual tem de continuar intacto');
    });

    test('3b. F-3b: SQLite válido mas corrompido (integrity falha) também é rejeitado', () async {
      final antes = counts(dbPath);
      final zipBytes = await exportaZip();
      final arch = ZipDecoder().decodeBytes(zipBytes);
      final raw = (arch.findFile('urutau.sqlite')!.content as List<int>);
      // corrompe o meio do arquivo: cabeçalho OK, conteúdo quebrado
      final corrompido = raw.sublist(0, raw.length ~/ 2);
      final msg = await BackupService.prepareRestoreFromBytes(corrompido);
      expect(msg, isNot(contains('Restauração marcada')));
      expect(counts(dbPath), antes);
    });

    test('4. manifesto com schemaVersion futuro (99) é rejeitado limpo', () async {
      final antes = counts(dbPath);
      final zipBytes = await exportaZip();
      final futuro = rebuildZip(zipBytes, schemaVersion: 99);

      final msg = await BackupService.prepareRestoreFromBytes(futuro);
      expect(msg, contains('Atualize o app'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('pending_restore'), isNot(true));
      expect(counts(dbPath), antes);
    });

    test('5. schema antigo restaura e o drift migra no reabrir (manifest v24, banco v31)',
        () async {
      final antes = counts(dbPath);
      final zipBytes = await exportaZip();
      // Manifest v24 passa na validação (<=25); user_version 31 no sqlite faz
      // o drift rodar onUpgrade 31->32 (a parte v32 é idempotente — verifica a
      // coluna antes de adicionar). Um manifesto v31 REAL seria hoje rejeitado
      // pela constante desatualizada — isso é o ACHADO F-3a, no teste 6.
      final antigo = rebuildZip(zipBytes, schemaVersion: 24, userVersion: 31);

      await wipe();
      final msg = await BackupService.prepareRestoreFromBytes(antigo);
      expect(msg, contains('Migrações serão aplicadas'));
      await BackupService.runPendingRestore();

      expect(counts(dbPath), antes);

      // Reabrir com o drift: onUpgrade 31->32 roda sem erro e sobe a versão.
      final db2 = AppDatabase.forTesting(NativeDatabase(File(dbPath)));
      await db2.customSelect('SELECT 1').get();
      await db2.close();
      final raw = sqlite3.open(dbPath, mode: OpenMode.readOnly);
      final uv = raw.select('PRAGMA user_version').first.values.first;
      raw.dispose();
      expect(uv, 32, reason: 'depois de reabrir, user_version tem de ser 32');
    });

    test('6. F-3a corrigido (t19): manifesto v31 (<= schema real) é aceite', () async {
      // _currentSchemaVersion agora é 32 (database.dart:234). Um backup de
      // app real (manifest v31) tem de ser aceite neste app.
      final antes = counts(dbPath);
      final zipBytes = await exportaZip();
      final antigo = rebuildZip(zipBytes, schemaVersion: 31);

      final msg = await BackupService.prepareRestoreFromBytes(antigo);
      expect(msg, contains('Restauração marcada'),
          reason: 'F-3a fix: v31 <= 32 tem de passar na validação');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('pending_restore'), true);
      await BackupService.runPendingRestore();
      expect(counts(dbPath), antes, reason: 'restore aplicado e banco bate');
    });

    test('7. restaurar com o app ABERTO: prepare com conexão viva não corrompe; aplica só no boot',
        () async {
      final antes = counts(dbPath);
      final zipBytes = await exportaZip();

      // app "aberto": conexão drift viva sobre o banco atual
      final dbAberto = AppDatabase.forTesting(NativeDatabase(File(dbPath)));
      await dbAberto.customSelect('SELECT 1').get();

      final msg = await BackupService.prepareRestoreFromBytes(zipBytes);
      expect(msg, contains('Restauração marcada'));
      // banco atual continua são e legível com a conexão aberta
      expect(counts(dbPath), antes);
      await dbAberto.customSelect('SELECT 1').get();
      await dbAberto.close();

      // boot seguinte: runPendingRestore aplica o pendente (wipe manual sem
      // tocar no restore_pending.sqlite que acabou de ser preparado)
      for (final sufixo in ['', '-wal', '-shm']) {
        final f = File(dbPath + sufixo);
        if (await f.exists()) await f.delete();
      }
      final fotos = Directory(fotosPath);
      if (fotos.existsSync()) await fotos.delete(recursive: true);
      await BackupService.runPendingRestore();
      expect(counts(dbPath), antes);
    });

    test('8. trava F-3a: constante do manifesto == schemaVersion real do AppDatabase', () async {
      final db = AppDatabase.forTesting(NativeDatabase(File(p.join(dir.path, 'verifica.sqlite'))));
      expect(BackupService.currentSchemaVersion, db.schemaVersion,
          reason: 'se alguém subir o schema e esquecer a constante, este teste falha');
      await db.close();
    });
  });
}
