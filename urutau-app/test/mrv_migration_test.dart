// ============================================================
// mrv_migration_test.dart — teste de migração v19 → v24 (Drift)
//
// PATCH NAO APLICADO. Destino: urutau-app/test/mrv_migration_test.dart
// Task t9 (dev-mrv) · entregavel para dev-codigo aplicar após os gates.
//
// BASE = v19 COMMITADA (43a165e): fotos_parcela.arquivo_ausente e
// plantas.foto_ausente já existem. Este patch é v20 → v24, por cima dela.
//
// RODAR COM:   flutter test test/mrv_migration_test.dart
// PRE-REQUISITO: build_runner já rodou POR CIMA (--delete-conflicting-outputs),
// nunca do zero — database.g.dart já está commitado.
//
// Estrategia: cria no banco SOMENTE as tabelas legadas (v19) com dados realistas,
// marca user_version = 19, e so depois abre o AppDatabase real — que dispara
// onUpgrade(19, 24). As assercoes rodam no MESMO executor, pos-migracao.
//
// Convenção de construtor: `AppDatabase.forTesting(NativeDatabase.memory())` —
// mesma de test/photo_evidence_test.dart:32. NÃO criar construtor novo.
//
// LIMITACAO CONHECIDA: o DDL legado é transcrito a mao de database.dart.
// As tabelas legadas não são alteradas por este patch, entao a transcricao
// continua valida. Se database.dart mudar, regere o DDL e atualize aqui.
// ============================================================

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urutau/data/database.dart';

/// DDL das 5 tabelas no estado v19 (transcrito de database.dart @ 43a165e).
/// Inclui as colunas do Q2: plantas.foto_ausente e fotos_parcela.arquivo_ausente.
const _legacyDdlV19 = <String>[
  '''
  CREATE TABLE usuarios (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid TEXT NOT NULL UNIQUE,
    nome TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    senha TEXT NOT NULL,
    is_admin INTEGER NOT NULL DEFAULT 0,
    ativo INTEGER NOT NULL DEFAULT 1,
    created_at INTEGER NOT NULL DEFAULT CURRENT_TIMESTAMP
  )''',
  '''
  CREATE TABLE parcelas (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid TEXT NOT NULL UNIQUE,
    propriedade TEXT NOT NULL DEFAULT '',
    prop_ut TEXT NOT NULL,
    id_parcela INTEGER NOT NULL,
    observacoes TEXT NULL,
    latitude REAL NULL,
    longitude REAL NULL,
    user_id TEXT NOT NULL,
    area_ha REAL NULL,
    synced INTEGER NOT NULL DEFAULT 0,
    pronta_para_sync INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at INTEGER NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL,
    deleted_by TEXT NULL,
    created_by TEXT NOT NULL DEFAULT '',
    parcialmente_sincronizada INTEGER NOT NULL DEFAULT 0
  )''',
  '''
  CREATE TABLE plantas (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid TEXT NOT NULL UNIQUE,
    parcela_uuid TEXT NOT NULL REFERENCES parcelas(uuid),
    especie TEXT NOT NULL,
    altura_cm REAL NOT NULL,
    dap_cm REAL NULL,
    categoria INTEGER NOT NULL,
    foto_especie_path TEXT NULL,
    synced INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at INTEGER NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL,
    foto_ausente INTEGER NOT NULL DEFAULT 0
  )''',
  '''
  CREATE TABLE fotos_parcela (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid TEXT NOT NULL UNIQUE,
    parcela_uuid TEXT NOT NULL REFERENCES parcelas(uuid),
    file_path TEXT NOT NULL,
    synced INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL,
    arquivo_ausente INTEGER NOT NULL DEFAULT 0
  )''',
  '''
  CREATE TABLE audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    action TEXT NOT NULL,
    entity_type TEXT NULL,
    entity_uuid TEXT NULL,
    user_id TEXT NULL,
    details TEXT NULL,
    created_at INTEGER NOT NULL DEFAULT CURRENT_TIMESTAMP,
    old_value TEXT NULL,
    new_value TEXT NULL
  )''',
];

