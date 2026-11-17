import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
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

  /// t de Student bicaudal 95% (t_0.975) por graus de liberdade 1..30;
  /// acima de 30 usa 1.96 (aproximação normal).
  static const Map<int, double> _t95 = {
    1: 12.706, 2: 4.303, 3: 3.182, 4: 2.776, 5: 2.571, 6: 2.447, 7: 2.365,
    8: 2.306, 9: 2.262, 10: 2.228, 11: 2.201, 12: 2.179, 13: 2.160,
    14: 2.145, 15: 2.131, 16: 2.120, 17: 2.110, 18: 2.101, 19: 2.093,
    20: 2.086, 21: 2.080, 22: 2.074, 23: 2.069, 24: 2.064, 25: 2.060,
    26: 2.056, 27: 2.052, 28: 2.048, 29: 2.045, 30: 2.042,
  };

  static double _tCritico95(int gl) => gl >= 30 ? 1.96 : (_t95[gl] ?? 1.96);

  /// Incerteza amostral (RS-03): a partir dos tCO₂e/ha por individuo,
  /// calcula média, desvio padrão amostral, erro padrão e IC 95% (t de
  /// Student), propagando o ±% para o tCO₂e/ha da parcela.
  static Map<String, dynamic> calcularIncerteza(
      List<double> tco2eHaPorIndividuo, double mediaTHa) {
    final n = tco2eHaPorIndividuo.length;
    if (n < 2 || mediaTHa <= 0) {
      return {
        'n': n,
        'desvio_padrao_tco2e_ha': 0.0,
        'erro_padrao_tco2e_ha': 0.0,
        'ic95_tco2e_ha': 0.0,
        'incerteza_pct': null,
        'nivel_confianca': 0.95,
        'metodo': 't-student',
        'observacao': n < 2
            ? 'n < 2: intervalo de confianca nao calculavel'
            : 'media <= 0',
      };
    }
    final media = tco2eHaPorIndividuo.reduce((a, b) => a + b) / n;
    final variancia =
        tco2eHaPorIndividuo.map((x) => pow(x - media, 2)).reduce((a, b) => a + b) /
            (n - 1);
    final dp = sqrt(variancia);
    final ep = dp / sqrt(n);
    final ic95 = _tCritico95(n - 1) * ep;
    return {
      'n': n,
      'media_tco2e_ha': media,
      'desvio_padrao_tco2e_ha': dp,
      'erro_padrao_tco2e_ha': ep,
      'ic95_tco2e_ha': ic95,
      'incerteza_pct': 100 * ic95 / mediaTHa,
      'nivel_confianca': 0.95,
      'metodo': 't-student (gl=${n - 1})',
    };
  }

  /// Resultado agregado de uma parcela.
  static Map<String, dynamic> calcularParcela({
    required List<Planta> plantas,
    required double areaM2,
    double? densidadeBasica,
    Map<String, double>? densidadesPorEspecie, // RQ-03: chave = nome em lowercase
  }) {
    final areaHa = areaM2 / 10000;
    double agbTotalKg = 0;
    int nComDap = 0;
    double somaAltura = 0;
    double somaDap = 0;
    final tco2eHaPorIndividuo = <double>[];
    bool usouCatalogo = false;

    for (final p in plantas) {
      final dap = p.dapCm;
      final alturaM = p.alturaCm / 100;
      somaAltura += alturaM;
      if (dap != null && dap > 0 && alturaM > 0) {
        // RQ-03: densidade da espécie vinda do catálogo; senão, densidade
        // única informada; senão, fallback 0.60 (e a fonte diz isso)
        final rhoCatalogo = densidadesPorEspecie?[p.especie.toLowerCase().trim()];
        final rho = rhoCatalogo ?? densidadeBasica ?? densidadePadrao;
        if (rhoCatalogo != null) usouCatalogo = true;
        // AGB em kg: a · (ρ·D²·H)^b
        final agb = aPadrao * pow(rho * dap * dap * alturaM, bPadrao);
        agbTotalKg += agb;
        nComDap++;
        somaDap += dap;
        if (areaHa > 0) {
          tco2eHaPorIndividuo
              .add((agb * fracaoCarbono * fatorCo2 / 1000) / areaHa);
        }
      }
    }

    final agbTHa = areaHa > 0 ? (agbTotalKg / 1000) / areaHa : 0.0;
    final carbonoTotalT = (agbTotalKg * fracaoCarbono) / 1000;
    final co2eTotalT = carbonoTotalT * fatorCo2;
    final tco2eHa = areaHa > 0 ? co2eTotalT / areaHa : 0.0;

    // RS-03: incerteza amostral propagada ao tCO2e/ha (promessa do pitch:
    // "o sistema diz o quanto confia no numero").
    final incerteza = calcularIncerteza(tco2eHaPorIndividuo, tco2eHa);

    // RQ-04: insumos brutos que alimentaram o cálculo (o auditor refaz a conta)
    final insumos = plantas
        .map((p) => {
              'uuid': p.uuid,
              'especie': p.especie,
              'dap_cm': p.dapCm,
              'altura_cm': p.alturaCm,
              'autor_uuid': p.autorUuid,
              // RQ-03: densidade usada neste indivíduo + fonte dela
              'densidade_g_cm3': densidadesPorEspecie?[p.especie.toLowerCase().trim()] ??
                  densidadeBasica ??
                  densidadePadrao,
              'densidade_fonte': densidadesPorEspecie?[p.especie.toLowerCase().trim()] != null
                  ? 'catalogo_especies'
                  : (densidadeBasica != null ? 'informada' : 'fallback_0.60'),
            })
        .toList();

    final base = <String, dynamic>{
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
      // RQ-03: fonte da densidade — o auditor vê se foi catálogo ou fallback
      'densidade_fonte': usouCatalogo
          ? 'catalogo_especies'
          : (densidadeBasica != null ? 'informada' : 'fallback_0.60'),
      'incerteza': incerteza,
      'incerteza_pct': incerteza['incerteza_pct'],
      'ic95_tco2e_ha': incerteza['ic95_tco2e_ha'],
      'insumos': insumos,
    };

    // RQ-04: hash dos insumos e hash do resultado (sobre o map SEM as chaves
    // de hash — senão vira auto-referência).
    final insumosHash = hashInsumos(base);
    base['insumos_hash'] = insumosHash;
    base['resultado_hash'] =
        sha256.convert(utf8.encode(jsonEncode(base))).toString();
    return base;
  }

  /// RQ-04: hash SHA-256 canônico dos insumos do cálculo (área, equacao,
  /// parametros e cada planta medida). Muda qualquer DAP/altura -> muda o hash.
  static String hashInsumos(Map<String, dynamic> resultado) {
    final canon = jsonEncode({
      'area_m2': resultado['area_m2'],
      'equacao': resultado['equacao'],
      'densidade_g_cm3': resultado['densidade_g_cm3'],
      'fracao_carbono': resultado['fracao_carbono'],
      'fator_co2': resultado['fator_co2'],
      'insumos': resultado['insumos'],
    });
    return sha256.convert(utf8.encode(canon)).toString();
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

    // RG-06: incidente bloqueador aberto (desta parcela ou global) bloqueia
    // o uso do resultado para crédito — o cálculo é gravado como evidência,
    // mas com status 'bloqueado_incidente'.
    final bloqueado = await db.haIncidenteBloqueadorAberto(parcelaUuid);
    if (bloqueado) {
      await db.logTrilha(
        acao: 'credito_bloqueado',
        entidadeTipo: 'calculo_mrv',
        entidadeUuid: calcUuid,
        depois: 'incidente bloqueador aberto — resultado não pode virar crédito',
        origem: 'app',
      );
    }

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
      // RQ-04: hash dos insumos vai na coluna dedicada; o resultado JSON já
      // carrega 'insumos_hash' e 'resultado_hash' (calculados no calcularParcela).
      insumosHash: drift.Value(resultado['insumos_hash'] as String?),
      resultado: drift.Value(jsonEncode(resultado)),
      // RS-03: incerteza amostral persistida junto ao cálculo (JSON).
      incerteza: resultado['incerteza'] != null
          ? drift.Value(jsonEncode(resultado['incerteza']))
          : const drift.Value(null),
      unidadeArea: drift.Value(areaM2),
      // RG-06
      status: drift.Value(bloqueado ? 'bloqueado_incidente' : 'valido'),
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
      // RS-03
      incerteza: resultado['incerteza'] != null
          ? drift.Value(jsonEncode(resultado['incerteza']))
          : const drift.Value(null),
    ));

    return calcUuid;
  }
}
