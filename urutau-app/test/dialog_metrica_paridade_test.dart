import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urutau/services/theme_provider.dart';
import 'package:urutau/theme/app_tokens.dart';

/// Mede o dialogo de confirmacao de edicao ("Parcela ja sincronizada",
/// botoes "Cancelar" e "Sim, editar") num dado tema, abrindo o dialogo
/// programaticamente (sem tap) para evitar animacao de troca de tema.
///
/// Cada chamada mede UM so tema (sem transicao), assim nao ha interpolacao
/// de TextStyle entre temas.
Future<_Metrica> _medirDialogo(WidgetTester tester, ThemeModeUrutau modo) async {
  final theme = ThemeProvider.themeFor(modo);
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    themeAnimationDuration: Duration.zero,
    home: _DialogHost(),
  ));
  await tester.pumpAndSettle();

  // Chaves no conteudo do dialog para medir a metrica intrinseca (o que
  // varia entre temas: wrap do texto por causa do fontWeight).
  final titleSize = tester.getSize(find.byKey(const Key('dialogTitle')).first);
  final contentSize =
      tester.getSize(find.byKey(const Key('dialogContent')).first);

  // botoes dentro do dialog: TextButton "Cancelar", FilledButton "Sim, editar"
  final cancelar = find.byType(TextButton).first;
  final simEditar = find.byType(FilledButton).first;
  return _Metrica(
    modo: modo,
    cancelarTamanho: tester.getSize(cancelar),
    cancelarTopLeft: tester.getTopLeft(cancelar),
    simEditarTamanho: tester.getSize(simEditar),
    simEditarTopLeft: tester.getTopLeft(simEditar),
    titleTamanho: titleSize,
    contentTamanho: contentSize,
  );
}

/// Abre o dialogo de confirmacao de edicao logo no primeiro frame.
class _DialogHost extends StatefulWidget {
  @override
  State<_DialogHost> createState() => _DialogHostState();
}

class _DialogHostState extends State<_DialogHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(
            Icons.info_outline,
            color: Theme.of(ctx).colorScheme.tertiary,
            size: 32,
          ),
          title: const Text('Parcela já sincronizada', key: Key('dialogTitle')),
          content: const Text(
            'Esta parcela ja foi concluida e sincronizada com o servidor. '
            'Deseja realmente edit-la? As alteracoes poderao ser enviadas '
            'de novo ao sincronizar.',
            key: Key('dialogContent'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sim, editar'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('host')));
}

class _Metrica {
  final ThemeModeUrutau modo;
  final Size cancelarTamanho;
  final Offset cancelarTopLeft;
  final Size simEditarTamanho;
  final Offset simEditarTopLeft;
  final Size titleTamanho;
  final Size contentTamanho;
  _Metrica({
    required this.modo,
    required this.cancelarTamanho,
    required this.cancelarTopLeft,
    required this.simEditarTamanho,
    required this.simEditarTopLeft,
    required this.titleTamanho,
    required this.contentTamanho,
  });
  @override
  String toString() =>
      '$modo: title=$titleTamanho | content=$contentTamanho | Cancelar=$cancelarTamanho @$cancelarTopLeft | Sim editar=$simEditarTamanho @$simEditarTopLeft';
}

/// Resultado da medição do tema claro (preenchido pelo teste 1).
_Metrica? metricaClaro;
/// Resultado da medição do tema alto contraste (preenchido pelo teste 2).
_Metrica? metricaHc;

void main() {
  testWidgets('mede o dialogo de edicao no tema claro', (tester) async {
    metricaClaro = await _medirDialogo(tester, ThemeModeUrutau.claro);
    debugPrint('CLARO: ${metricaClaro!}');
  });

  testWidgets('mede o dialogo de edicao no tema alto contraste',
      (tester) async {
    metricaHc = await _medirDialogo(tester, ThemeModeUrutau.altoContraste);
    debugPrint('ALTO CONTRASTE: ${metricaHc!}');
  });

  testWidgets(
      'paridade de metrica do dialogo de edicao: claro vs altoContraste (D1)',
      (tester) async {
    final claro = metricaClaro;
    final hc = metricaHc;
    expect(claro, isNotNull, reason: 'medição do claro não executou');
    expect(hc, isNotNull, reason: 'medição do alto contraste não executou');
    if (claro == null || hc == null) return;

    debugPrint('===== PARIDADE DE METRICA (D1) =====');
    debugPrint(claro.toString());
    debugPrint(hc.toString());

    final deltaTitleAltura =
        (claro.titleTamanho.height - hc.titleTamanho.height).abs();
    final deltaContentAltura =
        (claro.contentTamanho.height - hc.contentTamanho.height).abs();
    final deltaCancelarAltura =
        (claro.cancelarTamanho.height - hc.cancelarTamanho.height).abs();
    final deltaSimEditarAltura =
        (claro.simEditarTamanho.height - hc.simEditarTamanho.height).abs();
    final deltaCancelarLargura =
        (claro.cancelarTamanho.width - hc.cancelarTamanho.width).abs();

    expect(deltaTitleAltura, lessThanOrEqualTo(1),
        reason: 'altura do titulo do dialogo difere entre temas '
            '(claro=${claro.titleTamanho.height} hc=${hc.titleTamanho.height}, delta=$deltaTitleAltura px)');
    expect(deltaContentAltura, lessThanOrEqualTo(1),
        reason: 'altura do conteudo do dialogo difere entre temas '
            '(claro=${claro.contentTamanho.height} hc=${hc.contentTamanho.height}, delta=$deltaContentAltura px)');
    expect(deltaCancelarAltura, lessThanOrEqualTo(1),
        reason: 'altura do botao Cancelar difere entre temas '
            '(claro=${claro.cancelarTamanho.height} hc=${hc.cancelarTamanho.height}, delta=$deltaCancelarAltura px)');
    expect(deltaSimEditarAltura, lessThanOrEqualTo(1),
        reason: 'altura do botao Sim editar difere entre temas '
            '(claro=${claro.simEditarTamanho.height} hc=${hc.simEditarTamanho.height}, delta=$deltaSimEditarAltura px)');
    expect(deltaCancelarLargura, lessThanOrEqualTo(1),
        reason: 'largura do botao Cancelar difere entre temas '
            '(claro=${claro.cancelarTamanho.width} hc=${hc.cancelarTamanho.width}, delta=$deltaCancelarLargura px)');
  });

  testWidgets('contraste AA preservado no dialogo (alto contraste)',
      (tester) async {
    final hc = ThemeProvider.themeFor(ThemeModeUrutau.altoContraste);
    expect(hc.dialogTheme.backgroundColor, AppTokens.hcSurface);
    expect(hc.dialogTheme.titleTextStyle?.color, AppTokens.hcPrimary);
    expect(hc.dialogTheme.contentTextStyle?.color, AppTokens.hcText);
  });
}
