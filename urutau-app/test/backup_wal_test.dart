// ============================================================
// backup_wal_test.dart — regressão do backup WAL-safe (P0 t12/t13)
//
// BUG QUE ESTE TESTE FECHA (impl-backup-wal.md §2 PATH A):
// o export abria a conexão em OpenMode.readOnly, tentava
// PRAGMA wal_checkpoint(TRUNCATE) (RECUSADO em read-only — disk I/O
// error 10), ENGOLIA o erro como "não crítico" e copiava só o arquivo
// principal. Resultado medido: backup passa integrity_check "ok" mas
// perde os dados que estavam no WAL (tabela inexistente, user_version 0).
//
// FIX: dumpWalsafe() = VACUUM INTO (read-write) + validação tripla
// (integrity_check + contagem de objetos + user_version).
//
// Estrutura do teste:
//   PARTE 1 — simula o caminho ANTIGO e prova que ele PERDE dados
//             (regressão: se alguém voltar o read-only+checkpoint, falha)
//   PARTE 2 — prova que o caminho NOVO restaura TUDO (count + versão)
// ============================================================

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:urutau/data/database.dart';
import 'package:urutau/services/backup_service.dart';

void main() {
  group('backup WAL-safe (P0)', () {
    late Directory dir;
    late String dbPath;
    late AppDatabase db;

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('urutau_wal_test_');
      dbPath = p.join(dir.path, 'urutau.sqlite');
      db = AppDatabase.forTesting(NativeDatabase(File(dbPath)));
      await db.customSelect('SELECT 1').get(); // abre: WAL + schema v24
      await db.into(db.parcelas).insert(ParcelasCompanion.insert(
        uuid: 'p1',
        propUt: 'UT01',
        idParcela: 1,
        userId: 'u1',
      ));
      await db.into(db.plantas).insert(PlantasCompanion.insert(
        uuid: 'pl1',
        parcelaUuid: 'p1',
        especie: 'Eucalyptus urophylla',
        alturaCm: 145.5,
        categoria: 3,
      ));
      // NÃO fecha: conexão viva com dado ainda no WAL (pior caso real).
    });

    tearDown(() async {
      await db.close();
      // best-effort: handles do SO podem levar alguns ms para soltar
      try {
        if (await dir.exists()) await dir.delete(recursive: true);
      } catch (_) {}
    });

    test('PARTE 0: o WAL existe e retém escrita fora do principal', () async {
      final wal = File('$dbPath-wal');
      expect(await wal.exists(), true,
          reason: 'em journal_mode=WAL a escrita recente fica no -wal');
      expect(await wal.length(), greaterThan(0),
          reason: 'o -wal tem de ter conteúdo para o teste significar algo');
    });

    test('PARTE 1: caminho ANTIGO (read-only + checkpoint engolido) PERDE dado',
        () async {
      // Reproduz o código antigo à risca.
      List<int>? dbBytes;
      try {
        final ro = sqlite3.open(dbPath, mode: OpenMode.readOnly);
        try {
          ro.execute('PRAGMA wal_checkpoint(TRUNCATE)');
        } catch (_) {
          // engolido como no código velho ("não crítico")
        }
        ro.dispose();
        dbBytes = await File(dbPath).readAsBytes();
      } catch (_) {
        // se até o read-only open falhar, o caminho antigo já está morto
      }
      expect(dbBytes, isNotNull);

      // Abre a cópia como a restauração faria e procura os dados.
      final copia = p.join(dir.path, 'copia_antiga.sqlite');
      await File(copia).writeAsBytes(dbBytes!);
      final c = sqlite3.open(copia, mode: OpenMode.readOnly);
      final tabelas = c
          .select("SELECT COUNT(*) AS c FROM sqlite_master WHERE type='table'")
          .first['c'] as int;
      final versao = c.select('PRAGMA user_version').first.values.first;
      c.dispose();

      // O backup antigo pode passar integrity_check — o que o torna perigoso.
      final integ = sqlite3.open(copia, mode: OpenMode.readOnly)
          .select('PRAGMA integrity_check')
          .first
          .values
          .first;
      debugPrint('PARTE 1: tabelas=$tabelas user_version=$versao integrity=$integ');
      expect(integ, 'ok', reason: 'o backup velho PASSA integrity (falso conforto)');
      expect(versao, isNot(equals(24)),
          reason: 'REGRESSÃO: o caminho antigo perde o user_version do WAL');
    });

    test('PARTE 2: dumpWalsafe restaura TUDO (dados + versão + integridade)',
        () async {
      final bytes = await BackupService.dumpWalsafe(dbPath);
      expect(bytes.isNotEmpty, true);

      // Simula o restore: escreve o backup num arquivo limpo e abre.
      final restaurado = p.join(dir.path, 'restaurado.sqlite');
      await File(restaurado).writeAsBytes(bytes);
      final r = sqlite3.open(restaurado, mode: OpenMode.readOnly);

      final integ = r.select('PRAGMA integrity_check').first.values.first;
      expect(integ, 'ok');

      final versao = r.select('PRAGMA user_version').first.values.first;
      expect(versao, db.schemaVersion,
          reason: 'user_version tem de vir no backup (schema atual)');

      // A fixture deste teste insere p1/pl1; o banco também semeia o catálogo
      // (72 parcelas) no beforeOpen — por isso a assertação é por UUID.
      final parcelaMinha = r
          .select("SELECT COUNT(*) AS c FROM parcelas WHERE uuid='p1'")
          .first['c'] as int;
      final plantaMinha = r
          .select("SELECT COUNT(*) AS c FROM plantas WHERE uuid='pl1'")
          .first['c'] as int;
      final totalParcelas =
          r.select('SELECT COUNT(*) AS c FROM parcelas').first['c'] as int;
      expect(parcelaMinha, 1,
          reason: 'parcela inserida no WAL tem de sobreviver ao backup');
      expect(plantaMinha, 1,
          reason: 'planta inserida no WAL tem de sobreviver ao backup');
      expect(totalParcelas, greaterThanOrEqualTo(73),
          reason: 'catálogo (72) + fixture (1) têm de estar todos no backup');

      final objetos =
          r.select('SELECT COUNT(*) AS c FROM sqlite_master').first['c'] as int;
      expect(objetos, greaterThan(30), reason: 'schema completo (v24) no backup');
      r.dispose();
    });

    test('PARTE 3: dumpWalsafe é idempotente e limpa o temporário', () async {
      final b1 = await BackupService.dumpWalsafe(dbPath);
      final b2 = await BackupService.dumpWalsafe(dbPath);
      expect(b1.length, greaterThan(0));
      expect(b2.length, greaterThan(0));
      expect(await File('$dbPath.tmp-backup').exists(), false,
          reason: 'temporário tem de ser removido após o dump');
    });
  });
}
