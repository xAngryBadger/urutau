import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:sqlite3/sqlite3.dart';
import 'image_service.dart';

class BackupService {
  static const String _dbName = 'urutau';
  static const int _currentSchemaVersion = 16;
  static const String _pendingRestoreKey = 'pending_restore';
  static const String _pendingRestorePathKey = 'pending_restore_path';
  static const String _pendingRestoreFotosKey = 'pending_restore_fotos_path';
  static const String _preRestoreDbKey = 'pre_restore_db_path';
  static const String _preRestoreFotosKey = 'pre_restore_fotos_path';
  static const String _preRestoreCleanupKey = 'pre_restore_cleanup_needed';

  static Future<String> get _dbPath async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, '$_dbName.sqlite');
  }

  static bool _isZipFile(List<int> bytes) {
    return bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B;
  }

  static ({bool ok, String? error}) _validateManifest(String manifestJson) {
    try {
      final map = jsonDecode(manifestJson) as Map<String, dynamic>;
      final schemaVersion = map['schemaVersion'];
      if (schemaVersion == null) {
        return (ok: false, error: 'manifesto sem schemaVersion.');
      }
      final version = schemaVersion is int ? schemaVersion : int.tryParse(schemaVersion.toString());
      if (version == null) {
        return (ok: false, error: 'schemaVersion inválido no manifesto.');
      }
      if (version > _currentSchemaVersion) {
        return (ok: false, error: 'Backup requer schema v$version mas o app usa v$_currentSchemaVersion. Atualize o app.');
      }
      return (ok: true, error: null);
    } catch (e) {
      return (ok: false, error: 'Erro ao parsear manifesto: $e');
    }
  }

  static Future<void> runPendingRestore() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_pendingRestorePathKey);
    if (path == null || path.isEmpty) return;
    prefs.remove(_pendingRestorePathKey);
    prefs.setBool(_pendingRestoreKey, false);

    final backupFile = File(path);
    if (!await backupFile.exists()) return;

    final targetPath = await _dbPath;
    final target = File(targetPath);
    await backupFile.copy(target.path);
    try {
      await backupFile.delete();
    } catch (_) {}

    final fotosPendingPath = prefs.getString(_pendingRestoreFotosKey);
    if (fotosPendingPath != null && fotosPendingPath.isNotEmpty) {
      prefs.remove(_pendingRestoreFotosKey);
      final fotosPendingDir = Directory(fotosPendingPath);
      if (await fotosPendingDir.exists()) {
        final fotosDir = await ImageService.getPhotosDir();
        if (fotosDir.existsSync()) {
          try {
            await fotosDir.delete(recursive: true);
          } catch (_) {}
        }
        try {
          await fotosPendingDir.rename(fotosDir.path);
        } catch (_) {
          try {
            await fotosDir.create(recursive: true);
            await for (final entity in fotosPendingDir.list(recursive: true)) {
              if (entity is File) {
                final relative = p.relative(entity.path, from: fotosPendingDir.path);
                final destFile = File(p.join(fotosDir.path, relative));
                await destFile.parent.create(recursive: true);
                await entity.copy(destFile.path);
              }
            }
            await fotosPendingDir.delete(recursive: true);
          } catch (_) {}
        }
      }
    }

    final preRestoreDb = prefs.getString(_preRestoreDbKey);
    final preRestoreFotos = prefs.getString(_preRestoreFotosKey);
    if (preRestoreDb != null || preRestoreFotos != null) {
      await prefs.setBool(_preRestoreCleanupKey, true);
    }

    debugPrint('BackupService: restauração aplicada a $targetPath');
  }

  static Future<void> cleanPreRestoreFiles() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    final needed = prefs.getBool(_preRestoreCleanupKey) ?? false;
    if (!needed) return;

    final preRestoreDb = prefs.getString(_preRestoreDbKey);
    if (preRestoreDb != null) {
      prefs.remove(_preRestoreDbKey);
      try {
        final file = File(preRestoreDb);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }

    final preRestoreFotos = prefs.getString(_preRestoreFotosKey);
    if (preRestoreFotos != null) {
      prefs.remove(_preRestoreFotosKey);
      try {
        final dir = Directory(preRestoreFotos);
        if (await dir.exists()) await dir.delete(recursive: true);
      } catch (_) {}
    }

    prefs.remove(_preRestoreCleanupKey);
    debugPrint('BackupService: ficheiros pre-restore limpos.');
  }

  static Future<String> exportBackup() async {
    if (kIsWeb) return 'Backup não disponível na versão web.';
    try {
      final sourcePath = await _dbPath;
      final source = File(sourcePath);
      if (!await source.exists()) {
        return 'Base de dados não encontrada.';
      }

      try {
        final db = sqlite3.open(sourcePath, mode: OpenMode.readOnly);
        db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
        db.dispose();
      } catch (e) {
        debugPrint('BackupService: WAL checkpoint falhou (não crítico): $e');
      }

      final archive = Archive();

      final dbBytes = await source.readAsBytes();
      final dbFile = ArchiveFile('urutau.sqlite', dbBytes.length, dbBytes);
      dbFile.compress = true;
      archive.addFile(dbFile);

      final photosDir = await ImageService.getPhotosDir();
      int photoCount = 0;
      if (await photosDir.exists()) {
        await for (final entity in photosDir.list(recursive: true)) {
          if (entity is File) {
            final relative = p.relative(entity.path, from: photosDir.path);
            final archivePath = 'fotos/$relative';
            final photoBytes = await entity.readAsBytes();
            final photoFile = ArchiveFile(archivePath, photoBytes.length, photoBytes);
            final ext = p.extension(entity.path).toLowerCase();
            photoFile.compress = !(ext == '.jpg' || ext == '.jpeg');
            archive.addFile(photoFile);
            photoCount++;
          }
        }
      }

      int parcelaCount = 0;
      int plantaCount = 0;
      try {
        final db = sqlite3.open(sourcePath, mode: OpenMode.readOnly);
        final parcelaResult = db.select('SELECT COUNT(*) AS cnt FROM parcelas WHERE deleted_at IS NULL');
        parcelaCount = parcelaResult.first['cnt'] as int;
        final plantaResult = db.select('SELECT COUNT(*) AS cnt FROM plantas WHERE deleted_at IS NULL');
        plantaCount = plantaResult.first['cnt'] as int;
        db.dispose();
      } catch (e) {
        debugPrint('BackupService: erro ao contar registros: $e');
      }

      final manifest = jsonEncode({
        'schemaVersion': _currentSchemaVersion,
        'appVersion': '2.0.0',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'photoCount': photoCount,
        'parcelaCount': parcelaCount,
        'plantaCount': plantaCount,
      });
      final manifestBytes = utf8.encode(manifest);
      final manifestFile = ArchiveFile('manifest.json', manifestBytes.length, manifestBytes);
      manifestFile.compress = true;
      archive.addFile(manifestFile);

      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) {
        return 'Erro ao criar ZIP.';
      }

      final dir = await getApplicationDocumentsDirectory();
      final now = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
      final fileName = 'urutau_backup_$now.zip';
      final destPath = p.join(dir.path, fileName);
      final dest = File(destPath);
      await dest.writeAsBytes(zipBytes);

      await Share.shareXFiles(
        [XFile(dest.path)],
        subject: 'Backup Urutau',
        text: 'Guarde este ficheiro. Pode usar "Restaurar de backup" no app após reinstalar.',
      );
      try {
        await dest.delete();
      } catch (_) {}
      return 'Backup partilhado. Guarde o ficheiro (ex.: em Downloads ou Drive) para poder restaurar depois.';
    } catch (e) {
      return 'Erro ao exportar: $e';
    }
  }

  /// Creates a background backup without sharing (for Workmanager).
  static Future<String> exportBackgroundBackup() async {
    if (kIsWeb) return 'Backup não disponível na versão web.';
    try {
      final sourcePath = await _dbPath;
      final source = File(sourcePath);
      if (!await source.exists()) {
        return 'Base de dados não encontrada.';
      }

      try {
        final db = sqlite3.open(sourcePath, mode: OpenMode.readOnly);
        db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
        db.dispose();
      } catch (e) {
        debugPrint('BackupService: WAL checkpoint falhou (não crítico): $e');
      }

      final archive = Archive();

      final dbBytes = await source.readAsBytes();
      final dbFile = ArchiveFile('urutau.sqlite', dbBytes.length, dbBytes);
      dbFile.compress = true;
      archive.addFile(dbFile);

      final photosDir = await ImageService.getPhotosDir();
      int photoCount = 0;
      if (await photosDir.exists()) {
        await for (final entity in photosDir.list(recursive: true)) {
          if (entity is File) {
            final relative = p.relative(entity.path, from: photosDir.path);
            final archivePath = 'fotos/$relative';
            final photoBytes = await entity.readAsBytes();
            final photoFile = ArchiveFile(archivePath, photoBytes.length, photoBytes);
            final ext = p.extension(entity.path).toLowerCase();
            photoFile.compress = !(ext == '.jpg' || ext == '.jpeg');
            archive.addFile(photoFile);
            photoCount++;
          }
        }
      }

      int parcelaCount = 0;
      int plantaCount = 0;
      try {
        final db = sqlite3.open(sourcePath, mode: OpenMode.readOnly);
        final parcelaResult = db.select('SELECT COUNT(*) AS cnt FROM parcelas WHERE deleted_at IS NULL');
        parcelaCount = parcelaResult.first['cnt'] as int;
        final plantaResult = db.select('SELECT COUNT(*) AS cnt FROM plantas WHERE deleted_at IS NULL');
        plantaCount = plantaResult.first['cnt'] as int;
        db.dispose();
      } catch (e) {
        debugPrint('BackupService: erro ao contar registros: $e');
      }

      final manifest = jsonEncode({
        'schemaVersion': _currentSchemaVersion,
        'appVersion': '2.0.0',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'photoCount': photoCount,
        'parcelaCount': parcelaCount,
        'plantaCount': plantaCount,
      });
      final manifestBytes = utf8.encode(manifest);
      final manifestFile = ArchiveFile('manifest.json', manifestBytes.length, manifestBytes);
      manifestFile.compress = true;
      archive.addFile(manifestFile);

      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) {
        return 'Erro ao criar ZIP.';
      }

      final dir = await getApplicationDocumentsDirectory();
      final now = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
      final fileName = 'urutau_backup_$now.zip';
      final destPath = p.join(dir.path, fileName);
      final dest = File(destPath);
      await dest.writeAsBytes(zipBytes);

      return 'Background backup salvo em: $destPath';
    } catch (e) {
      return 'Erro ao exportar: $e';
    }
  }

  static Future<String> prepareRestore(String backupFilePath) async {
    if (kIsWeb) return 'Restaurar não disponível na versão web.';
    try {
      final backup = File(backupFilePath);
      if (!await backup.exists()) {
        return 'Ficheiro não encontrado.';
      }

      if (backupFilePath.toLowerCase().endsWith('.zip')) {
        final bytes = await backup.readAsBytes();
        return await _prepareRestoreFromZip(bytes);
      }

      return await _writePendingAndSetFlag(backup);
    } catch (e) {
      return 'Erro ao preparar restauração: $e';
    }
  }

  static Future<String> prepareRestoreFromBytes(List<int> bytes) async {
    if (kIsWeb) return 'Restaurar não disponível na versão web.';
    try {
      if (bytes.isEmpty) return 'Ficheiro vazio.';

      if (_isZipFile(bytes)) {
        return await _prepareRestoreFromZip(bytes);
      }

      final dir = await getApplicationDocumentsDirectory();
      const pendingName = 'restore_pending.sqlite';
      final pendingPath = p.join(dir.path, pendingName);
      final pending = File(pendingPath);
      if (await pending.exists()) await pending.delete();
      await pending.writeAsBytes(bytes);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingRestorePathKey, pendingPath);
      await prefs.setBool(_pendingRestoreKey, true);
      return 'Restauração marcada. Feche o app completamente e reabra para aplicar (os dados atuais serão substituídos pelo backup).';
    } catch (e) {
      return 'Erro ao preparar restauração: $e';
    }
  }

  static Future<String> _prepareRestoreFromZip(List<int> zipBytes) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);

    ArchiveFile? manifestFile;
    ArchiveFile? sqliteFile;
    final photoFiles = <ArchiveFile>[];

    for (final file in archive) {
      final name = file.name;
      if (name == 'manifest.json') {
        manifestFile = file;
      } else if (name == 'urutau.sqlite') {
        sqliteFile = file;
      } else if (name.startsWith('fotos/') && name.length > 6) {
        photoFiles.add(file);
      }
    }

    if (sqliteFile == null) {
      return 'Backup ZIP inválido: urutau.sqlite não encontrado.';
    }

    if (manifestFile != null) {
      final manifestContent = String.fromCharCodes(manifestFile.content as List<int>);
      final validation = _validateManifest(manifestContent);
      if (!validation.ok) {
        return 'Manifesto inválido: ${validation.error}';
      }
    }

    final dir = await getApplicationDocumentsDirectory();

    final pendingDbPath = p.join(dir.path, 'restore_pending.sqlite');
    final pendingDb = File(pendingDbPath);
    if (await pendingDb.exists()) await pendingDb.delete();
    await pendingDb.writeAsBytes(sqliteFile.content as List<int>);

    try {
      final db = sqlite3.open(pendingDbPath, mode: OpenMode.readOnly);
      final result = db.select('PRAGMA integrity_check');
      final integrityResult = result.first.values.first.toString();
      db.dispose();
      if (integrityResult != 'ok') {
        try { await pendingDb.delete(); } catch (_) {}
        return 'Integridade do banco de dados falhou: $integrityResult';
      }
    } catch (e) {
      try { await pendingDb.delete(); } catch (_) {}
      return 'Erro ao verificar integridade: $e';
    }

    final currentDbPath = await _dbPath;
    final currentDb = File(currentDbPath);
    if (await currentDb.exists()) {
      final preRestoreDbPath = p.join(dir.path, 'urutau_pre_restore.sqlite');
      final preRestoreDb = File(preRestoreDbPath);
      if (await preRestoreDb.exists()) await preRestoreDb.delete();
      await currentDb.copy(preRestoreDbPath);
      await SharedPreferences.getInstance().then((prefs) async {
        await prefs.setString(_preRestoreDbKey, preRestoreDbPath);
      });
    }

    final currentFotosDir = await ImageService.getPhotosDir();
    if (currentFotosDir.existsSync()) {
      final preRestoreFotosPath = p.join(dir.path, 'fotos_pre_restore');
      final preRestoreFotosDir = Directory(preRestoreFotosPath);
      if (await preRestoreFotosDir.exists()) {
        await preRestoreFotosDir.delete(recursive: true);
      }
      await _copyDirectory(currentFotosDir, preRestoreFotosDir);
      await SharedPreferences.getInstance().then((prefs) async {
        await prefs.setString(_preRestoreFotosKey, preRestoreFotosPath);
      });
    }

    final pendingFotosPath = p.join(dir.path, 'restore_pending_fotos');
    final pendingFotosDir = Directory(pendingFotosPath);
    if (await pendingFotosDir.exists()) {
      await pendingFotosDir.delete(recursive: true);
    }
    await pendingFotosDir.create(recursive: true);

    for (final photoFile in photoFiles) {
      final relativePath = photoFile.name.substring('fotos/'.length);
      final destPath = p.join(pendingFotosPath, relativePath);
      final destFile = File(destPath);
      await destFile.parent.create(recursive: true);
      await destFile.writeAsBytes(photoFile.content as List<int>);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingRestorePathKey, pendingDbPath);
    await prefs.setString(_pendingRestoreFotosKey, pendingFotosPath);
    await prefs.setBool(_pendingRestoreKey, true);

    String message = 'Restauração marcada. Feche o app completamente e reabra para aplicar (os dados atuais serão substituídos pelo backup).';
    if (manifestFile != null) {
      final manifestContent = String.fromCharCodes(manifestFile.content as List<int>);
      final map = jsonDecode(manifestContent) as Map<String, dynamic>;
      final schemaVersion = map['schemaVersion'] as int?;
      if (schemaVersion != null && schemaVersion < _currentSchemaVersion) {
        message = 'Backup com schema v$schemaVersion (atual: v$_currentSchemaVersion). Migrações serão aplicadas ao reabrir. $message';
      }
    }

    return message;
  }

  static Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(recursive: true)) {
      if (entity is File) {
        final relative = p.relative(entity.path, from: source.path);
        final destPath = p.join(destination.path, relative);
        final destFile = File(destPath);
        await destFile.parent.create(recursive: true);
        await entity.copy(destPath);
      }
    }
  }

  static Future<String> _writePendingAndSetFlag(File backup) async {
    final dir = await getApplicationDocumentsDirectory();
    const pendingName = 'restore_pending.sqlite';
    final pendingPath = p.join(dir.path, pendingName);
    final pending = File(pendingPath);
    if (await pending.exists()) await pending.delete();
    await backup.copy(pendingPath);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingRestorePathKey, pendingPath);
    await prefs.setBool(_pendingRestoreKey, true);
    return 'Restauração marcada. Feche o app completamente e reabra para aplicar (os dados atuais serão substituídos pelo backup).';
  }
}
