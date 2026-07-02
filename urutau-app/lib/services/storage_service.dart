import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class StorageService {
  static const double _warningThresholdGB = 1.0;
  static const double _criticalThresholdGB = 0.2;

  static const MethodChannel _channel = MethodChannel('com.urutau.storage');

  static Future<double> getFreeSpaceGB() async {
    try {
      if (Platform.isAndroid) {
        final appDir = await getApplicationDocumentsDirectory();
        final freeBytes = await _channel.invokeMethod('getFreeSpace', appDir.path);
        if (freeBytes is int) {
          return freeBytes / (1024 * 1024 * 1024);
        }
      }
      // Fallback for iOS and other platforms
      final dir = await getApplicationDocumentsDirectory();
      final freeBytes = await _getFreeSpaceFallback(dir.path);
      if (freeBytes >= 0) {
        return freeBytes / (1024 * 1024 * 1024);
      }
      return -1;
    } catch (_) {
      return -1;
    }
  }

  static Future<int> _getFreeSpaceFallback(String path) async {
    try {
      // Use a simple check - try to get filesystem info via statvfs equivalent
      // For now, return -1 to indicate unavailable
      return -1;
    } catch (_) {
      return -1;
    }
  }

  static Future<bool> hasEnoughSpaceFor({required int estimatedBytes}) async {
    final free = await getFreeSpaceGB();
    if (free < 0) return true;
    final needed = estimatedBytes / (1024 * 1024 * 1024);
    return free - needed > _criticalThresholdGB;
  }

  static bool isWarning(double freeGB) =>
      freeGB >= 0 && freeGB < _warningThresholdGB;

  static bool isCritical(double freeGB) =>
      freeGB >= 0 && freeGB < _criticalThresholdGB;

  static Future<Map<String, int>> getStorageBreakdown() async {
    final appDir = await _getAppDir();
    final dbFile = File(p.join(appDir.path, 'urutau.sqlite'));
    final photosDir = Directory(p.join(appDir.path, 'fotos'));
    final backupsDir = Directory(p.join(appDir.path, 'backups'));
    final cacheDir = Directory(p.join(appDir.path, 'compressed'));

    return {
      'database': await _getSize(dbFile),
      'fotos': await _getDirSize(photosDir),
      'backups': await _getDirSize(backupsDir),
      'temp': await _getDirSize(cacheDir),
    };
  }

  static Future<int> _getSize(File file) async {
    try {
      return await file.length();
    } catch (_) {
      return 0;
    }
  }

  static Future<int> _getDirSize(Directory dir) async {
    try {
      int total = 0;
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            total += await entity.length();
          }
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  static Future<Directory> _getAppDir() async {
    return await getApplicationDocumentsDirectory();
  }

  static Future<void> cleanCategory(String category, {Set<String>? protectedPaths}) async {
    final appDir = await _getAppDir();
    switch (category) {
      case 'fotos':
        final photosDir = Directory(p.join(appDir.path, 'fotos'));
        if (await photosDir.exists()) {
          await for (final entity in photosDir.list()) {
            if (entity is File) {
              final path = entity.path;
              if (protectedPaths == null || !protectedPaths.contains(path)) {
                await entity.delete();
              }
            }
          }
        }
        break;
      case 'backups':
        final backupsDir = Directory(p.join(appDir.path, 'backups'));
        if (await backupsDir.exists()) {
          await for (final entity in backupsDir.list()) {
            if (entity is File) await entity.delete();
          }
        }
        break;
      case 'temp':
        final cacheDir = Directory(p.join(appDir.path, 'compressed'));
        if (await cacheDir.exists()) {
          await cacheDir.delete(recursive: true);
          await cacheDir.create(recursive: true);
        }
        break;
      case 'database':
        // Database cleanup handled separately - requires app restart
        break;
    }
  }
}