import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:io' if (dart.library.html) 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../data/database.dart';
import '../models/conflict_info.dart';
import '../widgets/conflict_resolution_dialog.dart';
import 'clock_service.dart';
import 'image_service.dart';
import 'secure_storage_service.dart';
import 'password_service.dart';
import '../main.dart' as main;

const String kForcedOfflineKey = 'forced_offline_mode';

/// HTTP client com timeout global em todas as requisições.
class _TimeoutHttpClient extends http.BaseClient {
  final http.Client _inner;
  final Duration timeout;
  _TimeoutHttpClient(this._inner, {this.timeout = const Duration(seconds: 30)});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request).timeout(timeout, onTimeout: () {
      throw TimeoutException(
          'Requisição expirou após ${timeout.inSeconds}s: ${request.url}');
    });
  }
}

http.Client _createHttpClient(
        {Duration timeout = const Duration(seconds: 30)}) =>
    _TimeoutHttpClient(http.Client(), timeout: timeout);

String _escapePbFilter(String v) =>
    v.replaceAll('\\', '\\\\').replaceAll('"', '\\"');

class SyncService extends ChangeNotifier {
  final AppDatabase _db;
  PocketBase? _pb;
  bool _isSyncing = false;
  Completer<void>? _syncLock;
  int _pendingCount = 0;
  String? _lastError;
  String? _serverUrl;
  bool _isConnected = false;
  double _syncProgress = 0.0; // 0.0 a 1.0

  /// RG-04: resultado da última verificação da cadeia NO SERVIDOR
  /// (null = íntegra ou ainda não verificada; string = problema encontrado).
  String? lastServerChainStatus;

  // Usuário local atual
  Usuario? _currentUser;

  // Configurações de retry
  static const int _maxRetries = 3;
  static const Duration _baseRetryDelay = Duration(seconds: 2);
  static const int _pageSize = 200; // Itens por página no pull

  SyncService(this._db);

