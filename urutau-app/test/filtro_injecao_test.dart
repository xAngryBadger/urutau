import 'package:flutter_test/flutter_test.dart';
import 'package:urutau/services/sync_service.dart' show escapePbFilter;

/// GUARDA DE REGRESSÃO — injecção de filtro PocketBase (buraco 1 da bateria
/// adversária, docs/adversario-handshake.md).
///
/// O `filter:` do PocketBase é uma LINGUAGEM (`||`, `&&`, `(`, `)`, `>`, `<`,
/// `!=`). Um nome de UT/propriedade é texto do utilizador e entra dentro de
/// uma string do filtro. Se um operador do valor escapa para fora da string,
/// a condição da query muda de significado (ex.: `X || 1=1` passa a ser
/// "tudo"). Não é SQL injection — é injecção de FILTRO.
///
/// Este teste usa o escape REAL do app ([escapePbFilter]) e fixa o
/// comportamento correcto: para qualquer valor de ataque, o filtro
/// resultante (a) não contém operadores lógicos fora das strings além dos
/// que o próprio app colocou, e (b) cada string literal do filtro,
/// dest escapada, é EXACTAMENTE o valor original — ou seja, a query procura o
/// texto literal e nunca "todos". Na prática contra o servidor: 0 registos
/// ou exactamente o registo certo, NUNCA todos.
void main() {
  /// Constrói o filtro exactamente como o app faz em
  /// `_fetchServerParcelasByKeys` (sync_service.dart), mas com o escape forte.
  String filtroChave(String ut, String id) =>
      '(prop_ut = "${escapePbFilter(ut)}" && id_parcela = $id)';

  const ataques = <String, String>{
    'operador OU': 'UT-90 || 1=1',
    'operador E': 'UT-90 && 1=1',
    'fecha-parentise com escape': 'UT-90") || true || ("',
    'abre-parentise': '(UT-90',
    'desigualdade': 'UT-90 != x',
    'maior-que': 'UT-90 > x',
    'barra-invertida no fim': 'UT-90\\',
    'barra + aspa (tenta fechar a string)': 'UT-90\\"',
    'aspa solta': 'UT-90"',
    'newline + operador': 'UT-90\n|| 1=1',
    'condicao extra': 'UT-90 || id_parcela > 0',
    'unicode': 'UT-90 é ✨ \u{1F600}',
    'nome real com operador literal': 'P1 - UT1 || 1=1',
  };

  group('guarda: escapePbFilter nunca deixa operador sair da string', () {
    for (final caso in ataques.entries) {
      test(caso.key, () {
        final f = filtroChave(caso.value, '90');
        final fora = operadoresForaDasStrings(f);
        // O app coloca exactamente 1 `&&` (o da própria condição da chave).
        // Nenhum `||` pode aparecer fora; nenhum `&&` além do 1 esperado.
        expect(fora['||'], 0,
            reason: '"||" escapou para fora da string no filtro: $f');
        expect(fora['&&'], 1,
            reason: 'esperava só o && do próprio app fora das strings: $f');
      });
    }

    test('string literal do filtro dest-escapada == valor original (round-trip)', () {
      for (final caso in ataques.entries) {
        final f = filtroChave(caso.value, '90');
        final literais = literaisDeStrings(f);
        expect(literais, contains(caso.value),
            reason: 'o valor de ataque não sobreviveu inteiro dentro da string '
                'do filtro: $f -> literais: $literais');
      }
    });

    test('nome limpo produz filtro idêntico ao esperado', () {
      final f = filtroChave('UT-90', '90');
      expect(f, '(prop_ut = "UT-90" && id_parcela = 90)');
    });
  });

  // ============================================================
  // TESTES DE INTEGRAÇÃO — filtros PocketBase completos com payloads de ataque
  //
  // Estes testes simulam a construção de filtros COMPLETOS como o app faz
  // em vários pontos (sync_service.dart), verificando que:
  // 1. O filtro resultante NUNCA retorna todos os registros (full table scan)
  // 2. Espera-se 0 ou exatamente 1 registro correspondente
  // 3. Payloads de injeção são neutralizados pelo escapePbFilter
  // ============================================================
  group('integração: filtros completos do app com payloads de ataque', () {
    // Simula _fetchServerParcelasByKeys (linha ~1660-1682)
    String filtroChaves(Set<String> keys) {
      return keys.map((k) {
        final parts = k.split('|');
        if (parts.length != 3) return null;
        final utEsc = escapePbFilter(parts[1]);
        return '(prop_ut = "$utEsc" && id_parcela = ${parts[2]})';
      }).where((s) => s != null).join(' || ');
    }

    // Build proper test keys in the format: propriedade|propUt|idParcela
    Set<String> buildKeys(String prop, String ut, String id) => {'$prop|$ut|$id'};

    // Simula downloadFotosOrganizadas (linha ~2463-2467)
    String filtroDownload(String? userId, String? propUt, String? parcelaServerId) {
      final parts = <String>[];
      if (userId != null && userId.isNotEmpty) {
        parts.add('user = "${escapePbFilter(userId)}"');
      }
      if (propUt != null && propUt.isNotEmpty) {
        parts.add('prop_ut = "${escapePbFilter(propUt)}"');
      }
      if (parcelaServerId != null && parcelaServerId.isNotEmpty) {
        parts.add('id = "${escapePbFilter(parcelaServerId)}"');
      }
      return parts.join(' && ');
    }

    // Simula _getOrCreatePropriedadeId (linha ~1961-1962)
    String filtroPropriedade(String name) {
      final escaped = escapePbFilter(name);
      return '(codigo = "$escaped" || nome = "$escaped")';
    }

    // Simula _getOrCreateUtId (linha ~2005-2006)
    String filtroUt(String propriedadeId, String utName) {
      final escaped = escapePbFilter(utName);
      return 'codigo = "$escaped" && propriedade = "$propriedadeId"';
    }

    // Ataques que NÃO contêm '|' (válidos para teste de _fetchServerParcelasByKeys que usa split('|'))
    const ataquesSemPipe = <String, String>{
      'operador E': 'UT-90 && 1=1',
      'abre-parentise': '(UT-90',
      'desigualdade': 'UT-90 != x',
      'maior-que': 'UT-90 > x',
      'barra-invertida no fim': 'UT-90\\',
      'barra + aspa (tenta fechar a string)': 'UT-90\\"',
      'aspa solta': 'UT-90"',
      'unicode': 'UT-90 é ✨ \u{1F600}',
    };

    for (final caso in ataquesSemPipe.entries) {
      test('_fetchServerParcelasByKeys: $caso.key não injeta operadores', () {
        final f = filtroChaves(buildKeys('prop', caso.value, '90'));
        final fora = operadoresForaDasStrings(f);
        expect(fora['||'], 0, reason: '"||" escapou no filtro: $f');
        expect(fora['&&'], 1, reason: 'esperava só o && do app: $f');
      });

      test('downloadFotosOrganizadas user filter: $caso.key não injeta', () {
        final f = filtroDownload(caso.value, null, null);
        final fora = operadoresForaDasStrings(f);
        expect(fora['||'], 0, reason: '"||" escapou no filtro user: $f');
        expect(fora['&&'], 0, reason: 'não deve haver && no filtro user: $f');
      });

      test('downloadFotosOrganizadas propUt filter: $caso.key não injeta', () {
        final f = filtroDownload(null, caso.value, null);
        final fora = operadoresForaDasStrings(f);
        expect(fora['||'], 0, reason: '"||" escapou no filtro propUt: $f');
        expect(fora['&&'], 0, reason: 'não deve haver && no filtro propUt: $f');
      });

      test('downloadFotosOrganizadas parcelaServerId filter: $caso.key não injeta', () {
        final f = filtroDownload(null, null, caso.value);
        final fora = operadoresForaDasStrings(f);
        expect(fora['||'], 0, reason: '"||" escapou no filtro parcelaServerId: $f');
        expect(fora['&&'], 0, reason: 'não deve haver && no filtro parcelaServerId: $f');
      });

      test('_getOrCreatePropriedadeId: $caso.key não injeta', () {
        final f = filtroPropriedade(caso.value);
        final fora = operadoresForaDasStrings(f);
        expect(fora['||'], 1, reason: 'esperava só o || do app (codigo || nome): $f');
        expect(fora['&&'], 0, reason: 'não deve haver &&: $f');
      });

      test('_getOrCreateUtId: $caso.key não injeta', () {
        final f = filtroUt('prop-123', caso.value);
        final fora = operadoresForaDasStrings(f);
        expect(fora['||'], 0, reason: '"||" não deve aparecer: $f');
        expect(fora['&&'], 1, reason: 'esperava só o && do app: $f');
      });
    }

    test('filtro combinado com múltiplos ataques não injeta', () {
      // Simula cenário real: userId + propUt + parcelaServerId todos com payloads
      final f = filtroDownload(
        'user||1=1',
        'prop&&1=1',
        'parcela"id',
      );
      final fora = operadoresForaDasStrings(f);
      // Deve ter exatamente 2 '&&' (os dois separadores do app)
      expect(fora['&&'], 2, reason: 'esperava 2 && do app (user && propUt && parcela): $f');
      expect(fora['||'], 0, reason: '"||" não deve escapar: $f');
    });

    test('round-trip: valor original preservado dentro das strings do filtro', () {
      for (final caso in ataques.entries) {
        final f = filtroDownload(caso.value, caso.value, caso.value);
        final literais = literaisDeStrings(f);
        // Cada valor de ataque deve aparecer exatamente 3 vezes (user, propUt, parcelaServerId)
        final count = literais.where((l) => l == caso.value).length;
        expect(count, 3, reason: 'valor $caso.key não preservado 3x no filtro: $f -> literais: $literais');
      }
    });

    // Ataques com '||' não são válidos para chaves _fetchServerParcelasByKeys (split por '|')
    // mas podem ser testados no filtroDownload que não usa split
    test('ataques com || são neutralizados no filtroDownload', () {
      const ataquesComPipe = <String, String>{
        'operador OU': 'UT-90 || 1=1',
        'condicao extra': 'UT-90 || id_parcela > 0',
        'fecha-parentise com escape': 'UT-90") || true || ("',
        'newline + operador': 'UT-90\n|| 1=1',
        'nome real com operador literal': 'P1 - UT1 || 1=1',
      };
      for (final caso in ataquesComPipe.entries) {
        final f = filtroDownload(caso.value, caso.value, caso.value);
        final fora = operadoresForaDasStrings(f);
        // downloadFotosOrganizadas usa && para separar, não || entre chaves
        // Deve ter exatamente 2 '&&' (os separadores do app)
        expect(fora['&&'], 2, reason: 'esperava 2 && do app: $f');
        expect(fora['||'], 0, reason: '"||" não deve escapar no filtroDownload: $f');
      }
    });
  });
}

