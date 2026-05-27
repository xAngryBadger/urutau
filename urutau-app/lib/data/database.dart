import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../services/password_service.dart';

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
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get userId => text()();
    RealColumn get areaHa => real().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  /// true = utilizador marcou "concluída" → pode sincronizar; false = rascunho/incompleta
  BoolColumn get prontaParaSync => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  // Soft-delete
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deletedBy => text().nullable()();
  /// Quem criou esta parcela (uuid do user ou '' para seed/sistema). Usado para filtrar catálogo por usuário.
  TextColumn get createdBy => text().withDefault(const Constant(''))();
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
  // Soft-delete
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class FotosParcela extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get parcelaUuid => text().references(Parcelas, #uuid)();
  TextColumn get filePath => text()();
  TextColumn get compressedPath => text().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Tabela de auditoria — registra operações críticas no sistema.
class AuditLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get action => text()(); // ex: 'delete_parcela', 'login', 'sync_push'
  TextColumn get entityType => text().nullable()(); // 'parcela', 'planta', 'usuario'
  TextColumn get entityUuid => text().nullable()();
  TextColumn get userId => text().nullable()(); // quem fez a ação
  TextColumn get details => text().nullable()(); // JSON com detalhes extras
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// ============================================================
// DATABASE
// ============================================================

@DriftDatabase(tables: [Usuarios, Parcelas, Plantas, FotosParcela, AuditLog])
class AppDatabase extends _$AppDatabase {
  AppDatabase._internal(super.e);

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
  int get schemaVersion => 15;

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
        if (from < 4) {
          // Migração antiga de admin — agora não faz nada hardcoded
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
        await (delete(plantas)..where((t) => t.parcelaUuid.like('seed-%'))).go();
        await (delete(fotosParcela)..where((t) => t.parcelaUuid.like('seed-%'))).go();
        await (delete(parcelas)..where((t) => t.uuid.like('seed-%'))).go();
      }
          if (from < 12) {
            // Corrigir parcelas synced do servidor que ficaram com prontaParaSync=false
            await (update(parcelas)
              ..where((t) => t.synced.equals(true) & t.prontaParaSync.equals(false)))
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
},
      beforeOpen: (details) async {
        await _garantirAdminSeNecessario();
        await _seedCatalogoEstatico();
      },
    );
  }

  Future<void> _createIndexes(Migrator m) async {
    await customStatement('CREATE INDEX IF NOT EXISTS idx_plantas_parcela_uuid ON plantas(parcela_uuid)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_fotos_parcela_uuid ON fotos_parcela(parcela_uuid)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_parcelas_user_id ON parcelas(user_id)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_parcelas_deleted_at ON parcelas(deleted_at)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_parcelas_created_by ON parcelas(created_by)');
    // Índices para sincronização (usados em getParcelasNaoSincronizadas)
    await customStatement('CREATE INDEX IF NOT EXISTS idx_parcelas_synced ON parcelas(synced)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_parcelas_prontaParaSync ON parcelas(pronta_para_sync)');
    // Índice composto para busca eficiente de parcelas não sincronizadas
    await customStatement('CREATE INDEX IF NOT EXISTS idx_parcelas_sync_status ON parcelas(synced, pronta_para_sync, deleted_at)');
  }

  /// Migra senhas armazenadas em plaintext para formato hash (SHA-256 + salt).
  /// Mantém compatibilidade: se já estiver no formato hash, não faz nada.
  Future<void> _migrarSenhasParaHash() async {
    final todosUsuarios = await (select(usuarios)).get();
    for (final user in todosUsuarios) {
      if (!PasswordService.isHashed(user.senha)) {
        final hashedPassword = PasswordService.hashPassword(user.senha);
        await (update(usuarios)..where((t) => t.uuid.equals(user.uuid)))
            .write(UsuariosCompanion(senha: Value(hashedPassword)));
      }
    }
  }

  /// Migra dados existentes: tenta extrair propriedade do campo propUt.
  /// Se propUt contém " - " (ex: "Fazenda São João - UT 01"), separa.
  Future<void> _migrarPropriedadeDeProput() async {
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
      await (update(usuarios)..where((t) => t.uuid.equals(todosUsers.first.uuid)))
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
  }

  /// Remove parcelas/plantas/fotos de usuários que não existem mais
  Future<void> _limparDadosOrfaos() async {
    final todosUsuarios = await (select(usuarios)).get();
    final uuidsValidos = todosUsuarios.map((u) => u.uuid).toSet();

    // Busca todas as parcelas
    final todasParcelas = await (select(parcelas)).get();
    for (final parcela in todasParcelas) {
      if (!uuidsValidos.contains(parcela.userId)) {
        // Usuário não existe mais: apagar parcela e seus dados
        await deleteAllPlantasByParcela(parcela.uuid);
        await deleteAllFotosByParcela(parcela.uuid);
        await deleteParcela(parcela.uuid);
      }
    }
  }

  /// Apaga um usuário e TODOS os seus dados (parcelas, plantas, fotos)
  Future<void> deleteUsuarioComDados(String uuid) async {
    // 1. Buscar todas as parcelas do usuário
    final parcelasUser = await (select(parcelas)..where((t) => t.userId.equals(uuid))).get();
    for (final parcela in parcelasUser) {
      await deleteAllPlantasByParcela(parcela.uuid);
      await deleteAllFotosByParcela(parcela.uuid);
      await deleteParcela(parcela.uuid);
    }
    // 2. Deletar o usuário
    await deleteUsuario(uuid);
  }

  /// Remove todas as parcelas sincronizadas (importadas do servidor).
  /// Preserva parcelas locais não sincronizadas (trabalho do utilizador).
  Future<void> deleteAllSyncedParcelas() async {
    final synced = await (select(parcelas)
      ..where((t) => t.synced.equals(true) & t.deletedAt.isNull())).get();
    for (final p in synced) {
      await (delete(plantas)..where((t) => t.parcelaUuid.equals(p.uuid))).go();
      await (delete(fotosParcela)..where((t) => t.parcelaUuid.equals(p.uuid))).go();
      await (delete(parcelas)..where((t) => t.uuid.equals(p.uuid))).go();
    }
  }

  /// Limpa TUDO exceto admins (reset completo)
  Future<void> limparTodosDadosExcetoAdmin() async {
    await delete(fotosParcela).go();
    await delete(plantas).go();
    await delete(parcelas).go();
    // Apagar todos os usuários exceto admins
    await (delete(usuarios)..where((t) => t.isAdmin.equals(false))).go();
  }

  // ========== USUARIOS ==========

  Future<List<Usuario>> getAllUsuarios() =>
      (select(usuarios)
            ..where((t) => t.ativo.equals(true))
            ..orderBy([(t) => OrderingTerm.asc(t.nome)]))
          .get();

  Future<Usuario?> getUsuarioByEmail(String email) =>
      (select(usuarios)..where((t) => t.email.equals(email)))
          .getSingleOrNull();

  Future<Usuario?> getUsuarioByUuid(String uuid) =>
      (select(usuarios)..where((t) => t.uuid.equals(uuid)))
          .getSingleOrNull();

  Future<Usuario?> autenticarUsuario(String email, String senha) async {
    final user = await (select(usuarios)
      ..where((t) => t.email.equals(email) & t.ativo.equals(true)))
      .getSingleOrNull();
    if (user == null) return null;
    if (PasswordService.verifyPassword(senha, user.senha)) {
      return user;
    }
    return null;
  }

  Future<int> insertUsuario(UsuariosCompanion usuario) {
    // Hash a senha se está em plaintext
    if (usuario.senha.present && !PasswordService.isHashed(usuario.senha.value)) {
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
    await customStatement('BEGIN TRANSACTION');
    try {
      await (update(parcelas)..where((t) => t.userId.equals(oldUuid)))
          .write(ParcelasCompanion(userId: Value(newUuid)));
      await (update(parcelas)..where((t) => t.createdBy.equals(oldUuid)))
          .write(ParcelasCompanion(createdBy: Value(newUuid)));
      await (update(usuarios)..where((t) => t.uuid.equals(oldUuid)))
          .write(UsuariosCompanion(uuid: Value(newUuid)));
      await customStatement('COMMIT');
    } catch (e) {
      await customStatement('ROLLBACK');
      rethrow;
    }
  }

  /// Atualiza o UUID de uma parcela e cascata para plantas e fotos.
  /// Usado para mapear UUID local → PocketBase record ID após push.
  Future<void> remapParcelaUuid(String oldUuid, String newUuid) async {
    if (oldUuid == newUuid) return;
    await customStatement('BEGIN TRANSACTION');
    try {
      await (update(plantas)..where((t) => t.parcelaUuid.equals(oldUuid)))
          .write(PlantasCompanion(parcelaUuid: Value(newUuid)));
      await (update(fotosParcela)..where((t) => t.parcelaUuid.equals(oldUuid)))
          .write(FotosParcelaCompanion(parcelaUuid: Value(newUuid)));
      await (update(parcelas)..where((t) => t.uuid.equals(oldUuid)))
          .write(ParcelasCompanion(uuid: Value(newUuid)));
      await customStatement('COMMIT');
    } catch (e) {
      await customStatement('ROLLBACK');
      rethrow;
    }
  }

  /// Verifica se já existe parcela com mesmos (propUt, idParcela, userId).
  Future<Parcela?> findParcelaDuplicada(String propUt, int idParcela, String userId) =>
      (select(parcelas)
        ..where((t) =>
            t.propUt.equals(propUt) &
            t.idParcela.equals(idParcela) &
            t.userId.equals(userId) &
            t.deletedAt.isNull()))
          .getSingleOrNull();

  /// Parcela disponível (userId vazio) com mesmo (propriedade, propUt, idParcela).
  /// Evita duplicação ao criar nova parcela após limpar.
  Future<Parcela?> findParcelaDisponivel(String propriedade, String propUt, int idParcela) =>
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
  Future<List<String>> getAllPropriedades({String? userId, bool isAdmin = false}) async {
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
  Future<List<String>> getAllTalhoes({String? userId, bool isAdmin = false, String? propriedade}) async {
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
  Future<Parcela?> getLastParcela({String? userId, bool isAdmin = false, String? propriedade, String? propUt}) async {
    final query = select(parcelas)..where((t) => t.deletedAt.isNull());
    if (!isAdmin && userId != null) {
      query.where((t) =>
          t.createdBy.equals(userId) | t.createdBy.equals('') | t.userId.equals(userId));
    }
    if (propriedade != null) query.where((t) => t.propriedade.equals(propriedade));
    if (propUt != null) query.where((t) => t.propUt.equals(propUt));
    query.orderBy([(t) => OrderingTerm.desc(t.idParcela)]);
    query.limit(1);
    return query.getSingleOrNull();
  }

  /// Parcelas a enviar no push: apenas as marcadas como concluídas (prontaParaSync=true).
  Future<List<Parcela>> getParcelasNaoSincronizadas({String? userId}) {
    final query = select(parcelas)
      ..where((t) =>
          t.synced.equals(false) &
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

  Future<Parcela?> getParcelaByUuid(String uuid, {bool includeDeleted = false}) =>
      (select(parcelas)..where((t) => t.uuid.equals(uuid) & (includeDeleted ? const Constant(true) : t.deletedAt.isNull()))).getSingleOrNull();

  Future<int> insertParcela(ParcelasCompanion parcela) =>
      into(parcelas).insert(parcela);

  Future<int> updateParcela(ParcelasCompanion parcela, String uuid) =>
      (update(parcelas)..where((t) => t.uuid.equals(uuid))).write(parcela);

  Future<int> deleteParcela(String uuid) =>
      (delete(parcelas)..where((t) => t.uuid.equals(uuid))).go();

  Future<void> marcarParcelaSynced(String uuid) =>
      (update(parcelas)..where((t) => t.uuid.equals(uuid)))
          .write(const ParcelasCompanion(synced: Value(true)));

  Stream<List<Parcela>> watchAllParcelas({String? userId, bool isAdmin = false}) {
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
      ..where(parcelas.synced.equals(false))
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
        ..where((t) => t.parcelaUuid.equals(parcelaUuid) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
      .get();

  Future<int> insertPlanta(PlantasCompanion planta) =>
      into(plantas).insert(planta);

  Future<int> updatePlanta(PlantasCompanion planta, String uuid) =>
      (update(plantas)..where((t) => t.uuid.equals(uuid))).write(planta);

  Future<int> deletePlanta(String uuid) =>
      (delete(plantas)..where((t) => t.uuid.equals(uuid))).go();

  Future<int> deleteAllPlantasByParcela(String parcelaUuid) =>
      (delete(plantas)..where((t) => t.parcelaUuid.equals(parcelaUuid))).go();

  Future<void> marcarPlantaSynced(String uuid) =>
      (update(plantas)..where((t) => t.uuid.equals(uuid)))
          .write(const PlantasCompanion(synced: Value(true)));

  Stream<List<Planta>> watchPlantasByParcela(String parcelaUuid) =>
      (select(plantas)
        ..where((t) => t.parcelaUuid.equals(parcelaUuid) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();

  // ========== FOTOS PARCELA ==========

  Future<List<FotosParcelaData>> getFotosByParcela(String parcelaUuid) =>
      (select(fotosParcela)
        ..where((t) => t.parcelaUuid.equals(parcelaUuid) & t.deletedAt.isNull()))
      .get();

  Stream<List<FotosParcelaData>> watchFotosByParcela(String parcelaUuid) =>
      (select(fotosParcela)
        ..where((t) => t.parcelaUuid.equals(parcelaUuid) & t.deletedAt.isNull()))
      .watch();

  Future<int> insertFotoParcela(FotosParcelaCompanion foto) =>
      into(fotosParcela).insert(foto);

  Future<int> deleteFotoParcela(String uuid) =>
      (delete(fotosParcela)..where((t) => t.uuid.equals(uuid))).go();

  Future<int> deleteAllFotosByParcela(String parcelaUuid) =>
      (delete(fotosParcela)
            ..where((t) => t.parcelaUuid.equals(parcelaUuid)))
          .go();

  Future<void> marcarFotoSynced(String uuid) =>
      (update(fotosParcela)..where((t) => t.uuid.equals(uuid)))
          .write(const FotosParcelaCompanion(synced: Value(true)));

  Future<List<FotosParcelaData>> getFotosNaoSincronizadas() =>
      (select(fotosParcela)..where((t) => t.synced.equals(false) & t.deletedAt.isNull())).get();

  // ========== SOFT-DELETE ==========

  /// Soft-deleta uma parcela (marca deletedAt + deletedBy, não remove do DB).
  Future<void> softDeleteParcela(String uuid, {String? deletedBy}) async {
    final now = DateTime.now();
    await customStatement('BEGIN TRANSACTION');
    try {
      await (update(parcelas)..where((t) => t.uuid.equals(uuid)))
          .write(ParcelasCompanion(
        deletedAt: Value(now),
        deletedBy: Value(deletedBy),
      ));
      await (update(plantas)..where((t) => t.parcelaUuid.equals(uuid) & t.deletedAt.isNull()))
          .write(PlantasCompanion(deletedAt: Value(now)));
      await (update(fotosParcela)..where((t) => t.parcelaUuid.equals(uuid) & t.deletedAt.isNull()))
          .write(FotosParcelaCompanion(deletedAt: Value(now)));
      await customStatement('COMMIT');
    } catch (e) {
      await customStatement('ROLLBACK');
      rethrow;
    }
    await logAudit('soft_delete_parcela', entityType: 'parcela',
        entityUuid: uuid, userId: deletedBy);
  }

  /// Restaura uma parcela soft-deletada.
  Future<void> restaurarParcela(String uuid) async {
    final parcela = await getParcelaByUuid(uuid, includeDeleted: true);
    if (parcela == null || parcela.deletedAt == null) return;
    final deletedAtTs = parcela.deletedAt!;
    await customStatement('BEGIN TRANSACTION');
    try {
      await (update(parcelas)..where((t) => t.uuid.equals(uuid)))
          .write(const ParcelasCompanion(
        deletedAt: Value(null),
      ));
      await (update(plantas)..where((t) => t.parcelaUuid.equals(uuid) & t.deletedAt.equals(deletedAtTs)))
          .write(const PlantasCompanion(deletedAt: Value(null)));
      await (update(fotosParcela)..where((t) => t.parcelaUuid.equals(uuid) & t.deletedAt.equals(deletedAtTs)))
          .write(const FotosParcelaCompanion(deletedAt: Value(null)));
      await customStatement('COMMIT');
    } catch (e) {
      await customStatement('ROLLBACK');
      rethrow;
    }
    await logAudit('restore_parcela', entityType: 'parcela', entityUuid: uuid);
  }

  /// Lista parcelas soft-deletadas (lixeira).
  Future<List<Parcela>> getParcelasDeletadas({String? userId, bool isAdmin = false}) {
    final query = select(parcelas)..where((t) => t.deletedAt.isNotNull());
    if (!isAdmin && userId != null) {
      query.where((t) =>
          t.createdBy.equals(userId) | t.createdBy.equals('') | t.userId.equals(userId));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.deletedAt)]);
    return query.get();
  }

  /// Remove permanentemente parcelas soft-deletadas há mais de N dias.
  Future<int> purgarDeletados({int diasRetencao = 30}) async {
    final cutoff = DateTime.now().subtract(Duration(days: diasRetencao));
    final parcelasParaPurgar = await (select(parcelas)
          ..where((t) => t.deletedAt.isNotNull() & t.deletedAt.isSmallerThanValue(cutoff)))
        .get();
    int count = 0;
    for (final p in parcelasParaPurgar) {
      await deleteAllPlantasByParcela(p.uuid);
      await deleteAllFotosByParcela(p.uuid);
      await deleteParcela(p.uuid);
      count++;
    }
    return count;
  }

  // ========== AUDIT LOG ==========

  /// Registra uma ação no log de auditoria.
  Future<void> logAudit(String action, {
    String? entityType,
    String? entityUuid,
    String? userId,
    String? details,
  }) async {
    await into(auditLog).insert(AuditLogCompanion.insert(
      action: action,
      entityType: Value(entityType),
      entityUuid: Value(entityUuid),
      userId: Value(userId),
      details: Value(details),
    ));
  }

  /// Retorna últimas entradas do audit log.
  Future<List<AuditLogData>> getAuditLog({int limit = 100}) =>
      (select(auditLog)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(limit))
          .get();

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
  Future<int> criarPrimeiroAdmin(String uuid, String nome, String email, String senha) async {
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
}
