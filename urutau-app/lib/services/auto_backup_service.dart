import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup_service.dart';

/// t19 fase 2 — backup automático ANTES de actualizar (decisão do utilizador).
///
/// Opção (a) da análise: no boot, compara o versionCode atual com o último
/// em que o app correu (SharedPreferences). Se subiu, exporta o ZIP completo
/// (banco WAL-safe + fotos + manifesto, via BackupService.buildBackupZip) para
/// FORA do sandbox do app — Downloads/Urutau via MediaStore (canal nativa) —
/// antes de qualquer migração do drift tocar o banco.
///
/// Porquê fora do sandbox: uma cópia dentro do app desaparece com a
/// desinstalação (lição da t9 — update mal assinado apagou os dados e não
/// havia backup fora do aparelho).
///
/// Falha nunca bloqueia o boot (try/catch + debugPrint) e NÃO marca a versão,
/// para tentar de novo no próximo arranque.
class AutoBackupService {
  static const String _lastVersionCodeKey = 'auto_backup_last_version_code';
  static const MethodChannel _channel = MethodChannel('com.urutau.backup');

  /// Lógica testável: [versionCode], [readVersionCode] e [saveExternal] são
  /// injetáveis (os testes não usam platform channels).
  ///
  /// Devolve true se fez backup nesta execução.
  static Future<bool> backupIfVersionChanged({
    int? versionCode,
    Future<int> Function()? readVersionCode,
    Future<String?> Function(String fileName, List<int> bytes)? saveExternal,
  }) async {
    if (kIsWeb) return false;
    try {
      final current =
          versionCode ?? await (readVersionCode?.call() ?? _platformVersionCode());
      if (current <= 0) return false;

      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_lastVersionCodeKey);
      if (last != null && current <= last) return false; // mesma versão/downgrade

      final dbFile = File(await BackupService.dbFilePath);
      if (last == null && !await dbFile.exists()) {
        // Instalação nova (sem banco ainda): só marca a versão, sem backup.
        await prefs.setInt(_lastVersionCodeKey, current);
        return false;
      }
      // last == null com banco existente = update de versão pré-feature: faz backup.

      final zipBytes = await BackupService.buildBackupZip();
      final fileName = 'urutau_backup_auto_v$current.zip';
      final saved = saveExternal != null
          ? await saveExternal(fileName, zipBytes)
          : await _saveToDownloads(fileName, zipBytes);

      if (saved == null) {
        // Fallback: dentro do sandbox (pior que Downloads, melhor que nada).
        final dir = await getApplicationDocumentsDirectory();
        final backups = Directory(p.join(dir.path, 'backups'));
        await backups.create(recursive: true);
        await File(p.join(backups.path, fileName)).writeAsBytes(zipBytes);
        debugPrint('AutoBackupService: fallback para sandbox em ${backups.path}/$fileName');
      } else {
        debugPrint('AutoBackupService: backup v$current gravado em $saved');
      }

      await prefs.setInt(_lastVersionCodeKey, current);
      return true;
    } catch (e) {
      debugPrint('AutoBackupService: falha no backup automático (boot segue): $e');
      return false; // não marca a versão → retenta no próximo boot
    }
  }

  static Future<int> _platformVersionCode() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return int.tryParse(info.buildNumber) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Grava o ZIP em Downloads/Urutau/ FORA do sandbox.
  /// 1) canal nativa (MediaStore.Downloads — Android 10+ não pede permissão
  ///    para o próprio app contribuir); 2) fallback path_provider Downloads.
  static Future<String?> _saveToDownloads(String fileName, List<int> bytes) async {
    try {
      final r = await _channel.invokeMethod<String>('saveToDownloads', {
        'fileName': fileName,
        'bytes': bytes,
      });
      if (r != null && r.isNotEmpty) return r;
    } catch (_) {}
    try {
      // path_provider 2.1.x: getDownloadsPath só existe na platform interface
      final d = await PathProviderPlatform.instance.getDownloadsPath();
      if (d != null) {
        final f = File(p.join(d, 'Urutau', fileName));
        await f.parent.create(recursive: true);
        await f.writeAsBytes(bytes);
        return f.path;
      }
    } catch (_) {}
    return null;
  }
}
