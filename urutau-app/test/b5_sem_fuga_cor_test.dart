import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// B5 guarda: nenhuma tela/widget/main pode usar cor dura fora do tema.
///
/// Varre `lib/screens`, `lib/widgets` e `lib/main.dart` removendo comentários
/// de linha antes de procurar `Colors.<cor>` (exceto `Colors.transparent`,
/// que é overlay neutro) e `Color(0x...` literal. Arquivos de definição de
/// tokens/tema (`lib/theme/*`, `lib/services/theme_provider.dart`) ficam de
/// fora de propósito: lá é onde as cores moram.
void main() {
  final root = Directory.current.path;
  final alvos = <String>[
    ...Directory('$root/lib/screens')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.backup'))
        .map((f) => f.path),
    ...Directory('$root/lib/widgets')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map((f) => f.path),
    '$root/lib/main.dart',
  ];

  final regex = RegExp(r'Colors\.(?!transparent)\w+|Color\(0x[0-9a-fA-F]+\)');

  /// Scrims de overlay sobre foto (viewer fullscreen, badge na miniatura):
  /// preto/branco translúcido não vazam tema — permitidos.
  const scrims = {'Colors.black', 'Colors.black87', 'Colors.white54'};

  test('B5: zero cores duras em telas/widgets/main (fora tokens de tema)', () {
    final fugas = <String>[];
    for (final path in alvos) {
      final semComentarios =
          File(path).readAsStringSync().replaceAll(RegExp(r'//[^\n]*'), '');
      final linhas = semComentarios.split('\n');
      for (var i = 0; i < linhas.length; i++) {
        for (final m in regex.allMatches(linhas[i])) {
          final hit = m.group(0)!;
          if (scrims.contains(hit)) continue;
          // Colors.white só é aceito como scrim translúcido (withValues na linha)
          if (hit == 'Colors.white' && linhas[i].contains('withValues')) {
            continue;
          }
          fugas.add('${path.replaceAll(root, '')}:${i + 1} -> $hit');
        }
      }
    }
    expect(fugas, isEmpty,
        reason: 'Cores duras encontradas (devem usar Theme.of(context).colorScheme):\n'
            '${fugas.join('\n')}');
  });
}
