// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $UsuariosTable extends Usuarios with TableInfo<$UsuariosTable, Usuario> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsuariosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
      'uuid', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _nomeMeta = const VerificationMeta('nome');
  @override
  late final GeneratedColumn<String> nome = GeneratedColumn<String>(
      'nome', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _senhaMeta = const VerificationMeta('senha');
  @override
  late final GeneratedColumn<String> senha = GeneratedColumn<String>(
      'senha', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isAdminMeta =
      const VerificationMeta('isAdmin');
  @override
  late final GeneratedColumn<bool> isAdmin = GeneratedColumn<bool>(
      'is_admin', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_admin" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _ativoMeta = const VerificationMeta('ativo');
  @override
  late final GeneratedColumn<bool> ativo = GeneratedColumn<bool>(
      'ativo', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("ativo" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, uuid, nome, email, senha, isAdmin, ativo, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'usuarios';
  @override
  VerificationContext validateIntegrity(Insertable<Usuario> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
          _uuidMeta, uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta));
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('nome')) {
      context.handle(
          _nomeMeta, nome.isAcceptableOrUnknown(data['nome']!, _nomeMeta));
    } else if (isInserting) {
      context.missing(_nomeMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('senha')) {
      context.handle(
          _senhaMeta, senha.isAcceptableOrUnknown(data['senha']!, _senhaMeta));
    } else if (isInserting) {
      context.missing(_senhaMeta);
    }
    if (data.containsKey('is_admin')) {
      context.handle(_isAdminMeta,
          isAdmin.isAcceptableOrUnknown(data['is_admin']!, _isAdminMeta));
    }
    if (data.containsKey('ativo')) {
      context.handle(
          _ativoMeta, ativo.isAcceptableOrUnknown(data['ativo']!, _ativoMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Usuario map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Usuario(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      uuid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uuid'])!,
      nome: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}nome'])!,
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email'])!,
      senha: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}senha'])!,
      isAdmin: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_admin'])!,
      ativo: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}ativo'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $UsuariosTable createAlias(String alias) {
    return $UsuariosTable(attachedDatabase, alias);
  }
}

class Usuario extends DataClass implements Insertable<Usuario> {
  final int id;
  final String uuid;
  final String nome;
  final String email;
  final String senha;
  final bool isAdmin;
  final bool ativo;
  final DateTime createdAt;
  const Usuario(
      {required this.id,
      required this.uuid,
      required this.nome,
      required this.email,
      required this.senha,
      required this.isAdmin,
      required this.ativo,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['nome'] = Variable<String>(nome);
    map['email'] = Variable<String>(email);
    map['senha'] = Variable<String>(senha);
    map['is_admin'] = Variable<bool>(isAdmin);
    map['ativo'] = Variable<bool>(ativo);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  UsuariosCompanion toCompanion(bool nullToAbsent) {
    return UsuariosCompanion(
      id: Value(id),
      uuid: Value(uuid),
      nome: Value(nome),
      email: Value(email),
      senha: Value(senha),
      isAdmin: Value(isAdmin),
      ativo: Value(ativo),
      createdAt: Value(createdAt),
    );
  }

  factory Usuario.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Usuario(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      nome: serializer.fromJson<String>(json['nome']),
      email: serializer.fromJson<String>(json['email']),
      senha: serializer.fromJson<String>(json['senha']),
      isAdmin: serializer.fromJson<bool>(json['isAdmin']),
      ativo: serializer.fromJson<bool>(json['ativo']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'nome': serializer.toJson<String>(nome),
      'email': serializer.toJson<String>(email),
      'senha': serializer.toJson<String>(senha),
      'isAdmin': serializer.toJson<bool>(isAdmin),
      'ativo': serializer.toJson<bool>(ativo),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Usuario copyWith(
          {int? id,
          String? uuid,
          String? nome,
          String? email,
          String? senha,
          bool? isAdmin,
          bool? ativo,
          DateTime? createdAt}) =>
      Usuario(
        id: id ?? this.id,
        uuid: uuid ?? this.uuid,
        nome: nome ?? this.nome,
        email: email ?? this.email,
        senha: senha ?? this.senha,
        isAdmin: isAdmin ?? this.isAdmin,
        ativo: ativo ?? this.ativo,
        createdAt: createdAt ?? this.createdAt,
      );
  Usuario copyWithCompanion(UsuariosCompanion data) {
    return Usuario(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      nome: data.nome.present ? data.nome.value : this.nome,
      email: data.email.present ? data.email.value : this.email,
      senha: data.senha.present ? data.senha.value : this.senha,
      isAdmin: data.isAdmin.present ? data.isAdmin.value : this.isAdmin,
      ativo: data.ativo.present ? data.ativo.value : this.ativo,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Usuario(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('nome: $nome, ')
          ..write('email: $email, ')
          ..write('senha: $senha, ')
          ..write('isAdmin: $isAdmin, ')
          ..write('ativo: $ativo, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, uuid, nome, email, senha, isAdmin, ativo, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Usuario &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.nome == this.nome &&
          other.email == this.email &&
          other.senha == this.senha &&
          other.isAdmin == this.isAdmin &&
          other.ativo == this.ativo &&
          other.createdAt == this.createdAt);
}

class UsuariosCompanion extends UpdateCompanion<Usuario> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> nome;
  final Value<String> email;
  final Value<String> senha;
  final Value<bool> isAdmin;
  final Value<bool> ativo;
  final Value<DateTime> createdAt;
  const UsuariosCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.nome = const Value.absent(),
    this.email = const Value.absent(),
    this.senha = const Value.absent(),
    this.isAdmin = const Value.absent(),
    this.ativo = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  UsuariosCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required String nome,
    required String email,
    required String senha,
    this.isAdmin = const Value.absent(),
    this.ativo = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : uuid = Value(uuid),
        nome = Value(nome),
        email = Value(email),
        senha = Value(senha);
  static Insertable<Usuario> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? nome,
    Expression<String>? email,
    Expression<String>? senha,
    Expression<bool>? isAdmin,
    Expression<bool>? ativo,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (nome != null) 'nome': nome,
      if (email != null) 'email': email,
      if (senha != null) 'senha': senha,
      if (isAdmin != null) 'is_admin': isAdmin,
      if (ativo != null) 'ativo': ativo,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  UsuariosCompanion copyWith(
      {Value<int>? id,
      Value<String>? uuid,
      Value<String>? nome,
      Value<String>? email,
      Value<String>? senha,
      Value<bool>? isAdmin,
      Value<bool>? ativo,
      Value<DateTime>? createdAt}) {
    return UsuariosCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      nome: nome ?? this.nome,
      email: email ?? this.email,
      senha: senha ?? this.senha,
      isAdmin: isAdmin ?? this.isAdmin,
      ativo: ativo ?? this.ativo,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (nome.present) {
      map['nome'] = Variable<String>(nome.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (senha.present) {
      map['senha'] = Variable<String>(senha.value);
    }
    if (isAdmin.present) {
      map['is_admin'] = Variable<bool>(isAdmin.value);
    }
    if (ativo.present) {
      map['ativo'] = Variable<bool>(ativo.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsuariosCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('nome: $nome, ')
          ..write('email: $email, ')
          ..write('senha: $senha, ')
          ..write('isAdmin: $isAdmin, ')
          ..write('ativo: $ativo, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ParcelasTable extends Parcelas with TableInfo<$ParcelasTable, Parcela> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ParcelasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
      'uuid', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _propriedadeMeta =
      const VerificationMeta('propriedade');
  @override
  late final GeneratedColumn<String> propriedade = GeneratedColumn<String>(
      'propriedade', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _propUtMeta = const VerificationMeta('propUt');
  @override
  late final GeneratedColumn<String> propUt = GeneratedColumn<String>(
      'prop_ut', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _idParcelaMeta =
      const VerificationMeta('idParcela');
  @override
  late final GeneratedColumn<int> idParcela = GeneratedColumn<int>(
      'id_parcela', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _observacoesMeta =
      const VerificationMeta('observacoes');
  @override
  late final GeneratedColumn<String> observacoes = GeneratedColumn<String>(
      'observacoes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _latitudeMeta =
      const VerificationMeta('latitude');
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
      'latitude', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _longitudeMeta =
      const VerificationMeta('longitude');
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
      'longitude', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _areaHaMeta = const VerificationMeta('areaHa');
  @override
  late final GeneratedColumn<double> areaHa = GeneratedColumn<double>(
      'area_ha', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
      'synced', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("synced" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _prontaParaSyncMeta =
      const VerificationMeta('prontaParaSync');
  @override
  late final GeneratedColumn<bool> prontaParaSync = GeneratedColumn<bool>(
      'pronta_para_sync', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("pronta_para_sync" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedByMeta =
      const VerificationMeta('deletedBy');
  @override
  late final GeneratedColumn<String> deletedBy = GeneratedColumn<String>(
      'deleted_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdByMeta =
      const VerificationMeta('createdBy');
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
      'created_by', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        uuid,
        propriedade,
        propUt,
        idParcela,
        observacoes,
        latitude,
        longitude,
        userId,
        areaHa,
        synced,
        prontaParaSync,
        createdAt,
        updatedAt,
        deletedAt,
        deletedBy,
        createdBy
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'parcelas';
  @override
  VerificationContext validateIntegrity(Insertable<Parcela> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
          _uuidMeta, uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta));
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('propriedade')) {
      context.handle(
          _propriedadeMeta,
          propriedade.isAcceptableOrUnknown(
              data['propriedade']!, _propriedadeMeta));
    }
    if (data.containsKey('prop_ut')) {
      context.handle(_propUtMeta,
          propUt.isAcceptableOrUnknown(data['prop_ut']!, _propUtMeta));
    } else if (isInserting) {
      context.missing(_propUtMeta);
    }
    if (data.containsKey('id_parcela')) {
      context.handle(_idParcelaMeta,
          idParcela.isAcceptableOrUnknown(data['id_parcela']!, _idParcelaMeta));
    } else if (isInserting) {
      context.missing(_idParcelaMeta);
    }
    if (data.containsKey('observacoes')) {
      context.handle(
          _observacoesMeta,
          observacoes.isAcceptableOrUnknown(
              data['observacoes']!, _observacoesMeta));
    }
    if (data.containsKey('latitude')) {
      context.handle(_latitudeMeta,
          latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta));
    }
    if (data.containsKey('longitude')) {
      context.handle(_longitudeMeta,
          longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta));
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('area_ha')) {
      context.handle(_areaHaMeta,
          areaHa.isAcceptableOrUnknown(data['area_ha']!, _areaHaMeta));
    }
    if (data.containsKey('synced')) {
      context.handle(_syncedMeta,
          synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta));
    }
    if (data.containsKey('pronta_para_sync')) {
      context.handle(
          _prontaParaSyncMeta,
          prontaParaSync.isAcceptableOrUnknown(
              data['pronta_para_sync']!, _prontaParaSyncMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('deleted_by')) {
      context.handle(_deletedByMeta,
          deletedBy.isAcceptableOrUnknown(data['deleted_by']!, _deletedByMeta));
    }
    if (data.containsKey('created_by')) {
      context.handle(_createdByMeta,
          createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Parcela map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Parcela(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      uuid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uuid'])!,
      propriedade: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}propriedade'])!,
      propUt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}prop_ut'])!,
      idParcela: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id_parcela'])!,
      observacoes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}observacoes']),
      latitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}latitude']),
      longitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}longitude']),
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      areaHa: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}area_ha']),
      synced: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}synced'])!,
      prontaParaSync: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}pronta_para_sync'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
      deletedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deleted_by']),
      createdBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_by'])!,
    );
  }

  @override
  $ParcelasTable createAlias(String alias) {
    return $ParcelasTable(attachedDatabase, alias);
  }
}

class Parcela extends DataClass implements Insertable<Parcela> {
  final int id;
  final String uuid;
  final String propriedade;
  final String propUt;
  final int idParcela;
  final String? observacoes;
  final double? latitude;
  final double? longitude;
  final String userId;
  final double? areaHa;
  final bool synced;

  /// true = utilizador marcou "concluída" → pode sincronizar; false = rascunho/incompleta
  final bool prontaParaSync;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? deletedBy;

  /// Quem criou esta parcela (uuid do user ou '' para seed/sistema). Usado para filtrar catálogo por usuário.
  final String createdBy;
  const Parcela(
      {required this.id,
      required this.uuid,
      required this.propriedade,
      required this.propUt,
      required this.idParcela,
      this.observacoes,
      this.latitude,
      this.longitude,
      required this.userId,
      this.areaHa,
      required this.synced,
      required this.prontaParaSync,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt,
      this.deletedBy,
      required this.createdBy});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['propriedade'] = Variable<String>(propriedade);
    map['prop_ut'] = Variable<String>(propUt);
    map['id_parcela'] = Variable<int>(idParcela);
    if (!nullToAbsent || observacoes != null) {
      map['observacoes'] = Variable<String>(observacoes);
    }
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || areaHa != null) {
      map['area_ha'] = Variable<double>(areaHa);
    }
    map['synced'] = Variable<bool>(synced);
    map['pronta_para_sync'] = Variable<bool>(prontaParaSync);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || deletedBy != null) {
      map['deleted_by'] = Variable<String>(deletedBy);
    }
    map['created_by'] = Variable<String>(createdBy);
    return map;
  }

  ParcelasCompanion toCompanion(bool nullToAbsent) {
    return ParcelasCompanion(
      id: Value(id),
      uuid: Value(uuid),
      propriedade: Value(propriedade),
      propUt: Value(propUt),
      idParcela: Value(idParcela),
      observacoes: observacoes == null && nullToAbsent
          ? const Value.absent()
          : Value(observacoes),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      userId: Value(userId),
      areaHa:
          areaHa == null && nullToAbsent ? const Value.absent() : Value(areaHa),
      synced: Value(synced),
      prontaParaSync: Value(prontaParaSync),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deletedBy: deletedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedBy),
      createdBy: Value(createdBy),
    );
  }

  factory Parcela.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Parcela(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      propriedade: serializer.fromJson<String>(json['propriedade']),
      propUt: serializer.fromJson<String>(json['propUt']),
      idParcela: serializer.fromJson<int>(json['idParcela']),
      observacoes: serializer.fromJson<String?>(json['observacoes']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      userId: serializer.fromJson<String>(json['userId']),
      areaHa: serializer.fromJson<double?>(json['areaHa']),
      synced: serializer.fromJson<bool>(json['synced']),
      prontaParaSync: serializer.fromJson<bool>(json['prontaParaSync']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      deletedBy: serializer.fromJson<String?>(json['deletedBy']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'propriedade': serializer.toJson<String>(propriedade),
      'propUt': serializer.toJson<String>(propUt),
      'idParcela': serializer.toJson<int>(idParcela),
      'observacoes': serializer.toJson<String?>(observacoes),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'userId': serializer.toJson<String>(userId),
      'areaHa': serializer.toJson<double?>(areaHa),
      'synced': serializer.toJson<bool>(synced),
      'prontaParaSync': serializer.toJson<bool>(prontaParaSync),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'deletedBy': serializer.toJson<String?>(deletedBy),
      'createdBy': serializer.toJson<String>(createdBy),
    };
  }

  Parcela copyWith(
          {int? id,
          String? uuid,
          String? propriedade,
          String? propUt,
          int? idParcela,
          Value<String?> observacoes = const Value.absent(),
          Value<double?> latitude = const Value.absent(),
          Value<double?> longitude = const Value.absent(),
          String? userId,
          Value<double?> areaHa = const Value.absent(),
          bool? synced,
          bool? prontaParaSync,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent(),
          Value<String?> deletedBy = const Value.absent(),
          String? createdBy}) =>
      Parcela(
        id: id ?? this.id,
        uuid: uuid ?? this.uuid,
        propriedade: propriedade ?? this.propriedade,
        propUt: propUt ?? this.propUt,
        idParcela: idParcela ?? this.idParcela,
        observacoes: observacoes.present ? observacoes.value : this.observacoes,
        latitude: latitude.present ? latitude.value : this.latitude,
        longitude: longitude.present ? longitude.value : this.longitude,
        userId: userId ?? this.userId,
        areaHa: areaHa.present ? areaHa.value : this.areaHa,
        synced: synced ?? this.synced,
        prontaParaSync: prontaParaSync ?? this.prontaParaSync,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        deletedBy: deletedBy.present ? deletedBy.value : this.deletedBy,
        createdBy: createdBy ?? this.createdBy,
      );
  Parcela copyWithCompanion(ParcelasCompanion data) {
    return Parcela(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      propriedade:
          data.propriedade.present ? data.propriedade.value : this.propriedade,
      propUt: data.propUt.present ? data.propUt.value : this.propUt,
      idParcela: data.idParcela.present ? data.idParcela.value : this.idParcela,
      observacoes:
          data.observacoes.present ? data.observacoes.value : this.observacoes,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      userId: data.userId.present ? data.userId.value : this.userId,
      areaHa: data.areaHa.present ? data.areaHa.value : this.areaHa,
      synced: data.synced.present ? data.synced.value : this.synced,
      prontaParaSync: data.prontaParaSync.present
          ? data.prontaParaSync.value
          : this.prontaParaSync,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deletedBy: data.deletedBy.present ? data.deletedBy.value : this.deletedBy,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Parcela(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('propriedade: $propriedade, ')
          ..write('propUt: $propUt, ')
          ..write('idParcela: $idParcela, ')
          ..write('observacoes: $observacoes, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('userId: $userId, ')
          ..write('areaHa: $areaHa, ')
          ..write('synced: $synced, ')
          ..write('prontaParaSync: $prontaParaSync, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('createdBy: $createdBy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      uuid,
      propriedade,
      propUt,
      idParcela,
      observacoes,
      latitude,
      longitude,
      userId,
      areaHa,
      synced,
      prontaParaSync,
      createdAt,
      updatedAt,
      deletedAt,
      deletedBy,
      createdBy);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Parcela &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.propriedade == this.propriedade &&
          other.propUt == this.propUt &&
          other.idParcela == this.idParcela &&
          other.observacoes == this.observacoes &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.userId == this.userId &&
          other.areaHa == this.areaHa &&
          other.synced == this.synced &&
          other.prontaParaSync == this.prontaParaSync &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deletedBy == this.deletedBy &&
          other.createdBy == this.createdBy);
}

class ParcelasCompanion extends UpdateCompanion<Parcela> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> propriedade;
  final Value<String> propUt;
  final Value<int> idParcela;
  final Value<String?> observacoes;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<String> userId;
  final Value<double?> areaHa;
  final Value<bool> synced;
  final Value<bool> prontaParaSync;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String?> deletedBy;
  final Value<String> createdBy;
  const ParcelasCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.propriedade = const Value.absent(),
    this.propUt = const Value.absent(),
    this.idParcela = const Value.absent(),
    this.observacoes = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.userId = const Value.absent(),
    this.areaHa = const Value.absent(),
    this.synced = const Value.absent(),
    this.prontaParaSync = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.createdBy = const Value.absent(),
  });
  ParcelasCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    this.propriedade = const Value.absent(),
    required String propUt,
    required int idParcela,
    this.observacoes = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    required String userId,
    this.areaHa = const Value.absent(),
    this.synced = const Value.absent(),
    this.prontaParaSync = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.createdBy = const Value.absent(),
  })  : uuid = Value(uuid),
        propUt = Value(propUt),
        idParcela = Value(idParcela),
        userId = Value(userId);
  static Insertable<Parcela> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? propriedade,
    Expression<String>? propUt,
    Expression<int>? idParcela,
    Expression<String>? observacoes,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? userId,
    Expression<double>? areaHa,
    Expression<bool>? synced,
    Expression<bool>? prontaParaSync,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? deletedBy,
    Expression<String>? createdBy,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (propriedade != null) 'propriedade': propriedade,
      if (propUt != null) 'prop_ut': propUt,
      if (idParcela != null) 'id_parcela': idParcela,
      if (observacoes != null) 'observacoes': observacoes,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (userId != null) 'user_id': userId,
      if (areaHa != null) 'area_ha': areaHa,
      if (synced != null) 'synced': synced,
      if (prontaParaSync != null) 'pronta_para_sync': prontaParaSync,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deletedBy != null) 'deleted_by': deletedBy,
      if (createdBy != null) 'created_by': createdBy,
    });
  }

  ParcelasCompanion copyWith(
      {Value<int>? id,
      Value<String>? uuid,
      Value<String>? propriedade,
      Value<String>? propUt,
      Value<int>? idParcela,
      Value<String?>? observacoes,
      Value<double?>? latitude,
      Value<double?>? longitude,
      Value<String>? userId,
      Value<double?>? areaHa,
      Value<bool>? synced,
      Value<bool>? prontaParaSync,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<String?>? deletedBy,
      Value<String>? createdBy}) {
    return ParcelasCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      propriedade: propriedade ?? this.propriedade,
      propUt: propUt ?? this.propUt,
      idParcela: idParcela ?? this.idParcela,
      observacoes: observacoes ?? this.observacoes,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      userId: userId ?? this.userId,
      areaHa: areaHa ?? this.areaHa,
      synced: synced ?? this.synced,
      prontaParaSync: prontaParaSync ?? this.prontaParaSync,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (propriedade.present) {
      map['propriedade'] = Variable<String>(propriedade.value);
    }
    if (propUt.present) {
      map['prop_ut'] = Variable<String>(propUt.value);
    }
    if (idParcela.present) {
      map['id_parcela'] = Variable<int>(idParcela.value);
    }
    if (observacoes.present) {
      map['observacoes'] = Variable<String>(observacoes.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (areaHa.present) {
      map['area_ha'] = Variable<double>(areaHa.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (prontaParaSync.present) {
      map['pronta_para_sync'] = Variable<bool>(prontaParaSync.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (deletedBy.present) {
      map['deleted_by'] = Variable<String>(deletedBy.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ParcelasCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('propriedade: $propriedade, ')
          ..write('propUt: $propUt, ')
          ..write('idParcela: $idParcela, ')
          ..write('observacoes: $observacoes, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('userId: $userId, ')
          ..write('areaHa: $areaHa, ')
          ..write('synced: $synced, ')
          ..write('prontaParaSync: $prontaParaSync, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('createdBy: $createdBy')
          ..write(')'))
        .toString();
  }
}

class $PlantasTable extends Plantas with TableInfo<$PlantasTable, Planta> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlantasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
      'uuid', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _parcelaUuidMeta =
      const VerificationMeta('parcelaUuid');
  @override
  late final GeneratedColumn<String> parcelaUuid = GeneratedColumn<String>(
      'parcela_uuid', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES parcelas (uuid)'));
  static const VerificationMeta _especieMeta =
      const VerificationMeta('especie');
  @override
  late final GeneratedColumn<String> especie = GeneratedColumn<String>(
      'especie', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _alturaCmMeta =
      const VerificationMeta('alturaCm');
  @override
  late final GeneratedColumn<double> alturaCm = GeneratedColumn<double>(
      'altura_cm', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _dapCmMeta = const VerificationMeta('dapCm');
  @override
  late final GeneratedColumn<double> dapCm = GeneratedColumn<double>(
      'dap_cm', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _categoriaMeta =
      const VerificationMeta('categoria');
  @override
  late final GeneratedColumn<int> categoria = GeneratedColumn<int>(
      'categoria', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _fotoEspeciePathMeta =
      const VerificationMeta('fotoEspeciePath');
  @override
  late final GeneratedColumn<String> fotoEspeciePath = GeneratedColumn<String>(
      'foto_especie_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
      'synced', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("synced" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        uuid,
        parcelaUuid,
        especie,
        alturaCm,
        dapCm,
        categoria,
        fotoEspeciePath,
        synced,
        createdAt,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plantas';
  @override
  VerificationContext validateIntegrity(Insertable<Planta> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
          _uuidMeta, uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta));
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('parcela_uuid')) {
      context.handle(
          _parcelaUuidMeta,
          parcelaUuid.isAcceptableOrUnknown(
              data['parcela_uuid']!, _parcelaUuidMeta));
    } else if (isInserting) {
      context.missing(_parcelaUuidMeta);
    }
    if (data.containsKey('especie')) {
      context.handle(_especieMeta,
          especie.isAcceptableOrUnknown(data['especie']!, _especieMeta));
    } else if (isInserting) {
      context.missing(_especieMeta);
    }
    if (data.containsKey('altura_cm')) {
      context.handle(_alturaCmMeta,
          alturaCm.isAcceptableOrUnknown(data['altura_cm']!, _alturaCmMeta));
    } else if (isInserting) {
      context.missing(_alturaCmMeta);
    }
    if (data.containsKey('dap_cm')) {
      context.handle(
          _dapCmMeta, dapCm.isAcceptableOrUnknown(data['dap_cm']!, _dapCmMeta));
    }
    if (data.containsKey('categoria')) {
      context.handle(_categoriaMeta,
          categoria.isAcceptableOrUnknown(data['categoria']!, _categoriaMeta));
    } else if (isInserting) {
      context.missing(_categoriaMeta);
    }
    if (data.containsKey('foto_especie_path')) {
      context.handle(
          _fotoEspeciePathMeta,
          fotoEspeciePath.isAcceptableOrUnknown(
              data['foto_especie_path']!, _fotoEspeciePathMeta));
    }
    if (data.containsKey('synced')) {
      context.handle(_syncedMeta,
          synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Planta map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Planta(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      uuid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uuid'])!,
      parcelaUuid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parcela_uuid'])!,
      especie: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}especie'])!,
      alturaCm: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}altura_cm'])!,
      dapCm: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}dap_cm']),
      categoria: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}categoria'])!,
      fotoEspeciePath: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}foto_especie_path']),
      synced: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}synced'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $PlantasTable createAlias(String alias) {
    return $PlantasTable(attachedDatabase, alias);
  }
}

class Planta extends DataClass implements Insertable<Planta> {
  final int id;
  final String uuid;
  final String parcelaUuid;
  final String especie;
  final double alturaCm;
  final double? dapCm;
  final int categoria;
  final String? fotoEspeciePath;
  final bool synced;
  final DateTime createdAt;
  final DateTime? deletedAt;
  const Planta(
      {required this.id,
      required this.uuid,
      required this.parcelaUuid,
      required this.especie,
      required this.alturaCm,
      this.dapCm,
      required this.categoria,
      this.fotoEspeciePath,
      required this.synced,
      required this.createdAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['parcela_uuid'] = Variable<String>(parcelaUuid);
    map['especie'] = Variable<String>(especie);
    map['altura_cm'] = Variable<double>(alturaCm);
    if (!nullToAbsent || dapCm != null) {
      map['dap_cm'] = Variable<double>(dapCm);
    }
    map['categoria'] = Variable<int>(categoria);
    if (!nullToAbsent || fotoEspeciePath != null) {
      map['foto_especie_path'] = Variable<String>(fotoEspeciePath);
    }
    map['synced'] = Variable<bool>(synced);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  PlantasCompanion toCompanion(bool nullToAbsent) {
    return PlantasCompanion(
      id: Value(id),
      uuid: Value(uuid),
      parcelaUuid: Value(parcelaUuid),
      especie: Value(especie),
      alturaCm: Value(alturaCm),
      dapCm:
          dapCm == null && nullToAbsent ? const Value.absent() : Value(dapCm),
      categoria: Value(categoria),
      fotoEspeciePath: fotoEspeciePath == null && nullToAbsent
          ? const Value.absent()
          : Value(fotoEspeciePath),
      synced: Value(synced),
      createdAt: Value(createdAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Planta.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Planta(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      parcelaUuid: serializer.fromJson<String>(json['parcelaUuid']),
      especie: serializer.fromJson<String>(json['especie']),
      alturaCm: serializer.fromJson<double>(json['alturaCm']),
      dapCm: serializer.fromJson<double?>(json['dapCm']),
      categoria: serializer.fromJson<int>(json['categoria']),
      fotoEspeciePath: serializer.fromJson<String?>(json['fotoEspeciePath']),
      synced: serializer.fromJson<bool>(json['synced']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'parcelaUuid': serializer.toJson<String>(parcelaUuid),
      'especie': serializer.toJson<String>(especie),
      'alturaCm': serializer.toJson<double>(alturaCm),
      'dapCm': serializer.toJson<double?>(dapCm),
      'categoria': serializer.toJson<int>(categoria),
      'fotoEspeciePath': serializer.toJson<String?>(fotoEspeciePath),
      'synced': serializer.toJson<bool>(synced),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Planta copyWith(
          {int? id,
          String? uuid,
          String? parcelaUuid,
          String? especie,
          double? alturaCm,
          Value<double?> dapCm = const Value.absent(),
          int? categoria,
          Value<String?> fotoEspeciePath = const Value.absent(),
          bool? synced,
          DateTime? createdAt,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      Planta(
        id: id ?? this.id,
        uuid: uuid ?? this.uuid,
        parcelaUuid: parcelaUuid ?? this.parcelaUuid,
        especie: especie ?? this.especie,
        alturaCm: alturaCm ?? this.alturaCm,
        dapCm: dapCm.present ? dapCm.value : this.dapCm,
        categoria: categoria ?? this.categoria,
        fotoEspeciePath: fotoEspeciePath.present
            ? fotoEspeciePath.value
            : this.fotoEspeciePath,
        synced: synced ?? this.synced,
        createdAt: createdAt ?? this.createdAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  Planta copyWithCompanion(PlantasCompanion data) {
    return Planta(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      parcelaUuid:
          data.parcelaUuid.present ? data.parcelaUuid.value : this.parcelaUuid,
      especie: data.especie.present ? data.especie.value : this.especie,
      alturaCm: data.alturaCm.present ? data.alturaCm.value : this.alturaCm,
      dapCm: data.dapCm.present ? data.dapCm.value : this.dapCm,
      categoria: data.categoria.present ? data.categoria.value : this.categoria,
      fotoEspeciePath: data.fotoEspeciePath.present
          ? data.fotoEspeciePath.value
          : this.fotoEspeciePath,
      synced: data.synced.present ? data.synced.value : this.synced,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Planta(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('parcelaUuid: $parcelaUuid, ')
          ..write('especie: $especie, ')
          ..write('alturaCm: $alturaCm, ')
          ..write('dapCm: $dapCm, ')
          ..write('categoria: $categoria, ')
          ..write('fotoEspeciePath: $fotoEspeciePath, ')
          ..write('synced: $synced, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, uuid, parcelaUuid, especie, alturaCm,
      dapCm, categoria, fotoEspeciePath, synced, createdAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Planta &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.parcelaUuid == this.parcelaUuid &&
          other.especie == this.especie &&
          other.alturaCm == this.alturaCm &&
          other.dapCm == this.dapCm &&
          other.categoria == this.categoria &&
          other.fotoEspeciePath == this.fotoEspeciePath &&
          other.synced == this.synced &&
          other.createdAt == this.createdAt &&
          other.deletedAt == this.deletedAt);
}

class PlantasCompanion extends UpdateCompanion<Planta> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> parcelaUuid;
  final Value<String> especie;
  final Value<double> alturaCm;
  final Value<double?> dapCm;
  final Value<int> categoria;
  final Value<String?> fotoEspeciePath;
  final Value<bool> synced;
  final Value<DateTime> createdAt;
  final Value<DateTime?> deletedAt;
  const PlantasCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.parcelaUuid = const Value.absent(),
    this.especie = const Value.absent(),
    this.alturaCm = const Value.absent(),
    this.dapCm = const Value.absent(),
    this.categoria = const Value.absent(),
    this.fotoEspeciePath = const Value.absent(),
    this.synced = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  PlantasCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required String parcelaUuid,
    required String especie,
    required double alturaCm,
    this.dapCm = const Value.absent(),
    required int categoria,
    this.fotoEspeciePath = const Value.absent(),
    this.synced = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  })  : uuid = Value(uuid),
        parcelaUuid = Value(parcelaUuid),
        especie = Value(especie),
        alturaCm = Value(alturaCm),
        categoria = Value(categoria);
  static Insertable<Planta> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? parcelaUuid,
    Expression<String>? especie,
    Expression<double>? alturaCm,
    Expression<double>? dapCm,
    Expression<int>? categoria,
    Expression<String>? fotoEspeciePath,
    Expression<bool>? synced,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (parcelaUuid != null) 'parcela_uuid': parcelaUuid,
      if (especie != null) 'especie': especie,
      if (alturaCm != null) 'altura_cm': alturaCm,
      if (dapCm != null) 'dap_cm': dapCm,
      if (categoria != null) 'categoria': categoria,
      if (fotoEspeciePath != null) 'foto_especie_path': fotoEspeciePath,
      if (synced != null) 'synced': synced,
      if (createdAt != null) 'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  PlantasCompanion copyWith(
      {Value<int>? id,
      Value<String>? uuid,
      Value<String>? parcelaUuid,
      Value<String>? especie,
      Value<double>? alturaCm,
      Value<double?>? dapCm,
      Value<int>? categoria,
      Value<String?>? fotoEspeciePath,
      Value<bool>? synced,
      Value<DateTime>? createdAt,
      Value<DateTime?>? deletedAt}) {
    return PlantasCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      parcelaUuid: parcelaUuid ?? this.parcelaUuid,
      especie: especie ?? this.especie,
      alturaCm: alturaCm ?? this.alturaCm,
      dapCm: dapCm ?? this.dapCm,
      categoria: categoria ?? this.categoria,
      fotoEspeciePath: fotoEspeciePath ?? this.fotoEspeciePath,
      synced: synced ?? this.synced,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (parcelaUuid.present) {
      map['parcela_uuid'] = Variable<String>(parcelaUuid.value);
    }
    if (especie.present) {
      map['especie'] = Variable<String>(especie.value);
    }
    if (alturaCm.present) {
      map['altura_cm'] = Variable<double>(alturaCm.value);
    }
    if (dapCm.present) {
      map['dap_cm'] = Variable<double>(dapCm.value);
    }
    if (categoria.present) {
      map['categoria'] = Variable<int>(categoria.value);
    }
    if (fotoEspeciePath.present) {
      map['foto_especie_path'] = Variable<String>(fotoEspeciePath.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlantasCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('parcelaUuid: $parcelaUuid, ')
          ..write('especie: $especie, ')
          ..write('alturaCm: $alturaCm, ')
          ..write('dapCm: $dapCm, ')
          ..write('categoria: $categoria, ')
          ..write('fotoEspeciePath: $fotoEspeciePath, ')
          ..write('synced: $synced, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $FotosParcelaTable extends FotosParcela
    with TableInfo<$FotosParcelaTable, FotosParcelaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FotosParcelaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
      'uuid', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _parcelaUuidMeta =
      const VerificationMeta('parcelaUuid');
  @override
  late final GeneratedColumn<String> parcelaUuid = GeneratedColumn<String>(
      'parcela_uuid', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES parcelas (uuid)'));
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _compressedPathMeta =
      const VerificationMeta('compressedPath');
  @override
  late final GeneratedColumn<String> compressedPath = GeneratedColumn<String>(
      'compressed_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
      'synced', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("synced" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        uuid,
        parcelaUuid,
        filePath,
        compressedPath,
        synced,
        createdAt,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fotos_parcela';
  @override
  VerificationContext validateIntegrity(Insertable<FotosParcelaData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
          _uuidMeta, uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta));
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('parcela_uuid')) {
      context.handle(
          _parcelaUuidMeta,
          parcelaUuid.isAcceptableOrUnknown(
              data['parcela_uuid']!, _parcelaUuidMeta));
    } else if (isInserting) {
      context.missing(_parcelaUuidMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('compressed_path')) {
      context.handle(
          _compressedPathMeta,
          compressedPath.isAcceptableOrUnknown(
              data['compressed_path']!, _compressedPathMeta));
    }
    if (data.containsKey('synced')) {
      context.handle(_syncedMeta,
          synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FotosParcelaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FotosParcelaData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      uuid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uuid'])!,
      parcelaUuid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parcela_uuid'])!,
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path'])!,
      compressedPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}compressed_path']),
      synced: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}synced'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $FotosParcelaTable createAlias(String alias) {
    return $FotosParcelaTable(attachedDatabase, alias);
  }
}

class FotosParcelaData extends DataClass
    implements Insertable<FotosParcelaData> {
  final int id;
  final String uuid;
  final String parcelaUuid;
  final String filePath;
  final String? compressedPath;
  final bool synced;
  final DateTime createdAt;
  final DateTime? deletedAt;
  const FotosParcelaData(
      {required this.id,
      required this.uuid,
      required this.parcelaUuid,
      required this.filePath,
      this.compressedPath,
      required this.synced,
      required this.createdAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['parcela_uuid'] = Variable<String>(parcelaUuid);
    map['file_path'] = Variable<String>(filePath);
    if (!nullToAbsent || compressedPath != null) {
      map['compressed_path'] = Variable<String>(compressedPath);
    }
    map['synced'] = Variable<bool>(synced);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  FotosParcelaCompanion toCompanion(bool nullToAbsent) {
    return FotosParcelaCompanion(
      id: Value(id),
      uuid: Value(uuid),
      parcelaUuid: Value(parcelaUuid),
      filePath: Value(filePath),
      compressedPath: compressedPath == null && nullToAbsent
          ? const Value.absent()
          : Value(compressedPath),
      synced: Value(synced),
      createdAt: Value(createdAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory FotosParcelaData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FotosParcelaData(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      parcelaUuid: serializer.fromJson<String>(json['parcelaUuid']),
      filePath: serializer.fromJson<String>(json['filePath']),
      compressedPath: serializer.fromJson<String?>(json['compressedPath']),
      synced: serializer.fromJson<bool>(json['synced']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'parcelaUuid': serializer.toJson<String>(parcelaUuid),
      'filePath': serializer.toJson<String>(filePath),
      'compressedPath': serializer.toJson<String?>(compressedPath),
      'synced': serializer.toJson<bool>(synced),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  FotosParcelaData copyWith(
          {int? id,
          String? uuid,
          String? parcelaUuid,
          String? filePath,
          Value<String?> compressedPath = const Value.absent(),
          bool? synced,
          DateTime? createdAt,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      FotosParcelaData(
        id: id ?? this.id,
        uuid: uuid ?? this.uuid,
        parcelaUuid: parcelaUuid ?? this.parcelaUuid,
        filePath: filePath ?? this.filePath,
        compressedPath:
            compressedPath.present ? compressedPath.value : this.compressedPath,
        synced: synced ?? this.synced,
        createdAt: createdAt ?? this.createdAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  FotosParcelaData copyWithCompanion(FotosParcelaCompanion data) {
    return FotosParcelaData(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      parcelaUuid:
          data.parcelaUuid.present ? data.parcelaUuid.value : this.parcelaUuid,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      compressedPath: data.compressedPath.present
          ? data.compressedPath.value
          : this.compressedPath,
      synced: data.synced.present ? data.synced.value : this.synced,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FotosParcelaData(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('parcelaUuid: $parcelaUuid, ')
          ..write('filePath: $filePath, ')
          ..write('compressedPath: $compressedPath, ')
          ..write('synced: $synced, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, uuid, parcelaUuid, filePath,
      compressedPath, synced, createdAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FotosParcelaData &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.parcelaUuid == this.parcelaUuid &&
          other.filePath == this.filePath &&
          other.compressedPath == this.compressedPath &&
          other.synced == this.synced &&
          other.createdAt == this.createdAt &&
          other.deletedAt == this.deletedAt);
}

class FotosParcelaCompanion extends UpdateCompanion<FotosParcelaData> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> parcelaUuid;
  final Value<String> filePath;
  final Value<String?> compressedPath;
  final Value<bool> synced;
  final Value<DateTime> createdAt;
  final Value<DateTime?> deletedAt;
  const FotosParcelaCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.parcelaUuid = const Value.absent(),
    this.filePath = const Value.absent(),
    this.compressedPath = const Value.absent(),
    this.synced = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  FotosParcelaCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required String parcelaUuid,
    required String filePath,
    this.compressedPath = const Value.absent(),
    this.synced = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  })  : uuid = Value(uuid),
        parcelaUuid = Value(parcelaUuid),
        filePath = Value(filePath);
  static Insertable<FotosParcelaData> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? parcelaUuid,
    Expression<String>? filePath,
    Expression<String>? compressedPath,
    Expression<bool>? synced,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (parcelaUuid != null) 'parcela_uuid': parcelaUuid,
      if (filePath != null) 'file_path': filePath,
      if (compressedPath != null) 'compressed_path': compressedPath,
      if (synced != null) 'synced': synced,
      if (createdAt != null) 'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  FotosParcelaCompanion copyWith(
      {Value<int>? id,
      Value<String>? uuid,
      Value<String>? parcelaUuid,
      Value<String>? filePath,
      Value<String?>? compressedPath,
      Value<bool>? synced,
      Value<DateTime>? createdAt,
      Value<DateTime?>? deletedAt}) {
    return FotosParcelaCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      parcelaUuid: parcelaUuid ?? this.parcelaUuid,
      filePath: filePath ?? this.filePath,
      compressedPath: compressedPath ?? this.compressedPath,
      synced: synced ?? this.synced,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (parcelaUuid.present) {
      map['parcela_uuid'] = Variable<String>(parcelaUuid.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (compressedPath.present) {
      map['compressed_path'] = Variable<String>(compressedPath.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FotosParcelaCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('parcelaUuid: $parcelaUuid, ')
          ..write('filePath: $filePath, ')
          ..write('compressedPath: $compressedPath, ')
          ..write('synced: $synced, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $AuditLogTable extends AuditLog
    with TableInfo<$AuditLogTable, AuditLogData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuditLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
      'action', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityTypeMeta =
      const VerificationMeta('entityType');
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
      'entity_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _entityUuidMeta =
      const VerificationMeta('entityUuid');
  @override
  late final GeneratedColumn<String> entityUuid = GeneratedColumn<String>(
      'entity_uuid', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _detailsMeta =
      const VerificationMeta('details');
  @override
  late final GeneratedColumn<String> details = GeneratedColumn<String>(
      'details', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, action, entityType, entityUuid, userId, details, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audit_log';
  @override
  VerificationContext validateIntegrity(Insertable<AuditLogData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('action')) {
      context.handle(_actionMeta,
          action.isAcceptableOrUnknown(data['action']!, _actionMeta));
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
          _entityTypeMeta,
          entityType.isAcceptableOrUnknown(
              data['entity_type']!, _entityTypeMeta));
    }
    if (data.containsKey('entity_uuid')) {
      context.handle(
          _entityUuidMeta,
          entityUuid.isAcceptableOrUnknown(
              data['entity_uuid']!, _entityUuidMeta));
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    }
    if (data.containsKey('details')) {
      context.handle(_detailsMeta,
          details.isAcceptableOrUnknown(data['details']!, _detailsMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AuditLogData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AuditLogData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      action: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}action'])!,
      entityType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_type']),
      entityUuid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_uuid']),
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id']),
      details: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}details']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $AuditLogTable createAlias(String alias) {
    return $AuditLogTable(attachedDatabase, alias);
  }
}

class AuditLogData extends DataClass implements Insertable<AuditLogData> {
  final int id;
  final String action;
  final String? entityType;
  final String? entityUuid;
  final String? userId;
  final String? details;
  final DateTime createdAt;
  const AuditLogData(
      {required this.id,
      required this.action,
      this.entityType,
      this.entityUuid,
      this.userId,
      this.details,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['action'] = Variable<String>(action);
    if (!nullToAbsent || entityType != null) {
      map['entity_type'] = Variable<String>(entityType);
    }
    if (!nullToAbsent || entityUuid != null) {
      map['entity_uuid'] = Variable<String>(entityUuid);
    }
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    if (!nullToAbsent || details != null) {
      map['details'] = Variable<String>(details);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AuditLogCompanion toCompanion(bool nullToAbsent) {
    return AuditLogCompanion(
      id: Value(id),
      action: Value(action),
      entityType: entityType == null && nullToAbsent
          ? const Value.absent()
          : Value(entityType),
      entityUuid: entityUuid == null && nullToAbsent
          ? const Value.absent()
          : Value(entityUuid),
      userId:
          userId == null && nullToAbsent ? const Value.absent() : Value(userId),
      details: details == null && nullToAbsent
          ? const Value.absent()
          : Value(details),
      createdAt: Value(createdAt),
    );
  }

  factory AuditLogData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AuditLogData(
      id: serializer.fromJson<int>(json['id']),
      action: serializer.fromJson<String>(json['action']),
      entityType: serializer.fromJson<String?>(json['entityType']),
      entityUuid: serializer.fromJson<String?>(json['entityUuid']),
      userId: serializer.fromJson<String?>(json['userId']),
      details: serializer.fromJson<String?>(json['details']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'action': serializer.toJson<String>(action),
      'entityType': serializer.toJson<String?>(entityType),
      'entityUuid': serializer.toJson<String?>(entityUuid),
      'userId': serializer.toJson<String?>(userId),
      'details': serializer.toJson<String?>(details),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AuditLogData copyWith(
          {int? id,
          String? action,
          Value<String?> entityType = const Value.absent(),
          Value<String?> entityUuid = const Value.absent(),
          Value<String?> userId = const Value.absent(),
          Value<String?> details = const Value.absent(),
          DateTime? createdAt}) =>
      AuditLogData(
        id: id ?? this.id,
        action: action ?? this.action,
        entityType: entityType.present ? entityType.value : this.entityType,
        entityUuid: entityUuid.present ? entityUuid.value : this.entityUuid,
        userId: userId.present ? userId.value : this.userId,
        details: details.present ? details.value : this.details,
        createdAt: createdAt ?? this.createdAt,
      );
  AuditLogData copyWithCompanion(AuditLogCompanion data) {
    return AuditLogData(
      id: data.id.present ? data.id.value : this.id,
      action: data.action.present ? data.action.value : this.action,
      entityType:
          data.entityType.present ? data.entityType.value : this.entityType,
      entityUuid:
          data.entityUuid.present ? data.entityUuid.value : this.entityUuid,
      userId: data.userId.present ? data.userId.value : this.userId,
      details: data.details.present ? data.details.value : this.details,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AuditLogData(')
          ..write('id: $id, ')
          ..write('action: $action, ')
          ..write('entityType: $entityType, ')
          ..write('entityUuid: $entityUuid, ')
          ..write('userId: $userId, ')
          ..write('details: $details, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, action, entityType, entityUuid, userId, details, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuditLogData &&
          other.id == this.id &&
          other.action == this.action &&
          other.entityType == this.entityType &&
          other.entityUuid == this.entityUuid &&
          other.userId == this.userId &&
          other.details == this.details &&
          other.createdAt == this.createdAt);
}

class AuditLogCompanion extends UpdateCompanion<AuditLogData> {
  final Value<int> id;
  final Value<String> action;
  final Value<String?> entityType;
  final Value<String?> entityUuid;
  final Value<String?> userId;
  final Value<String?> details;
  final Value<DateTime> createdAt;
  const AuditLogCompanion({
    this.id = const Value.absent(),
    this.action = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityUuid = const Value.absent(),
    this.userId = const Value.absent(),
    this.details = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AuditLogCompanion.insert({
    this.id = const Value.absent(),
    required String action,
    this.entityType = const Value.absent(),
    this.entityUuid = const Value.absent(),
    this.userId = const Value.absent(),
    this.details = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : action = Value(action);
  static Insertable<AuditLogData> custom({
    Expression<int>? id,
    Expression<String>? action,
    Expression<String>? entityType,
    Expression<String>? entityUuid,
    Expression<String>? userId,
    Expression<String>? details,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (action != null) 'action': action,
      if (entityType != null) 'entity_type': entityType,
      if (entityUuid != null) 'entity_uuid': entityUuid,
      if (userId != null) 'user_id': userId,
      if (details != null) 'details': details,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AuditLogCompanion copyWith(
      {Value<int>? id,
      Value<String>? action,
      Value<String?>? entityType,
      Value<String?>? entityUuid,
      Value<String?>? userId,
      Value<String?>? details,
      Value<DateTime>? createdAt}) {
    return AuditLogCompanion(
      id: id ?? this.id,
      action: action ?? this.action,
      entityType: entityType ?? this.entityType,
      entityUuid: entityUuid ?? this.entityUuid,
      userId: userId ?? this.userId,
      details: details ?? this.details,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityUuid.present) {
      map['entity_uuid'] = Variable<String>(entityUuid.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (details.present) {
      map['details'] = Variable<String>(details.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuditLogCompanion(')
          ..write('id: $id, ')
          ..write('action: $action, ')
          ..write('entityType: $entityType, ')
          ..write('entityUuid: $entityUuid, ')
          ..write('userId: $userId, ')
          ..write('details: $details, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UsuariosTable usuarios = $UsuariosTable(this);
  late final $ParcelasTable parcelas = $ParcelasTable(this);
  late final $PlantasTable plantas = $PlantasTable(this);
  late final $FotosParcelaTable fotosParcela = $FotosParcelaTable(this);
  late final $AuditLogTable auditLog = $AuditLogTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [usuarios, parcelas, plantas, fotosParcela, auditLog];
}

typedef $$UsuariosTableCreateCompanionBuilder = UsuariosCompanion Function({
  Value<int> id,
  required String uuid,
  required String nome,
  required String email,
  required String senha,
  Value<bool> isAdmin,
  Value<bool> ativo,
  Value<DateTime> createdAt,
});
typedef $$UsuariosTableUpdateCompanionBuilder = UsuariosCompanion Function({
  Value<int> id,
  Value<String> uuid,
  Value<String> nome,
  Value<String> email,
  Value<String> senha,
  Value<bool> isAdmin,
  Value<bool> ativo,
  Value<DateTime> createdAt,
});

class $$UsuariosTableFilterComposer
    extends Composer<_$AppDatabase, $UsuariosTable> {
  $$UsuariosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get uuid => $composableBuilder(
      column: $table.uuid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nome => $composableBuilder(
      column: $table.nome, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get senha => $composableBuilder(
      column: $table.senha, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isAdmin => $composableBuilder(
      column: $table.isAdmin, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get ativo => $composableBuilder(
      column: $table.ativo, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$UsuariosTableOrderingComposer
    extends Composer<_$AppDatabase, $UsuariosTable> {
  $$UsuariosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get uuid => $composableBuilder(
      column: $table.uuid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nome => $composableBuilder(
      column: $table.nome, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get senha => $composableBuilder(
      column: $table.senha, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isAdmin => $composableBuilder(
      column: $table.isAdmin, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get ativo => $composableBuilder(
      column: $table.ativo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$UsuariosTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsuariosTable> {
  $$UsuariosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get nome =>
      $composableBuilder(column: $table.nome, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get senha =>
      $composableBuilder(column: $table.senha, builder: (column) => column);

  GeneratedColumn<bool> get isAdmin =>
      $composableBuilder(column: $table.isAdmin, builder: (column) => column);

  GeneratedColumn<bool> get ativo =>
      $composableBuilder(column: $table.ativo, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$UsuariosTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UsuariosTable,
    Usuario,
    $$UsuariosTableFilterComposer,
    $$UsuariosTableOrderingComposer,
    $$UsuariosTableAnnotationComposer,
    $$UsuariosTableCreateCompanionBuilder,
    $$UsuariosTableUpdateCompanionBuilder,
    (Usuario, BaseReferences<_$AppDatabase, $UsuariosTable, Usuario>),
    Usuario,
    PrefetchHooks Function()> {
  $$UsuariosTableTableManager(_$AppDatabase db, $UsuariosTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsuariosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsuariosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsuariosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> uuid = const Value.absent(),
            Value<String> nome = const Value.absent(),
            Value<String> email = const Value.absent(),
            Value<String> senha = const Value.absent(),
            Value<bool> isAdmin = const Value.absent(),
            Value<bool> ativo = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              UsuariosCompanion(
            id: id,
            uuid: uuid,
            nome: nome,
            email: email,
            senha: senha,
            isAdmin: isAdmin,
            ativo: ativo,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String uuid,
            required String nome,
            required String email,
            required String senha,
            Value<bool> isAdmin = const Value.absent(),
            Value<bool> ativo = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              UsuariosCompanion.insert(
            id: id,
            uuid: uuid,
            nome: nome,
            email: email,
            senha: senha,
            isAdmin: isAdmin,
            ativo: ativo,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$UsuariosTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UsuariosTable,
    Usuario,
    $$UsuariosTableFilterComposer,
    $$UsuariosTableOrderingComposer,
    $$UsuariosTableAnnotationComposer,
    $$UsuariosTableCreateCompanionBuilder,
    $$UsuariosTableUpdateCompanionBuilder,
    (Usuario, BaseReferences<_$AppDatabase, $UsuariosTable, Usuario>),
    Usuario,
    PrefetchHooks Function()>;
typedef $$ParcelasTableCreateCompanionBuilder = ParcelasCompanion Function({
  Value<int> id,
  required String uuid,
  Value<String> propriedade,
  required String propUt,
  required int idParcela,
  Value<String?> observacoes,
  Value<double?> latitude,
  Value<double?> longitude,
  required String userId,
  Value<double?> areaHa,
  Value<bool> synced,
  Value<bool> prontaParaSync,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String> createdBy,
});
typedef $$ParcelasTableUpdateCompanionBuilder = ParcelasCompanion Function({
  Value<int> id,
  Value<String> uuid,
  Value<String> propriedade,
  Value<String> propUt,
  Value<int> idParcela,
  Value<String?> observacoes,
  Value<double?> latitude,
  Value<double?> longitude,
  Value<String> userId,
  Value<double?> areaHa,
  Value<bool> synced,
  Value<bool> prontaParaSync,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> deletedBy,
  Value<String> createdBy,
});

final class $$ParcelasTableReferences
    extends BaseReferences<_$AppDatabase, $ParcelasTable, Parcela> {
  $$ParcelasTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlantasTable, List<Planta>> _plantasRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.plantas,
          aliasName:
              $_aliasNameGenerator(db.parcelas.uuid, db.plantas.parcelaUuid));

  $$PlantasTableProcessedTableManager get plantasRefs {
    final manager = $$PlantasTableTableManager($_db, $_db.plantas).filter(
        (f) => f.parcelaUuid.uuid.sqlEquals($_itemColumn<String>('uuid')!));

    final cache = $_typedResult.readTableOrNull(_plantasRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$FotosParcelaTable, List<FotosParcelaData>>
      _fotosParcelaRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.fotosParcela,
              aliasName: $_aliasNameGenerator(
                  db.parcelas.uuid, db.fotosParcela.parcelaUuid));

  $$FotosParcelaTableProcessedTableManager get fotosParcelaRefs {
    final manager = $$FotosParcelaTableTableManager($_db, $_db.fotosParcela)
        .filter(
            (f) => f.parcelaUuid.uuid.sqlEquals($_itemColumn<String>('uuid')!));

    final cache = $_typedResult.readTableOrNull(_fotosParcelaRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ParcelasTableFilterComposer
    extends Composer<_$AppDatabase, $ParcelasTable> {
  $$ParcelasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get uuid => $composableBuilder(
      column: $table.uuid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get propriedade => $composableBuilder(
      column: $table.propriedade, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get propUt => $composableBuilder(
      column: $table.propUt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get idParcela => $composableBuilder(
      column: $table.idParcela, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get observacoes => $composableBuilder(
      column: $table.observacoes, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get areaHa => $composableBuilder(
      column: $table.areaHa, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get prontaParaSync => $composableBuilder(
      column: $table.prontaParaSync,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdBy => $composableBuilder(
      column: $table.createdBy, builder: (column) => ColumnFilters(column));

  Expression<bool> plantasRefs(
      Expression<bool> Function($$PlantasTableFilterComposer f) f) {
    final $$PlantasTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.uuid,
        referencedTable: $db.plantas,
        getReferencedColumn: (t) => t.parcelaUuid,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlantasTableFilterComposer(
              $db: $db,
              $table: $db.plantas,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> fotosParcelaRefs(
      Expression<bool> Function($$FotosParcelaTableFilterComposer f) f) {
    final $$FotosParcelaTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.uuid,
        referencedTable: $db.fotosParcela,
        getReferencedColumn: (t) => t.parcelaUuid,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FotosParcelaTableFilterComposer(
              $db: $db,
              $table: $db.fotosParcela,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ParcelasTableOrderingComposer
    extends Composer<_$AppDatabase, $ParcelasTable> {
  $$ParcelasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get uuid => $composableBuilder(
      column: $table.uuid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get propriedade => $composableBuilder(
      column: $table.propriedade, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get propUt => $composableBuilder(
      column: $table.propUt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get idParcela => $composableBuilder(
      column: $table.idParcela, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get observacoes => $composableBuilder(
      column: $table.observacoes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get areaHa => $composableBuilder(
      column: $table.areaHa, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get prontaParaSync => $composableBuilder(
      column: $table.prontaParaSync,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedBy => $composableBuilder(
      column: $table.deletedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdBy => $composableBuilder(
      column: $table.createdBy, builder: (column) => ColumnOrderings(column));
}

class $$ParcelasTableAnnotationComposer
    extends Composer<_$AppDatabase, $ParcelasTable> {
  $$ParcelasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get propriedade => $composableBuilder(
      column: $table.propriedade, builder: (column) => column);

  GeneratedColumn<String> get propUt =>
      $composableBuilder(column: $table.propUt, builder: (column) => column);

  GeneratedColumn<int> get idParcela =>
      $composableBuilder(column: $table.idParcela, builder: (column) => column);

  GeneratedColumn<String> get observacoes => $composableBuilder(
      column: $table.observacoes, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<double> get areaHa =>
      $composableBuilder(column: $table.areaHa, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);

  GeneratedColumn<bool> get prontaParaSync => $composableBuilder(
      column: $table.prontaParaSync, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  Expression<T> plantasRefs<T extends Object>(
      Expression<T> Function($$PlantasTableAnnotationComposer a) f) {
    final $$PlantasTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.uuid,
        referencedTable: $db.plantas,
        getReferencedColumn: (t) => t.parcelaUuid,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlantasTableAnnotationComposer(
              $db: $db,
              $table: $db.plantas,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> fotosParcelaRefs<T extends Object>(
      Expression<T> Function($$FotosParcelaTableAnnotationComposer a) f) {
    final $$FotosParcelaTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.uuid,
        referencedTable: $db.fotosParcela,
        getReferencedColumn: (t) => t.parcelaUuid,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FotosParcelaTableAnnotationComposer(
              $db: $db,
              $table: $db.fotosParcela,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ParcelasTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ParcelasTable,
    Parcela,
    $$ParcelasTableFilterComposer,
    $$ParcelasTableOrderingComposer,
    $$ParcelasTableAnnotationComposer,
    $$ParcelasTableCreateCompanionBuilder,
    $$ParcelasTableUpdateCompanionBuilder,
    (Parcela, $$ParcelasTableReferences),
    Parcela,
    PrefetchHooks Function({bool plantasRefs, bool fotosParcelaRefs})> {
  $$ParcelasTableTableManager(_$AppDatabase db, $ParcelasTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ParcelasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ParcelasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ParcelasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> uuid = const Value.absent(),
            Value<String> propriedade = const Value.absent(),
            Value<String> propUt = const Value.absent(),
            Value<int> idParcela = const Value.absent(),
            Value<String?> observacoes = const Value.absent(),
            Value<double?> latitude = const Value.absent(),
            Value<double?> longitude = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<double?> areaHa = const Value.absent(),
            Value<bool> synced = const Value.absent(),
            Value<bool> prontaParaSync = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String> createdBy = const Value.absent(),
          }) =>
              ParcelasCompanion(
            id: id,
            uuid: uuid,
            propriedade: propriedade,
            propUt: propUt,
            idParcela: idParcela,
            observacoes: observacoes,
            latitude: latitude,
            longitude: longitude,
            userId: userId,
            areaHa: areaHa,
            synced: synced,
            prontaParaSync: prontaParaSync,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            createdBy: createdBy,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String uuid,
            Value<String> propriedade = const Value.absent(),
            required String propUt,
            required int idParcela,
            Value<String?> observacoes = const Value.absent(),
            Value<double?> latitude = const Value.absent(),
            Value<double?> longitude = const Value.absent(),
            required String userId,
            Value<double?> areaHa = const Value.absent(),
            Value<bool> synced = const Value.absent(),
            Value<bool> prontaParaSync = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> deletedBy = const Value.absent(),
            Value<String> createdBy = const Value.absent(),
          }) =>
              ParcelasCompanion.insert(
            id: id,
            uuid: uuid,
            propriedade: propriedade,
            propUt: propUt,
            idParcela: idParcela,
            observacoes: observacoes,
            latitude: latitude,
            longitude: longitude,
            userId: userId,
            areaHa: areaHa,
            synced: synced,
            prontaParaSync: prontaParaSync,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deletedBy: deletedBy,
            createdBy: createdBy,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$ParcelasTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {plantasRefs = false, fotosParcelaRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (plantasRefs) db.plantas,
                if (fotosParcelaRefs) db.fotosParcela
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (plantasRefs)
                    await $_getPrefetchedData<Parcela, $ParcelasTable, Planta>(
                        currentTable: table,
                        referencedTable:
                            $$ParcelasTableReferences._plantasRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ParcelasTableReferences(db, table, p0)
                                .plantasRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.parcelaUuid == item.uuid),
                        typedResults: items),
                  if (fotosParcelaRefs)
                    await $_getPrefetchedData<Parcela, $ParcelasTable,
                            FotosParcelaData>(
                        currentTable: table,
                        referencedTable: $$ParcelasTableReferences
                            ._fotosParcelaRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ParcelasTableReferences(db, table, p0)
                                .fotosParcelaRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.parcelaUuid == item.uuid),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ParcelasTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ParcelasTable,
    Parcela,
    $$ParcelasTableFilterComposer,
    $$ParcelasTableOrderingComposer,
    $$ParcelasTableAnnotationComposer,
    $$ParcelasTableCreateCompanionBuilder,
    $$ParcelasTableUpdateCompanionBuilder,
    (Parcela, $$ParcelasTableReferences),
    Parcela,
    PrefetchHooks Function({bool plantasRefs, bool fotosParcelaRefs})>;
typedef $$PlantasTableCreateCompanionBuilder = PlantasCompanion Function({
  Value<int> id,
  required String uuid,
  required String parcelaUuid,
  required String especie,
  required double alturaCm,
  Value<double?> dapCm,
  required int categoria,
  Value<String?> fotoEspeciePath,
  Value<bool> synced,
  Value<DateTime> createdAt,
  Value<DateTime?> deletedAt,
});
typedef $$PlantasTableUpdateCompanionBuilder = PlantasCompanion Function({
  Value<int> id,
  Value<String> uuid,
  Value<String> parcelaUuid,
  Value<String> especie,
  Value<double> alturaCm,
  Value<double?> dapCm,
  Value<int> categoria,
  Value<String?> fotoEspeciePath,
  Value<bool> synced,
  Value<DateTime> createdAt,
  Value<DateTime?> deletedAt,
});

final class $$PlantasTableReferences
    extends BaseReferences<_$AppDatabase, $PlantasTable, Planta> {
  $$PlantasTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ParcelasTable _parcelaUuidTable(_$AppDatabase db) =>
      db.parcelas.createAlias(
          $_aliasNameGenerator(db.plantas.parcelaUuid, db.parcelas.uuid));

  $$ParcelasTableProcessedTableManager get parcelaUuid {
    final $_column = $_itemColumn<String>('parcela_uuid')!;

    final manager = $$ParcelasTableTableManager($_db, $_db.parcelas)
        .filter((f) => f.uuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parcelaUuidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$PlantasTableFilterComposer
    extends Composer<_$AppDatabase, $PlantasTable> {
  $$PlantasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get uuid => $composableBuilder(
      column: $table.uuid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get especie => $composableBuilder(
      column: $table.especie, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get alturaCm => $composableBuilder(
      column: $table.alturaCm, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get dapCm => $composableBuilder(
      column: $table.dapCm, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get categoria => $composableBuilder(
      column: $table.categoria, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fotoEspeciePath => $composableBuilder(
      column: $table.fotoEspeciePath,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  $$ParcelasTableFilterComposer get parcelaUuid {
    final $$ParcelasTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parcelaUuid,
        referencedTable: $db.parcelas,
        getReferencedColumn: (t) => t.uuid,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ParcelasTableFilterComposer(
              $db: $db,
              $table: $db.parcelas,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PlantasTableOrderingComposer
    extends Composer<_$AppDatabase, $PlantasTable> {
  $$PlantasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get uuid => $composableBuilder(
      column: $table.uuid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get especie => $composableBuilder(
      column: $table.especie, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get alturaCm => $composableBuilder(
      column: $table.alturaCm, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get dapCm => $composableBuilder(
      column: $table.dapCm, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get categoria => $composableBuilder(
      column: $table.categoria, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fotoEspeciePath => $composableBuilder(
      column: $table.fotoEspeciePath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  $$ParcelasTableOrderingComposer get parcelaUuid {
    final $$ParcelasTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parcelaUuid,
        referencedTable: $db.parcelas,
        getReferencedColumn: (t) => t.uuid,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ParcelasTableOrderingComposer(
              $db: $db,
              $table: $db.parcelas,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PlantasTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlantasTable> {
  $$PlantasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get especie =>
      $composableBuilder(column: $table.especie, builder: (column) => column);

  GeneratedColumn<double> get alturaCm =>
      $composableBuilder(column: $table.alturaCm, builder: (column) => column);

  GeneratedColumn<double> get dapCm =>
      $composableBuilder(column: $table.dapCm, builder: (column) => column);

  GeneratedColumn<int> get categoria =>
      $composableBuilder(column: $table.categoria, builder: (column) => column);

  GeneratedColumn<String> get fotoEspeciePath => $composableBuilder(
      column: $table.fotoEspeciePath, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$ParcelasTableAnnotationComposer get parcelaUuid {
    final $$ParcelasTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parcelaUuid,
        referencedTable: $db.parcelas,
        getReferencedColumn: (t) => t.uuid,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ParcelasTableAnnotationComposer(
              $db: $db,
              $table: $db.parcelas,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PlantasTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlantasTable,
    Planta,
    $$PlantasTableFilterComposer,
    $$PlantasTableOrderingComposer,
    $$PlantasTableAnnotationComposer,
    $$PlantasTableCreateCompanionBuilder,
    $$PlantasTableUpdateCompanionBuilder,
    (Planta, $$PlantasTableReferences),
    Planta,
    PrefetchHooks Function({bool parcelaUuid})> {
  $$PlantasTableTableManager(_$AppDatabase db, $PlantasTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlantasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlantasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlantasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> uuid = const Value.absent(),
            Value<String> parcelaUuid = const Value.absent(),
            Value<String> especie = const Value.absent(),
            Value<double> alturaCm = const Value.absent(),
            Value<double?> dapCm = const Value.absent(),
            Value<int> categoria = const Value.absent(),
            Value<String?> fotoEspeciePath = const Value.absent(),
            Value<bool> synced = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
          }) =>
              PlantasCompanion(
            id: id,
            uuid: uuid,
            parcelaUuid: parcelaUuid,
            especie: especie,
            alturaCm: alturaCm,
            dapCm: dapCm,
            categoria: categoria,
            fotoEspeciePath: fotoEspeciePath,
            synced: synced,
            createdAt: createdAt,
            deletedAt: deletedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String uuid,
            required String parcelaUuid,
            required String especie,
            required double alturaCm,
            Value<double?> dapCm = const Value.absent(),
            required int categoria,
            Value<String?> fotoEspeciePath = const Value.absent(),
            Value<bool> synced = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
          }) =>
              PlantasCompanion.insert(
            id: id,
            uuid: uuid,
            parcelaUuid: parcelaUuid,
            especie: especie,
            alturaCm: alturaCm,
            dapCm: dapCm,
            categoria: categoria,
            fotoEspeciePath: fotoEspeciePath,
            synced: synced,
            createdAt: createdAt,
            deletedAt: deletedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$PlantasTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({parcelaUuid = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (parcelaUuid) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.parcelaUuid,
                    referencedTable:
                        $$PlantasTableReferences._parcelaUuidTable(db),
                    referencedColumn:
                        $$PlantasTableReferences._parcelaUuidTable(db).uuid,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$PlantasTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlantasTable,
    Planta,
    $$PlantasTableFilterComposer,
    $$PlantasTableOrderingComposer,
    $$PlantasTableAnnotationComposer,
    $$PlantasTableCreateCompanionBuilder,
    $$PlantasTableUpdateCompanionBuilder,
    (Planta, $$PlantasTableReferences),
    Planta,
    PrefetchHooks Function({bool parcelaUuid})>;
typedef $$FotosParcelaTableCreateCompanionBuilder = FotosParcelaCompanion
    Function({
  Value<int> id,
  required String uuid,
  required String parcelaUuid,
  required String filePath,
  Value<String?> compressedPath,
  Value<bool> synced,
  Value<DateTime> createdAt,
  Value<DateTime?> deletedAt,
});
typedef $$FotosParcelaTableUpdateCompanionBuilder = FotosParcelaCompanion
    Function({
  Value<int> id,
  Value<String> uuid,
  Value<String> parcelaUuid,
  Value<String> filePath,
  Value<String?> compressedPath,
  Value<bool> synced,
  Value<DateTime> createdAt,
  Value<DateTime?> deletedAt,
});

final class $$FotosParcelaTableReferences extends BaseReferences<_$AppDatabase,
    $FotosParcelaTable, FotosParcelaData> {
  $$FotosParcelaTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ParcelasTable _parcelaUuidTable(_$AppDatabase db) =>
      db.parcelas.createAlias(
          $_aliasNameGenerator(db.fotosParcela.parcelaUuid, db.parcelas.uuid));

  $$ParcelasTableProcessedTableManager get parcelaUuid {
    final $_column = $_itemColumn<String>('parcela_uuid')!;

    final manager = $$ParcelasTableTableManager($_db, $_db.parcelas)
        .filter((f) => f.uuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parcelaUuidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$FotosParcelaTableFilterComposer
    extends Composer<_$AppDatabase, $FotosParcelaTable> {
  $$FotosParcelaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get uuid => $composableBuilder(
      column: $table.uuid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get compressedPath => $composableBuilder(
      column: $table.compressedPath,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  $$ParcelasTableFilterComposer get parcelaUuid {
    final $$ParcelasTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parcelaUuid,
        referencedTable: $db.parcelas,
        getReferencedColumn: (t) => t.uuid,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ParcelasTableFilterComposer(
              $db: $db,
              $table: $db.parcelas,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FotosParcelaTableOrderingComposer
    extends Composer<_$AppDatabase, $FotosParcelaTable> {
  $$FotosParcelaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get uuid => $composableBuilder(
      column: $table.uuid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get compressedPath => $composableBuilder(
      column: $table.compressedPath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  $$ParcelasTableOrderingComposer get parcelaUuid {
    final $$ParcelasTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parcelaUuid,
        referencedTable: $db.parcelas,
        getReferencedColumn: (t) => t.uuid,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ParcelasTableOrderingComposer(
              $db: $db,
              $table: $db.parcelas,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FotosParcelaTableAnnotationComposer
    extends Composer<_$AppDatabase, $FotosParcelaTable> {
  $$FotosParcelaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get compressedPath => $composableBuilder(
      column: $table.compressedPath, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$ParcelasTableAnnotationComposer get parcelaUuid {
    final $$ParcelasTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parcelaUuid,
        referencedTable: $db.parcelas,
        getReferencedColumn: (t) => t.uuid,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ParcelasTableAnnotationComposer(
              $db: $db,
              $table: $db.parcelas,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FotosParcelaTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FotosParcelaTable,
    FotosParcelaData,
    $$FotosParcelaTableFilterComposer,
    $$FotosParcelaTableOrderingComposer,
    $$FotosParcelaTableAnnotationComposer,
    $$FotosParcelaTableCreateCompanionBuilder,
    $$FotosParcelaTableUpdateCompanionBuilder,
    (FotosParcelaData, $$FotosParcelaTableReferences),
    FotosParcelaData,
    PrefetchHooks Function({bool parcelaUuid})> {
  $$FotosParcelaTableTableManager(_$AppDatabase db, $FotosParcelaTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FotosParcelaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FotosParcelaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FotosParcelaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> uuid = const Value.absent(),
            Value<String> parcelaUuid = const Value.absent(),
            Value<String> filePath = const Value.absent(),
            Value<String?> compressedPath = const Value.absent(),
            Value<bool> synced = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
          }) =>
              FotosParcelaCompanion(
            id: id,
            uuid: uuid,
            parcelaUuid: parcelaUuid,
            filePath: filePath,
            compressedPath: compressedPath,
            synced: synced,
            createdAt: createdAt,
            deletedAt: deletedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String uuid,
            required String parcelaUuid,
            required String filePath,
            Value<String?> compressedPath = const Value.absent(),
            Value<bool> synced = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
          }) =>
              FotosParcelaCompanion.insert(
            id: id,
            uuid: uuid,
            parcelaUuid: parcelaUuid,
            filePath: filePath,
            compressedPath: compressedPath,
            synced: synced,
            createdAt: createdAt,
            deletedAt: deletedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$FotosParcelaTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({parcelaUuid = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (parcelaUuid) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.parcelaUuid,
                    referencedTable:
                        $$FotosParcelaTableReferences._parcelaUuidTable(db),
                    referencedColumn: $$FotosParcelaTableReferences
                        ._parcelaUuidTable(db)
                        .uuid,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$FotosParcelaTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FotosParcelaTable,
    FotosParcelaData,
    $$FotosParcelaTableFilterComposer,
    $$FotosParcelaTableOrderingComposer,
    $$FotosParcelaTableAnnotationComposer,
    $$FotosParcelaTableCreateCompanionBuilder,
    $$FotosParcelaTableUpdateCompanionBuilder,
    (FotosParcelaData, $$FotosParcelaTableReferences),
    FotosParcelaData,
    PrefetchHooks Function({bool parcelaUuid})>;
typedef $$AuditLogTableCreateCompanionBuilder = AuditLogCompanion Function({
  Value<int> id,
  required String action,
  Value<String?> entityType,
  Value<String?> entityUuid,
  Value<String?> userId,
  Value<String?> details,
  Value<DateTime> createdAt,
});
typedef $$AuditLogTableUpdateCompanionBuilder = AuditLogCompanion Function({
  Value<int> id,
  Value<String> action,
  Value<String?> entityType,
  Value<String?> entityUuid,
  Value<String?> userId,
  Value<String?> details,
  Value<DateTime> createdAt,
});

class $$AuditLogTableFilterComposer
    extends Composer<_$AppDatabase, $AuditLogTable> {
  $$AuditLogTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get action => $composableBuilder(
      column: $table.action, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityUuid => $composableBuilder(
      column: $table.entityUuid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get details => $composableBuilder(
      column: $table.details, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$AuditLogTableOrderingComposer
    extends Composer<_$AppDatabase, $AuditLogTable> {
  $$AuditLogTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get action => $composableBuilder(
      column: $table.action, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityUuid => $composableBuilder(
      column: $table.entityUuid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get details => $composableBuilder(
      column: $table.details, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$AuditLogTableAnnotationComposer
    extends Composer<_$AppDatabase, $AuditLogTable> {
  $$AuditLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => column);

  GeneratedColumn<String> get entityUuid => $composableBuilder(
      column: $table.entityUuid, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get details =>
      $composableBuilder(column: $table.details, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AuditLogTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AuditLogTable,
    AuditLogData,
    $$AuditLogTableFilterComposer,
    $$AuditLogTableOrderingComposer,
    $$AuditLogTableAnnotationComposer,
    $$AuditLogTableCreateCompanionBuilder,
    $$AuditLogTableUpdateCompanionBuilder,
    (AuditLogData, BaseReferences<_$AppDatabase, $AuditLogTable, AuditLogData>),
    AuditLogData,
    PrefetchHooks Function()> {
  $$AuditLogTableTableManager(_$AppDatabase db, $AuditLogTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AuditLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AuditLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AuditLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> action = const Value.absent(),
            Value<String?> entityType = const Value.absent(),
            Value<String?> entityUuid = const Value.absent(),
            Value<String?> userId = const Value.absent(),
            Value<String?> details = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              AuditLogCompanion(
            id: id,
            action: action,
            entityType: entityType,
            entityUuid: entityUuid,
            userId: userId,
            details: details,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String action,
            Value<String?> entityType = const Value.absent(),
            Value<String?> entityUuid = const Value.absent(),
            Value<String?> userId = const Value.absent(),
            Value<String?> details = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              AuditLogCompanion.insert(
            id: id,
            action: action,
            entityType: entityType,
            entityUuid: entityUuid,
            userId: userId,
            details: details,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AuditLogTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AuditLogTable,
    AuditLogData,
    $$AuditLogTableFilterComposer,
    $$AuditLogTableOrderingComposer,
    $$AuditLogTableAnnotationComposer,
    $$AuditLogTableCreateCompanionBuilder,
    $$AuditLogTableUpdateCompanionBuilder,
    (AuditLogData, BaseReferences<_$AppDatabase, $AuditLogTable, AuditLogData>),
    AuditLogData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UsuariosTableTableManager get usuarios =>
      $$UsuariosTableTableManager(_db, _db.usuarios);
  $$ParcelasTableTableManager get parcelas =>
      $$ParcelasTableTableManager(_db, _db.parcelas);
  $$PlantasTableTableManager get plantas =>
      $$PlantasTableTableManager(_db, _db.plantas);
  $$FotosParcelaTableTableManager get fotosParcela =>
      $$FotosParcelaTableTableManager(_db, _db.fotosParcela);
  $$AuditLogTableTableManager get auditLog =>
      $$AuditLogTableTableManager(_db, _db.auditLog);
}
