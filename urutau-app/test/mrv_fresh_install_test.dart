// ============================================================
// mrv_fresh_install_test.dart — teste do CAMINHO FRESCO (onCreate)
//
// Bug que este teste fecha (§10.4 de impl-migracao-drift.md): banco NOVO
// nascia com ZERO índice MRV (os 27 vivem em MrvMigration.v19..v23, só
// chamados em onUpgrade), protocolos/papéis vazios e as parcelas do seed
// sem campos MRV. Correção: MrvMigration.aplicarBase roda no onCreate
// (depois de _createIndexes) e no beforeOpen (depois de _seedCatalogoEstatico).
//
// Estratégia: NativeDatabase.memory() pura + AppDatabase.forTesting — a
// primeira query dispara onCreate (tabelas+índices+base) e beforeOpen
// (admin, seed do catálogo, reparo idempotente). NADA de seed manual: é
// justamente o comportamento do app instalado que importa.
// ============================================================

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urutau/data/database.dart';
import 'package:urutau/data/migrations/mrv_migration.dart';

void main() {
  group('caminho FRESCO (onCreate): banco novo sai consistente', () {
    late NativeDatabase executor;
    late AppDatabase db;

    setUp(() async {
      executor = NativeDatabase.memory();
      db = AppDatabase.forTesting(executor);
      // Dispara onCreate + beforeOpen.
      await db.customSelect('SELECT 1').get();
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> _count(String sql) async {
      final rows = await executor.runSelect(sql, const []);
      return rows.first.values.first as int;
    }

    test('índices MRV existem em banco novo (não só em migração)', () async {
      // Um índice representante de cada versão de SQL.
      const indices = [
        'idx_parcelas_projeto_id', // v19
        'idx_parcelas_parcela_id_text', // v19
        'idx_amostras_parcela_uuid', // v19
        'idx_individuos_parcela_uuid', // v20
        'idx_medicoes_amostra_uuid', // v20
        'uq_ativos_brutos_sha256', // v21 (UNIQUE)
        'idx_trilha_entidade', // v21
        'idx_especies_nome', // v22
        'idx_usuario_papeis_usuario', // v23
        'idx_incidentes_entidade', // v23
      ];
      for (final idx in indices) {
        expect(
            await _count(
                "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name='$idx'"),
            1,
            reason: 'índice $idx deveria existir em banco novo');
      }
    });

    test('scaffold presente: LEGADO, SOP-MRV e 5 papéis', () async {
      expect(
          await _count(
              "SELECT COUNT(*) FROM projetos_mrv WHERE uuid='LEGADO-PROJ-0000'"),
          1,
          reason: 'projeto LEGADO tem de existir em banco novo');
      expect(
          await _count(
              "SELECT COUNT(*) FROM periodos_monitoramento WHERE uuid='LEGADO-PER-0000'"),
          1);
      expect(
          await _count(
              "SELECT COUNT(*) FROM campanhas WHERE uuid='LEGADO-CAMP-0001'"),
          1);
      expect(
          await _count(
              "SELECT COUNT(*) FROM protocolos_medicao WHERE codigo='SOP-MRV'"),
          1,
          reason: 'protocolo SOP-MRV (convencao DAP 1,30m) tem de ser semeado');
      expect(await _count('SELECT COUNT(*) FROM papeis'), 5,
          reason: '5 papéis-base de governança');
    });

    test('parcelas do seed nascem com identidade MRV (projeto_id + parcela_id_text)',
        () async {
      final seed = await _count("SELECT COUNT(*) FROM parcelas WHERE uuid LIKE 'seed-%'");
      expect(seed, greaterThan(0),
          reason: 'o seed do catálogo tem de rodar no beforeOpen');

      expect(
          await _count(
              "SELECT COUNT(*) FROM parcelas WHERE uuid LIKE 'seed-%' AND projeto_id IS NULL"),
          0,
          reason: 'parcela seed nao pode nascer sem projeto_id (bug §9.1)');
      expect(
          await _count(
              "SELECT COUNT(*) FROM parcelas WHERE uuid LIKE 'seed-%' AND parcela_id_text IS NULL"),
          0,
          reason: 'parcela seed nao pode nascer sem parcela_id_text (bug §9.1)');
    });

    test('backfill fresco: catálogo semeia só parcelas — nada a backfillar',
        () async {
      // REALIDADE MEDICA: _seedCatalogoEstatico() insere apenas parcelas
      // (uuid seed-<prop>-<ut>-1), NÃO plantas. Logo, no caminho fresco, os
      // backfills de indivíduo/medição/amostra não têm fonte e não criam
      // nada. A cobertura do backfill com dados reais é do teste de MIGRAÇÃO
      // (mrv_migration_test.dart), que semeia plantas na mão.
      final plantas = await _count('SELECT COUNT(*) FROM plantas');
      expect(plantas, 0,
          reason: 'o catálogo do app semeia parcelas sem plantas');
      expect(await _count('SELECT COUNT(*) FROM individuos'), 0);
      expect(await _count('SELECT COUNT(*) FROM medicoes_individuo'), 0);
      expect(await _count('SELECT COUNT(*) FROM amostras_parcela'), 0,
          reason: 'amostra só existe para parcela COM planta');
      expect(await _count('SELECT COUNT(*) FROM especies_catalogo'), 0);

      // O scaffold e a identidade das parcelas semearam (testes acima) — o
      // fresco fica pronto para receber trabalho de campo.
    });

    test('idempotência: 2ª aplicação da base não duplica nada', () async {
      // Não dá para reabrir o executor (drift proíbe). Em vez disso, prova a
      // idempotência pelo que importa: rodar o SQL da base OUTRA vez sobre o
      // banco já inicializado (é o que aconteceria em cada beforeOpen).
      final antesProj = await _count('SELECT COUNT(*) FROM projetos_mrv');
      final antesSop = await _count(
          "SELECT COUNT(*) FROM protocolos_medicao WHERE codigo='SOP-MRV'");
      final antesPapeis = await _count('SELECT COUNT(*) FROM papeis');
      final antesAmos = await _count('SELECT COUNT(*) FROM amostras_parcela');

      await MrvMigration.aplicarBase((sql) => db.customStatement(sql));

      expect(await _count('SELECT COUNT(*) FROM projetos_mrv'), antesProj);
      expect(await _count(
          "SELECT COUNT(*) FROM protocolos_medicao WHERE codigo='SOP-MRV'"), antesSop);
      expect(await _count('SELECT COUNT(*) FROM papeis'), antesPapeis);
      expect(await _count('SELECT COUNT(*) FROM amostras_parcela'), antesAmos);
    });
  });
}
