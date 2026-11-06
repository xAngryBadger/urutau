import 'dart:io' show HttpDate;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// RC-05 — tempo confiável (MRV).
///
/// O relógio do celular é ajustável pelo usuário; a trilha de auditoria não
/// pode depender dele sozinho. Este serviço mede o offset device↔servidor
/// usando o cabeçalho HTTP `Date` (sempre GMT, enviado pelo PocketBase) e
/// guarda em SharedPreferences. Toda escrita na trilha usa
/// [agoraConfiavel] = relógio do device + offset medido.
class ClockService {
  static const String _kOffsetMs = 'clock_offset_ms';
  static const String _kOffsetEm = 'clock_offset_capturado_em';
  static const String _kFonte = 'clock_offset_fonte';

  /// Acima disso o relógio do aparelho está desalinhado e precisa de ajuste.
  static const Duration alertaDesalinhamento = Duration(seconds: 60);

  /// Mede o offset contra o servidor e persiste. Retorna o offset ou null.
  static Future<Duration?> capturarOffsetServidor(String serverUrl) async {
    final base = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;
    final client = http.Client();
    try {
      final resp = await client
          .get(Uri.parse('$base/api/health'))
          .timeout(const Duration(seconds: 8));
      final date = resp.headers['date'];
      if (date == null) return null;
      final servidor = HttpDate.parse(date); // GMT
      final agoraDevice = DateTime.now().toUtc();
      final offset = servidor.difference(agoraDevice);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kOffsetMs, offset.inMilliseconds);
      await prefs.setString(_kOffsetEm, agoraDevice.toIso8601String());
      await prefs.setString(_kFonte, base);
      return offset;
    } catch (_) {
      return null; // offline — mantém o último offset conhecido
    } finally {
      client.close();
    }
  }

  /// Offset medido mais recente (null se nunca mediu ou se prefs falhar —
  /// ex.: teste puro sem binding; nesse caso cai no relógio do device).
  static Future<Duration?> offsetMedido() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(_kOffsetMs);
      return ms == null ? null : Duration(milliseconds: ms);
    } catch (_) {
      return null;
    }
  }

  /// Quando a última medición aconteceu (pra saber se está velha).
  static Future<DateTime?> offsetCapturadoEm() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kOffsetEm);
    return s == null ? null : DateTime.tryParse(s);
  }

  /// Agora "confiável": relógio do device + offset medido (UTC).
  static Future<DateTime> agoraConfiavel() async {
    final off = await offsetMedido();
    return DateTime.now().toUtc().add(off ?? Duration.zero);
  }

  /// true se o offset medido é maior que o limiar de alerta.
  static Future<bool> desalinhado() async {
    final off = await offsetMedido();
    return off != null && off.abs() > alertaDesalinhamento;
  }
}
