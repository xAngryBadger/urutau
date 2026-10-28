import 'dart:io' as io;
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../services/backup_service.dart';
import '../services/password_service.dart';
import '../services/image_service.dart';
// >>> t9 patch: inicio (imports ANTES do part — Dart exige essa ordem)
import 'migrations/mrv_tables.dart';
import 'migrations/mrv_migration.dart';
// <<< t9 patch: fim

part 'database.g.dart';

// ============================================================
// TABELAS DO DRIFT (SQLite LOCAL)
// ============================================================

class Usuarios extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get nome => text()();
  TextColumn get email => text().unique()();
  TextColumn get senha => text()(); // SHA-256 com salt (formato: "salt:hash")
  BoolColumn get isAdmin => boolean().withDefault(const Constant(false))();
  BoolColumn get ativo => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Parcelas: hierarquia é Propriedade > UT/Talhão > Parcela.
/// - propriedade: nome da Propriedade (nível 1; não confundir com UT).
/// - propUt: nome do UT/Talhão (nível 2). No PocketBase o campo é prop_ut.
class Parcelas extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get propriedade => text().withDefault(const Constant(''))();
  TextColumn get propUt => text()();
  IntColumn get idParcela => integer()();
  TextColumn get observacoes => text().nullable()();
  // Reservado para uso futuro com GPS — atualmente sem uso (GPS desativado)
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get userId => text()();
  RealColumn get areaHa => real().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  /// true = utilizador marcou "concluída" → pode sincronizar; false = rascunho/incompleta
  BoolColumn get prontaParaSync =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  // Soft-delete
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deletedBy => text().nullable()();

  /// Quem criou esta parcela (uuid do user ou '' para seed/sistema). Usado para filtrar catálogo por usuário.
  TextColumn get createdBy => text().withDefault(const Constant(''))();

  BoolColumn get parcialmenteSincronizada =>
      boolean().withDefault(const Constant(false))();

  // >>> t9 patch: inicio — MRV (v20)
  // projeto/modalidade (D-02)
  TextColumn get projetoId => text().nullable()();
  // chave de negócio legível da parcela (RS-02). NAO é UNIQUE: o app permite
  // parcela duplicada entre coletores e SINALIZA o conflito
  // (findParcelaDuplicada). Índice único quebraria essa feature (Compat-UNIQUE).
  TextColumn get parcelaIdText => text().nullable()();
  // geo obrigatória (RC-10): {"tipo","coordenadas","crs","acuracia_m",
  //                          "n_satelites","fix_em","fonte"}
  TextColumn get geoJson => text().nullable()();
  // unidade amostral (RS-01)
  RealColumn get areaM2 => real().nullable()();
  TextColumn get unidadeForma => text().nullable()(); // retangular|circular|quadrada
  RealColumn get raioM => real().nullable()();
  TextColumn get statusParcela =>
      text().nullable().withDefault(const Constant('ativa'))();
  TextColumn get marcador => text().nullable()(); // estaca/plaqueta (RS-02)
  TextColumn get protocoloVersao => text().nullable()(); // SOP aplicado (RC-11)
  TextColumn get substitutaDe => text().nullable()(); // rastreio de substituição (RS-06)
  // <<< t9 patch: fim
}

class Plantas extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get parcelaUuid => text().references(Parcelas, #uuid)();
  TextColumn get especie => text()();
  RealColumn get alturaCm => real()();
  RealColumn get dapCm => real().nullable()();
  IntColumn get categoria => integer()(); // 1, 2 ou 3
  TextColumn get fotoEspeciePath => text().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  // Soft-delete
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// (Q2) true = fotoEspeciePath aponta para arquivo ausente no disco.
  /// O PATH permanece (evidência do original); a marcação informa a UI.
  BoolColumn get fotoAusente =>
      boolean().withDefault(const Constant(false))();
}

class FotosParcela extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get parcelaUuid => text().references(Parcelas, #uuid)();
  TextColumn get filePath => text()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// (Q2) true = arquivo não encontrado no disco. A LINHA permanece como
  /// evidência de que a foto existiu — nunca deletar (auditoria).
  BoolColumn get arquivoAusente =>
      boolean().withDefault(const Constant(false))();
}

/// Tabela de auditoria — registra operações críticas no sistema.
class AuditLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get action =>
      text()(); // ex: 'delete_parcela', 'login', 'sync_push'
  TextColumn get entityType =>
      text().nullable()(); // 'parcela', 'planta', 'usuario'
  TextColumn get entityUuid => text().nullable()();
  TextColumn get userId => text().nullable()(); // quem fez a ação
  TextColumn get details => text().nullable()(); // JSON com detalhes extras
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get oldValue => text().nullable()();
  TextColumn get newValue => text().nullable()();
}

// ============================================================
// DATABASE
// ============================================================

@DriftDatabase(tables: [
  Usuarios, Parcelas, Plantas, FotosParcela, AuditLog,
  // >>> t9 patch: inicio — MRV v20..v23
  ProjetosMrv, PeriodosMonitoramento, Campanhas, DesenhoAmostral,
  ProtocolosMedicao, AmostrasParcela,
  Individuos, MedicoesIndividuo, PlantacaoUts, MedicoesPlantacao,
  RestauracaoProjetos, RestauracaoUts, MedicoesRestauracao, CoberturasAmostra,
  AtivosBrutos, Dispositivos, TrilhaAuditoria,
  EspeciesCatalogo, EquacoesAlometricas, CalculosMrv, ResultadosAmostra,
  Papeis, UsuarioPapeis, Incidentes, VerificacoesInternas, Competencias,
  // <<< t9 patch: fim
])
class AppDatabase extends _$AppDatabase {
  AppDatabase._internal(super.e);

  /// Construtor para testes: injeta um QueryExecutor (ex.: NativeDatabase.memory()).
  AppDatabase.forTesting(QueryExecutor e) : super(e);

  static AppDatabase? _instance;

  factory AppDatabase() {
    _instance ??= AppDatabase._internal(
      driftDatabase(
        name: 'urutau',
        web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js')),
      ),
    );
    return _instance!;
  }

