import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import 'clock_service.dart';

/// RC-13 — registro do dispositivo que fez a medição.
/// Identidade estável em SharedPreferences (uuid + fingerprint), linha na
/// tabela `dispositivos` (modelo/SO/versão do app/offset mediano do relógio)
/// e dispositivo_id enviado na trilha do servidor.
class DeviceService {
  /// Manter sincronizado com pubspec.yaml (version: 2.0.0+2).
  static const appVersion = '2.0.0+2';

  static const _kUuid = 'device_uuid';
  static const _kFingerprint = 'device_fingerprint';

  /// UUID estável deste dispositivo (cria na 1ª vez).
  static Future<String> uuidAtual() async {
    final prefs = await SharedPreferences.getInstance();
    var u = prefs.getString(_kUuid);
    if (u == null || u.isEmpty) {
      u = const Uuid().v4();
      await prefs.setString(_kUuid, u);
    }
    return u;
  }

  /// Fingerprint estável (hostname + SO) — não muda entre aberturas do app.
  static Future<String> fingerprint() async {
    final prefs = await SharedPreferences.getInstance();
    var f = prefs.getString(_kFingerprint);
    if (f == null || f.isEmpty) {
      f = '${Platform.localHostname}|${Platform.operatingSystem}';
      await prefs.setString(_kFingerprint, f);
    }
    return f;
  }

  /// Registra/atualiza a linha deste dispositivo na tabela `dispositivos`.
  /// Idempotente. Retorna o uuid do dispositivo.
  static Future<String> registrarDispositivo(AppDatabase db) async {
    final uuid = await uuidAtual();
    final fp = await fingerprint();
    final modelo = '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    final so = Platform.operatingSystem;
    final offset = await ClockService.offsetMedido();

    final existente = await (db.select(db.dispositivos)
          ..where((t) => t.uuid.equals(uuid)))
        .getSingleOrNull();

    if (existente == null) {
      await db.into(db.dispositivos).insert(DispositivosCompanion.insert(
            uuid: uuid,
            identificador: fp,
            modelo: drift.Value(modelo),
            so: drift.Value(so),
            versaoApp: drift.Value(appVersion),
            offsetRelogioMedianoMs: drift.Value(offset?.inMilliseconds),
          ));
    } else {
      await (db.update(db.dispositivos)..where((t) => t.uuid.equals(uuid)))
          .write(DispositivosCompanion(
        identificador: drift.Value(fp),
        modelo: drift.Value(modelo),
        so: drift.Value(so),
        versaoApp: drift.Value(appVersion),
        offsetRelogioMedianoMs: drift.Value(offset?.inMilliseconds),
        updatedAt: drift.Value(DateTime.now()),
      ));
    }
    return uuid;
  }
}
