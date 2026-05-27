///
/// Seed PocketBase com schema normalizado: Propriedade > UT/Talhão > Parcela.
/// Garante que nunca se grava UT no lugar de Propriedade (relações no servidor).
///
/// 1. Limpa: plantas, parcelas, uts, propriedades (nesta ordem).
/// 2. Cria propriedades (nome único).
/// 3. Cria uts (relação → propriedade, nome).
/// 4. Cria parcelas (relação → ut, id_parcela, user, area_ha).
///
/// CSV: col0=Propriedade, col1=UT; col2=Área; col3=Qtd Parcelas (vírgula = decimal).
/// Opção --swap-columns se o CSV tiver UT na 1ª coluna.
///
/// Uso (na raiz do projeto):
///   dart run tool/seed_pocketbase_from_csv.dart [caminho/planilha.csv]
///   dart run tool/seed_pocketbase_from_csv.dart --swap-columns planilha.csv
///
/// Credenciais: PB_URL, PB_ADMIN_EMAIL, PB_ADMIN_PASSWORD (env, args ou tool/.env.seed)
///
/// Pré-requisito: no PocketBase Admin criar as coleções propriedades, uts, parcelas
/// conforme docs/POCKETBASE_SCHEMA.md (parcelas com relação ut → uts; uts com relação propriedade → propriedades).
///

import 'dart:convert';
import 'dart:io';

bool _looksLikeUt(String s) {
  if (s.isEmpty) return false;
  final t = s.trim().toUpperCase();
  if (!t.startsWith('UT') || t.length < 2) return false;
  final rest = t.substring(2);
  if (rest.isEmpty) return true;
  if (rest.startsWith('E') && rest.length > 1) return true;
  return RegExp(r'^[A-Z0-9]+$').hasMatch(rest);
}

void main(List<String> args) async {
  String? csvPath;
  String? pbUrl;
  String? adminEmail;
  String? adminPassword;
  bool swapColumns = false;

  for (final a in args) {
    if (a.startsWith('--pb-url=')) {
      pbUrl = a.substring('--pb-url='.length).trim();
    } else if (a.startsWith('--admin-email=')) {
      adminEmail = a.substring('--admin-email='.length).trim();
    } else if (a.startsWith('--admin-password=')) {
      adminPassword = a.substring('--admin-password='.length).trim();
    } else if (a == '--swap-columns') {
      swapColumns = true;
    } else if (!a.startsWith('--')) {
      csvPath = a;
    }
  }

  pbUrl ??= Platform.environment['PB_URL'];
  adminEmail ??= Platform.environment['PB_ADMIN_EMAIL'];
  adminPassword ??= Platform.environment['PB_ADMIN_PASSWORD'];

  if (pbUrl == null || adminEmail == null || adminPassword == null) {
    final envFile = File('tool/.env.seed');
    if (envFile.existsSync()) {
      for (final line in envFile.readAsStringSync().split('\n')) {
        final s = line.trim();
        if (s.isEmpty || s.startsWith('#')) continue;
        final idx = s.indexOf('=');
        if (idx <= 0) continue;
        final key = s.substring(0, idx).trim();
        final value = s.substring(idx + 1).trim();
        if (key == 'PB_URL') pbUrl = value;
        if (key == 'PB_ADMIN_EMAIL') adminEmail = value;
        if (key == 'PB_ADMIN_PASSWORD') adminPassword = value;
      }
    }
  }

  csvPath ??= 'Planilha_ISAAC 1(mapeamento_area_pt).csv';

  if (pbUrl == null || pbUrl!.isEmpty) {
    stderr.writeln('Missing PB_URL.');
    exit(1);
  }
  if (adminEmail == null || adminEmail!.isEmpty) {
    stderr.writeln('Missing PB_ADMIN_EMAIL.');
    exit(1);
  }
  if (adminPassword == null || adminPassword!.isEmpty) {
    stderr.writeln('Missing PB_ADMIN_PASSWORD.');
    exit(1);
  }

  final file = File(csvPath!);
  if (!file.existsSync()) {
    stderr.writeln('CSV not found: $csvPath');
    exit(1);
  }

  final baseUrl = pbUrl.endsWith('/') ? pbUrl : '$pbUrl/';
  final client = HttpClient();

  try {
    stdout.writeln('Authenticating as admin...');
    final token = await _adminAuth(client, baseUrl, adminEmail, adminPassword);
    if (token == null) {
      stderr.writeln('Admin auth failed.');
      exit(1);
    }

    // Limpar na ordem das relações: plantas → parcelas → uts → propriedades
    stdout.writeln('Cleaning: plantas, parcelas, uts, propriedades...');
    await _deleteAll(client, baseUrl, token, 'plantas');
    await _deleteAll(client, baseUrl, token, 'parcelas');
    await _deleteAll(client, baseUrl, token, 'uts');
    await _deleteAll(client, baseUrl, token, 'propriedades');

    // Parse CSV: Propriedade (col0), UT (col1), Área, Qtd Parcelas
    final lines = file.readAsStringSync(encoding: utf8).split('\n');
    final rows = <_CsvRow>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final parts = line.split(';');
      if (parts.length < 4) continue;
      if (parts[0] == 'ID_PROP' && parts[1] == 'ID_UT') continue;
      if (parts[0] == 'ID_UT' && parts[1] == 'ID_PROP') continue;
      var col0 = parts[0].trim();
      var col1 = parts[1].trim();
      if (swapColumns) {
        final t = col0;
        col0 = col1;
        col1 = t;
      }
      if (_looksLikeUt(col0) && !_looksLikeUt(col1)) {
        final t = col0;
        col0 = col1;
        col1 = t;
      }
      final areaStr = parts[2].trim().replaceAll(',', '.');
      final qtdStr = parts[3].trim();
      final area = double.tryParse(areaStr);
      final qtd = int.tryParse(qtdStr) ?? 1;
      if (col0.isEmpty || col1.isEmpty || area == null || qtd < 1) continue;
      rows.add(_CsvRow(propName: col0, utName: col1, areaHa: area, qtdParcelas: qtd));
    }

    final propNameToId = <String, String>{};
    final utKeyToId = <String, String>{}; // key = '$propId|$utName'

    // 1. Criar propriedades (nomes únicos)
    final uniqueProps = rows.map((r) => r.propName).toSet().toList()..sort();
    stdout.writeln('Creating ${uniqueProps.length} propriedades...');
    for (final name in uniqueProps) {
      final id = await _createRecord(client, baseUrl, token, 'propriedades', {'name': name});
      if (id != null) propNameToId[name] = id;
    }

    // 2. Criar uts (por propriedade + nome UT)
    final uniquePropUt = <String>{};
    for (final r in rows) {
      uniquePropUt.add('${r.propName}|${r.utName}');
    }
    stdout.writeln('Creating ${uniquePropUt.length} uts...');
    for (final key in uniquePropUt) {
      final parts = key.split('|');
      if (parts.length < 2) continue;
      final propName = parts[0];
      final utName = parts.sublist(1).join('|');
      final propId = propNameToId[propName];
      if (propId == null) continue;
      final id = await _createRecord(client, baseUrl, token, 'uts', {
        'propriedade': propId,
        'name': utName,
      });
      if (id != null) utKeyToId['$propId|$utName'] = id;
    }

    // 3. Criar parcelas (ut=id, id_parcela, area_ha, user='')
    final Map<String, int> nextId = {};
    var created = 0;
    stdout.writeln('Creating parcelas...');
    for (final r in rows) {
      final propId = propNameToId[r.propName];
      final utId = propId != null ? utKeyToId['$propId|${r.utName}'] : null;
      if (utId == null) continue;
      final key = '${r.propName}|${r.utName}';
      final start = nextId[key] ?? 1;
      for (var k = 0; k < r.qtdParcelas; k++) {
        final ok = await _createRecord(client, baseUrl, token, 'parcelas', {
          'ut': utId,
          'id_parcela': start + k,
          'area_ha': r.areaHa,
          'user': '',
        }) != null;
        if (ok) created++;
        if (created % 50 == 0 && created > 0) stdout.writeln('  $created...');
      }
      nextId[key] = start + r.qtdParcelas;
    }
    stdout.writeln('Done. Created $created parcelas.');
  } finally {
    client.close();
  }
}

