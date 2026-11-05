import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import '../data/database.dart';

/// RQ-01..RQ-03 — cálculo de carbono no próprio app (uso em campo).
///
/// Equação padrão: pantropical de Chave et al. (2014), forma potência:
///   AGB(kg) = a · (ρ · D² · H)^b
/// com ρ = densidade básica da madeira (g/cm³), D = DAP (cm), H = altura (m).
/// Valores de Chave 2014 para floresta tropical úmida: a = 0.0673, b = 0.976.
///
/// Cadeia até tCO₂e (padrão IPCC/SBCE):
///   carbono = AGB · 0,47 (fração de carbono)
///   CO₂e   = carbono · 44/12
///
/// A área da parcela entra em m² e o resultado sai em tCO₂e/ha.
class MrvCalcService {
  static const String codigoEquacaoPadrao = 'CHAVE-2014-PANTROPICAL';
  static const double aPadrao = 0.0673;
  static const double bPadrao = 0.976;
  static const double fracaoCarbono = 0.47;
  static const double fatorCo2 = 44 / 12; // 3.6667
  static const double densidadePadrao = 0.60; // g/cm³ — fallback quando a espécie não tem densidade no catálogo

  /// Resultado agregado de uma parcela.
  static Map<String, dynamic> calcularParcela({
    required List<Planta> plantas,
    required double areaM2,
    double? densidadeBasica,
  }) {
    final areaHa = areaM2 / 10000;
    double agbTotalKg = 0;
    int nComDap = 0;
    double somaAltura = 0;
    double somaDap = 0;

    for (final p in plantas) {
      final dap = p.dapCm;
      final alturaM = p.alturaCm / 100;
      somaAltura += alturaM;
      if (dap != null && dap > 0 && alturaM > 0) {
        final rho = densidadeBasica ?? densidadePadrao;
        // AGB em kg: a · (ρ·D²·H)^b
        final agb = aPadrao * pow(rho * dap * dap * alturaM, bPadrao);
        agbTotalKg += agb;
        nComDap++;
        somaDap += dap;
      }
    }

    final agbTHa = areaHa > 0 ? (agbTotalKg / 1000) / areaHa : 0.0;
    final carbonoTotalT = (agbTotalKg * fracaoCarbono) / 1000;
    final co2eTotalT = carbonoTotalT * fatorCo2;
    final tco2eHa = areaHa > 0 ? co2eTotalT / areaHa : 0.0;

    return {
      'n_individuos': plantas.length,
      'n_com_dap': nComDap,
      'altura_media_m': plantas.isEmpty ? 0.0 : somaAltura / plantas.length,
      'dap_medio_cm': nComDap == 0 ? 0.0 : somaDap / nComDap,
      'agb_total_kg': agbTotalKg,
      'agb_t_ha': agbTHa,
      'carbono_total_t': carbonoTotalT,
      'tco2e_total': co2eTotalT,
      'tco2e_ha': tco2eHa,
      'area_m2': areaM2,
      'area_ha': areaHa,
      'fracao_carbono': fracaoCarbono,
      'fator_co2': fatorCo2,
      'equacao': codigoEquacaoPadrao,
      'densidade_g_cm3': densidadeBasica ?? densidadePadrao,
    };
  }

  /// Garante que a equação padrão exista em `equacoes_alometricas`
  /// (uso interno no app de campo; status 'ativo'). Retorna o uuid.
  static Future<String> garantirEquacaoPadrao(AppDatabase db) async {
    final existente = await (db.select(db.equacoesAlometricas)
          ..where((t) => t.codigo.equals(codigoEquacaoPadrao)))
        .getSingleOrNull();
    if (existente != null) return existente.uuid;

    final uuid = const Uuid().v4();
    await db.into(db.equacoesAlometricas).insert(EquacoesAlometricasCompanion(
      uuid: drift.Value(uuid),
      codigo: drift.Value(codigoEquacaoPadrao),
      versao: drift.Value('1.0'),
      alvo: drift.Value('agb'),
      escopo: drift.Value('geral'),
      escopoValor: const drift.Value(null),
      bioma: drift.Value('Mata Atlantica / restauracao'),
      forma: drift.Value('potencia'),
      parametros: drift.Value(jsonEncode({'a': aPadrao, 'b': bPadrao})),
      variaveisEntrada: drift.Value(jsonEncode(['dap_cm', 'altura_m', 'densidade_g_cm3'])),
      densidadeAssumida: drift.Value(densidadePadrao),
      fonte: drift.Value('Chave et al. 2014, PNAS 111(31) — pantropical allometric equation'),
      uso: drift.Value('aprovada_interna'),
      status: drift.Value('ativo'),
    ));
    return uuid;
  }

  /// Persiste o cálculo da parcela em `calculos_mrv` + `resultados_amostra`.
  /// Retorna o uuid do cálculo.
  static Future<String> persistirCalculo({
    required AppDatabase db,
    required String parcelaUuid,
    required Map<String, dynamic> resultado,
    required double areaM2,
  }) async {
    final equacaoUuid = await garantirEquacaoPadrao(db);
    final calcUuid = const Uuid().v4();
    final agora = DateTime.now();

    await db.into(db.calculosMrv).insert(CalculosMrvCompanion(
      uuid: drift.Value(calcUuid),
      escopoTipo: drift.Value('parcela'),
      escopoUuid: drift.Value(parcelaUuid),
      equacaoUuid: drift.Value(equacaoUuid),
      pipelineVersao: drift.Value('app-2.0.0+2'),
      algorithmVersao: drift.Value('$codigoEquacaoPadrao-v1.0'),
      fracaoCarbono: drift.Value(fracaoCarbono),
      fatorCo2: drift.Value(fatorCo2),
      poolsIncluidos: drift.Value(jsonEncode(['agb_aerea'])),
      poolsNaoMedidos: drift.Value(jsonEncode(['raizes', 'serapilheira', 'solo', 'madeira_morta'])),
      resultado: drift.Value(jsonEncode(resultado)),
      unidadeArea: drift.Value(areaM2),
      status: drift.Value('valido'),
      executadoEm: drift.Value(agora),
    ));

    await db.into(db.resultadosAmostra).insert(ResultadosAmostraCompanion(
      uuid: drift.Value(const Uuid().v4()),
      amostraUuid: drift.Value(parcelaUuid),
      alturaMediaM: drift.Value(resultado['altura_media_m'] as double),
      dapMedioCm: drift.Value(resultado['dap_medio_cm'] as double),
      agbTHa: drift.Value(resultado['agb_t_ha'] as double),
      tco2eHa: drift.Value(resultado['tco2e_ha'] as double),
      nIndividuos: drift.Value(resultado['n_individuos'] as int),
    ));

    return calcUuid;
  }
}
