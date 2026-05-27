import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:sqlite3/sqlite3.dart';

class BackupService {
  static const String _dbName = 'urutau';
  static const String _pendingRestoreKey = 'pending_restore';
  static const String _pendingRestorePathKey = 'pending_restore_path';

  static Future<String> get _dbPath async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, '$_dbName.sqlite');
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
    debugPrint('BackupService: restauração aplicada a $targetPath');
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

      final dir = await getApplicationDocumentsDirectory();
      final now = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
      final fileName = 'urutau_backup_$now.sqlite';
      final destPath = p.join(dir.path, fileName);
      final dest = await source.copy(destPath);
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

  static Future<String> prepareRestore(String backupFilePath) async {
    if (kIsWeb) return 'Restaurar não disponível na versão web.';
    try {
      final backup = File(backupFilePath);
      if (!await backup.exists()) {
        return 'Ficheiro não encontrado.';
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