/// Cria o estado v19 com fixtures realistas e devolve o executor.
/// NÃO abre o AppDatabase aqui: a migração tem de rodar por cima destes dados.
Future<NativeDatabase> _seedV19() async {
  // drift 2.31: o padrao suportado para testes de migracao e o callback
  // `setup:` — roda no banco cru ANTES de qualquer migracao do drift
  // (garantindo user_version=19 para o AppDatabase disparar onUpgrade).
  return NativeDatabase.memory(setup: (rawDb) {
    for (final ddl in _legacyDdlV19) {
      rawDb.execute(ddl);
    }
  // 3 parcelas: 1 seed, 1 de coletor com geo, 1 soft-deletada com planta
  rawDb.execute(
      "INSERT INTO parcelas (uuid, propriedade, prop_ut, id_parcela, user_id, area_ha, "
      "latitude, longitude, created_by, synced) VALUES "
      "('p-seed', 'GHGH0064', 'UT01', 1, '', 0.0, -19.8123, -43.9451, '', 1), "
      "('p-user', 'GHGH0065', 'UT02', 1, 'u1', 1.25, -19.8200, -43.9500, 'u1', 1), "
      "('p-soft', 'GHGH0066', 'UT03', 2, 'u1', NULL, NULL, NULL, 'u1', 1)");
  rawDb.execute("UPDATE parcelas SET deleted_at = 1750003000, deleted_by = 'u1' "
      "WHERE uuid = 'p-soft'");
  // 4 plantas: com DAP, NI sem DAP, cat2 sem dap>=5, e uma na parcela soft-deletada.
  // pl-5 (NI) tem foto_ausente=1: o arquivo se perdeu, a linha ficou (Q2/43a165e).
  rawDb.execute(
      "INSERT INTO plantas (uuid, parcela_uuid, especie, altura_cm, dap_cm, categoria, "
      "foto_especie_path, created_at, foto_ausente) VALUES "
      "('pl1', 'p-user', 'Eucalyptus urophylla', 145.5, 12.3, 3, '/d/f1.jpg', 1750001100, 0), "
      "('pl2', 'p-user', 'NI', 32.0, NULL, 1, '/d/f2.jpg', 1750001200, 0), "
      "('pl3', 'p-seed', 'Cecropia hololeuca Miq.', 210.0, 25.0, 3, NULL, 1750001300, 0), "
      "('pl4', 'p-soft', 'Eucalyptus urophylla', 88.0, NULL, 2, NULL, 1750002100, 0)");
  // 3 fotos: 2 presentes + 1 marcada como arquivo ausente (Q2/43a165e)
  rawDb.execute(
      "INSERT INTO fotos_parcela (uuid, parcela_uuid, file_path, created_at, arquivo_ausente) "
      "VALUES ('f1', 'p-user', '/d/p1.jpg', 1750001050, 0), "
      "('f2', 'p-seed', '/d/p2.jpg', 1750001060, 0), "
      "('f3', 'p-user', '/d/perdida.jpg', 1750001070, 1)");
  rawDb.execute(
      "INSERT INTO audit_log (action, entity_type, entity_uuid, user_id, old_value, new_value) "
      "VALUES ('soft_delete_parcela', 'parcela', 'p-soft', 'u1', 'ativo', 'deletado')");
  rawDb.execute('PRAGMA user_version = 19');
  });
}

Future<int> _count(NativeDatabase e, String sql) async {
  // drift 2.31: runCustom devolve Future<void>; resultados vem de runSelect.
  final rows = await e.runSelect(sql, const []);
  return rows.first.values.first as int;
}

