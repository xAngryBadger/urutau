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