Future<String?> _adminAuth(HttpClient client, String baseUrl, String email, String password) async {
  final req = await client.postUrl(Uri.parse('${baseUrl}api/admins/auth-with-password'));
  req.headers.set('Content-Type', 'application/json');
  req.write(jsonEncode({'identity': email, 'password': password}));
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  if (res.statusCode != 200) return null;
  final data = jsonDecode(body) as Map<String, dynamic>;
  return data['token'] as String?;
}

Future<void> _deleteAll(HttpClient client, String baseUrl, String token, String collection) async {
  var page = 1;
  const perPage = 200;
  while (true) {
    final req = await client.getUrl(Uri.parse('${baseUrl}api/collections/$collection/records?perPage=$perPage&page=$page'));
    req.headers.set('Authorization', 'Bearer $token');
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) break;
    final data = jsonDecode(body) as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];
    if (items.isEmpty) break;
    for (final item in items) {
      final id = (item as Map<String, dynamic>)['id'] as String?;
      if (id == null) continue;
      final delReq = await client.deleteUrl(Uri.parse('${baseUrl}api/collections/$collection/records/$id'));
      delReq.headers.set('Authorization', 'Bearer $token');
      await delReq.close();
    }
    if (items.length < perPage) break;
    page++;
  }
}

Future<String?> _createRecord(HttpClient client, String baseUrl, String token, String collection, Map<String, dynamic> body) async {
  final req = await client.postUrl(Uri.parse('${baseUrl}api/collections/$collection/records'));
  req.headers.set('Content-Type', 'application/json');
  req.headers.set('Authorization', 'Bearer $token');
  req.write(jsonEncode(body));
  final res = await req.close();
  final bodyStr = await res.transform(utf8.decoder).join();
  if (res.statusCode != 200 && res.statusCode != 201) {
    stderr.writeln('$collection create failed: ${res.statusCode} $bodyStr');
    return null;
  }
  final data = jsonDecode(bodyStr) as Map<String, dynamic>;
  return data['id'] as String?;
}

class _CsvRow {
  final String propName;
  final String utName;
  final double areaHa;
  final int qtdParcelas;
  _CsvRow({required this.propName, required this.utName, required this.areaHa, required this.qtdParcelas});
}
