// UX-APP-CAMPO: wizard de 4 etapas com swipe no form da parcela.
// Prova: (a) wizard abre na etapa 1; (b) Continuar bloqueia sem GPS/planta
// com as mensagens atuais (e o swipe pra frente em etapa inválida não
// avança); (c) concluir grava pronta_para_sync=1 + calculos_mrv, enquanto
// o rascunho NÃO persiste cálculo MRV.
import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urutau/data/database.dart';
import 'package:urutau/screens/parcela_form_screen.dart';
import 'package:urutau/services/sync_service.dart';

class _FakeSyncService extends SyncService {
  _FakeSyncService(super.db);

  @override
  Usuario? get currentUser => Usuario(
        id: 1,
        uuid: 'u1',
        nome: 'Admin Teste',
        email: 'admin@urutau.app',
        senha: 'x',
        isAdmin: true,
        ativo: true,
        createdAt: DateTime(2026, 1, 1),
      );

  @override
  bool get isAdmin => true;

  @override
  Future<void> refreshPendingCount() async {}
}

Future<AppDatabase> _seedDb({
  required bool comGps,
  required bool comPlanta,
}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await db.customSelect('SELECT 1').get();
  await db.insertParcela(ParcelasCompanion.insert(
    uuid: 'p1',
    propriedade: const drift.Value('Fazenda Teste'),
    propUt: 'UT-77',
    idParcela: 7,
    userId: 'u1',
    areaM2: const drift.Value(400),
    unidadeForma: const drift.Value('retangular'),
    latitude: comGps ? const drift.Value(-23.5) : const drift.Value(null),
    longitude: comGps ? const drift.Value(-46.6) : const drift.Value(null),
    geoJson:
        comGps ? const drift.Value('{"tipo":"Point"}') : const drift.Value(null),
  ));
  if (comPlanta) {
    await db.insertPlanta(PlantasCompanion.insert(
      uuid: 'pl1',
      parcelaUuid: 'p1',
      especie: 'Cecropia pachystachya',
      alturaCm: 1500,
      dapCm: const drift.Value(20),
      categoria: 1,
    ));
  }
  return db;
}

Future<void> _pumpForm(WidgetTester tester, AppDatabase db,
    {String? parcelaUuid}) async {
  await tester.pumpWidget(MultiProvider(
    providers: [
      Provider<AppDatabase>.value(value: db),
      ChangeNotifierProvider<SyncService>.value(value: _FakeSyncService(db)),
    ],
    child: MaterialApp(
      home: ParcelaFormScreen(parcelaUuid: parcelaUuid),
    ),
  ));
  await tester.pump();
  // _initAsync + _loadParcela (assíncronos) + catálogo de espécies
  await tester.pump(const Duration(milliseconds: 100));
}

