// RQ-03: densidade por espécie do catálogo entra no cálculo e a fonte é registrada
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urutau/data/database.dart';
import 'package:urutau/services/mrv_calc_service.dart';

Planta _planta(String especie) => Planta(
      id: 1,
      uuid: 'pl-$especie',
      parcelaUuid: 'p1',
      especie: especie,
      alturaCm: 1000, // 10 m
      dapCm: 30,
      categoria: 1,
      synced: false,
      fotoEspeciePath: null,
      fotoAusente: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      deletedAt: null,
      serverPlantaId: null,
      parcelaServerId: null,
      arquivoEstado: 'capturado',
      enviadoVerificadoEm: null,
    );

void main() {
  test('RQ-03: densité do catálogo é usada e a fonte fica registrada', () {
    final r = MrvCalcService.calcularParcela(
      plantas: [_planta('Eucalyptus grandis')],
      areaM2: 400,
      densidadesPorEspecie: {'eucalyptus grandis': 0.55},
    );
    expect(r['densidade_fonte'], 'catalogo_especies');
    expect((r['insumos'] as List).first['densidade_g_cm3'], 0.55);
    expect((r['insumos'] as List).first['densidade_fonte'], 'catalogo_especies');
  });

  test('RQ-03: sem catálogo -> fallback 0.60 explícito na fonte', () {
    final r = MrvCalcService.calcularParcela(
      plantas: [_planta('Desconhecida')],
      areaM2: 400,
    );
    expect(r['densidade_fonte'], 'fallback_0.60');
    expect(r['densidade_g_cm3'], 0.60);
    expect((r['insumos'] as List).first['densidade_fonte'], 'fallback_0.60');
  });

  test('RQ-03: hash muda quando a densidade muda (insumos incluem densidade)', () {
    final a = MrvCalcService.calcularParcela(
        plantas: [_planta('X')], areaM2: 400, densidadesPorEspecie: {'x': 0.50});
    final b = MrvCalcService.calcularParcela(
        plantas: [_planta('X')], areaM2: 400, densidadesPorEspecie: {'x': 0.70});
    expect(a['insumos_hash'], isNot(b['insumos_hash']));
    expect(a['resultado_hash'], isNot(b['resultado_hash']));
  });

  test('RQ-03: catálogo persiste densidade na tabela especies_catalogo', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
    addTearDown(db.close);
    await db.into(db.especiesCatalogo).insert(EspeciesCatalogoCompanion.insert(
          uuid: 'esp-1',
          nomeCientifico: 'Eucalyptus grandis',
          nomePopular: const drift.Value('eucalipto'),
          origem: const drift.Value('catalogo'),
          densidadeBasica: const drift.Value(0.55),
          densidadeFonte: const drift.Value('IPCC/GPD wood density db'),
        ));
    final e = await (db.select(db.especiesCatalogo)).getSingle();
    expect(e.densidadeBasica, 0.55);
    expect(e.densidadeFonte, contains('wood density'));
  });
}
