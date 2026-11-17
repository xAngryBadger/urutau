import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urutau/data/database.dart';

// Q1 — regressão: a trilha de auditoria NÃO pode se auto-destruir.
// Antes do fix, purgarAuditLog() (chamado no beforeOpen) deletava linhas com
// >90 dias a cada abertura do app. Depois do fix, é no-op por padrão.
void main() {
  group('Q1 purgarAuditLog', () {
    test('auditoria com >90 dias NÃO é deletada no comportamento padrão',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      // Trilha com 120 dias — cenário que o bug apagava silenciosamente.
      await db.into(db.auditLog).insert(
            AuditLogCompanion.insert(
              action: 'delete_parcela',
              entityType: const Value('parcela'),
              entityUuid: const Value('uuid-parcela-1'),
              details: const Value('{"motivo":"teste"}'),
              createdAt: Value(
                  DateTime.now().subtract(const Duration(days: 120))),
            ),
          );
      // Trilha recente também deve sobreviver.
      await db.into(db.auditLog).insert(
            AuditLogCompanion.insert(action: 'create_planta'),
          );

      final antes = await db.select(db.auditLog).get();
      expect(antes.length, 2, reason: 'setup: duas entradas de auditoria');

      // Comportamento padrão (flag desligada): nada é removido.
      await db.purgarAuditLog();
      final depois = await db.select(db.auditLog).get();
      expect(depois.length, 2,
          reason: 'Q1: auditoria >90 dias deve permanecer (sem auto-purge)');

      // Mesmo chamando via beforeOpen (segunda abertura simulada): intacta.
      await db.purgarAuditLog();
      final depois2 = await db.select(db.auditLog).get();
      expect(depois2.length, 2);

      await db.close();
    });

    test('purga só roda quando a flag é ligada EXPLICITAMENTE', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      await db.into(db.auditLog).insert(
            AuditLogCompanion.insert(
              action: 'delete_parcela',
              createdAt: Value(
                  DateTime.now().subtract(const Duration(days: 120))),
            ),
          );
      await db.into(db.auditLog).insert(
            AuditLogCompanion.insert(
              action: 'login',
              createdAt: Value(DateTime.now()),
            ),
          );

      // Default: preserva tudo.
      await db.purgarAuditLog();
      expect((await db.select(db.auditLog).get()).length, 2);

      // Operador liga a flag: purge é ação explícita e destrutiva (documentada).
      AppDatabase.auditAutoPurgeEnabled = true;
      await db.purgarAuditLog();
      final restante = await db.select(db.auditLog).get();
      expect(restante.length, 1);
      expect(restante.first.action, 'login');

      AppDatabase.auditAutoPurgeEnabled = false;
      await db.close();
    });
  });
}
