// RG-04: trilha de auditoria encadeada por hash (append-only)
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urutau/data/database.dart';

void main() {
  group('RG-04: trilha encadeada por hash', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.customSelect('SELECT 1').get();
    });

    tearDown(() async => db.close());

    test('logAudit faz dual-write: auditLog + trilhaAuditoria', () async {
      await db.logAudit('create',
          entityType: 'parcela', entityUuid: 'p1', newValue: 'draft');
      final antigo = await db.getAuditLog(limit: 10);
      final trilha = await (db.select(db.trilhaAuditoria)).get();
      expect(antigo.length, 1);
      expect(trilha.length, 1);
      expect(trilha.first.acao, 'create');
      expect(trilha.first.prevHash, 'GENESIS');
      expect(trilha.first.entryHash, isNotNull);
    });

    test('cadeia encadeia: 2ª entrada aponta pra hash da 1ª', () async {
      await db.logAudit('create', entityType: 'parcela', entityUuid: 'p1');
      await db.logAudit('update', entityType: 'parcela', entityUuid: 'p1');
      final trilha = await (db.select(db.trilhaAuditoria)
            ..orderBy([(t) => OrderingTerm.asc(t.idSeq)]))
          .get();
      expect(trilha.length, 2);
      expect(trilha[1].prevHash, trilha[0].entryHash);
      expect(trilha[1].entryHash, isNot(equals(trilha[0].entryHash)));
      expect(await db.verificarCadeiaAuditoria(), isNull); // íntegra
    });

    test('verificarCadeia detecta adulteração de uma entrada', () async {
      await db.logAudit('create', entityType: 'parcela', entityUuid: 'p1');
      await db.logAudit('delete', entityType: 'parcela', entityUuid: 'p1');
      // adultera a ação da 1ª entrada direto no banco (simula ataque)
      await db.customUpdate(
        'UPDATE trilha_auditoria SET acao = \'sumiu\' WHERE id_seq = 1',
        updates: {db.trilhaAuditoria},
      );
      final problema = await db.verificarCadeiaAuditoria();
      expect(problema, isNotNull);
      expect(problema, contains('idSeq=1'));
    });

    test('verificarCadeia detecta quebra de elo (prevHash alterado)', () async {
      await db.logAudit('a');
      await db.logAudit('b');
      await db.customUpdate(
        'UPDATE trilha_auditoria SET prev_hash = \'FORJADO\' WHERE id_seq = 2',
        updates: {db.trilhaAuditoria},
      );
      final problema = await db.verificarCadeiaAuditoria();
      expect(problema, isNotNull);
      expect(problema, contains('idSeq=2'));
    });
  });
}
