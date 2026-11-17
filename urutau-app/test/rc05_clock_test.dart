// RC-05: tempo confiável — offset device↔servidor entra na trilha (v29)
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urutau/data/database.dart';
import 'package:urutau/services/clock_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RC-05: relogio confiavel (offset servidor)', () {
    late AppDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.customSelect('SELECT 1').get();
    });

    tearDown(() async => db.close());

    test('sem offset medido, agoraConfiavel ≈ relogio do device (UTC)', () async {
      final antes = DateTime.now().toUtc();
      final agora = await ClockService.agoraConfiavel();
      final depois = DateTime.now().toUtc();
      expect(agora.isAfter(antes.subtract(const Duration(seconds: 2))), isTrue);
      expect(agora.isBefore(depois.add(const Duration(seconds: 2))), isTrue);
      expect(await ClockService.desalinhado(), isFalse);
    });

    test('offset armazenado desloca agoraConfiavel e marca desalinhamento', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('clock_offset_ms', 5 * 60 * 1000); // +5 min
      final agora = await ClockService.agoraConfiavel();
      final device = DateTime.now().toUtc();
      final delta = agora.difference(device).inSeconds;
      expect(delta, greaterThanOrEqualTo(299)); // ~300s
      expect(delta, lessThan(310));
      expect(await ClockService.desalinhado(), isTrue); // > 60s
    });

    test('trilha grava tsServidor ajustado, tsDispositivo bruto e offset (v29)',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('clock_offset_ms', 120000); // +2 min

      await db.logTrilha(
        acao: 'teste_rc05',
        entidadeTipo: 'parcela',
        entidadeUuid: 'p1',
        origem: 'app',
      );

      final e = await (db.select(db.trilhaAuditoria)).getSingle();
      expect(e.offsetRelogioMs, 120000);
      expect(e.tsDispositivo, isNotNull);
      expect(e.tsServidor, isNotNull);
      // tsServidor ≈ tsDispositivo + 120s (tolerancia de truncamento 1s)
      final deltaMs =
          e.tsServidor!.millisecondsSinceEpoch - e.tsDispositivo!.millisecondsSinceEpoch;
      expect(deltaMs, greaterThanOrEqualTo(119000));
      expect(deltaMs, lessThanOrEqualTo(121000));
      // cadeia continua integra com o offset no hash
      expect(await db.verificarCadeiaAuditoria(), isNull);
    });

    test('offset no hash: trocar offset quebra a verificacao da entrada nova',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('clock_offset_ms', 0);
      await db.logTrilha(acao: 'a', origem: 'app');
      await prefs.setInt('clock_offset_ms', 999999);
      await db.logTrilha(acao: 'b', origem: 'app');
      // adultera o offset da 2ª entrada: o hash dela foi calculado com 999999
      await db.customUpdate(
        "UPDATE trilha_auditoria SET offset_relogio_ms = 0 WHERE id_seq = 2",
        updates: {db.trilhaAuditoria},
      );
      final problema = await db.verificarCadeiaAuditoria();
      expect(problema, isNotNull);
      expect(problema, contains('idSeq=2'));
    });
  });
}