void main() {
  group('migracao MRV v19 -> v28 (v24 + motor Fase 1 + v26 + D-1 v27 + foto/planta GPS/dono v28)', () {
    late NativeDatabase executor;
    late AppDatabase db;

    setUp(() async {
      executor = await _seedV19();
    });

    tearDown(() async {
      await db.close();
    });

    test('a migracao roda e o banco sai em v28', () async {
      db = AppDatabase.forTesting(executor);
      await db.customSelect('SELECT 1').get(); // forca abertura
      final v = await _count(executor, 'PRAGMA user_version');
      expect(v, 28,
          reason: 'schemaVersion tem de ser 28 (v27 + foto/planta GPS/dono)');
    });

    test('v28: fotos_parcela e plantas têm as colunas de rastreabilidade',
        () async {
      db = AppDatabase.forTesting(executor);
      await db.customSelect('SELECT 1').get();
      final colsFotos = await executor
          .runSelect('PRAGMA table_info(fotos_parcela)', const []);
      final nomesFotos =
          colsFotos.map((r) => r.values.elementAt(1) as String).toList();
      expect(nomesFotos, containsAll(['latitude', 'longitude', 'autor_uuid']));
      final colsPlantas = await executor
          .runSelect('PRAGMA table_info(plantas)', const []);
      final nomesPlantas =
          colsPlantas.map((r) => r.values.elementAt(1) as String).toList();
      expect(nomesPlantas, contains('autor_uuid'));
    });

    test('Q3 motor Fase 1: plantas.server_planta_id existe e nasce NULL',
        () async {
      db = AppDatabase.forTesting(executor);
      await db.customSelect('SELECT 1').get();
      final cols = await executor
          .runSelect('PRAGMA table_info(plantas)', const []);
      final nomes = cols.map((r) => r.values.elementAt(1) as String).toList();
      expect(nomes, contains('server_planta_id'),
          reason: 'ponte local→servidor tem de existir após a migração');
      // plantas legadas ficam com NULL (ainda não sincronizadas) — o push
      // upsert preenche; nada de backfill inventado.
      final nulos = await _count(executor,
          'SELECT COUNT(*) FROM plantas WHERE server_planta_id IS NULL');
      expect(nulos, await _count(executor, 'SELECT COUNT(*) FROM plantas'));
    });

    test('nenhum drop: as 5 tabelas legadas preservam dados', () async {
      db = AppDatabase.forTesting(executor);
      await db.customSelect('SELECT 1').get();
      expect(await _count(executor, 'SELECT COUNT(*) FROM plantas'), 4,
          reason: 'as 4 plantas legadas tem de sobreviver');
      expect(await _count(executor, 'SELECT COUNT(*) FROM fotos_parcela'), 3);
      expect(await _count(executor, 'SELECT COUNT(*) FROM audit_log'), 1,
          reason: 'trilha legada NAO e apagada pela migracao');
      // NOTA: o beforeOpen do app semeia o catálogo estático (72 parcelas)
      // DEPOIS da migração — por isso as contagens de parcela são escopadas
      // às fixtures semeadas em _seedV19.
      expect(
          await _count(executor,
              "SELECT COUNT(*) FROM parcelas WHERE uuid IN ('p-seed','p-user','p-soft')"),
          3);
      expect(
          await _count(executor,
              "SELECT COUNT(*) FROM parcelas WHERE deleted_at IS NOT NULL "
              "AND uuid IN ('p-seed','p-user','p-soft')"),
          1,
          reason: 'soft-delete nao pode ser ressuscitado');
    });

    test('as colunas do Q2 (43a165e) seguem la, intactas', () async {
      db = AppDatabase.forTesting(executor);
      await db.customSelect('SELECT 1').get();
      // arquivo_ausente=1 em f3, foto_ausente=1 em nenhuma planta da fixture
      expect(
          await _count(executor, 'SELECT COUNT(*) FROM fotos_parcela WHERE arquivo_ausente = 1'),
          1,
          reason: 'a marcação do Q2 NAO pode ser perdida pela migração');
      expect(
          await _count(executor, 'SELECT COUNT(*) FROM plantas WHERE foto_ausente = 1'),
          0);
    });

    test('as 26 tabelas MRV novas existem', () async {
      db = AppDatabase.forTesting(executor);
      await db.customSelect('SELECT 1').get();
      const esperadas = [
        'projetos_mrv', 'periodos_monitoramento', 'campanhas', 'desenho_amostral',
        'protocolos_medicao', 'amostras_parcela', 'individuos', 'medicoes_individuo',
        'plantacao_uts', 'medicoes_plantacao', 'restauracao_projetos', 'restauracao_uts',
        'medicoes_restauracao', 'coberturas_amostra', 'ativos_brutos', 'dispositivos',
        'trilha_auditoria', 'especies_catalogo', 'equacoes_alometricas', 'calculos_mrv',
        'resultados_amostra', 'papeis', 'usuario_papeis', 'incidentes',
        'verificacoes_internas', 'competencias',
      ];
      for (final t in esperadas) {
        final rows = await executor
            .runSelect("SELECT name FROM sqlite_master WHERE type='table' AND name='$t'", const []);
        expect(rows.length, 1, reason: 'tabela $t deveria existir');
      }
    });

    test('backfill v20: parcela_id_text, area_m2, geo_json', () async {
      db = AppDatabase.forTesting(executor);
      await db.customSelect('SELECT 1').get();
      // escopado às fixtures: o catálogo semeado no beforeOpen (após a
      // migração) nasce sem parcela_id_text — isso é gap de produto
      // documentado no relatório, não falha do backfill.
      expect(
          await _count(executor,
              "SELECT COUNT(*) FROM parcelas WHERE parcela_id_text IS NULL "
              "AND uuid IN ('p-seed','p-user','p-soft')"),
          0);
      final area = await executor
          .runSelect("SELECT area_m2 AS v FROM parcelas WHERE uuid='p-user'", const []);
      expect(area.first.values.first, 12500, reason: '1,25 ha = 12500 m2');
      final geoQtd = await _count(executor, 'SELECT COUNT(*) FROM parcelas WHERE geo_json IS NOT NULL');
      expect(geoQtd, 2, reason: 'so as 2 parcelas com lat/lon recebem geo');
      // geo sem acuracia: NAO inventamos dado de GPS
      final geo = await executor
          .runSelect("SELECT geo_json AS v FROM parcelas WHERE uuid='p-seed'", const []);
      expect(geo.first.values.first, contains('"crs":null'));
    });

    test('backfill v20: 4 individuos, 4 medicos, 3 amostras, scaffold LEGADO',
        () async {
      db = AppDatabase.forTesting(executor);
      await db.customSelect('SELECT 1').get();
      expect(await _count(executor, 'SELECT COUNT(*) FROM individuos'), 4,
          reason: '1 individuo por planta, inclusive da parcela soft-deletada');
      expect(await _count(executor, 'SELECT COUNT(*) FROM medicoes_individuo'), 4);
      expect(await _count(executor, 'SELECT COUNT(*) FROM amostras_parcela'), 3,
          reason: 'amostra inclusive para parcela soft-deletada (evidencia)');
      expect(await _count(executor, "SELECT COUNT(*) FROM projetos_mrv WHERE codigo='LEGADO'"), 1);
      expect(await _count(executor, "SELECT COUNT(*) FROM campanhas WHERE uuid='LEGADO-CAMP-0001'"), 1);
      // toda medicao aponta para uma amostra existente (amostra_uuid e NOT NULL)
      expect(
          await _count(executor,
              'SELECT COUNT(*) FROM medicoes_individuo m WHERE NOT EXISTS '
              '(SELECT 1 FROM amostras_parcela a WHERE a.uuid = m.amostra_uuid)'),
          0,
          reason: 'nenhuma medicao pode ficar orfa');
      // dap_cm NULL nao virou 0
      final dap = await executor.runSelect(
          "SELECT dap_cm AS v FROM medicoes_individuo m "
          "JOIN individuos i ON i.uuid = m.individuo_uuid WHERE i.especie_legado='NI'", const []);
      expect(dap.first.values.first, null);
    });

    test('backfill v21: ativos_brutos LE arquivo_ausente/foto_ausente (Q2)',
        () async {
      db = AppDatabase.forTesting(executor);
      await db.customSelect('SELECT 1').get();
      expect(await _count(executor, "SELECT COUNT(*) FROM ativos_brutos WHERE entidade_tipo='parcela'"), 3);
      expect(await _count(executor, "SELECT COUNT(*) FROM ativos_brutos WHERE entidade_tipo='medicao'"), 2,
          reason: 'pl1 e pl2 tem foto_especie_path');
      // A FONTE DA VERDADE sao as colunas COMMITADAS na v19 (43a165e)
      expect(
          await _count(executor,
              "SELECT COUNT(*) FROM ativos_brutos a JOIN fotos_parcela f ON a.uuid = 'legado-ativo-' || f.uuid "
              "WHERE f.arquivo_ausente = 1 AND a.status = 'ausente'"),
          1,
          reason: 'arquivo_ausente=true => ativo nasce ausente, nao pendente_hash');
      expect(
          await _count(executor,
              "SELECT COUNT(*) FROM ativos_brutos a JOIN fotos_parcela f ON a.uuid = 'legado-ativo-' || f.uuid "
              "WHERE f.arquivo_ausente = 0 AND a.status = 'pendente_hash'"),
          2);
      expect(
          await _count(executor, 'SELECT COUNT(*) FROM ativos_brutos WHERE sha256 IS NOT NULL'),
          0,
          reason: 'SQLite nao calcula SHA-256: hash nasce NULL e vira trabalho do app');
    });

    test('backfill v22: catalogo de especies sem densidade inventada', () async {
      db = AppDatabase.forTesting(executor);
      await db.customSelect('SELECT 1').get();
      expect(await _count(executor, 'SELECT COUNT(*) FROM especies_catalogo'), 3);
      expect(
          await _count(executor,
              "SELECT COUNT(*) FROM especies_catalogo WHERE nome_cientifico='NI' AND origem='desconhecida'"),
          1);
      expect(
          await _count(executor,
              'SELECT COUNT(*) FROM especies_catalogo WHERE densidade_basica IS NOT NULL'),
          0,
          reason: 'rho nao existe no sistema hoje; NAO inventar');
      expect(await _count(executor, 'SELECT COUNT(*) FROM individuos WHERE especie_uuid IS NOT NULL'), 4);
      expect(
          await _count(executor,
              "SELECT COUNT(*) FROM individuos WHERE especie_legado='Eucalyptus urophylla' AND especie_uuid IS NOT NULL"),
          2,
          reason: 'o texto original e preservado ao lado do link');
    });

    test('backfill v23: 5 papeis, nenhum usuario promovido', () async {
      db = AppDatabase.forTesting(executor);
      await db.customSelect('SELECT 1').get();
      expect(await _count(executor, 'SELECT COUNT(*) FROM papeis'), 5);
      expect(await _count(executor, 'SELECT COUNT(*) FROM usuario_papeis'), 0,
          reason: 'atribuir papel e decisao de governanca, nao efeito de migracao');
    });

    test('convencao DAP 1,30 m semeada como confirmada pelo usuario', () async {
      db = AppDatabase.forTesting(executor);
      await db.customSelect('SELECT 1').get();
      final rows = await executor.runSelect(
          "SELECT regra_altura AS a, regra_dap AS d, unidades AS u FROM protocolos_medicao WHERE codigo='SOP-MRV'", const []);
      expect(rows.length, 1);
      final data = rows.first;
      expect(data['a'] as String, contains('ALTURA sempre coletada'));
      expect(data['d'] as String, contains('1,30 m'));
      expect(data['d'] as String, contains('confirmado pelo usuario'));
      expect(data['u'] as String, contains('dap_referencia_m'));
    });

    test('DAN continua booleano generico, sem calculo dependendo dele', () async {
      db = AppDatabase.forTesting(executor);
      await db.customSelect('SELECT 1').get();
      final cols = await executor.runSelect('PRAGMA table_info(medicoes_restauracao)', const []);
      final nomes = cols.map((r) => r.values.elementAt(1) as String).toList();
      expect(nomes, contains('dan'));
      expect(nomes, contains('sobreviveu'));
    });

    test('regressao: se alguem adicionar DROP nas tabelas legadas, falha', () async {
      db = AppDatabase.forTesting(executor);
      await db.customSelect('SELECT 1').get();
      for (final t in ['plantas', 'fotos_parcela', 'audit_log', 'parcelas', 'usuarios']) {
        final rows = await executor
            .runSelect("SELECT name FROM sqlite_master WHERE type='table' AND name='$t'", const []);
        expect(rows.length, 1, reason: 'tabela legada $t nao pode ser dropada');
      }
    });

    test('caminhos destrutivos do app continuam funcionando (foreign_keys=ON)',
        () async {
      db = AppDatabase.forTesting(executor);
      await db.customSelect('SELECT 1').get();
      await executor.runCustom('PRAGMA foreign_keys = ON');
      // replica deleteAllSyncedParcelas: filhos primeiro, depois parcelas
      await executor.runCustom(
          'DELETE FROM plantas WHERE parcela_uuid IN (SELECT uuid FROM parcelas WHERE synced = 1)');
      await executor.runCustom(
          'DELETE FROM fotos_parcela WHERE parcela_uuid IN (SELECT uuid FROM parcelas WHERE synced = 1)');
      await executor.runCustom('DELETE FROM parcelas WHERE synced = 1');
      // as 26 tabelas MRV novas usam FK LOGICA: nenhuma constraint nova
      for (final t in const ['individuos', 'medicoes_individuo', 'amostras_parcela']) {
        final fks = await executor.runSelect('PRAGMA foreign_key_list($t)', const []);
        expect(fks.isEmpty, true,
            reason: '$t nao deve declarar FK real (decisao Compat-FK)');
      }
    });
  });
}