/// Conta operadores lógicos que aparecem FORA de qualquer string do filtro.
Map<String, int> operadoresForaDasStrings(String filtro) {
  final fora = <String, int>{'||': 0, '&&': 0};
  var dentro = false;
  for (var i = 0; i < filtro.length; i++) {
    final c = filtro[i];
    if (c == '\\' && dentro && i + 1 < filtro.length) {
      i++; // caractere escapado dentro da string: pula
      continue;
    }
    if (c == '"') {
      dentro = !dentro;
      continue;
    }
    if (dentro) continue;
    final dois = i + 1 < filtro.length ? filtro.substring(i, i + 2) : '';
    if (dois == '||' || dois == '&&') {
      fora[dois] = (fora[dois] ?? 0) + 1;
      i++;
    }
  }
  return fora;
}

/// Extrai as strings literais do filtro, desfazendo o escape (`\\` -> `\`,
/// `\"` -> `"`).
List<String> literaisDeStrings(String filtro) {
  final literais = <String>[];
  var dentro = false;
  final atual = StringBuffer();
  for (var i = 0; i < filtro.length; i++) {
    final c = filtro[i];
    if (dentro && c == '\\' && i + 1 < filtro.length) {
      atual.write(filtro[i + 1]);
      i++;
      continue;
    }
    if (c == '"') {
      if (dentro) literais.add(atual.toString());
      dentro = !dentro;
      atual.clear();
      continue;
    }
    if (dentro) atual.write(c);
  }
  return literais;
}