  bool get isSyncing => _isSyncing;
  int get pendingCount => _pendingCount;
  String? get lastError => _lastError;
  String? get serverUrl => _serverUrl;
  bool get isConfigured => _serverUrl != null && _serverUrl!.isNotEmpty;
  bool get isConnected => _isConnected;
  double get syncProgress => _syncProgress;
  Usuario? get currentUser => _currentUser;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  /// Verifica se o modo offline forçado está ativo.
  Future<bool> get isForcedOffline async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kForcedOfflineKey) ?? false;
  }

  /// Detecta se o valor parece ser um UT (ex: UT11, UTE2) e não uma propriedade.
  static bool _looksLikeUt(String s) {
    if (s.isEmpty) return false;
    final t = s.trim().toUpperCase();
    if (t.startsWith('UT') && t.length >= 2) {
      final rest = t.substring(2);
      if (rest.isEmpty) return true;
      if (rest.startsWith('E') && rest.length > 1) return true; // UTE2
      if (RegExp(r'^[A-Z0-9]+$').hasMatch(rest)) return true; // UT11, UT1
    }
    return false;
  }

  /// Executa uma operação com retry exponencial.
  Future<T> _withRetry<T>(Future<T> Function() operation,
      {int maxRetries = _maxRetries}) async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await operation();
      } catch (e) {
        if (attempt == maxRetries) rethrow;
        final delay = _baseRetryDelay * (1 << attempt); // 2s, 4s, 8s
        debugPrint(
            'Tentativa ${attempt + 1} falhou, retentando em ${delay.inSeconds}s: $e');
        await Future.delayed(delay);
      }
    }
    throw Exception('Retry exaurido'); // Nunca alcançado
  }

  /// Inicializa o serviço com a URL do servidor salva localmente.
  Future<void> init() async {
    // Migra credenciais legadas de SharedPreferences para SecureStorage
    await SecureStorageService.migrateFromSharedPreferences();

    final prefs = await SharedPreferences.getInstance();
    _serverUrl = prefs.getString('server_url');

    if (_serverUrl == null || _serverUrl!.isEmpty) {
      _serverUrl = null;
    }

    if (_serverUrl != null) {
      _pb = PocketBase(_serverUrl!, httpClientFactory: _createHttpClient);
      // Restaurar auth token se existir
      final authToken =
          await SecureStorageService.read(SecureStorageService.keyAuthToken);
      if (authToken != null) {
        _pb!.authStore.save(authToken, null);
      }
    }

    // Restaurar usuário local atual
    final userUuid = prefs.getString('current_user_uuid');
    if (userUuid != null) {
      _currentUser = await _db.getUsuarioByUuid(userUuid);
    }

    await _updatePendingCount();
    notifyListeners();
  }

  /// RG-04/RC-05: envia entradas novas da trilha local para o servidor
  /// (append-only). Idempotente: pula entry_hash já existente no servidor.
  /// Mantém a ordem: se uma falhar, para (não pula buraco na cadeia).
  /// Retorna quantas entradas foram effectively enviadas.
  Future<int> pushTrilhaAuditoria() async {
    if (_pb == null) return 0;
    final prefs = await SharedPreferences.getInstance();
    final ultimoId = prefs.getInt('trilha_last_synced_idseq') ?? 0;
    final entradas = await (_db.select(_db.trilhaAuditoria)
          ..where((t) => t.idSeq.isBiggerThanValue(ultimoId))
          ..orderBy([(t) => OrderingTerm.asc(t.idSeq)]))
        .get();
    if (entradas.isEmpty) return 0;

    int enviadas = 0;
    int ultimoEnviado = ultimoId;
    for (final e in entradas) {
      try {
        final existe = await _withRetry(() => _pb!.collection('trilha_auditoria')
            .getList(page: 1, perPage: 1, filter: "entry_hash = '${e.entryHash}'"));
        if (existe.items.isEmpty) {
          // RC-13: dispositivo_id vai no registro do servidor (fora do hash local)
          final dispId = prefs.getString('device_uuid');
          await _withRetry(() => _pb!.collection('trilha_auditoria').create(body: {
                'entidade_tipo': e.entidadeTipo,
                'entidade_uuid': e.entidadeUuid,
                'acao': e.acao,
                'antes': e.antes,
                'depois': e.depois,
                'usuario_uuid': e.usuarioUuid,
                'ts_servidor': e.tsServidor?.toUtc().toIso8601String(),
                'ts_dispositivo': e.tsDispositivo?.toUtc().toIso8601String(),
                'offset_relogio_ms': e.offsetRelogioMs,
                'origem': e.origem,
                'prev_hash': e.prevHash,
                'entry_hash': e.entryHash,
                'dispositivo_id': dispId,
              }));
        }
        enviadas++;
        ultimoEnviado = e.idSeq;
      } catch (err) {
        debugPrint('Falha ao enviar trilha idSeq=${e.idSeq}: $err — parando (cadeia em ordem).');
        break;
      }
    }
    await prefs.setInt('trilha_last_synced_idseq', ultimoEnviado);
    return enviadas;
  }

  /// RG-04: verifica a cadeia COMPLETA no servidor (ordem por id de criação),
  /// remontando o mesmo payload hasheado no app. Retorna null se íntegra.
  Future<String?> verificarCadeiaServidor() async {
    if (_pb == null) return 'servidor não configurado';
    try {
      final todos = await _withRetry(() => _pb!
          .collection('trilha_auditoria')
          .getFullList(sort: 'id', batch: 500));
      String prev = 'GENESIS';
      for (final rec in todos) {
        final prevHash = (rec.data['prev_hash'] as String?) ?? '';
        if (prevHash != prev) {
          return 'Cadeia quebrada no servidor (id=${rec.id}): prevHash esperado $prev, encontrado $prevHash';
        }
        // mesmo payload do insert local (mesma ordem de chaves)
        final tsDisp = rec.data['ts_dispositivo'] as String?;
        final offset = (rec.data['offset_relogio_ms'] as num?)?.toInt();
        final payload = jsonEncode({
          'prev': prevHash,
          'acao': rec.getStringValue('acao'),
          'entidade_tipo': rec.data['entidade_tipo'] as String?,
          'entidade_uuid': rec.data['entidade_uuid'] as String?,
          'usuario_uuid': rec.data['usuario_uuid'] as String?,
          'antes': rec.data['antes'] as String?,
          'depois': rec.data['depois'] as String?,
          'ts_dispositivo': tsDisp == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(
                      DateTime.parse(tsDisp).toUtc().millisecondsSinceEpoch,
                      isUtc: true)
                  .toIso8601String(),
          if (offset != null) 'offset_relogio_ms': offset,
          'origem': rec.getStringValue('origem'),
        });
        final esperado = sha256.convert(utf8.encode(payload)).toString();
        final entryHash = rec.data['entry_hash'] as String?;
        if (entryHash == null) {
          return 'Hash ausente no servidor (id=${rec.id})';
        }
        if (entryHash != esperado) {
          return 'Hash divergente no servidor (id=${rec.id})';
        }
        prev = entryHash;
      }
      return null; // íntegra
    } catch (e) {
      return 'erro ao verificar cadeia no servidor: $e';
    }
  }

  /// Testa conexão com o servidor PocketBase.
  /// Retorna uma string descritiva do resultado.
  Future<String> testConnection([String? urlOverride]) async {
    final url = urlOverride ?? _serverUrl;
    if (url == null || url.isEmpty) {
      return 'URL do servidor não configurada.';
    }

    try {
      final testPb = PocketBase(url, httpClientFactory: _createHttpClient);
      final response = await testPb.health.check();
      if (response.code == 200) {
        _isConnected = true;
        // RC-05: mede offset device↔servidor pelo cabeçalho Date
        await ClockService.capturarOffsetServidor(url);
        notifyListeners();
        return 'OK';
      }
      return 'Servidor respondeu com código ${response.code}.';
    } catch (e) {
      _isConnected = false;
      notifyListeners();
      final errorStr = e.toString();
      if (errorStr.contains('Failed to fetch') ||
          errorStr.contains('SocketException')) {
        return 'Servidor não encontrado em $url.\n'
            'Verifique se o PocketBase está rodando.';
      }
      if (errorStr.contains('CERTIFICATE') ||
          errorStr.contains('HandshakeException')) {
        return 'Erro de certificado SSL.\n'
            'Tente usar http:// em vez de https://';
      }
      return 'Erro: $errorStr';
    }
  }

  /// Define o usuário local atual.
  Future<void> setCurrentUser(Usuario user, {String? password}) async {
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user_uuid', user.uuid);
    await prefs.setString('current_user_name', user.nome);
    await prefs.setBool('current_user_is_admin', user.isAdmin);
    // Senha vai para secure storage (não SharedPreferences)
    if (password != null && password.isNotEmpty) {
      await SecureStorageService.write(
          SecureStorageService.keyCurrentPassword, password);
    }
  await _updatePendingCount();
  notifyListeners();
}

  /// Remove o usuário atual (logout).
  Future<void> clearCurrentUser() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_uuid');
    await prefs.remove('current_user_name');
    await prefs.remove('current_user_is_admin');
    notifyListeners();
  }

  /// Configura a URL do servidor PocketBase.
  Future<void> setServerUrl(String url) async {
    _serverUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    _pb = PocketBase(_serverUrl!, httpClientFactory: _createHttpClient);
    _isConnected = false;
    _pb!.authStore.clear();
    await SecureStorageService.delete(SecureStorageService.keyAuthToken);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', _serverUrl!);
    notifyListeners();
  }

  /// Login no PocketBase.
  Future<bool> login(String email, String password) async {
    if (_pb == null) return false;
    try {
      final authData = await _withRetry(
        () => _pb!.collection('users').authWithPassword(email, password),
      );
      await SecureStorageService.write(
          SecureStorageService.keyAuthToken, _pb!.authStore.token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', authData.record.id);
      await prefs.setString(
          'user_name', authData.record.getStringValue('name'));
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Erro ao fazer login: $e';
      debugPrint(_lastError);
      notifyListeners();
      return false;
    }
  }

  /// Verifica se o usuário está logado.
  Future<bool> isLoggedIn() async {
    final token =
        await SecureStorageService.read(SecureStorageService.keyAuthToken);
    return token != null && token.isNotEmpty;
  }

  /// Retorna dados do usuário logado.
  Future<Map<String, String>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'id': prefs.getString('user_id') ?? '',
      'name': prefs.getString('user_name') ?? '',
    };
  }

  /// Logout.
  Future<void> logout() async {
    _pb?.authStore.clear();
    await SecureStorageService.deleteAll();
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('current_user_uuid');
    await prefs.remove('current_user_name');
    await prefs.remove('current_user_is_admin');
    _pendingCount = 0;
    notifyListeners();
  }

  /// Pedido de recuperação de senha (apenas online).
  /// Envia um email com link para redefinir a senha no servidor PocketBase.
  /// Requer que o servidor tenha email configurado.
  Future<void> requestPasswordReset(String email) async {
    if (_pb == null) throw Exception('Servidor não configurado.');
    await _pb!.collection('users').requestPasswordReset(email);
  }

  /// Verifica conectividade.
  Future<bool> hasInternet() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  /// Registra usuário no servidor PocketBase (cadastro online-first).
  /// Retorna o ID do registro criado, ou null se falhar.
  Future<String?> registrarUsuarioNoServidor(
      String nome, String email, String senha,
      {bool isAdmin = false}) async {
    if (_pb == null || _serverUrl == null) return null;

    // Verifica se já existe no servidor
    try {
      final safeEmail = _escapePbFilter(email);
      final records = await _withRetry(
        () => _pb!
            .collection('users')
            .getFullList(filter: 'email = "$safeEmail"'),
      );
      if (records.isNotEmpty) {
        return records.first.id;
      }
    } catch (_) {}

    // Tenta criar via SDK
    try {
      final record = await _withRetry(
        () => _pb!.collection('users').create(body: {
          'email': email,
          'password': senha,
          'passwordConfirm': senha,
          'name': nome,
          'isAdmin': isAdmin,
        }),
      );
      return record.id;
    } catch (e) {
      debugPrint('SDK create user falhou: $e');
    }

    // Tenta via HTTP raw (contorna possíveis incompatibilidades do SDK)
    try {
      final client = _createHttpClient();
      final uri = Uri.parse('$_serverUrl/api/collections/users/records');
      final response = await client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': senha,
          'passwordConfirm': senha,
          'name': nome,
          'isAdmin': isAdmin,
        }),
      );
      client.close();
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['id'] as String?;
      }
      debugPrint(
          'HTTP raw create user: ${response.statusCode} - ${response.body}');
    } catch (e) {
      debugPrint('HTTP raw create user erro: $e');
    }

    return null;
  }

  /// Busca e autentica usuário no servidor PocketBase por email+senha.
  /// Retorna dados do usuário se autenticou com sucesso, null caso contrário.
  Future<Map<String, dynamic>?> buscarUsuarioNoServidor(String email,
      {String? password}) async {
    if (_pb == null) return null;

    // 1. Se temos senha, tenta auth direta (mais confiável, não precisa de admin auth)
    if (password != null && password.isNotEmpty) {
      try {
        final authData = await _withRetry(
          () => _pb!.collection('users').authWithPassword(email, password),
        );
        final r = authData.record;
        debugPrint('Auth PocketBase OK para $email (id: ${r.id})');
        return {
          'id': r.id,
          'name': r.getStringValue('name'),
          'email': r.getStringValue('email'),
        };
      } catch (e) {
        debugPrint('Auth PocketBase falhou para $email: $e');
        // Se auth falhou, pode ser senha errada ou user não existe
        // Tenta listagem como fallback abaixo
      }
    }

    // 2. Fallback: tenta buscar por listagem (requer admin auth)
    try {
      final records = await _withRetry(
        () => _pb!.collection('users').getFullList(filter: 'email = "$email"'),
      );
      if (records.isNotEmpty) {
        final r = records.first;
        return {
          'id': r.id,
          'name': r.getStringValue('name'),
          'email': r.getStringValue('email'),
        };
      }
    } catch (e) {
      debugPrint('Erro ao buscar usuário no servidor (listagem): $e');
    }
    return null;
  }

  /// Atualiza contagem de itens pendentes.
  Future<void> _updatePendingCount() async {
    // Admin vê todos os pendentes; usuário comum só os seus
    final userId = (_currentUser?.isAdmin ?? false) ? null : _currentUser?.uuid;
    _pendingCount = await _db.countParcelasNaoSincronizadas(userId: userId);
    notifyListeners();
  }

  /// Retorna o timestamp do último sync bem-sucedido.
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt('last_sync_timestamp');
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  /// Tenta auto-autenticar no PocketBase usando as credenciais do usuário local.
  Future<bool> _tryAutoAuth() async {
    if (_pb == null || _currentUser == null) return false;
    if (_pb!.authStore.isValid) return true;

    // Obtém senha do secure storage (sem fallbacks hardcoded)
    final password = await _getStoredPassword();
    if (password == null || password.isEmpty) {
      debugPrint('Auto-auth: sem senha armazenada para ${_currentUser!.email}');
      return false;
    }

    try {
      final authData = await _withRetry(
        () => _pb!
            .collection('users')
            .authWithPassword(_currentUser!.email, password),
      );
      await SecureStorageService.write(
          SecureStorageService.keyAuthToken, _pb!.authStore.token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', authData.record.id);
      await prefs.setString(
          'user_name', authData.record.getStringValue('name'));

      // ── Reconcilia UUID local com o ID do PocketBase ──
      await _reconcileUserUuid(authData.record.id);

      return true;
    } catch (e) {
      debugPrint('Auto-auth falhou: $e');
      // Tenta criar o usuário no PocketBase e depois logar
      try {
        await _withRetry(
          () => _pb!.collection('users').create(body: {
            'email': _currentUser!.email,
            'password': password,
            'passwordConfirm': password,
            'name': _currentUser!.nome,
          }),
        );
        final authData = await _withRetry(
          () => _pb!
              .collection('users')
              .authWithPassword(_currentUser!.email, password),
        );
        await SecureStorageService.write(
            SecureStorageService.keyAuthToken, _pb!.authStore.token);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', authData.record.id);
        await prefs.setString(
            'user_name', authData.record.getStringValue('name'));

        await _reconcileUserUuid(authData.record.id);
        return true;
      } catch (e2) {
        debugPrint('Auto-registro falhou: $e2');
        return false;
      }
    }
  }

  /// Atualiza o UUID do usuário atual no banco local para coincidir com o ID do PocketBase.
  /// Também atualiza todas as parcelas que referenciam o UUID antigo.
  Future<void> _reconcileUserUuid(String pbRecordId) async {
    if (_currentUser == null) return;
    final oldUuid = _currentUser!.uuid;
    if (oldUuid == pbRecordId) return; // Já está correto

    debugPrint('Reconciliando UUID: $oldUuid → $pbRecordId');
    final saved = _currentUser;
    try {
      await _db.remapUsuarioUuid(oldUuid, pbRecordId);
    } catch (_) {
      _currentUser = saved;
      rethrow;
    }

    // Atualiza referência em memória
    _currentUser = await _db.getUsuarioByUuid(pbRecordId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user_uuid', pbRecordId);
  }

  /// Constrói mapa de UUID local → PocketBase ID para TODOS os usuários.
  /// Usado ao sincronizar parcelas de outros usuários (modo admin).
  Future<Map<String, String>> _buildUserIdMap() async {
    final map = <String, String>{};
    if (_pb == null) return map;

    try {
      // Paginado
      final List<RecordModel> pbUsers = [];
      int page = 1;
      bool hasMore = true;
      while (hasMore) {
        final result = await _withRetry(
          () =>
              _pb!.collection('users').getList(page: page, perPage: _pageSize),
        );
        pbUsers.addAll(result.items);
        hasMore = result.items.length == _pageSize;
        page++;
      }

      final localUsers = await _db.getAllUsuarios();

      for (final local in localUsers) {
        final pbMatch = pbUsers.where((r) =>
            r.getStringValue('email').toLowerCase() ==
            local.email.toLowerCase());
        if (pbMatch.isNotEmpty) {
          final pbId = pbMatch.first.id;
          map[local.uuid] = pbId;
          if (local.uuid != pbId) {
            await _db.remapUsuarioUuid(local.uuid, pbId);
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao construir mapa de IDs: $e');
    }
    return map;
  }

  Future<String?> _getStoredPassword() async {
    return SecureStorageService.read(SecureStorageService.keyCurrentPassword);
  }

  /// Espera o sync anterior terminar.
  ///
  /// Q3 item 2: engole a falha do sync ANTERIOR. Antes, `completeError` no
  /// catch do syncAll transferia a exceção para todo sync que chegasse depois
  /// e ficasse na fila — o "envenenamento" — e o sync novo falhava sem nem ter
  /// começado. Falha do sync anterior é problema dele; o próximo começa limpo.
  Future<void> _waitForSyncLock() async {
    try {
      await _syncLock?.future;
    } catch (_) {
      // falha do sync anterior não invalida o próximo
    }
  }

  /// Sincroniza todas as parcelas pendentes com o servidor.
  /// Agora bidirecional: PUSH local → servidor, depois PULL servidor → local.
  Future<void> syncAll() async {
    // Verifica modo offline forçado
    if (await isForcedOffline) {
      _lastError = 'Sync bloqueada: modo offline forçado ativo.';
      notifyListeners();
      return;
    }

    await _waitForSyncLock();
    _syncLock = Completer<void>();

    if (_pb == null) {
      _lastError =
          'Servidor não configurado. Vá em Configurações e informe a URL.';
      notifyListeners();
      _syncLock!.complete();
      _syncLock = null;
      return;
    }

    if (!await hasInternet()) {
      _lastError = 'Sem conexão com a internet.';
      notifyListeners();
      _syncLock!.complete();
      _syncLock = null;
      return;
    }

    // Tenta auto-autenticar (não bloqueia sync se falhar — PB collections são abertas)
    if (!_pb!.authStore.isValid) {
      final ok = await _tryAutoAuth();
      if (!ok) {
        debugPrint(
            'Auth falhou, mas prosseguindo sync sem auth (collections abertas).');
      }
    }

    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      // ── RC-05: atualiza o offset do relógio antes de gravar qualquer coisa ──
      if (_serverUrl != null) {
        await ClockService.capturarOffsetServidor(_serverUrl!);
      }
      // ── 0. Reconcilia UUIDs de TODOS os usuários locais com PocketBase ──
      await _buildUserIdMap();
      // Recarrega currentUser pois o uuid pode ter mudado
      if (_currentUser != null) {
        final prefs = await SharedPreferences.getInstance();
        final uuid = prefs.getString('current_user_uuid');
        if (uuid != null) {
          _currentUser = await _db.getUsuarioByUuid(uuid);
        }
      }

      // ── 1. PUSH: envia parcelas locais não sincronizadas ──
      final prefs = await SharedPreferences.getInstance();

      List<Parcela> parcelas = await _db.getParcelasNaoSincronizadas();

      // Busca UUIDs de usuários ativos para filtrar dados órfãos
      final usuariosAtivos = await _db.getAllUsuarios();
      final uuidsAtivos = usuariosAtivos.map((u) => u.uuid).toSet();

      // Detectar conflitos antes de sincronizar
      final currentUserId = _currentUser?.uuid;
      if (currentUserId != null) {
        final conflicts = await fetchDetailedConflicts(userId: currentUserId);
        if (conflicts.isNotEmpty) {
          final resolved = <ConflictInfo>[];
          final context = main.navigatorKey.currentContext;
          if (context != null) {
            await _showConflictResolutionDialog(context, conflicts, resolved);
          }
          // Atualizar lista de parcelas baseada nas resoluções
          for (final r in resolved) {
            // Marcar parcela como resolvida localmente
            debugPrint('Conflito resolvido para ${r.parcelaId}: ${r.differingFields}');
          }
        }
      }

      int sincronizados = 0;
      int partialSyncCount = 0;
      final total = parcelas.length;

      // Processa em lotes de 50
      for (int i = 0; i < parcelas.length; i += 50) {
        final lote = parcelas.skip(i).take(50).toList();
        for (final parcela in lote) {
          // Ignora parcelas de usuários que não existem mais (userId vazio = "desistir", envia)
          if (parcela.userId.isNotEmpty &&
              !uuidsAtivos.contains(parcela.userId)) {
            debugPrint('Ignorando parcela órfã ${parcela.uuid}');
            await _db.marcarParcelaSynced(parcela.uuid);
            continue;
          }
          try {
            await _syncParcela(parcela);
            // >>> t16 D-1 (H3): sync MARCA, nunca apaga (RC-03)
            await _db.marcarFotosEnviadasVerificadas(parcela.uuid);
            // RC-04 pós-upload: hash conferido no recheck -> sha256_verificado
            await _db.marcarAtivosVerificadosDaParcela(parcela.uuid);
            // <<< t16 D-1: fim
            sincronizados++;
            _syncProgress = total > 0 ? sincronizados / total : 1.0;
            notifyListeners();
          } catch (e) {
            debugPrint('Erro ao sincronizar parcela ${parcela.uuid}: $e');
            final msg = e.toString();
            if (msg.contains('planta(s) falharam')) {
              _lastError = msg.replaceFirst('Exception: ', '');
              partialSyncCount++;
            } else {
              _lastError =
                  'Falha ao enviar parcela ${parcela.idParcela}. Verifique a conexão e tente novamente.';
            }
          }
        }
      }

      // ── 1b. PUSH da trilha de auditoria (RG-04/RC-05): réplica append-only
      // pro servidor. Falha não bloqueia o sync de parcelas. ──
      try {
        final enviadas = await pushTrilhaAuditoria();
        if (enviadas > 0) debugPrint('Trilha: $enviadas entradas enviadas ao servidor.');
        lastServerChainStatus = await verificarCadeiaServidor();
      } catch (e) {
        debugPrint('Erro ao enviar trilha de auditoria: $e');
      }

      // ── 2. PULL usuários do servidor ──
      try {
        final novosUsuarios = await pullUsuariosDoServidor();
        if (novosUsuarios > 0) {
          debugPrint('Pull: $novosUsuarios novos usuários importados.');
        }
      } catch (e) {
        debugPrint('Erro no pull de usuários: $e');
      }

      // ── 3. PULL de parcelas desativado (catálogo agora é estático/local) ──
      // try {
      //   final importados = await pullDadosDoServidor();
      //   debugPrint('Pull: $importados parcelas importadas do servidor.');
      // } catch (e) {
      //   debugPrint('Erro no pull do servidor: $e');
      // }

      // Salvar timestamp do último sync bem-sucedido
      await prefs.setInt(
          'last_sync_timestamp', DateTime.now().millisecondsSinceEpoch);

      await _updatePendingCount();
    } catch (e) {
      _lastError =
          'Falha na sincronização. Verifique a conexão e tente novamente.';
      debugPrint('Erro na sincronização: $e');
      // Q3 item 2: completa o lock SEM erro — o waiter pega o estado limpo e
      // o erro já está em _lastError para a UI mostrar. Sem rethrow: quem
      // chama não precisa (e antes não tinha) try/catch em 4 telas.
      if (_syncLock != null) {
        _syncLock!.complete();
        _syncLock = null;
      }
    } finally {
      _isSyncing = false;
      _syncProgress = 0.0;
      if (_syncLock != null) {
        _syncLock!.complete();
        _syncLock = null;
      }
      notifyListeners();
    }
  }

  /// Baixa usuários do PocketBase para o banco local (inclui usuários de outros dispositivos).
  /// Retorna quantidade de novos usuários importados.
  /// Também ATUALIZA nomes de usuários existentes que parecem hashes (IDs do PB).
  Future<int> pullUsuariosDoServidor() async {
    if (_pb == null) return 0;
    if (!_pb!.authStore.isValid) {
      final ok = await _tryAutoAuth();
      if (!ok) {
        debugPrint('pullUsuariosDoServidor: _tryAutoAuth falhou, abortando');
        return 0;
      }
    }
    try {
      // Paginado
      final List<RecordModel> registros = [];
      int page = 1;
      bool hasMore = true;
      while (hasMore) {
        final result = await _withRetry(
          () =>
              _pb!.collection('users').getList(page: page, perPage: _pageSize),
        );
        registros.addAll(result.items);
        hasMore = result.items.length == _pageSize;
        page++;
      }

      debugPrint(
          'pullUsuariosDoServidor: ${registros.length} usuários encontrados no PB');

      int novos = 0;
      int atualizados = 0;
      for (final rec in registros) {
        final email = rec.getStringValue('email');
        final nome = rec.getStringValue('name');
        if (email.isEmpty) continue;

        final serverId = rec.id;
        final nomeReal = nome.isNotEmpty ? nome : email.split('@').first;
        debugPrint('PB User: id=$serverId, email=$email, name=$nomeReal');

        // Busca usuário existente por EMAIL ou UUID
        var existing = await _db.getUsuarioByEmail(email);
        existing ??= await _db.getUsuarioByUuid(serverId);

        if (existing != null) {
          // Usuário já existe. Verifica se precisa atualizar
          bool needsUpdate = false;
          final updates = <dynamic, dynamic>{};

          debugPrint(
              '  Existente: nome="${existing.nome}", email="${existing.email}"');

          // Nome precisa atualizar se:
          // - é igual ao serverId (hash do PB)
          // - contém "@imported"
          // - parece um ID PB (15 chars alfanuméricos sem espaço)
          // - é diferente do nome real e é muito curto/sem espaço (fallback heurístico)
          final nomeAtual = existing.nome;
          final nomeParecePbId = RegExp(r'^[a-z0-9]{15}$').hasMatch(nomeAtual);
          final nomeNaoBate = nomeAtual != nomeReal && nomeReal.isNotEmpty;
          if (nomeAtual == serverId ||
              nomeAtual.contains('@imported') ||
              nomeParecePbId ||
              (nomeNaoBate && nomeAtual == existing.uuid)) {
            updates['nome'] = nomeReal;
            needsUpdate = true;
            debugPrint('  → Atualizando nome: $nomeAtual → $nomeReal');
          }

          // Email precisa atualizar se é placeholder
          final emailAtual = existing.email;
          if (emailAtual != email &&
              (emailAtual.contains('@imported') ||
                  RegExp(r'^[a-z0-9]{15}@').hasMatch(emailAtual))) {
            updates['email'] = email;
            needsUpdate = true;
            debugPrint(' → Atualizando email: $emailAtual → $email');
          }

          final serverIsAdmin = rec.getBoolValue('isAdmin');
          if (existing.isAdmin != serverIsAdmin) {
            updates['isAdmin'] = serverIsAdmin;
            needsUpdate = true;
            debugPrint(
                ' → Atualizando isAdmin: ${existing.isAdmin} → $serverIsAdmin');
          }

          if (needsUpdate) {
            try {
              await _db.updateUsuario(
                UsuariosCompanion(
                  nome: updates.containsKey('nome')
                      ? Value(updates['nome'] as String)
                      : const Value.absent(),
                  email: updates.containsKey('email')
                      ? Value(updates['email'] as String)
                      : const Value.absent(),
                  isAdmin: updates.containsKey('isAdmin')
                      ? Value(updates['isAdmin'] as bool)
                      : const Value.absent(),
                ),
                existing.uuid,
              );
              atualizados++;
              debugPrint('  ✓ Atualização bem-sucedida no banco');
            } catch (e) {
              debugPrint('  ✗ Erro ao atualizar no banco: $e');
            }
          }
          continue;
        }

        // Novo usuário — insere (ou atualiza se já existe por uuid, ex.: criado noutro fluxo)
        final jaExistePorUuid = await _db.getUsuarioByUuid(serverId);
        if (jaExistePorUuid != null) {
          final serverIsAdmin = rec.getBoolValue('isAdmin');
          bool needsUpdate = jaExistePorUuid.nome != nomeReal ||
              jaExistePorUuid.email != email ||
              jaExistePorUuid.isAdmin != serverIsAdmin;
          if (needsUpdate) {
            await _db.updateUsuario(
              UsuariosCompanion(
                nome: Value(nomeReal),
                email: Value(email),
                isAdmin: Value(serverIsAdmin),
              ),
              serverId,
            );
            atualizados++;
          }
          continue;
        }
        final serverIsAdmin = rec.getBoolValue('isAdmin');
        await _db.insertUsuarioRaw(UsuariosCompanion.insert(
          uuid: serverId,
          nome: nomeReal,
          email: email,
          senha: PasswordService.generateServerPlaceholder(),
          isAdmin: Value(serverIsAdmin),
        ));
        novos++;
        debugPrint('  ✓ Novo usuário inserido: $email → nome=$nomeReal');
      }
      debugPrint(
          'pullUsuariosDoServidor: $novos novos usuários, $atualizados atualizados');
      return novos;
    } catch (e) {
      debugPrint('Erro ao puxar usuários do servidor: $e');
      return 0;
    }
  }

  /// Detecta se o servidor usa schema normalizado (parcelas.ut → uts → propriedades).
  bool _isNormalizedSchema(RecordModel rec) {
    try {
      final exp = rec.expand;
      if (exp == null) return false;
      final ut = exp['ut'];
      final utProp = exp['ut.propriedade'];
      return ut != null && utProp != null;
    } catch (_) {
      return false;
    }
  }

  /// Nome legível de um registro expandido (propriedade/UT).
  ///
  /// O schema do servidor (migrations 1776862933_created_propriedades.js e
  /// 1776862934_created_uts.js) usa `codigo` como chave/identificador e
  /// `nome` como rótulo. O painel urutau-admin exibe `codigo`
  /// (src/pages/Parcels.jsx:482,504). Por isso `codigo` vem primeiro;
  /// `name`/`nome` ficam só como fallback para schemas antigos.
  static String _expandName(dynamic o) {
    if (o == null) return '';
    if (o is RecordModel) {
      final codigo = o.getStringValue('codigo');
      if (codigo.isNotEmpty) return codigo;
      final nome = o.getStringValue('nome');
      if (nome.isNotEmpty) return nome;
      return o.getStringValue('name');
    }
    if (o is Map) {
      for (final k in const ['codigo', 'nome', 'name']) {
        final v = o[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
    }
    return '';
  }

  /// Extrai propriedade e UT de um registro: schema normalizado (expand) ou flat (campos texto).
  void _parseParcelaHierarchy(
      RecordModel rec, List<String> outProp, List<String> outUt) {
    if (_isNormalizedSchema(rec) && rec.expand != null) {
      final propRec = rec.expand!['ut.propriedade'];
      final utRec = rec.expand!['ut'];
      outProp.add(_expandName(propRec));
      outUt.add(_expandName(utRec));
      return;
    }
    String prop = rec.getStringValue('propriedade');
    String ut = rec.getStringValue('prop_ut');
    if (prop.isEmpty && ut.contains(' - ')) {
      final parts = ut.split(' - ');
      prop = parts.first.trim();
      ut = parts.length > 1 ? parts.sublist(1).join(' - ').trim() : ut;
    }
    if (_looksLikeUt(prop)) {
      if (ut.isEmpty) ut = prop;
      prop = 'Sem propriedade';
    }
    outProp.add(prop);
    outUt.add(ut);
  }

  /// Baixa parcelas do servidor PocketBase para o banco local.
  /// Usa upsert: atualiza existentes, insere novas. Nunca apaga dados locais.
  /// Se a internet cair durante o download, aborta sem perder dados existentes.
  Future<int> pullDadosDoServidor({String? userId}) async {
    if (_pb == null) return 0;

    try {
      String filter = '';
      if (userId != null && userId.isNotEmpty) {
        filter = 'user = "$userId"';
      }

      // 1. Detectar schema (normalizado vs flat)
      bool useExpand = true;
      try {
        final first = await _withRetry(
          () => _pb!.collection('parcelas').getList(
                page: 1,
                perPage: 1,
                filter: filter.isNotEmpty ? filter : null,
                expand: 'ut,ut.propriedade',
              ),
        );
        if (first.items.isEmpty) return 0;
        if (!_isNormalizedSchema(first.items.first)) useExpand = false;
      } catch (_) {
        useExpand = false;
      }

      // 2. Baixar TODAS as parcelas do servidor antes de processar
      //    Se a conexão cair no meio, aborta e mantém dados locais intactos.
      final List<RecordModel> parcelasServidor = [];
      int page = 1;
      bool hasMore = true;
      while (hasMore) {
        if (!await hasInternet()) {
          _lastError = 'Conexão perdida durante download. Tente novamente.';
          notifyListeners();
          return 0;
        }
        final result = await _withRetry(
          () => _pb!.collection('parcelas').getList(
                page: page,
                perPage: _pageSize,
                filter: filter.isNotEmpty ? filter : null,
                expand: useExpand ? 'ut,ut.propriedade' : null,
              ),
        );
        parcelasServidor.addAll(result.items);
        hasMore = result.items.length == _pageSize;
        page++;
      }

      if (parcelasServidor.isEmpty) return 0;

      // 3. Processar com upsert (insert ou update, sem deletar dados locais)
      int importados = 0;

      for (final rec in parcelasServidor) {
        final serverUser = rec.getStringValue('user');
        final outProp = <String>[], outUt = <String>[];
        _parseParcelaHierarchy(rec, outProp, outUt);
        final propriedade = outProp.isNotEmpty ? outProp.first : '';
        final propUt = outUt.isNotEmpty ? outUt.first : '';
        final idParcela = rec.getIntValue('id_parcela');
        var areaHa = rec.getDoubleValue('area_ha');
        final obs = rec.getStringValue('observacoes');
        var cleanObs = obs;
        if (areaHa == 0 && obs.startsWith('area_ha:')) {
          final afterPrefix = obs.substring(8);
          final match = RegExp(r'^\s*([\d.]+)').firstMatch(afterPrefix);
          if (match != null) {
            areaHa = double.tryParse(match.group(1)!) ?? 0;
            final rest = afterPrefix.substring(match.end).trim();
            cleanObs = rest.isEmpty ? '' : rest;
          }
        }

        final parcelaUuid = 'pb-${rec.id}';

        // A) Já existe por UUID → atualizar campos do servidor (se não foi editada localmente)
        final existing = await _db.getParcelaByUuid(parcelaUuid);
        if (existing != null) {
          if (existing.synced) {
            // Campos MRV vindos do servidor (RC-10/RS-01/RS-02/RG-02)
            final lat = rec.data['latitude'];
            final lon = rec.data['longitude'];
            final areaM2 = rec.data['area_m2'];
            final raio = rec.data['raio_m'];
            final statusVer = rec.getStringValue('status_verificacao');
            await _db.updateParcela(
              ParcelasCompanion(
                propriedade: Value(propriedade),
                propUt: Value(propUt),
                userId: Value(serverUser),
                areaHa: Value(areaHa != 0 ? areaHa : null),
                observacoes: Value(cleanObs.isNotEmpty ? cleanObs : null),
                latitude: Value(lat is num ? lat.toDouble() : null),
                longitude: Value(lon is num ? lon.toDouble() : null),
                geoJson: Value(rec.getStringValue('geo_json').isNotEmpty
                    ? rec.getStringValue('geo_json')
                    : null),
                areaM2: Value(areaM2 is num ? areaM2.toDouble() : null),
                unidadeForma: Value(
                    rec.getStringValue('unidade_forma').isNotEmpty
                        ? rec.getStringValue('unidade_forma')
                        : null),
                raioM: Value(raio is num ? raio.toDouble() : null),
                marcador: Value(rec.getStringValue('marcador').isNotEmpty
                    ? rec.getStringValue('marcador')
                    : null),
                statusParcela: Value(statusVer.isNotEmpty ? statusVer : null),
                // RT-01/RC-11: devolve projeto/período/protocolo do servidor
                projetoUuid: Value((rec.data['projeto_id'] as String?)?.isNotEmpty == true
                    ? rec.data['projeto_id'] as String
                    : null),
                periodoUuid: Value((rec.data['periodo_id'] as String?)?.isNotEmpty == true
                    ? rec.data['periodo_id'] as String
                    : null),
                protocoloVersao: Value(
                    (rec.data['protocolo_versao'] as String?)?.isNotEmpty == true
                        ? rec.data['protocolo_versao'] as String
                        : null),
              ),
              parcelaUuid,
            );
            // v28 MRV: aplica metadados das fotos vindos do servidor
            await _aplicarFotosMetaDoServidor(
                parcelaUuid, rec.getStringValue('fotos_meta'));
          }
          if (existing.deletedAt != null) {
            // Q3 item 6: soft-delete LOCAL tem precedência sobre o servidor.
            // Antes este ramo RESSUSCITAVA a parcela (restaurarParcela) em
            // todo pull — a deleção offline nunca venciava. Agora: propaga o
            // delete para o servidor e mantém a parcela morta localmente.
            try {
              await _pb!.collection('parcelas').delete(rec.id);
              debugPrint('Parcela $parcelaUuid: deletada localmente — '
                  'delete propagado ao servidor no pull');
            } catch (e) {
              debugPrint('Aviso: falha ao propagar delete no pull: $e');
            }
          }
          continue;
        }

        // B) Duplicata por conteúdo → remapear UUID
        final dup =
            await _db.findParcelaDuplicada(propUt, idParcela, serverUser);
        if (dup != null) {
          if (!dup.uuid.startsWith('pb-')) {
            try {
              await _db.remapParcelaUuid(dup.uuid, parcelaUuid);
              await _db.marcarParcelaSynced(parcelaUuid);
              await _db.restaurarParcela(parcelaUuid);
            } catch (e) {
              debugPrint('Erro ao remapear parcela duplicada: $e');
            }
          }
          continue;
        }

        // C) Garantir que o dono da parcela existe localmente (upsert: não inserir se já existe por uuid)
        if (serverUser.isNotEmpty) {
          var usuario = await _db.getUsuarioByUuid(serverUser);
          if (usuario == null) {
            usuario = await _db.getUsuarioByEmail('$serverUser@imported.local');
            if (usuario != null) {
              await _db.remapUsuarioUuid(usuario.uuid, serverUser);
            } else {
              await _db.insertUsuarioRaw(UsuariosCompanion.insert(
                uuid: serverUser,
                nome: serverUser,
                email: '$serverUser@imported.local',
                senha: PasswordService.generateServerPlaceholder(),
              ));
            }
          }
        }

        // Q3 item 6 (parte 2): chave natural já existe LOCALMENTE como
        // soft-delete — inserir criaria duplicata ressuscitada. Propaga o
        // delete ao servidor e não reinsere.
        final localDeletado =
            await _db.findParcelaDeletadaPorChave(propriedade, propUt, idParcela);
        if (localDeletado != null) {
          try {
            await _pb!.collection('parcelas').delete(rec.id);
            debugPrint('Parcela ${localDeletado.uuid}: deletada localmente — '
                'delete propagado ao servidor no pull (insert evitado)');
          } catch (e) {
            debugPrint('Aviso: falha ao propagar delete no pull: $e');
          }
          continue;
        }

        // D) Inserir nova parcela
        DateTime createdAt;
        try {
          createdAt = DateTime.parse(rec.created);
        } catch (_) {
          createdAt = DateTime.now();
        }

        final lat = rec.data['latitude'];
        final lon = rec.data['longitude'];
        final areaM2 = rec.data['area_m2'];
        final raio = rec.data['raio_m'];
        final statusVer = rec.getStringValue('status_verificacao');
        await _db.insertParcela(ParcelasCompanion.insert(
          uuid: parcelaUuid,
          propriedade: Value(propriedade.isNotEmpty ? propriedade : ''),
          propUt: propUt,
          idParcela: idParcela,
          areaHa: Value(areaHa != 0 ? areaHa : null),
          userId: serverUser,
          observacoes: Value(cleanObs.isNotEmpty ? cleanObs : null),
          synced: const Value(true),
          createdAt: Value(createdAt),
          updatedAt: Value(createdAt),
          // campos MRV vindos do servidor
          latitude: Value(lat is num ? lat.toDouble() : null),
          longitude: Value(lon is num ? lon.toDouble() : null),
          geoJson: Value(rec.getStringValue('geo_json').isNotEmpty
              ? rec.getStringValue('geo_json')
              : null),
          areaM2: Value(areaM2 is num ? areaM2.toDouble() : null),
          unidadeForma: Value(rec.getStringValue('unidade_forma').isNotEmpty
              ? rec.getStringValue('unidade_forma')
              : null),
          raioM: Value(raio is num ? raio.toDouble() : null),
          marcador: Value(rec.getStringValue('marcador').isNotEmpty
              ? rec.getStringValue('marcador')
              : null),
          statusParcela: Value(statusVer.isNotEmpty ? statusVer : 'pendente'),
        ));
        importados++;
      }

      // 4. Renumerar parcelas dentro de cada UT para 1, 2, 3...
      await _renumerarParcelasLocal();

      return importados;
    } catch (e) {
      debugPrint('Erro ao puxar dados do servidor: $e');
      return 0;
    }
  }

  /// Renumera parcelas dentro de cada UT para 1, 2, 3...
  /// Corrige numeração não-sequencial vinda do servidor.
  ///
  /// Q3 item 7: a renumeração também (re)deriva parcela_id_text — se a chave
  /// fosse calculada só no insert, a renumeração a invalidaria. Aqui ela é
  /// mantida consistente com o idParcela final.
  Future<void> _renumerarParcelasLocal() async {
    final talhoes = await _db.getAllTalhoes();
    for (final ut in talhoes) {
      final parcelas = await _db.getParcelasByHierarchy(propUt: ut);
      for (int i = 0; i < parcelas.length; i++) {
        final expected = i + 1;
        final expectedText = '$ut-P$expected';
        if (parcelas[i].idParcela != expected ||
            parcelas[i].parcelaIdText != expectedText) {
          await _db.updateParcela(
            ParcelasCompanion(
              idParcela: Value(expected),
              parcelaIdText: Value(expectedText),
            ),
            parcelas[i].uuid,
          );
        }
      }
    }
  }

  /// Busca parcelas que já foram feitas no servidor (user preenchido).
  /// Não grava no banco local — só para consulta.
  Future<List<Map<String, String>>> fetchParcelasFeitasDoServidor() async {
    if (_pb == null) return [];
    try {
      bool useExpand = true;
      try {
        final first = await _pb!.collection('parcelas').getList(perPage: 1);
        if (first.items.isEmpty) return [];
        if (!_isNormalizedSchema(first.items.first)) useExpand = false;
      } catch (_) {
        useExpand = false;
      }
      final recs = <RecordModel>[];
      int page = 1;
      while (true) {
        if (!await hasInternet()) break;
        final r = await _withRetry(() => _pb!.collection('parcelas').getList(
              page: page,
              perPage: _pageSize,
              filter: 'user != ""',
              expand: useExpand ? 'ut,ut.propriedade' : null,
            ));
        recs.addAll(r.items);
        if (r.items.length < _pageSize) break;
        page++;
      }
      return recs.map(_toParcelaInfo).toList();
    } catch (e) {
      debugPrint('fetchParcelasFeitasDoServidor: $e');
      return [];
    }
  }

  Map<String, String> _toParcelaInfo(RecordModel rec) {
    final prop = <String>[], ut = <String>[];
    _parseParcelaHierarchy(rec, prop, ut);
    return {
      'propriedade': prop.isNotEmpty ? prop.first : '',
      'propUt': ut.isNotEmpty ? ut.first : '',
      'idParcela': rec.getIntValue('id_parcela').toString(),
      'user': rec.getStringValue('user'),
    };
  }

  /// Chave única para (propriedade, UT, idParcela).
  static String parcelaKey(Parcela p) =>
      '${p.propriedade}|${p.propUt}|${p.idParcela}';

  /// Verifica conflitos: mesma (propriedade, UT, parcela) no servidor com outro utilizador.
  /// Retorna mensagens e o conjunto de chaves em conflito (para bloquear envio).
  Future<({List<String> messages, Set<String> conflictKeys})> fetchConflitos(
      {String? userId}) async {
    const empty = (messages: <String>[], conflictKeys: <String>{});
    if (_pb == null || userId == null) return empty;
    try {
      final locais = await _db.getParcelasNaoSincronizadas(userId: userId);
      if (locais.isEmpty) return empty;

      // Build filter to only fetch matching parcelas from server
      final keys = locais.map(parcelaKey).toSet();
      final serverList = await _fetchServerParcelasByKeys(keys);
      
      final serverKeyToUser = <String, String>{};
      for (final m in serverList) {
        final key =
            '${m['propriedade'] ?? ''}|${m['propUt'] ?? ''}|${m['idParcela'] ?? ''}';
        final u = m['user'] ?? '';
        if (u.isNotEmpty) serverKeyToUser[key] = u;
      }
      
      final messages = <String>[];
      final conflictKeys = <String>{};
      for (final p in locais) {
        final key = parcelaKey(p);
        final serverUser = serverKeyToUser[key];
        if (serverUser != null && serverUser != userId) {
          conflictKeys.add(key);
          messages.add(
              '${p.propriedade} · ${p.propUt} · Parcela ${p.idParcela}: outro utilizador no servidor.');
        }
      }
      return (messages: messages, conflictKeys: conflictKeys);
    } catch (e) {
      debugPrint('fetchConflitos: $e');
      return empty;
    }
  }

  /// Fetches parcelas from server matching the given keys only.
  Future<List<Map<String, dynamic>>> _fetchServerParcelasByKeys(Set<String> keys) async {
    if (_pb == null || keys.isEmpty) return [];

    try {
      // A coleção parcelas NÃO tem campo `propriedade` (só `prop_ut` text e a
      // relation `ut`). Filtrar por `propriedade` dava 400 "Something went
      // wrong" e a detecção de conflito morria silenciosamente (catch → []).
      // Filtra por prop_ut + id_parcela, que existem e identificam a parcela.
      final filterParts = keys.map((k) {
        final parts = k.split('|');
        if (parts.length != 3) return null;
        final utEsc = parts[1].replaceAll('"', '\\"');
        return '(prop_ut = "$utEsc" && id_parcela = ${parts[2]})';
      }).where((s) => s != null).join(' || ');

      if (filterParts.isEmpty) return [];

      final result = await _withRetry(() => _pb!.collection('parcelas').getList(
        filter: filterParts,
        perPage: keys.length + 10,
      ));
      return result.items.map((r) => {
        'propriedade': _expandName(r.expand?['ut.propriedade']),
        'propUt': _expandName(r.expand?['ut']),
        'idParcela': r.getIntValue('id_parcela'),
        'user': r.getStringValue('user'),
      }).toList();
    } catch (e) {
      debugPrint('_fetchServerParcelasByKeys: $e');
      return [];
    }
  }

  /// Busca conflitos detalhados com diff campo a campo.
  /// Retorna lista de ConflictInfo para mostrar na UI de resolução.
  Future<List<ConflictInfo>> fetchDetailedConflicts({String? userId}) async {
    if (_pb == null || userId == null) return [];

    try {
      final locais = await _db.getParcelasNaoSincronizadas(userId: userId);
      if (locais.isEmpty) return [];

      // Fetch only matching parcelas from server
      final keys = locais.map(parcelaKey).toSet();
      final serverList = await _fetchServerParcelasByKeys(keys);
      
      final serverKeyToRec = <String, Map<String, dynamic>>{};
      for (final m in serverList) {
        final key =
            '${m['propriedade'] ?? ''}|${m['propUt'] ?? ''}|${m['idParcela'] ?? ''}';
        final u = m['user'] ?? '';
        if (u.isNotEmpty && u != userId) {
          serverKeyToRec[key] = {
            'propriedade': m['propriedade'] ?? '',
            'propUt': m['propUt'] ?? '',
            'idParcela': m['idParcela'] ?? 0,
            'areaHa': m['areaHa'],
            'observacoes': m['observacoes'] ?? '',
            'synced': true,
            'user': u,
          };
        }
      }

      final conflicts = <ConflictInfo>[];

      for (final p in locais) {
        final key = parcelaKey(p);
        final serverRec = serverKeyToRec[key];
        if (serverRec != null) {
          final conflict = ConflictInfo.fromSyncComparison(p, serverRec);
          if (conflict != null) {
            conflicts.add(conflict);
          }
        }
      }

      return conflicts;
    } catch (e) {
      debugPrint('fetchDetailedConflicts: $e');
      return [];
    }
  }

  Future<void> _showConflictResolutionDialog(
      BuildContext context, List<ConflictInfo> conflicts, List<ConflictInfo> resolved) async {
    final completer = Completer<void>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ConflictResolutionDialog(
        conflicts: conflicts,
        onResolve: (conflict, resolution) {
          resolved.add(conflict.copyWith(resolution: resolution));
        },
      ),
    );
    completer.complete();
    return completer.future;
  }

  /// Envia apenas as parcelas cujos UUIDs estão em [uuids].
  /// Usado pela UI de sync com seleção (checkboxes).
  Future<({int sent, int conflictsBlocked})> syncSelected({
    required Set<String> uuids,
    required Set<String> conflictKeys,
    String? userId,
  }) async {
    // Verifica modo offline forçado
    if (await isForcedOffline) {
      _lastError = 'Sync bloqueada: modo offline forçado ativo.';
      notifyListeners();
      return (sent: 0, conflictsBlocked: 0);
    }

    await _waitForSyncLock();
    _syncLock = Completer<void>();

    if (_pb == null) {
      _syncLock!.complete();
      _syncLock = null;
      return (sent: 0, conflictsBlocked: 0);
    }
    if (!await hasInternet()) {
      _lastError = 'Sem conexão com a internet.';
      notifyListeners();
      _syncLock!.complete();
      _syncLock = null;
      return (sent: 0, conflictsBlocked: 0);
    }
    if (!_pb!.authStore.isValid) {
      await _tryAutoAuth();
    }
    _isSyncing = true;
    _lastError = null;
    notifyListeners();
    int sent = 0;
    int conflictsBlocked = 0;
    try {
      await _buildUserIdMap();
      final parcelas = await _db.getParcelasNaoSincronizadas(userId: userId);
      final toSync = parcelas.where((p) => uuids.contains(p.uuid)).toList();
      for (final p in toSync) {
        final key = parcelaKey(p);
        if (conflictKeys.contains(key)) {
          conflictsBlocked++;
          continue;
        }
        try {
          await _syncParcela(p);
          // >>> t16 D-1 (H3): sync MARCA, nunca apaga (RC-03)
          await _db.marcarFotosEnviadasVerificadas(p.uuid);
          // RC-04 pós-upload: sha256_verificado nos ativos da parcela
          await _db.marcarAtivosVerificadosDaParcela(p.uuid);
          // <<< t16 D-1: fim
          sent++;
          notifyListeners();
        } catch (e) {
          debugPrint('Erro ao sincronizar ${p.uuid}: $e');
          _lastError = 'Falha ao enviar parcela ${p.idParcela}.';
        }
      }
      await _updatePendingCount();

    } catch (e) {
      // Q3 item 2: mesma semântica do syncAll — completa limpo e sem rethrow.
      debugPrint('Erro na sincronização selecionada: $e');
      if (_syncLock != null) {
        _syncLock!.complete();
        _syncLock = null;
      }
    } finally {
      _isSyncing = false;
      if (_syncLock != null) {
        _syncLock!.complete();
        _syncLock = null;
      }
      notifyListeners();
    }
    return (sent: sent, conflictsBlocked: conflictsBlocked);
  }

  /// Garante que o catálogo local exista.
  /// O catálogo é estático (embutido no app via CSV) — não requer internet.
  Future<bool> ensureCatalogSeeded({bool force = false}) async {
    try {
      final props = await _db.getAllPropriedades(isAdmin: true);
      if (props.isNotEmpty && !force) return true;

      // O catálogo é populado automaticamente pelo database.dart (_seedCatalogoEstatico)
      // Forçar re-seed se necessário: limpar parcelas seed e reabrir o DB fará o seed rodar novamente.
      return true;
    } catch (e) {
      debugPrint('ensureCatalogSeeded falhou: $e');
      return false;
    }
  }

  /// Gera nome padronizado para foto de parcela.
  /// Ex: FazSaoJoao-UT01_P05_FotoParcela01_2026-02-18_14h30.jpg
  String _gerarNomeFotoParcela(Parcela parcela, int index) {
    final propUt = _sanitizeFileName(parcela.propUt);
    final dt = parcela.createdAt;
    final data =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    final hora =
        '${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';
    return '${propUt}_P${parcela.idParcela.toString().padLeft(2, '0')}_FotoParcela${(index + 1).toString().padLeft(2, '0')}_${data}_$hora.jpg';
  }

  /// Gera nome padronizado para foto de planta.
  /// Ex: FazSaoJoao-UT01_P05_Planta03_C2_2026-02-18_14h30.jpg
  String _gerarNomeFotoPlanta(Parcela parcela, Planta planta, int index) {
    final propUt = _sanitizeFileName(parcela.propUt);
    final dt = planta.createdAt;
    final data =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    final hora =
        '${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';
    return '${propUt}_P${parcela.idParcela.toString().padLeft(2, '0')}_Planta${(index + 1).toString().padLeft(2, '0')}_C${planta.categoria}_${data}_$hora.jpg';
  }

  /// v28 MRV: JSON com os metadados de cada foto da parcela
  /// (uuid, nome, sha256, lat/long, autor, timestamp) — o pitch promete
  /// "cada foto recebe hash SHA-256, GPS, timestamp e dono"; isso sobe
  /// junto com a parcela pra o auditor refazer a conta.
  Future<String> _fotosMetaJson(String parcelaUuid) async {
    final fotos = await _db.getFotosByParcela(parcelaUuid);
    final lista = <Map<String, dynamic>>[];
    for (final f in fotos) {
      final hash = await _db.hashDoAtivoDaFoto(f.uuid);
      lista.add({
        'uuid': f.uuid,
        'arquivo': f.filePath.split(RegExp(r'[\\/]')).last,
        'sha256': hash,
        'latitude': f.latitude,
        'longitude': f.longitude,
        'autor': f.autorUuid,
        'capturada_em': f.createdAt.toIso8601String(),
      });
    }
    return jsonEncode(lista);
  }

  /// v28 MRV: aplica no banco local o fotos_meta vindo do servidor
  /// (atualiza GPS/dono das fotos PELOS dados do servidor, sem apagar hash).
  Future<void> _aplicarFotosMetaDoServidor(
      String parcelaUuid, String fotosMetaJson) async {
    if (fotosMetaJson.trim().isEmpty) return;
    try {
      final lista = jsonDecode(fotosMetaJson);
      if (lista is! List) return;
      for (final item in lista) {
        if (item is! Map) continue;
        final uuid = item['uuid']?.toString();
        if (uuid == null || uuid.isEmpty) continue;
        final lat = item['latitude'];
        final lon = item['longitude'];
        final autor = item['autor']?.toString();
        await _db.updateFotoParcelaCampos(
          uuid,
          latitude: lat is num ? lat.toDouble() : null,
          longitude: lon is num ? lon.toDouble() : null,
          autorUuid: (autor != null && autor.isNotEmpty) ? autor : null,
        );
      }
    } catch (e) {
      debugPrint('fotos_meta inválido vindo do servidor: $e');
    }
  }

  /// Remove caracteres especiais de nomes de arquivo.
  String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
  }

   /// Normaliza o status local para os valores que o select
   /// `status_verificacao` aceita no servidor.
   ///
   /// O default do banco local é 'ativa' (legado) e o wizard já tratava
   /// 'ativa' como 'pendente' (parcela_form_screen.dart:284-290). Sem esta
   /// normalização o push mandava 'ativa' e o servidor respondia 400.
   static String _statusVerificacaoParaServidor(String? status) {
     switch (status) {
       case 'revisado':
       case 'aprovado':
         return status!;
       default:
         // 'pendente', 'ativa', null, ou qualquer valor desconhecido
         return 'pendente';
     }
   }

   /// Schema normalizado: obtém ou cria propriedade por nome; retorna id ou null se coleção não existir.
   ///
   /// Contrato do schema (1776862933_created_propriedades.js): `codigo` é TEXT
   /// **required**, `nome` é TEXT opcional. Enviar `name` dava 400
   /// ("Cannot be blank" em codigo + campo inexistente) e o catch engolia o
   /// erro, derrubando o push da parcela inteira.
   ///
   /// CUIDADO com o filtro: PocketBase valida TODOS os campos do filter e
   /// devolve 400 se algum não existir na coleção. `name` NÃO existe aqui —
   /// por isso o filtro usa só `codigo` e `nome`.
   Future<String?> _getOrCreatePropriedadeId(String name) async {
     if (name.isEmpty) return null;
     final escaped = name.replaceAll('"', '\\"');
     final filter = '(codigo = "$escaped" || nome = "$escaped")';
     try {
       final list = await _pb!.collection('propriedades').getList(
             page: 1,
             perPage: 1,
             filter: filter,
           );
       if (list.items.isNotEmpty) return list.items.first.id;
       try {
         final created = await _pb!.collection('propriedades').create(body: {
           'codigo': name,
           'nome': name,
         });
         return created.id;
       } catch (_) {
         final retry = await _pb!.collection('propriedades').getList(
               page: 1, perPage: 1,
               filter: filter,
             );
         if (retry.items.isNotEmpty) {
           // Log dedup event
           await _db.logAudit('dedup_propriedade',
               entityType: 'propriedade',
               details: 'Concurrent create detected, reused existing: $name',
               newValue: 'deduplicated');
           return retry.items.first.id;
         }
         return null;
       }
     } catch (_) {
       return null;
     }
   }

   /// Schema normalizado: obtém ou cria UT por (propriedadeId, nome UT); retorna id ou null.
   ///
   /// Contrato do schema (1776862934_created_uts.js): `codigo` é TEXT
   /// **required** e a coleção NÃO tem campo `nome`/`name` — só `codigo` e a
   /// relation `propriedade`. Enviar `name` dava 400.
   ///
   /// Mesma restrição de filtro: só `codigo` (e `propriedade`).
   Future<String?> _getOrCreateUtId(String propriedadeId, String utName) async {
     if (propriedadeId.isEmpty || utName.isEmpty) return null;
     final escaped = utName.replaceAll('"', '\\"');
     final filter = 'codigo = "$escaped" && propriedade = "$propriedadeId"';
     try {
       final list = await _pb!.collection('uts').getList(
             page: 1,
             perPage: 1,
             filter: filter,
           );
       if (list.items.isNotEmpty) return list.items.first.id;
       try {
         final created = await _pb!.collection('uts').create(body: {
           'codigo': utName,
           'propriedade': propriedadeId,
         });
         return created.id;
       } catch (_) {
         final retry = await _pb!.collection('uts').getList(
               page: 1, perPage: 1,
               filter: filter,
             );
         if (retry.items.isNotEmpty) {
           // Log dedup event
           await _db.logAudit('dedup_ut',
               entityType: 'ut',
               details: 'Concurrent create detected, reused existing: $utName',
               newValue: 'deduplicated');
           return retry.items.first.id;
         }
         return null;
       }
     } catch (_) {
       return null;
     }
   }

  /// Sincroniza uma parcela pelo UUID.
  /// Público para uso em operações em lote.
  ///
  /// Q3 item 3: antes este caminho NÃO tinha os guards do canônico — sem
  /// lock (dois syncs podiam correr concorrentes na mesma parcela; com o
  /// delete+recreate do motor de plantas, isso é corrupção de servidor) e sem
  /// a checagem de modo offline forçado que syncAll/syncSelected têm. Continua
  /// lançando exceção nas falhas — os callers em lote contam falha por parcela.
  Future<void> syncSingleParcela(String parcelaUuid) async {
    final parcela = await _db.getParcelaByUuid(parcelaUuid);
    if (parcela == null) {
      throw Exception('Parcela não encontrada: $parcelaUuid');
    }

    if (_pb == null) {
      throw Exception('Servidor não configurado');
    }

    if (await isForcedOffline) {
      throw Exception('Sync bloqueada: modo offline forçado ativo.');
    }

    if (!await hasInternet()) {
      throw Exception('Sem conexão com a internet');
    }

    // Mesma serialização do syncAll: espera o sync em curso e ocupa o lock.
    await _waitForSyncLock();
    _syncLock = Completer<void>();
    try {
      await _syncParcela(parcela);
    } finally {
      if (_syncLock != null) {
        _syncLock!.complete();
        _syncLock = null;
      }
    }
  }

  /// Apaga uma parcela (soft delete local + tentativa no servidor).
  /// Público para uso em operações em lote.
  Future<void> deleteParcela(String parcelaUuid) async {
    // Apagar no servidor se já estiver sincronizada
    if (parcelaUuid.startsWith('pb-')) {
      await deleteParcelaNoServidor(parcelaUuid);
    }
  }

  /// Sincroniza uma parcela individual.
  /// Preferência: schema normalizado (ut → uts → propriedades); fallback: flat (propriedade/prop_ut texto).
  Future<void> _syncParcela(Parcela parcela) async {
    final propUtValido = parcela.propUt.trim().isEmpty
        ? 'Sem_Identificacao'
        : parcela.propUt.trim();
    final propName = parcela.propriedade.trim().isEmpty
        ? 'Sem propriedade'
        : parcela.propriedade.trim();

    Map<String, dynamic> parcelaBody;
    final propId = await _getOrCreatePropriedadeId(propName);
    final utId =
        (propId != null) ? await _getOrCreateUtId(propId, propUtValido) : null;
    // Campos MRV (RC-10/RS-01/RS-02/RG-02) — vão junto em qualquer schema.
    // status_verificacao é select no servidor com values
    // [pendente,revisado,aprovado] (1778900000_parcelas_mrv_verificacao.js).
    // O valor local default é 'ativa' (legado) — mandar cru dava 400.
    final mrvBody = <String, dynamic>{
      'latitude': parcela.latitude,
      'longitude': parcela.longitude,
      'geo_json': parcela.geoJson,
      'area_m2': parcela.areaM2,
      'unidade_forma': parcela.unidadeForma,
      'raio_m': parcela.raioM,
      'marcador': parcela.marcador,
      'status_verificacao': _statusVerificacaoParaServidor(parcela.statusParcela),
      // v28 MRV: metadados por foto (hash + GPS + timestamp + dono) —
      // promessa do pitch: "cada foto recebe hash SHA-256, GPS, timestamp e dono"
      'fotos_meta': await _fotosMetaJson(parcela.uuid),
      // RT-01/RC-11: vínculo projeto/período + SOP aplicado nesta medição
      'projeto_id': parcela.projetoUuid,
      'periodo_id': parcela.periodoUuid,
      'protocolo_versao': parcela.protocoloVersao,
    };
    // A coleção parcelas NÃO tem campo area_ha (schema medido no servidor).
    // A área vai em observacoes, no mesmo formato "area_ha:0.1234" de sempre.
    final areaStr = (parcela.areaHa != null && parcela.areaHa! > 0)
        ? 'area_ha:${parcela.areaHa!.toStringAsFixed(4)}'
        : '';
    final obsBase = parcela.observacoes?.trim() ?? '';
    final observacoesVal = areaStr.isEmpty
        ? obsBase
        : obsBase.isEmpty
            ? areaStr
            : '$areaStr\n$obsBase';
    if (utId != null) {
      // prop_ut é TEXT **required** no servidor (schema medido): precisa ir
      // mesmo no caminho normalizado, não só no flat.
      parcelaBody = {
        'ut': utId,
        'prop_ut': propUtValido,
        'id_parcela': parcela.idParcela,
        'observacoes': observacoesVal,
        'user': parcela.userId,
        ...mrvBody,
      };
    } else {
      // Schema flat: a coleção parcelas também NÃO tem campo propriedade.
      // prop_ut carrega "propriedade - UT", formato que _parseParcelaHierarchy
      // já reconhece no pull (linha do split por ' - ').
      parcelaBody = {
        'prop_ut': '${propName.trim()} - ${propUtValido}',
        'id_parcela': parcela.idParcela,
        'observacoes': observacoesVal,
        'user': parcela.userId,
        ...mrvBody,
      };
    }

    final fotos = await _db.getFotosByParcela(parcela.uuid);
    final fotoPathsAndNames = <Map<String, dynamic>>[];

    if (!kIsWeb) {
      for (int i = 0; i < fotos.length; i++) {
        final foto = fotos[i];
      final path = foto.filePath;
      final file = File(path);
      if (await file.exists()) {
        final nomeArquivo = _gerarNomeFotoParcela(parcela, i);
          fotoPathsAndNames.add({
            'index': i,
            'name': nomeArquivo,
          });
        }
      }
    }

    final existingServerId =
        parcela.uuid.startsWith('pb-') ? parcela.uuid.substring(3) : null;

    final record = await _withRetry(() async {
      final freshFiles = <http.MultipartFile>[];
      for (final entry in fotoPathsAndNames) {
    final foto = fotos[entry['index'] as int];
    final path = foto.filePath;
    final file = File(path);
    // >>> t14 S3 (H4): inicio — recheck de hash antes de subir (RC-04)
    // D-1: o ORIGINAL sobe; hash conferido contra o catálogo.
    final hashDoUpload = await ImageService.sha256De(file.path);
    final doCatalogo = await _db.hashDoAtivoDaFoto(foto.uuid);
    if (doCatalogo != null && hashDoUpload != null && hashDoUpload != doCatalogo) {
      await _db.logAudit('hash_divergente_upload',
          entityType: 'foto',
          entityUuid: foto.uuid,
          oldValue: doCatalogo,
          newValue: hashDoUpload);
      throw Exception(
          'Hash divergente no upload (RC-04): catalogo=$doCatalogo arquivo=$hashDoUpload');
    }
    final fileToSend = file;
    // <<< t14 S3: fim
        freshFiles.add(await http.MultipartFile.fromPath(
          'fotos_parcela',
          fileToSend.path,
          filename: entry['name'] as String,
        ));
      }
      if (existingServerId != null) {
        return _pb!.collection('parcelas').update(
              existingServerId,
              body: parcelaBody,
              files: freshFiles,
            );
      }
      return _pb!.collection('parcelas').create(
            body: parcelaBody,
            files: freshFiles,
          );
    });

    // 2. UPSERT versionado das plantas (Q3 motor Fase 2 — fim do delete+recreate)
    // ANTES: coletava todas as plantas do servidor, DELETAVA todas e recriava.
    // Se o create falhasse no meio, o servidor perdia plantas que existiam; a
    // retry seguinte deletava até as já criadas. AGORA: upsert por
    // (parcela, uuid_local), last-writer-wins por updated_at (política
    // documentada: campo numérico/texto — o updated_at mais recente vence).
    // Push normal NUNCA faz delete cego.
    final plantas = await _db.getPlantasByParcela(parcela.uuid);
    bool allPlantasOk = true;
    final List<String> plantaErrors = [];

    // Índice do que está no servidor por uuid_local. Registros SEM uuid_local
    // (legado pré-Fase-1) ficam fora do upsert por identidade — não são
    // apagados (regra P-2: evidência sobrevive) e sua normalização é v25+.
    final existentes = <String, RecordModel>{};
    try {
      final serverPlantas = await _withRetry(
        () => _pb!.collection('plantas').getFullList(
              filter: 'parcela = "${record.id}"',
            ),
      );
      for (final r in serverPlantas) {
        final u = r.data['uuid_local'];
        if (u is String && u.isNotEmpty) existentes[u] = r;
      }
    } catch (e) {
      debugPrint('Aviso: não foi possível buscar plantas existentes: $e');
    }

    for (int i = 0; i < plantas.length; i++) {
      final planta = plantas[i];
      try {
        final existente = existentes[planta.uuid];
        final plantaBody = <String, dynamic>{
          'parcela': record.id,
          // t14: relation nova (1778600000) — MESMO valor do texto; o campo
          // texto fica para o app antigo e para o filtro durante a transição.
          'parcela_rel': record.id,
          'especie': planta.especie,
          'altura_cm': planta.alturaCm,
          'dap_cm': planta.dapCm,
          'categoria': planta.categoria,
          'created_at': planta.createdAt.toIso8601String(),
          // Fase 1: identidade + versão para o upsert
          'uuid_local': planta.uuid,
          'updated_at': planta.updatedAt.toIso8601String(),
          // v28 MRV: dono da medição (pitch: cada medição tem dono)
          'autor': planta.autorUuid,
        };

        // Pré-calcula caminho da foto para criar MultipartFile fresco a cada retry
        String? plantaFotoPath;
        String? plantaFotoName;

        if (!kIsWeb && planta.fotoEspeciePath != null) {
          final fotoFile = File(planta.fotoEspeciePath!);
          if (await fotoFile.exists()) {
            // >>> t14 S3 (H4): inicio — recheck de hash antes de subir (RC-04)
            // D-1: o ORIGINAL sobe, sem re-encodar.
            final hashDoUpload = await ImageService.sha256De(fotoFile.path);
            final doCatalogo = await _db.hashDoAtivoDaFoto(planta.uuid);
            if (doCatalogo != null &&
                hashDoUpload != null &&
                hashDoUpload != doCatalogo) {
              await _db.logAudit('hash_divergente_upload',
                  entityType: 'foto',
                  entityUuid: planta.uuid,
                  oldValue: doCatalogo,
                  newValue: hashDoUpload);
              throw Exception(
                  'Hash divergente no upload (RC-04): catalogo=$doCatalogo arquivo=$hashDoUpload');
            }
            // <<< t14 S3: fim
            plantaFotoPath = fotoFile.path;
            plantaFotoName = _gerarNomeFotoPlanta(parcela, planta, i);
          }
        }

        RecordModel resultado;
        if (existente == null) {
          plantaBody['version'] = 1;
          resultado = await _withRetry(() async {
            final freshPlantaFiles = <http.MultipartFile>[];
            if (plantaFotoPath != null) {
              freshPlantaFiles.add(await http.MultipartFile.fromPath(
                'foto_especie',
                plantaFotoPath,
                filename: plantaFotoName,
              ));
            }
            return _pb!.collection('plantas').create(
                  body: plantaBody,
                  files: freshPlantaFiles,
                );
          });
        } else {
          // last-writer-wins por updated_at
          final serverUpdated = DateTime.tryParse(
              existente.data['updated_at']?.toString() ?? '');
          final localNewer = serverUpdated == null ||
              planta.updatedAt.isAfter(serverUpdated);
          if (localNewer) {
            plantaBody['version'] =
                ((existente.data['version'] as num?)?.toInt() ?? 1) + 1;
            resultado = await _withRetry(() async {
              final freshPlantaFiles = <http.MultipartFile>[];
              if (plantaFotoPath != null) {
                freshPlantaFiles.add(await http.MultipartFile.fromPath(
                  'foto_especie',
                  plantaFotoPath,
                  filename: plantaFotoName,
                ));
              }
              return _pb!.collection('plantas').update(
                    existente.id,
                    body: plantaBody,
                    files: freshPlantaFiles,
                  );
            });
          } else {
            // servidor mais novo: política last-writer-wins = servidor vence.
            // Não sobrescreve; marca synced (cópia local é histórico) e loga —
            // a reconciliação completa de plantas é o item 6 (pull).
            debugPrint(
                'Planta ${planta.uuid}: servidor mais novo, update ignorado');
            resultado = existente;
          }
        }

        await _db.marcarPlantaSynced(planta.uuid);
        if (planta.serverPlantaId != resultado.id) {
          await _db.atualizarServerPlantaId(planta.uuid, resultado.id);
        }
        // t14 v26: guarda o server id da parcela para a relation (nunca
        // sobrescreve — valor já preenchido fica como está)
        await _db.registrarParcelaServerId(planta.uuid, record.id);
      } catch (e) {
        allPlantasOk = false;
        plantaErrors.add('Planta ${planta.especie}: $e');
        debugPrint('Erro ao enviar planta ${planta.uuid}: $e');
      }
    }

    // Propaga deleções locais: planta no servidor (identificada por uuid_local)
    // sem par local vivo é removida — deleção EXPLÍCITA por identidade, não o
    // delete-all cego de antes. Legado sem uuid_local fica intacto (P-2).
    try {
      final vivas = plantas.map((p) => p.uuid).toSet();
      for (final entry in existentes.entries) {
        if (vivas.contains(entry.key)) continue;
        try {
          await _pb!.collection('plantas').delete(entry.value.id);
          debugPrint('Planta ${entry.key}: deletada localmente, removida do servidor');
        } catch (e) {
          debugPrint('Aviso: falha ao propagar delete de ${entry.key}: $e');
        }
      }
    } catch (e) {
      debugPrint('Aviso: propagação de deletes falhou: $e');
    }

    // 4. Só marca tudo como synced se TODAS as plantas foram enviadas
    if (allPlantasOk) {
      await _db.transaction(() async {
        for (final foto in fotos) {
          await _db.marcarFotoSynced(foto.uuid);
        }
        await _db.marcarParcelaSynced(parcela.uuid);

        // 5. Remapear UUID local para 'pb-{recordId}' (só para parcelas criadas localmente)
        if (existingServerId == null) {
          try {
            await _db.remapParcelaUuid(parcela.uuid, 'pb-${record.id}');
          } catch (e) {
            debugPrint('Aviso: não foi possível remapear UUID da parcela: $e');
          }
        }

        // Audita sync bem-sucedido
        await _db.logAudit('sync_push',
            entityType: 'parcela',
            entityUuid: parcela.uuid,
            userId: parcela.userId,
            newValue: 'synced');
      });
      } else {
        // Q3 item 5: planta falhou → a parcela NÃO está completa. Antes este
        // ramo marcava as FOTOS como synced mesmo com plantas pendentes —
        // órfão: foto no servidor (subiu com a parcela) marcada localmente
        // como feita enquanto a planta dona nem existe lá. Agora nada é
        // marcado synced no caminho parcial: a retry trata tudo junto.
        await _db.marcarParcelaParcialmenteSincronizada(parcela.uuid);
        throw Exception(
            '${plantaErrors.length} planta(s) falharam ao sincronizar, tentará novamente na próxima vez');
      }
  }

  /// Remove a parcela (e suas plantas) no servidor. Só para parcelas já sincronizadas (uuid pb-*).
  Future<void> deleteParcelaNoServidor(String parcelaUuid) async {
    if (!parcelaUuid.startsWith('pb-') || _pb == null) return;
    final serverId = parcelaUuid.substring(3);
    try {
      final plantas = await _pb!.collection('plantas').getFullList(
            filter: 'parcela = "$serverId"',
          );
      for (final pl in plantas) {
        await _pb!.collection('plantas').delete(pl.id);
      }
      await _pb!.collection('parcelas').delete(serverId);
    } catch (e) {
      debugPrint('Erro ao apagar parcela no servidor: $e');
      rethrow;
    }
  }

  /// Extrai nome do UT de um registro parcela (schema normalizado ou flat).
  String _getPropUtFromRecord(RecordModel rec) {
    if (_isNormalizedSchema(rec) && rec.expand != null) {
      return _expandName(rec.expand!['ut']);
    }
    return rec.getStringValue('prop_ut');
  }

  /// Baixa fotos do servidor organizadas por usuário/parcela.
  /// Suporta schema normalizado e flat.
  Future<String?> downloadFotosOrganizadas(
      {String? userId,
      String? userName,
      String? propUt,
      String? parcelaServerId}) async {
    if (_pb == null || !_pb!.authStore.isValid) {
      final ok = await _tryAutoAuth();
      if (!ok) return null;
    }

    try {
      final filterParts = <String>[];
      if (userId != null && userId.isNotEmpty) {
        filterParts.add('user = "$userId"');
      }
      if (propUt != null && propUt.isNotEmpty) {
        filterParts.add('prop_ut = "$propUt"');
      }
      if (parcelaServerId != null && parcelaServerId.isNotEmpty) {
        filterParts.add('id = "$parcelaServerId"');
      }
      final filter = filterParts.join(' && ');

      final parcelas = await _withRetry(
        () => _pb!.collection('parcelas').getFullList(
              filter: filter.isNotEmpty ? filter : null,
              expand: 'ut',
            ),
      );

      if (parcelas.isEmpty) return null;

      // Diretório de destino: Downloads (acessível ao usuário)
      Directory? baseDir;
      if (kIsWeb) {
        return null;
      } else if (Platform.isAndroid) {
        baseDir = Directory('/storage/emulated/0/Download');
        if (!await baseDir.exists()) {
          baseDir = await getApplicationDocumentsDirectory();
        }
      } else {
        baseDir = await getApplicationDocumentsDirectory();
      }

      final exportDir = Directory(
        '${baseDir!.path}/MonitoramentoFlorestal_Fotos/${userName ?? "todos"}',
      );
      if (exportDir.existsSync()) {
        exportDir.deleteSync(recursive: true);
      }
      exportDir.createSync(recursive: true);

      int totalDownloads = 0;
      int completedDownloads = 0;
      final Map<String, List<RecordModel>> plantasCache = {};

      for (final parcelaRecord in parcelas) {
        totalDownloads +=
            parcelaRecord.getListValue<String>('fotos_parcela').length;
        final plantas = await _withRetry(
          () => _pb!.collection('plantas').getFullList(
                filter: 'parcela = "${parcelaRecord.id}"',
              ),
        );
        plantasCache[parcelaRecord.id] = plantas;
        for (final plantaRecord in plantas) {
          if (plantaRecord.getStringValue('foto_especie').isNotEmpty) {
            totalDownloads++;
          }
        }
      }

      for (final parcelaRecord in parcelas) {
        final propUtName = _getPropUtFromRecord(parcelaRecord);
        final idParcela = parcelaRecord.getIntValue('id_parcela');
        final pastaName = _sanitizeFileName(
            '${propUtName}_P${idParcela.toString().padLeft(2, '0')}');

        final parcelaDir = Directory('${exportDir.path}/$pastaName');
        parcelaDir.createSync(recursive: true);

        final fotosParcela =
            parcelaRecord.getListValue<String>('fotos_parcela');
        for (int i = 0; i < fotosParcela.length; i++) {
          final fotoName = fotosParcela[i];
          try {
            final url = _pb!.files.getUrl(parcelaRecord, fotoName);
            final response = await http.get(url);
            if (response.statusCode == 200) {
              final file = File('${parcelaDir.path}/$fotoName');
              await Isolate.run(
                  () => file.writeAsBytesSync(response.bodyBytes));
              completedDownloads++;
              _syncProgress = completedDownloads / totalDownloads;
              notifyListeners();
            }
          } catch (e) {
            debugPrint('Erro ao baixar foto parcela: $e');
          }
        }

        final plantas = plantasCache[parcelaRecord.id] ?? [];
        for (final plantaRecord in plantas) {
          final fotoEspecie = plantaRecord.getStringValue('foto_especie');
          if (fotoEspecie.isNotEmpty) {
            try {
              final url = _pb!.files.getUrl(plantaRecord, fotoEspecie);
              final response = await http.get(url);
              if (response.statusCode == 200) {
                final file = File('${parcelaDir.path}/$fotoEspecie');
                await Isolate.run(
                    () => file.writeAsBytesSync(response.bodyBytes));
                completedDownloads++;
                _syncProgress = completedDownloads / totalDownloads;
                notifyListeners();
              }
            } catch (e) {
              debugPrint('Erro ao baixar foto planta: $e');
            }
          }
        }
      }

      return exportDir.path;
    } catch (e) {
      debugPrint('Erro ao baixar fotos: $e');
      return null;
    }
  }

  /// Atualiza o campo isAdmin de um usuário no PocketBase.
  /// Retorna true se atualizou com sucesso, false se falhou.
  Future<bool> syncAdminFlagToServer(String email, bool isAdmin) async {
    if (_pb == null) return false;
    if (!_pb!.authStore.isValid) {
      final ok = await _tryAutoAuth();
      if (!ok) return false;
    }

    try {
      final records = await _withRetry(
        () => _pb!.collection('users').getFullList(filter: 'email = "$email"'),
      );
      if (records.isEmpty) return false;

      final pbId = records.first.id;
      await _withRetry(
        () => _pb!.collection('users').update(pbId, body: {'isAdmin': isAdmin}),
      );

      await _db.logAudit(
        isAdmin ? 'promote_admin' : 'demote_admin',
        entityType: 'usuario',
        entityUuid: pbId,
        details: 'email=$email, isAdmin=$isAdmin',
      );
      return true;
    } catch (e) {
      debugPrint('Erro ao sincronizar admin flag: $e');
      return false;
    }
  }

  /// Força atualização da contagem de pendentes.
  Future<void> refreshPendingCount() async {
    await _updatePendingCount();
  }

  /// Deleta um usuário e todos os seus dados do PocketBase.
  /// Retorna true se dados foram deletados.
  Future<bool> deleteUsuarioDoServidor(String uuid, String email) async {
    if (_pb == null) return false;

    try {
      bool deletouAlgo = false;

      final possibleIds = <String>{uuid};

      // Tenta encontrar o user no PB para pegar o PB record ID
      try {
        final userRecords = await _withRetry(
          () =>
              _pb!.collection('users').getFullList(filter: 'email = "$email"'),
        );
        for (final u in userRecords) {
          possibleIds.add(u.id);
        }
      } catch (_) {}

      // Busca parcelas para cada possível ID
      for (final uid in possibleIds) {
        try {
          final parcelas = await _withRetry(
            () => _pb!
                .collection('parcelas')
                .getFullList(filter: 'user = "$uid"'),
          );

          for (final parcela in parcelas) {
            try {
              final plantas = await _withRetry(
                () => _pb!.collection('plantas').getFullList(
                      filter: 'parcela = "${parcela.id}"',
                    ),
              );
              for (final planta in plantas) {
                try {
                  await _pb!.collection('plantas').delete(planta.id);
                  deletouAlgo = true;
                } catch (e) {
                  debugPrint('Erro ao deletar planta ${planta.id}: $e');
                }
              }
            } catch (_) {}
            try {
              await _pb!.collection('parcelas').delete(parcela.id);
              deletouAlgo = true;
            } catch (e) {
              debugPrint('Erro ao deletar parcela ${parcela.id}: $e');
            }
          }
        } catch (_) {}
      }

      // Deleta o registro do usuário do PB
      try {
        final userRecords = await _withRetry(
          () =>
              _pb!.collection('users').getFullList(filter: 'email = "$email"'),
        );
        for (final u in userRecords) {
          await _pb!.collection('users').delete(u.id);
          deletouAlgo = true;
        }
      } catch (_) {}

      if (deletouAlgo) {
        debugPrint('Dados de $email deletados do servidor com sucesso.');
        await _db.logAudit('delete_user_server',
            entityType: 'usuario', entityUuid: uuid, details: 'email=$email');
      }
      return deletouAlgo;
    } catch (e) {
      debugPrint('Erro ao deletar usuário do servidor: $e');
      rethrow;
    }
  }
}
