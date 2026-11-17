// UX-APP-CAMPO: bug das sugestões de espécie — a lista precisa aparecer na
// PRIMEIRA interação (toque no campo e/ou primeira digitação), e não só no
// 2º clique. Antes: `_showSpeciesList` só era ligado no onChanged com texto
// não vazio (e no onTap somente quando o campo JÁ tinha texto); com o
// catálogo ainda carregando (XLSX assíncrono), a primeira digitação filtrava
// lista vazia e nada aparecia.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urutau/screens/planta_form_screen.dart';

void main() {
  testWidgets('sugestões aparecem no 1º toque no campo (catálogo carregado)',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: PlantaFormScreen(parcelaUuid: 'p1')));
    await tester.pump();
    // catálogo (asset XLSX ou fallback) terminar de carregar
    await tester.pump(const Duration(milliseconds: 200));

    final campo = find.byType(TextFormField).first;
    await tester.tap(campo);
    await tester.pump();

    // 1º clique: a lista de espécies já aparece (catálogo inteiro)
    expect(find.byType(ListTile), findsWidgets,
        reason: 'sugestões devem aparecer na primeira interação');
  });

  testWidgets('sugestões filtram na primeira digitação', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: PlantaFormScreen(parcelaUuid: 'p1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final campo = find.byType(TextFormField).first;
    await tester.tap(campo);
    await tester.pump();
    await tester.enterText(campo, 'Cecropia');
    await tester.pump();

    expect(find.text('Cecropia pachystachya'), findsOneWidget);
    expect(find.text('Cecropia hololeuca Miq.'), findsOneWidget);
    // espécie que não bate com o filtro não aparece
    expect(find.text('Dalbergia nigra (Vell.) Allemão ex Benth.'),
        findsNothing);
  });

  testWidgets('sugestões aparecem mesmo se o catálogo carregar depois do toque',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: PlantaFormScreen(parcelaUuid: 'p1')));
    await tester.pump();

    final campo = find.byType(TextFormField).first;
    // toca e digita ANTES do catálogo terminar de carregar (race do bug
    // original: filtrava lista vazia e nada aparecia)
    await tester.tap(campo);
    await tester.pump();
    await tester.enterText(campo, 'Cecropia');
    await tester.pump(const Duration(milliseconds: 300));

    // a lista aparece sem 2º clique quando o catálogo chega
    expect(find.text('Cecropia pachystachya'), findsOneWidget);
  });

  testWidgets('selecionar da lista preenche o campo e esconde a lista',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: PlantaFormScreen(parcelaUuid: 'p1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final campo = find.byType(TextFormField).first;
    await tester.tap(campo);
    await tester.pump();
    await tester.enterText(campo, 'Cecropia');
    await tester.pump();
    await tester.tap(find.text('Cecropia pachystachya'));
    await tester.pump();

    expect(find.text('Cecropia pachystachya'), findsOneWidget); // valor do campo
    // lista fechou: as outras sugestões saem da tela
    expect(find.text('Cecropia hololeuca Miq.'), findsNothing);
    expect(find.text('Cecropia glaziovii Snethl.'), findsNothing);
  });
}
