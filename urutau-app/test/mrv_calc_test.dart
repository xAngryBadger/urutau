import 'package:flutter_test/flutter_test.dart';
import 'package:urutau/data/database.dart';
import 'package:urutau/services/mrv_calc_service.dart';

/// Planta mínima só pra alimentar o cálculo (o serviço só lê dapCm/alturaCm).
Planta _plantaFake({required double alturaCm, double? dapCm}) {
  return Planta(
    id: 1,
    uuid: 'fake',
    parcelaUuid: 'p1',
    especie: 'Teste',
    alturaCm: alturaCm,
    dapCm: dapCm,
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
}

void main() {
  group('MrvCalcService.calcularParcela (RQ-01..03)', () {
    test('árvore de 30 cm DAP x 20 m em parcela de 400 m²', () {
      // Chave 2014: AGB = 0.0673 * (0.6 * 30^2 * 20)^0.976
      // ρ·D²·H = 0.6*900*20 = 10800 -> AGB ≈ 581 kg
      final r = MrvCalcService.calcularParcela(
        plantas: [_plantaFake(alturaCm: 2000, dapCm: 30)],
        areaM2: 400,
      );
      final agbKg = r['agb_total_kg'] as double;
      expect(agbKg, closeTo(581, 30)); // tolerante a arredondamento
      // tCO2e do indivíduo: 581 kg * 0.47 * 44/12 / 1000 ≈ 1.00 t
      expect(r['tco2e_total'] as double, closeTo(1.0, 0.15));
      // por ha: 400 m² = 0.04 ha -> ≈ 25 tCO2e/ha pra 1 árvore
      expect(r['tco2e_ha'] as double, closeTo(25.0, 4.0));
      expect(r['fracao_carbono'], 0.47);
      expect(r['fator_co2'], closeTo(44 / 12, 0.001));
    });

    test('parcela vazia zera resultados sem quebrar', () {
      final r = MrvCalcService.calcularParcela(plantas: [], areaM2: 400);
      expect(r['tco2e_ha'], 0.0);
      expect(r['n_individuos'], 0);
    });

    test('planta sem DAP não entra no cálculo de AGB', () {
      final r = MrvCalcService.calcularParcela(
        plantas: [_plantaFake(alturaCm: 500, dapCm: null)],
        areaM2: 400,
      );
      expect(r['n_com_dap'], 0);
      expect(r['agb_total_kg'], 0.0);
      expect(r['tco2e_ha'], 0.0);
    });

    test('20 árvores de 20 cm em 400 m² dá ordem de grandeza plausível', () {
      final plantas = List.generate(
          20, (_) => _plantaFake(alturaCm: 1500, dapCm: 20));
      final r = MrvCalcService.calcularParcela(plantas: plantas, areaM2: 400);
      // AGB árvore 20cm/15m: 0.0673*(0.6*400*15)^0.976 ≈ 0.0673*3600^0.976 ≈ 205 kg
      // 20 × 205 = 4100 kg -> 4.1 t AGB -> tCO2e total ≈ 4.1*0.47*3.667 ≈ 7.1 t
      // por ha (0.04 ha) ≈ 176 tCO2e/ha — plausível pra restauração densa
      final t = r['tco2e_ha'] as double;
      expect(t, greaterThan(80));
      expect(t, lessThan(400));
    });
  });
}