  @override
  int get schemaVersion => 24; // t9: MRV v20..v24, por cima da v19 (43a165e)

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _createIndexes(m);
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(usuarios);
        }
  if (from < 3) {
      await m.addColumn(parcelas, parcelas.latitude);
      await m.addColumn(parcelas, parcelas.longitude);
    }
        if (from < 5) {
          await _limparDadosOrfaos();
        }
        if (from < 6) {
          // Novas colunas de soft-delete
          await m.addColumn(parcelas, parcelas.deletedAt);
          await m.addColumn(parcelas, parcelas.deletedBy);
          await m.addColumn(plantas, plantas.deletedAt);
          // Tabela de auditoria
          await m.createTable(auditLog);
          // Migra senhas plaintext para hash
          await _migrarSenhasParaHash();
        }
        if (from < 7) {
          // Nova coluna: propriedade (hierarquia)
          await m.addColumn(parcelas, parcelas.propriedade);
          // Migrar dados existentes: tentar extrair propriedade do propUt
          await _migrarPropriedadeDeProput();
        }
        if (from < 8) {
          // Nova coluna: área em hectares
          await m.addColumn(parcelas, parcelas.areaHa);
        }
        if (from < 9) {
          await m.addColumn(parcelas, parcelas.prontaParaSync);
        }
        if (from < 10) {
          await m.addColumn(parcelas, parcelas.createdBy);
        }
        if (from < 11) {
          // Re-seed: apaga seed antigo (múltiplas parcelas/UT) para re-inserir 1/UT
          await (delete(plantas)..where((t) => t.parcelaUuid.like('seed-%')))
              .go();
          await (delete(fotosParcela)
                ..where((t) => t.parcelaUuid.like('seed-%')))
              .go();
          await (delete(parcelas)..where((t) => t.uuid.like('seed-%'))).go();
        }
        if (from < 12) {
          // Corrigir parcelas synced do servidor que ficaram com prontaParaSync=false
          await (update(parcelas)
                ..where((t) =>
                    t.synced.equals(true) & t.prontaParaSync.equals(false)))
              .write(const ParcelasCompanion(prontaParaSync: Value(true)));
        }
        if (from < 13) {
          await m.addColumn(fotosParcela, fotosParcela.deletedAt);
        }
        if (from < 14) {
          await _createIndexes(m);
        }
        if (from < 15) {
          // v15: Adicionar índices para sincronização
          await _createIndexes(m);
        }
        if (from < 16) {
          await customStatement(
              'ALTER TABLE fotos_parcela DROP COLUMN compressed_path');
        }
      if (from < 17) {
        await m.addColumn(parcelas, parcelas.parcialmenteSincronizada);
        await m.addColumn(auditLog, auditLog.oldValue);
        await m.addColumn(auditLog, auditLog.newValue);
      }
      if (from < 18) {
      await m.addColumn(plantas, plantas.updatedAt);
      await customStatement(
          'UPDATE plantas SET updated_at = created_at WHERE updated_at IS NULL');
    }
      if (from < 19) {
        // Q2: marcar ausência de arquivo sem apagar evidência
        await m.addColumn(fotosParcela, fotosParcela.arquivoAusente);
        await m.addColumn(plantas, plantas.fotoAusente);
      }
      // >>> t9 patch: inicio — migracao MRV v20..v24
      if (from < 20) {
        await _mrvV20Ddl(m);
        // dev-codigo: o hunk original chamava so v20. O backfill das colunas
        // de parcela + indices + semente do protocolo SOP-MRV vive em
        // MrvMigration.v19() (o patch a marcou "nunca chamar", mas o proprio
        // teste mrv_migration_test.dart exige parcela_id_text/area_m2/geo_json
        // e o SOP-MRV semeado). Roda DEPOIS do DDL (as colunas passam a
        // existir) e ANTES de v20 (scaffold LEGADO depende das colunas).
        await MrvMigration.v19(m);
        await MrvMigration.v20(m);
      }
      if (from < 21) { await _mrvV21Ddl(m); await MrvMigration.v21(m); }
      if (from < 22) { await _mrvV22Ddl(m); await MrvMigration.v22(m); }
      if (from < 23) { await _mrvV23Ddl(m); await MrvMigration.v23(m); }
      // v24 nao tem DDL: e o marco de depreciacao controlada. Nada e dropado.
      if (from < 24) { await MrvMigration.v24(m); }
      // <<< t9 patch: fim
  },
      beforeOpen: (details) async {
        await customStatement('PRAGMA journal_mode = WAL');
        await customStatement('PRAGMA foreign_keys = ON');
        await customStatement('PRAGMA synchronous = NORMAL');
        await _garantirAdminSeNecessario();
        await _seedCatalogoEstatico();
        await purgarAuditLog();
      },
    );
  }

  Future<void> _createIndexes(Migrator m) async {
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_plantas_parcela_uuid ON plantas(parcela_uuid)');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_fotos_parcela_uuid ON fotos_parcela(parcela_uuid)');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_parcelas_user_id ON parcelas(user_id)');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_parcelas_deleted_at ON parcelas(deleted_at)');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_parcelas_created_by ON parcelas(created_by)');
    // Índices para sincronização (usados em getParcelasNaoSincronizadas)
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_parcelas_synced ON parcelas(synced)');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_parcelas_prontaParaSync ON parcelas(pronta_para_sync)');
    // Índice composto para busca eficiente de parcelas não sincronizadas
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_parcelas_sync_status ON parcelas(synced, pronta_para_sync, deleted_at)');
  }

  // >>> t9 patch: inicio — DDL do modelo MRV (v20..v23)
  // createTable/addColumn precisam das instancias geradas pelo build_runner,
  // que so existem como campos desta classe. Por isso o DDL fica aqui, e o SQL
  // puro (indices + backfill) fica em migrations/mrv_migration.dart.
  // Nenhuma coluna nova NOT NULL sem default; nenhum drop.

  Future<void> _mrvV20Ddl(Migrator m) async {
    // 10 colunas de parcela — vieram para a v20 porque a v19 committed
    // (43a165e) é so do Q2.
    await m.addColumn(parcelas, parcelas.projetoId);
    await m.addColumn(parcelas, parcelas.parcelaIdText);
    await m.addColumn(parcelas, parcelas.geoJson);
    await m.addColumn(parcelas, parcelas.areaM2);
    await m.addColumn(parcelas, parcelas.unidadeForma);
    await m.addColumn(parcelas, parcelas.raioM);
    await m.addColumn(parcelas, parcelas.statusParcela);
    await m.addColumn(parcelas, parcelas.marcador);
    await m.addColumn(parcelas, parcelas.protocoloVersao);
    await m.addColumn(parcelas, parcelas.substitutaDe);
    await m.createTable(projetosMrv);
    await m.createTable(periodosMonitoramento);
    await m.createTable(campanhas);
    await m.createTable(desenhoAmostral);
    await m.createTable(protocolosMedicao);
    await m.createTable(amostrasParcela);
    await m.createTable(individuos);
    await m.createTable(medicoesIndividuo);
    await m.createTable(plantacaoUts);
    await m.createTable(restauracaoProjetos);
    await m.createTable(restauracaoUts);
    await m.createTable(medicoesRestauracao);
    await m.createTable(medicoesPlantacao);
    await m.createTable(coberturasAmostra);
  }

  Future<void> _mrvV21Ddl(Migrator m) async {
    await m.createTable(ativosBrutos);
    await m.createTable(dispositivos);
    await m.createTable(trilhaAuditoria);
  }

  Future<void> _mrvV22Ddl(Migrator m) async {
    await m.createTable(especiesCatalogo);
    await m.createTable(equacoesAlometricas);
    await m.createTable(calculosMrv);
    await m.createTable(resultadosAmostra);
  }

  Future<void> _mrvV23Ddl(Migrator m) async {
    await m.createTable(papeis);
    await m.createTable(usuarioPapeis);
    await m.createTable(incidentes);
    await m.createTable(verificacoesInternas);
    await m.createTable(competencias);
  }
  // <<< t9 patch: fim

  /// Migra senhas armazenadas em plaintext para formato hash (SHA-256 + salt).
  /// Mantém compatibilidade: se já estiver no formato hash, não faz nada.
  Future<void> _migrarSenhasParaHash() async {
    await transaction(() async {
      try {
        final todosUsuarios = await (select(usuarios)).get();
        for (final user in todosUsuarios) {
          if (!PasswordService.isHashed(user.senha)) {
            final String hashed;
            if (user.senha == 'servidor' || user.senha == 'importado') {
              hashed = PasswordService.generateServerPlaceholder();
            } else {
              hashed = PasswordService.hashPassword(user.senha);
            }
            await (update(usuarios)..where((t) => t.uuid.equals(user.uuid)))
                .write(UsuariosCompanion(senha: Value(hashed)));
          }
        }
      } catch (e) {
        print('[DB] Password migration failed: $e');
      }
    });
  }

  /// Migra dados existentes: tenta extrair propriedade do campo propUt.
  /// Se propUt contém " - " (ex: "Fazenda São João - UT 01"), separa.
  Future<void> _migrarPropriedadeDeProput() async {
    await transaction(() async {
      final todasParcelas = await (select(parcelas)).get();
      for (final p in todasParcelas) {
        if (p.propriedade.isEmpty && p.propUt.contains(' - ')) {
          final parts = p.propUt.split(' - ');
          final prop = parts.first.trim();
          final ut = parts.sublist(1).join(' - ').trim();
          await (update(parcelas)..where((t) => t.uuid.equals(p.uuid)))
              .write(ParcelasCompanion(
            propriedade: Value(prop),
            propUt: Value(ut.isEmpty ? p.propUt : ut),
          ));
        }
      }
    });
  }

  /// Garante que existe pelo menos 1 admin no sistema.
  /// Se não houver nenhum, marca o primeiro usuário como admin.
  /// NÃO injeta credenciais hardcoded.
  Future<void> _garantirAdminSeNecessario() async {
    final admins = await (select(usuarios)
          ..where((t) => t.isAdmin.equals(true) & t.ativo.equals(true)))
        .get();
    if (admins.isNotEmpty) return; // Já existe admin

    // Se não há admin, e há usuários, o primeiro cadastrado vira admin
    final todosUsers = await (select(usuarios)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    if (todosUsers.isNotEmpty) {
      await (update(usuarios)
            ..where((t) => t.uuid.equals(todosUsers.first.uuid)))
          .write(const UsuariosCompanion(isAdmin: Value(true)));
    }
    // Se não há nenhum usuário, o primeiro a se cadastrar vira admin
    // (tratado na lógica de registro)
  }

  // ─── Catálogo estático de parcelas (1 parcela por UT, 72 UTs únicas) ───
  // Usuários adicionam mais parcelas pelo app conforme necessário.
  static const String _catalogoCsv = '''DIMI0020;UT01;0.0;1
DIMI0020;UT05;0.0;1
DIMI0021;UT03;0.0;1
GHGH0058;UT06;0.0;1
GHGH0059;UT03;0.0;1
GHGH0064;UT01;0.0;1
GHGH0070;UT05;0.0;1
GHGH0070;UT06;0.0;1
GHGH0084;UT04;0.0;1
GHGH0107;UT01;0.0;1
GHGH0110;UT01;0.0;1
GHGH0111;UT02;0.0;1
GHGH0112;UT01;0.0;1
GHGH0115;UT01;0.0;1
GHGH0128;UT01;0.0;1
GHGH0147;UT01;0.0;1
GHGH0147;UT02;0.0;1
GHGH0150;UT01;0.0;1
GHGH0152;UT01;0.0;1
GHGH0154;UT01;0.0;1
GHGH0170;UT01;0.0;1
GHGH0180;UT02;0.0;1
GHGH0180;UT03;0.0;1
GHGH0185;UT02;0.0;1
GHGH0185;UT03;0.0;1
GHGH0185;UT04;0.0;1
GHGH0186;UT01;0.0;1
GHGH0190;UT01;0.0;1
GHGH0194;UT02;0.0;1
GHGH0194;UT03;0.0;1
GHGH0194;UT08;0.0;1
GHGH0194;UT10;0.0;1
GHGH0194;UT11;0.0;1
GHGH0195;UT01;0.0;1
GHGH0195;UT02;0.0;1
GHGH0195;UT03;0.0;1
GHGH0195;UT04;0.0;1
GHGH0195;UT05;0.0;1
GHGH0195;UT06;0.0;1
GHGH0201;UT01;0.0;1
GHGH0201;UT02;0.0;1
GHGH0201;UT03;0.0;1
GHGH0206;UT02;0.0;1
GHGH0206;UT03;0.0;1
GHGH0206;UT04;0.0;1
SESE0007;UT08;0.0;1
SESE0012;UT01;0.0;1
SESE0012;UT02;0.0;1
SESE0013;UT01;0.0;1
SESE0014;UT01;0.0;1
SESE0019;UT02;0.0;1
SESE0022;UT01;0.0;1
SESE0022;UT02;0.0;1
SESE0026;UT01;0.0;1
SESE0027;UT01;0.0;1
SESE0027;UT02;0.0;1
SESE0027;UT03;0.0;1
SESE0027;UT04;0.0;1
SESE0027;UT05;0.0;1
VGVG0063;UT03;0.0;1
VGVG0063;UT04;0.0;1
VGVG0063;UT05;0.0;1
VGVG0063;UT06;0.0;1
VGVG0064;UT01;0.0;1
VGVG0068;UT02;0.0;1
VGVG0068;UT03;0.0;1
VGVG0068;UT04;0.0;1
VGVG0068;UT05;0.0;1
VGVG0069;UT01;0.0;1
VGVG0069;UT02;0.0;1
VGVG0069;UT03;0.0;1
VGVG0069;UT04;0.0;1''';

  /// Popula o banco com o catálogo estático: 1 parcela por UT.
  /// Idempotente: só roda se não existir nenhuma parcela com UUID 'seed-'.
  /// NÃO apaga parcelas vindas do servidor (pb-); dados do servidor e seed coexistem.
  Future<void> _seedCatalogoEstatico() async {
    await transaction(() async {
      final probe = await (select(parcelas)
            ..where((t) => t.uuid.like('seed-%'))
            ..limit(1))
          .get();
      if (probe.isNotEmpty) return;

      final now = DateTime.now();
      for (final line in _catalogoCsv.split('\n')) {
        if (line.trim().isEmpty) continue;
        final parts = line.split(';');
        if (parts.length < 4) continue;
        final prop = parts[0].trim();
        final ut = parts[1].trim();
        final uuid = 'seed-$prop-$ut-1';
        await into(parcelas).insert(ParcelasCompanion.insert(
          uuid: uuid,
          propriedade: Value(prop),
          propUt: ut,
          idParcela: 1,
          userId: '',
          synced: const Value(true),
          prontaParaSync: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now),
        ));
      }
    });
  }

  /// Remove parcelas/plantas/fotos de usuários que não existem mais
  Future<void> _limparDadosOrfaos() async {
    final todosUsuarios = await (select(usuarios)).get();
    final uuidsValidos = todosUsuarios.map((u) => u.uuid).toSet();

    final todasParcelas = await (select(parcelas)).get();
    final orphanPaths = <String>[];
    for (final parcela in todasParcelas) {
      if (!uuidsValidos.contains(parcela.userId)) {
        final fotos = await getFotosByParcela(parcela.uuid);
        orphanPaths.addAll(fotos.map((f) => f.filePath));
        final plantas = await getPlantasByParcela(parcela.uuid);
        for (final planta in plantas) {
          if (planta.fotoEspeciePath != null)
            orphanPaths.add(planta.fotoEspeciePath!);
        }
      }
    }

    await transaction(() async {
      for (final parcela in todasParcelas) {
        if (!uuidsValidos.contains(parcela.userId)) {
          await deleteAllPlantasByParcela(parcela.uuid);
          await deleteAllFotosByParcela(parcela.uuid);
          await deleteParcela(parcela.uuid);
        }
      }
    });

    await ImageService.deletePhotos(orphanPaths);
  }

  /// Apaga um usuário e TODOS os seus dados (parcelas, plantas, fotos)
  Future<void> deleteUsuarioComDados(String uuid) async {
    final parcelasUser =
        await (select(parcelas)..where((t) => t.userId.equals(uuid))).get();
    final photoPaths = <String>[];
    for (final parcela in parcelasUser) {
      final fotos = await (select(fotosParcela)
            ..where((t) => t.parcelaUuid.equals(parcela.uuid)))
          .get();
      photoPaths.addAll(fotos.map((f) => f.filePath));
      final plantasList = await (select(plantas)
            ..where((t) => t.parcelaUuid.equals(parcela.uuid)))
          .get();
      for (final planta in plantasList) {
        if (planta.fotoEspeciePath != null)
          photoPaths.add(planta.fotoEspeciePath!);
      }
    }

  await ImageService.deletePhotos(photoPaths);
  await transaction(() async {
    for (final parcela in parcelasUser) {
      await deleteAllPlantasByParcela(parcela.uuid);
      await deleteAllFotosByParcela(parcela.uuid);
      await deleteParcela(parcela.uuid);
    }
    await deleteUsuario(uuid);
  });
  }

  Future<void> deleteAllSyncedParcelas() async {
    final synced = await (select(parcelas)
          ..where((t) => t.synced.equals(true) & t.deletedAt.isNull()))
        .get();
    final photoPaths = <String>[];
    for (final p in synced) {
      final fotos = await getFotosByParcela(p.uuid);
      photoPaths.addAll(fotos.map((f) => f.filePath));
    }
    await transaction(() async {
      for (final p in synced) {
        await (delete(plantas)..where((t) => t.parcelaUuid.equals(p.uuid)))
            .go();
        await (delete(fotosParcela)..where((t) => t.parcelaUuid.equals(p.uuid)))
            .go();
        await (delete(parcelas)..where((t) => t.uuid.equals(p.uuid))).go();
      }
    });
    await ImageService.deletePhotos(photoPaths);
  }

  Future<void> limparTodosDadosExcetoAdmin() async {
    try {
      await BackupService.exportBackup();
    } catch (_) {}
    final allFotos = await (select(fotosParcela)).get();
    final allPlantas = await (select(plantas)
          ..where((t) => t.fotoEspeciePath.isNotNull()))
        .get();
    final photoPaths = <String>[
      ...allFotos.map((f) => f.filePath),
      ...allPlantas.map((p) => p.fotoEspeciePath!),
    ];
    
    // Delete photo files directly
    for (final path in photoPaths) {
      final file = io.File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    
    // Delete photos directory
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = io.Directory(p.join(appDir.path, 'fotos'));
    if (await photosDir.exists()) {
      await photosDir.delete(recursive: true);
    }

    await transaction(() async {
      await delete(fotosParcela).go();
      await delete(plantas).go();
      await delete(parcelas).go();
      await (delete(usuarios)..where((t) => t.isAdmin.equals(false))).go();
    });
  }

  // ========== USUARIOS ==========

  Future<List<Usuario>> getAllUsuarios() => (select(usuarios)
        ..where((t) => t.ativo.equals(true))
        ..orderBy([(t) => OrderingTerm.asc(t.nome)]))
      .get();

  Future<Usuario?> getUsuarioByEmail(String email) =>
      (select(usuarios)..where((t) => t.email.equals(email))).getSingleOrNull();

  Future<Usuario?> getUsuarioByUuid(String uuid) =>
      (select(usuarios)..where((t) => t.uuid.equals(uuid))).getSingleOrNull();

  Future<Usuario?> autenticarUsuario(String email, String senha) async {
    final user = await (select(usuarios)
          ..where((t) => t.email.equals(email) & t.ativo.equals(true)))
        .getSingleOrNull();
    if (user == null) return null;
    if (PasswordService.isServerPlaceholder(user.senha)) return null;
    if (PasswordService.verifyPassword(senha, user.senha)) {
      return user;
    }
    return null;
  }

  Future<int> insertUsuario(UsuariosCompanion usuario) {
    // Hash a senha se está em plaintext
    if (usuario.senha.present &&
        !PasswordService.isHashed(usuario.senha.value)) {
      final hashed = PasswordService.hashPassword(usuario.senha.value);
      usuario = usuario.copyWith(senha: Value(hashed));
    }
    return into(usuarios).insert(usuario);
  }

  /// Insere usuário SEM hashear a senha (para importações do servidor onde
  /// a senha é um placeholder como 'servidor' ou 'importado').
  Future<int> insertUsuarioRaw(UsuariosCompanion usuario) =>
      into(usuarios).insert(usuario);

  Future<int> updateUsuario(UsuariosCompanion usuario, String uuid) =>
      (update(usuarios)..where((t) => t.uuid.equals(uuid))).write(usuario);

  /// Atualiza o UUID de um usuário e cascata para todas as parcelas referenciadas.
  /// Usado para reconciliar UUID local com o ID do PocketBase.
  Future<void> remapUsuarioUuid(String oldUuid, String newUuid) async {
    if (oldUuid == newUuid) return;
    await transaction(() async {
      await (update(parcelas)..where((t) => t.userId.equals(oldUuid)))
          .write(ParcelasCompanion(userId: Value(newUuid)));
      await (update(parcelas)..where((t) => t.createdBy.equals(oldUuid)))
          .write(ParcelasCompanion(createdBy: Value(newUuid)));
      await (update(usuarios)..where((t) => t.uuid.equals(oldUuid)))
          .write(UsuariosCompanion(uuid: Value(newUuid)));
    });
  }

  /// Atualiza o UUID de uma parcela e cascata para plantas e fotos.
  /// Usado para mapear UUID local → PocketBase record ID após push.
  Future<void> remapParcelaUuid(String oldUuid, String newUuid) async {
    if (oldUuid == newUuid) return;
    await transaction(() async {
      await (update(plantas)..where((t) => t.parcelaUuid.equals(oldUuid)))
          .write(PlantasCompanion(parcelaUuid: Value(newUuid)));
      await (update(fotosParcela)..where((t) => t.parcelaUuid.equals(oldUuid)))
          .write(FotosParcelaCompanion(parcelaUuid: Value(newUuid)));
      // >>> t9 patch: inicio — cascade MRV (RS-02)
      // Linhas MRV apontam para parcelas.uuid por texto; sem este cascade o
      // remap (sync_service _syncParcela) as deixaria orfas de identidade.
      await (update(individuos)..where((t) => t.parcelaUuid.equals(oldUuid)))
          .write(IndividuosCompanion(parcelaUuid: Value(newUuid)));
      await (update(amostrasParcela)..where((t) => t.parcelaUuid.equals(oldUuid)))
          .write(AmostrasParcelaCompanion(parcelaUuid: Value(newUuid)));
      // ativos_brutos: so os de escopo parcela (vinculo polimorfico)
      await (update(ativosBrutos)
            ..where((t) =>
                t.entidadeTipo.equals('parcela') &
                t.entidadeUuid.equals(oldUuid)))
          .write(AtivosBrutosCompanion(entidadeUuid: Value(newUuid)));
      // <<< t9 patch: fim
      await (update(parcelas)..where((t) => t.uuid.equals(oldUuid)))
          .write(ParcelasCompanion(uuid: Value(newUuid)));
    });
  }

  /// Verifica se já existe parcela com mesmos (propUt, idParcela, userId).
  Future<Parcela?> findParcelaDuplicada(
          String propUt, int idParcela, String userId) =>
      (select(parcelas)
            ..where((t) =>
                t.propUt.equals(propUt) &
                t.idParcela.equals(idParcela) &
                t.userId.equals(userId) &
                t.deletedAt.isNull()))
          .getSingleOrNull();

  /// Parcela disponível (userId vazio) com mesmo (propriedade, propUt, idParcela).
  /// Evita duplicação ao criar nova parcela após limpar.
  Future<Parcela?> findParcelaDisponivel(
          String propriedade, String propUt, int idParcela) =>
      (select(parcelas)
            ..where((t) =>
                t.propriedade.equals(propriedade) &
                t.propUt.equals(propUt) &
                t.idParcela.equals(idParcela) &
                t.userId.equals('') &
                t.deletedAt.isNull()))
          .getSingleOrNull();

  /// Verifica se já existe outra parcela (excluindo [excludeUuid]) com mesmo (propriedade, propUt, idParcela).
  /// Usado ao renomear para evitar duplicados.
  Future<Parcela?> findOutraParcelaComMesmoId({
    required String propriedade,
    required String propUt,
    required int idParcela,
    required String excludeUuid,
  }) async {
    final list = await (select(parcelas)
          ..where((t) =>
              t.propriedade.equals(propriedade) &
              t.propUt.equals(propUt) &
              t.idParcela.equals(idParcela) &
              t.deletedAt.isNull()))
        .get();
    for (final p in list) {
      if (p.uuid != excludeUuid) return p;
    }
    return null;
  }

  Future<int> deleteUsuario(String uuid) =>
      (delete(usuarios)..where((t) => t.uuid.equals(uuid))).go();

  // ========== PARCELAS ==========

  Future<List<Parcela>> getAllParcelas({String? userId, bool isAdmin = false}) {
    final query = select(parcelas)..where((t) => t.deletedAt.isNull());
    if (!isAdmin && userId != null) {
      query.where((t) =>
          t.createdBy.equals(userId) |
          t.createdBy.equals('') |
          t.userId.equals(userId));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.get();
  }

  /// Busca parcelas com filtros opcionais: userId, propriedade, talhão e intervalo de datas.
  Future<List<Parcela>> searchParcelas({
    String? userId,
    bool isAdmin = false,
    String? propriedade,
    String? propUt,
    DateTime? dataInicio,
    DateTime? dataFim,
  }) {
    final query = select(parcelas)..where((t) => t.deletedAt.isNull());
    if (!isAdmin && userId != null) {
      query.where((t) =>
          t.createdBy.equals(userId) |
          t.createdBy.equals('') |
          t.userId.equals(userId));
    }
    if (propriedade != null && propriedade.isNotEmpty) {
      query.where((t) => t.propriedade.equals(propriedade));
    }
    if (propUt != null && propUt.isNotEmpty) {
      query.where((t) => t.propUt.equals(propUt));
    }
    if (dataInicio != null) {
      query.where((t) => t.createdAt.isBiggerOrEqualValue(dataInicio));
    }
    if (dataFim != null) {
      final nextDay = DateTime(dataFim.year, dataFim.month, dataFim.day + 1);
      query.where((t) => t.createdAt.isSmallerThanValue(nextDay));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.get();
  }

  /// Retorna lista de propriedades únicas.
  /// Se não admin: só parcelas que o user criou (createdBy), que são seed (createdBy=''), ou que está trabalhando (userId).
  Future<List<String>> getAllPropriedades(
      {String? userId, bool isAdmin = false}) async {
    final query = select(parcelas)..where((t) => t.deletedAt.isNull());
    if (!isAdmin && userId != null) {
      query.where((t) =>
          t.createdBy.equals(userId) |
          t.createdBy.equals('') |
          t.userId.equals(userId));
    }
    final rows = await query.get();
    final Set<String> unicos = {};
    for (final p in rows) {
      if (p.propriedade.isNotEmpty) unicos.add(p.propriedade);
    }
    final list = unicos.toList()..sort();
    return list;
  }

  /// Retorna lista de talhões/UTs únicos (propUt), opcionalmente filtrado por propriedade.
  Future<List<String>> getAllTalhoes(
      {String? userId, bool isAdmin = false, String? propriedade}) async {
    final query = select(parcelas)..where((t) => t.deletedAt.isNull());
    if (!isAdmin && userId != null) {
      query.where((t) =>
          t.createdBy.equals(userId) |
          t.createdBy.equals('') |
          t.userId.equals(userId));
    }
    if (propriedade != null && propriedade.isNotEmpty) {
      query.where((t) => t.propriedade.equals(propriedade));
    }
    final rows = await query.get();
    final Set<String> unicos = {};
    for (final p in rows) {
      if (p.propUt.isNotEmpty) unicos.add(p.propUt);
    }
    final list = unicos.toList()..sort();
    return list;
  }

  /// Retorna parcelas filtradas por propriedade e/ou talhão.
  Future<List<Parcela>> getParcelasByHierarchy({
    String? userId,
    bool isAdmin = false,
    String? propriedade,
    String? propUt,
    int limit = 500,
    int offset = 0,
  }) {
    final query = select(parcelas)..where((t) => t.deletedAt.isNull());
    if (!isAdmin && userId != null) {
      query.where((t) =>
          t.createdBy.equals(userId) |
          t.createdBy.equals('') |
          t.userId.equals(userId));
    }
    if (propriedade != null && propriedade.isNotEmpty) {
      query.where((t) => t.propriedade.equals(propriedade));
    }
    if (propUt != null && propUt.isNotEmpty) {
      query.where((t) => t.propUt.equals(propUt));
    }
    query.orderBy([(t) => OrderingTerm.asc(t.idParcela)]);
    query.limit(limit, offset: offset);
    return query.get();
  }

  /// Retorna a última parcela criada (para sugerir a próxima).
  Future<Parcela?> getLastParcela(
      {String? userId,
      bool isAdmin = false,
      String? propriedade,
      String? propUt}) async {
    final query = select(parcelas)..where((t) => t.deletedAt.isNull());
    if (!isAdmin && userId != null) {
      query.where((t) =>
          t.createdBy.equals(userId) |
          t.createdBy.equals('') |
          t.userId.equals(userId));
    }
    if (propriedade != null)
      query.where((t) => t.propriedade.equals(propriedade));
    if (propUt != null) query.where((t) => t.propUt.equals(propUt));
    query.orderBy([(t) => OrderingTerm.desc(t.idParcela)]);
    query.limit(1);
    return query.getSingleOrNull();
  }

  /// Parcelas a enviar no push: apenas as marcadas como concluídas (prontaParaSync=true).
  Future<List<Parcela>> getParcelasNaoSincronizadas({String? userId}) {
    final query = select(parcelas)
      ..where((t) =>
          (t.synced.equals(false) | t.parcialmenteSincronizada.equals(true)) &
          t.deletedAt.isNull() &
          t.prontaParaSync.equals(true));
    if (userId != null) {
      query.where((t) => t.userId.equals(userId));
    }
    return query.get();
  }

  /// Minhas parcelas incompletas (rascunho): não prontas para sync, para retomar depois.
  Future<List<Parcela>> getParcelasIncompletas(String userId) {
    return (select(parcelas)
          ..where((t) =>
              t.userId.equals(userId) &
              t.synced.equals(false) &
              t.prontaParaSync.equals(false) &
              t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  Future<Parcela?> getParcelaByUuid(String uuid,
          {bool includeDeleted = false}) =>
      (select(parcelas)
            ..where((t) =>
                t.uuid.equals(uuid) &
                (includeDeleted ? const Constant(true) : t.deletedAt.isNull())))
          .getSingleOrNull();

  Future<int> insertParcela(ParcelasCompanion parcela) =>
      into(parcelas).insert(parcela);

  Future<int> updateParcela(ParcelasCompanion parcela, String uuid) =>
      (update(parcelas)..where((t) => t.uuid.equals(uuid))).write(parcela);

  Future<int> deleteParcela(String uuid) =>
      (delete(parcelas)..where((t) => t.uuid.equals(uuid))).go();

  Future<void> marcarParcelaSynced(String uuid) =>
      (update(parcelas)..where((t) => t.uuid.equals(uuid)))
          .write(const ParcelasCompanion(
              synced: Value(true), parcialmenteSincronizada: Value(false)));

  Future<void> marcarParcelaParcialmenteSincronizada(String uuid) =>
      (update(parcelas)..where((t) => t.uuid.equals(uuid)))
          .write(const ParcelasCompanion(parcialmenteSincronizada: Value(true)));

  Stream<List<Parcela>> watchAllParcelas(
      {String? userId, bool isAdmin = false}) {
    final query = select(parcelas)..where((t) => t.deletedAt.isNull());
    if (!isAdmin && userId != null) {
      query.where((t) =>
          t.createdBy.equals(userId) |
          t.createdBy.equals('') |
          t.userId.equals(userId));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch();
  }

  /// Conta parcelas minhas concluídas mas ainda não sincronizadas (badge pendente).
  Future<int> countParcelasNaoSincronizadas({String? userId}) async {
    final count = parcelas.id.count();
    final query = selectOnly(parcelas)
      ..addColumns([count])
      ..where(parcelas.synced.equals(false) |
          parcelas.parcialmenteSincronizada.equals(true))
      ..where(parcelas.deletedAt.isNull())
      ..where(parcelas.prontaParaSync.equals(true));
    if (userId != null) {
      query.where(parcelas.userId.equals(userId));
    }
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  // ========== PLANTAS ==========

  Future<List<Planta>> getPlantasByParcela(String parcelaUuid) =>
      (select(plantas)
            ..where(
                (t) => t.parcelaUuid.equals(parcelaUuid) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Future<int> insertPlanta(PlantasCompanion planta) =>
      into(plantas).insert(planta);

  Future<int> updatePlanta(PlantasCompanion planta, String uuid) =>
      (update(plantas)..where((t) => t.uuid.equals(uuid)))
          .write(planta.copyWith(updatedAt: Value(DateTime.now())));

  Future<int> deletePlanta(String uuid) =>
      (delete(plantas)..where((t) => t.uuid.equals(uuid))).go();

  Future<int> deleteAllPlantasByParcela(String parcelaUuid) =>
      (delete(plantas)..where((t) => t.parcelaUuid.equals(parcelaUuid))).go();

  Future<void> marcarPlantaSynced(String uuid) =>
      (update(plantas)..where((t) => t.uuid.equals(uuid)))
          .write(PlantasCompanion(
              synced: Value(true), updatedAt: Value(DateTime.now())));

  Stream<List<Planta>> watchPlantasByParcela(String parcelaUuid) =>
      (select(plantas)
            ..where(
                (t) => t.parcelaUuid.equals(parcelaUuid) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  // ========== FOTOS PARCELA ==========

  Future<List<FotosParcelaData>> getFotosByParcela(String parcelaUuid) =>
      (select(fotosParcela)
            ..where((t) =>
                t.parcelaUuid.equals(parcelaUuid) & t.deletedAt.isNull()))
          .get();

  Stream<List<FotosParcelaData>> watchFotosByParcela(String parcelaUuid) =>
      (select(fotosParcela)
            ..where((t) =>
                t.parcelaUuid.equals(parcelaUuid) & t.deletedAt.isNull()))
          .watch();

  Future<int> insertFotoParcela(FotosParcelaCompanion foto) =>
      into(fotosParcela).insert(foto);

  Future<int> deleteFotoParcela(String uuid) =>
      (delete(fotosParcela)..where((t) => t.uuid.equals(uuid))).go();

  Future<int> deleteAllFotosByParcela(String parcelaUuid) =>
      (delete(fotosParcela)..where((t) => t.parcelaUuid.equals(parcelaUuid)))
          .go();

  Future<void> marcarFotoSynced(String uuid) =>
      (update(fotosParcela)..where((t) => t.uuid.equals(uuid)))
          .write(const FotosParcelaCompanion(synced: Value(true)));

  Future<List<FotosParcelaData>> getFotosNaoSincronizadas() =>
      (select(fotosParcela)
            ..where((t) => t.synced.equals(false) & t.deletedAt.isNull()))
          .get();

  // ========== SOFT-DELETE ==========

  /// Soft-deleta uma parcela (marca deletedAt + deletedBy, não remove do DB).
  Future<void> softDeleteParcela(String uuid, {String? deletedBy}) async {
    final now = DateTime.now();
    await transaction(() async {
      await (update(parcelas)..where((t) => t.uuid.equals(uuid)))
          .write(ParcelasCompanion(
        deletedAt: Value(now),
        deletedBy: Value(deletedBy),
      ));
      await (update(plantas)
            ..where((t) => t.parcelaUuid.equals(uuid) & t.deletedAt.isNull()))
          .write(PlantasCompanion(deletedAt: Value(now), updatedAt: Value(now)));
      await (update(fotosParcela)
            ..where((t) => t.parcelaUuid.equals(uuid) & t.deletedAt.isNull()))
          .write(FotosParcelaCompanion(deletedAt: Value(now)));
      await logAudit('soft_delete_parcela',
          entityType: 'parcela',
          entityUuid: uuid,
          userId: deletedBy,
          oldValue: 'ativo',
          newValue: 'deletado');
    });
  }

  /// Restaura uma parcela soft-deletada.
  Future<void> restaurarParcela(String uuid) async {
    final parcela = await getParcelaByUuid(uuid, includeDeleted: true);
    if (parcela == null || parcela.deletedAt == null) return;
    final deletedAtTs = parcela.deletedAt!;
    await transaction(() async {
      await (update(parcelas)..where((t) => t.uuid.equals(uuid)))
          .write(const ParcelasCompanion(
        deletedAt: Value(null),
      ));
      await (update(plantas)
            ..where((t) =>
                t.parcelaUuid.equals(uuid) & t.deletedAt.equals(deletedAtTs)))
          .write(PlantasCompanion(deletedAt: Value(null), updatedAt: Value(DateTime.now())));
      await (update(fotosParcela)
            ..where((t) =>
                t.parcelaUuid.equals(uuid) & t.deletedAt.equals(deletedAtTs)))
          .write(const FotosParcelaCompanion(deletedAt: Value(null)));
      await logAudit('restore_parcela',
          entityType: 'parcela',
          entityUuid: uuid,
          oldValue: 'deletado',
          newValue: 'restaurado');
    });
  }

  /// Lista parcelas soft-deletadas (lixeira).
  Future<List<Parcela>> getParcelasDeletadas(
      {String? userId, bool isAdmin = false}) {
    final query = select(parcelas)..where((t) => t.deletedAt.isNotNull());
    if (!isAdmin && userId != null) {
      query.where((t) =>
          t.createdBy.equals(userId) |
          t.createdBy.equals('') |
          t.userId.equals(userId));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.deletedAt)]);
    return query.get();
  }

  /// Remove permanentemente parcelas soft-deletadas há mais de N dias.
  Future<int> purgarDeletados({int diasRetencao = 30}) async {
    final cutoff = DateTime.now().subtract(Duration(days: diasRetencao));
    final parcelasParaPurgar = await (select(parcelas)
          ..where((t) =>
              t.deletedAt.isNotNull() & t.deletedAt.isSmallerThanValue(cutoff)))
        .get();
    final photoPaths = <String>[];
    for (final p in parcelasParaPurgar) {
      final fotos = await getFotosByParcela(p.uuid);
      photoPaths.addAll(fotos.map((f) => f.filePath));
      final plantas = await getPlantasByParcela(p.uuid);
      for (final planta in plantas) {
        if (planta.fotoEspeciePath != null)
          photoPaths.add(planta.fotoEspeciePath!);
      }
    }

  int count = 0;
  await ImageService.deletePhotos(photoPaths);
  await transaction(() async {
    for (final p in parcelasParaPurgar) {
      await deleteAllPlantasByParcela(p.uuid);
      await deleteAllFotosByParcela(p.uuid);
      await deleteParcela(p.uuid);
      count++;
    }
  });

  return count;
  }

  // ========== AUDIT LOG ==========

  /// Registra uma ação no log de auditoria.
  Future<void> logAudit(
    String action, {
    String? entityType,
    String? entityUuid,
    String? userId,
    String? details,
    String? oldValue,
    String? newValue,
  }) async {
    await into(auditLog).insert(AuditLogCompanion.insert(
      action: action,
      entityType: Value(entityType),
      entityUuid: Value(entityUuid),
      userId: Value(userId),
      details: Value(details),
      oldValue: Value(oldValue),
      newValue: Value(newValue),
    ));
  }

  /// Retorna últimas entradas do audit log.
  Future<List<AuditLogData>> getAuditLog({
    int limit = 100,
    int offset = 0,
    String? entityType,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final query = select(auditLog)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(limit, offset: offset);
    if (entityType != null) {
      query.where((t) => t.entityType.equals(entityType));
    }
    if (startDate != null) {
      query.where((t) => t.createdAt.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where((t) => t.createdAt.isSmallerOrEqualValue(endDate));
    }
    return query.get();
  }

  /// (Q1) Purga automática da auditoria DESLIGADA por padrão.
  ///
  /// Antes: beforeOpen chamava este método em CADA abertura do app e ele fazia
  /// DELETE de linhas com >90 dias — a trilha de auditoria se auto-destruía,
  /// perdendo evidência exatamente quando a auditoria externa pediria histórico.
  ///
  /// Segundo achado (Q1): o DELETE antigo comparava `created_at` (INTEGER,
  /// epoch seconds — formato padrão do drift) com `datetime('now',...)`, que
  /// devolve TEXTO. No SQLite, INTEGER < TEXT é SEMPRE verdadeiro, então a
  /// purga nem respeitava os 90 dias: apagava a tabela INTEIRA a cada abertura.
  /// Corrigido com CAST(strftime('%s',...) AS INTEGER).
  ///
  /// Agora: no-op enquanto `auditAutoPurgeEnabled` for false (default). Só com
  /// decisão EXPLÍCITA do operador (liga a flag) a purga roda — e ainda assim é
  /// hard delete, por isso está documentada como ação destrutiva deliberada.
  /// O histórico permanece integral no comportamento padrão.
  static bool auditAutoPurgeEnabled = false;

  Future<void> purgarAuditLog(
      {Duration retencao = const Duration(days: 90)}) async {
    if (!auditAutoPurgeEnabled) return;
    final dias = retencao.inDays;
    // created_at é INTEGER (epoch seconds) no drift — compara com inteiro.
    await customStatement(
        "DELETE FROM audit_log WHERE created_at < CAST(strftime('%s', 'now', '-$dias days') AS INTEGER)");
  }

  // ========== FIRST-RUN ADMIN SETUP ==========

  /// Verifica se existe algum usuário no sistema (first-run check).
  Future<bool> hasAnyUser() async {
    final count = usuarios.id.count();
    final query = selectOnly(usuarios)
      ..addColumns([count])
      ..where(usuarios.ativo.equals(true));
    final result = await query.getSingle();
    return (result.read(count) ?? 0) > 0;
  }

  /// Cria o primeiro usuário como admin (first-run wizard).
  Future<int> criarPrimeiroAdmin(
      String uuid, String nome, String email, String senha) async {
    return insertUsuario(UsuariosCompanion.insert(
      uuid: uuid,
      nome: nome,
      email: email,
      senha: senha,
      isAdmin: const Value(true),
    ));
  }

  /// Atualiza a senha de um usuário (já hasheia automaticamente via insertUsuario-style).
  Future<void> atualizarSenha(String uuid, String novaSenha) async {
    final hashed = PasswordService.hashPassword(novaSenha);
    await (update(usuarios)..where((t) => t.uuid.equals(uuid)))
        .write(UsuariosCompanion(senha: Value(hashed)));
  }

  Future<List<({String path, String uuid, String source})>>
      getAllPhotoPaths() async {
    final results = <({String path, String uuid, String source})>[];
    final fotos = await (select(fotosParcela)).get();
    for (final f in fotos) {
      results.add((path: f.filePath, uuid: f.uuid, source: 'foto'));
    }
    final todasPlantas = await (select(plantas)).get();
    for (final p in todasPlantas) {
      if (p.fotoEspeciePath != null) {
        results.add((path: p.fotoEspeciePath!, uuid: p.uuid, source: 'planta'));
      }
    }
    return results;
  }

  /// (Q2) Marca a foto da parcela como ausente (soft) — NUNCA deleta a linha.
  /// A evidência de que a foto existiu permanece no banco para auditoria.
  Future<void> cleanMissingFotoParcela(String uuid) async {
    await (update(fotosParcela)..where((t) => t.uuid.equals(uuid)))
        .write(const FotosParcelaCompanion(arquivoAusente: Value(true)));
  }

  /// (Q2) Marca a foto da planta como ausente (soft) — MANTÉM fotoEspeciePath
  /// (evidência do caminho original); apenas sinaliza a ausência.
  Future<void> cleanMissingFotoPlanta(String uuid) async {
    await (update(plantas)..where((t) => t.uuid.equals(uuid)))
        .write(PlantasCompanion(
            fotoAusente: const Value(true),
            updatedAt: Value(DateTime.now())));
  }

  /// Verifica e corrige referências órfãs de fotos no banco de dados.
  /// Retorna (orphanedCount, unreferencedFilesCount)
  Future<(int, int)> checkAndFixOrphanedPhotos() async {
    final allPaths = await getAllPhotoPaths();
    final missingFromDb = <String>[];
    final existingPaths = <String>[];

    for (final entry in allPaths) {
      final file = io.File(entry.path);
      if (!await file.exists()) {
        missingFromDb.add(entry.path);
      } else {
        existingPaths.add(entry.path);
      }
    }

    // (Q2) MARCA referências a arquivos ausentes — nunca deleta (evidência).
    int markedCount = 0;
    for (final entry in allPaths) {
      final file = io.File(entry.path);
      if (!await file.exists()) {
        if (entry.source == 'foto') {
          await cleanMissingFotoParcela(entry.uuid);
        } else {
          await cleanMissingFotoPlanta(entry.uuid);
        }
        markedCount++;
      }
    }

    // Find files on disk not in DB
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = io.Directory(p.join(appDir.path, 'fotos'));
    int unreferencedCount = 0;
    if (await photosDir.exists()) {
      await for (final entity in photosDir.list(recursive: true)) {
        if (entity is io.File) {
          final path = entity.path;
          if (!existingPaths.contains(path)) {
            unreferencedCount++;
          }
        }
      }
    }

    return (markedCount, unreferencedCount);
  }

  Future<({bool ok, String? error})> checkIntegrity() async {
    try {
      final integrityRows = await customSelect('PRAGMA integrity_check').get();
      final integrityResult =
          integrityRows.first.read<String>('integrity_check');
      if (integrityResult != 'ok') {
        return (ok: false, error: 'Integrity check: $integrityResult');
      }

      final fkRows = await customSelect('PRAGMA foreign_key_check').get();
      if (fkRows.isNotEmpty) {
        return (
          ok: false,
          error: 'Foreign key violation (${fkRows.length} row(s))'
        );
      }

      return (ok: true, error: null);
    } catch (e) {
      return (ok: false, error: 'Database check error: $e');
    }
  }
}