/// Pumps até as animações de página (220 ms) terminarem.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({}); // wizard default LIGADO
  });

  testWidgets('(a) wizard abre na etapa 1 (Local) — sem MRV nem plantas',
      (tester) async {
    final db = await _seedDb(comGps: true, comPlanta: true);
    addTearDown(db.close);
    await _pumpForm(tester, db, parcelaUuid: 'p1');

    expect(find.text('Etapa 1 de 4'), findsOneWidget);
    expect(find.text('Local'), findsWidgets);
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Voltar'), findsOneWidget);
    // campos da etapa Local presentes
    expect(find.text('Propriedade *'), findsOneWidget);
    expect(find.text('UT / Talhão *'), findsOneWidget);
    // estimativa MRV só na etapa Revisar; lista de plantas só na etapa 2
    expect(find.text('Estimativa de carbono (MRV)'), findsNothing);
    expect(find.text('Nenhuma planta adicionada'), findsNothing);
  });

  testWidgets('(b1) Continuar bloqueia na etapa 1 vazia (mensagens atuais)',
      (tester) async {
    final db = await _seedDb(comGps: false, comPlanta: false);
    addTearDown(db.close);
    // parcela NOVA: campos vazios
    await _pumpForm(tester, db);

    await tester.tap(find.text('Continuar'));
    await tester.pump();

    expect(find.text('Etapa 1 de 4'), findsOneWidget); // não avançou
    expect(find.text('Propriedade: Campo obrigatório'), findsOneWidget);
    // validator inline (mensagem atual) visível no campo propriedade
    expect(find.text('Campo obrigatório'), findsWidgets);
  });

  testWidgets('(b2) etapa Plantas sem planta bloqueia o Continuar',
      (tester) async {
    final db = await _seedDb(comGps: false, comPlanta: false);
    addTearDown(db.close);
    await _pumpForm(tester, db, parcelaUuid: 'p1');

    // etapa 1 válida (campos carregados da parcela) — GPS não obriga avançar
    await tester.tap(find.text('Continuar'));
    await _settle(tester);
    expect(find.text('Etapa 2 de 4'), findsOneWidget);
    expect(find.text('Nenhuma planta adicionada'), findsOneWidget);

    await tester.tap(find.text('Continuar'));
    await tester.pump();
    expect(find.text('Etapa 2 de 4'), findsOneWidget); // não avançou
    expect(
        find.text('Adicione pelo menos 1 planta para concluir a parcela.'),
        findsOneWidget);
  });

  testWidgets('(b3) swipe pra frente em etapa inválida não avança + snackbar',
      (tester) async {
    final db = await _seedDb(comGps: false, comPlanta: false);
    addTearDown(db.close);
    await _pumpForm(tester, db);

    // fling a partir do card do GPS (sem campos de texto no caminho do gesto)
    await tester.flingFrom(
        const Offset(700, 220), const Offset(-620, 0), 3000);
    await _settle(tester);

    expect(find.text('Etapa 1 de 4'), findsOneWidget); // voltou sozinho
    expect(find.textContaining('Campo obrigatório'), findsWidgets);
  });

  testWidgets('(b4) swipe pra trás sempre permitido', (tester) async {
    final db = await _seedDb(comGps: true, comPlanta: true);
    addTearDown(db.close);
    await _pumpForm(tester, db, parcelaUuid: 'p1');

    await tester.tap(find.text('Continuar'));
    await _settle(tester);
    expect(find.text('Etapa 2 de 4'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(600, 0), 3000);
    await _settle(tester);
    expect(find.text('Etapa 1 de 4'), findsOneWidget);
  });

  testWidgets('(c) concluir grava pronta_para_sync=1 + calculos_mrv',
      (tester) async {
    final db = await _seedDb(comGps: true, comPlanta: true);
    addTearDown(db.close);
    await _pumpForm(tester, db, parcelaUuid: 'p1');

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Continuar'));
      await _settle(tester);
    }
    expect(find.text('Etapa 4 de 4'), findsOneWidget);
    expect(find.text('Revisar'), findsWidgets);
    // o conteúdo da etapa Revisar é longo — rolar até o card MRV
    await tester.dragUntilVisible(
      find.text('Estimativa de carbono (MRV)'),
      find.byType(ListView).first,
      const Offset(0, -80),
    );
    // estimativa MRV aparece SOMENTE na etapa Revisar
    expect(find.text('Estimativa de carbono (MRV)'), findsOneWidget);
    // resumo da parcela presente
    expect(find.text('Resumo da parcela'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('Concluir alterações'),
      find.byType(ListView).first,
      const Offset(0, -80),
    );
    await tester.tap(find.text('Concluir alterações'));
    await _settle(tester);

    final parcela = await db.getParcelaByUuid('p1');
    expect(parcela, isNotNull);
    expect(parcela!.prontaParaSync, isTrue);
    expect(parcela.protocoloVersao, 'SOP-MRV-V1');
    expect(parcela.statusParcela, 'pendente');
    // geoJson com n_satelites_fonte (RC-10/RC-14) intacto
    final geo = jsonDecode(parcela.geoJson!) as Map<String, dynamic>;
    expect(geo['n_satelites_fonte'], 'indisponivel_geolocator');
    expect(geo['coordenadas'], [-46.6, -23.5]);
    // invariantes de vínculo gravados iguais
    expect(parcela.propUt, 'UT-77');
    expect(parcela.idParcela, 7);

    // cálculo MRV persistido (só no caminho prontaParaSync=true)
    final calculos = await db.select(db.calculosMrv).get();
    expect(calculos, hasLength(1));
    final resultado =
        jsonDecode(calculos.first.resultado!) as Map<String, dynamic>;
    expect(resultado['resultado_hash'], isA<String>());
    expect(resultado['n_com_dap'], 1);
    final resAmostra = await db.select(db.resultadosAmostra).get();
    expect(resAmostra, hasLength(1));
    expect(resAmostra.first.tco2eHa, greaterThan(0));

    // trilha de create/update intacta
    final audit = await db.select(db.auditLog).get();
    expect(audit.any((a) => a.action == 'update'), isTrue);
    final trilha = await db.select(db.trilhaAuditoria).get();
    expect(trilha.any((t) => t.acao == 'update'), isTrue);
  });

  testWidgets('(c2) rascunho NÃO persiste cálculo MRV', (tester) async {
    final db = await _seedDb(comGps: false, comPlanta: true);
    addTearDown(db.close);
    await _pumpForm(tester, db, parcelaUuid: 'p1');

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Continuar'));
      await _settle(tester);
    }
    await tester.dragUntilVisible(
      find.text('Guardar rascunho'),
      find.byType(ListView).first,
      const Offset(0, -80),
    );
    await tester.tap(find.text('Guardar rascunho'));
    await _settle(tester);

    final parcela = await db.getParcelaByUuid('p1');
    expect(parcela!.prontaParaSync, isFalse);
    expect(await db.select(db.calculosMrv).get(), isEmpty);
    expect(await db.select(db.resultadosAmostra).get(), isEmpty);
  });

  testWidgets('(d) flag desligada renderiza o formulário clássico',
      (tester) async {
    SharedPreferences.setMockInitialValues({'wizard_mode_enabled': false});
    final db = await _seedDb(comGps: true, comPlanta: true);
    addTearDown(db.close);
    await _pumpForm(tester, db, parcelaUuid: 'p1');

    // sem stepper/botões do wizard
    expect(find.text('Etapa 1 de 4'), findsNothing);
    expect(find.text('Continuar'), findsNothing);
    // form clássico: tudo no mesmo scroll (ListView única)
    final lista = find.byType(ListView).first;
    await tester.dragUntilVisible(
        find.text('Anotações (opcional)'), lista, const Offset(0, -80));
    expect(find.text('Anotações (opcional)'), findsOneWidget);
    await tester.dragUntilVisible(
        find.text('Adicionar Planta'), lista, const Offset(0, -80));
    expect(find.text('Adicionar Planta'), findsOneWidget);
    await tester.dragUntilVisible(
        find.text('Guardar rascunho'), lista, const Offset(0, -80));
    expect(find.text('Guardar rascunho'), findsOneWidget);
    expect(find.text('Concluir alterações'), findsOneWidget);
    expect(find.text('Concluir parcela'), findsNothing);
  });
}
