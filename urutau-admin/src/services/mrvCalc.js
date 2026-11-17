/**
 * PORT FIEL de `urutau-app/lib/services/mrv_calc_service.dart` — o verificador
 * "refaz a conta sozinho" no navegador e compara com o hash gravado pelo app.
 * Qualquer divergência de parâmetro aqui é BUG: mantenha espelhado com o Dart.
 *
 * Equação: Chave et al. 2014 (pantropical, potência) AGB(kg) = a·(ρ·D²·H)^b
 *   a=0.0673, b=0.976, ρ fallback 0.60 g/cm³, FC=0.47, fator CO₂=44/12.
 */

export const EQUACAO_PADRAO = 'CHAVE-2014-PANTROPICAL';
export const A_PADRAO = 0.0673;
export const B_PADRAO = 0.976;
export const FRACAO_CARBONO = 0.47;
export const FATOR_CO2 = 44 / 12;
export const DENSIDADE_PADRAO = 0.60;

const T95 = {
  1: 12.706, 2: 4.303, 3: 3.182, 4: 2.776, 5: 2.571, 6: 2.447, 7: 2.365,
  8: 2.306, 9: 2.262, 10: 2.228, 11: 2.201, 12: 2.179, 13: 2.160,
  14: 2.145, 15: 2.131, 16: 2.120, 17: 2.110, 18: 2.101, 19: 2.093,
  20: 2.086, 21: 2.080, 22: 2.074, 23: 2.069, 24: 2.064, 25: 2.060,
  26: 2.056, 27: 2.052, 28: 2.048, 29: 2.045, 30: 2.042,
};

const tCritico95 = (gl) => (gl >= 30 ? 1.96 : T95[gl] ?? 1.96);

/** Número no formato do jsonEncode do Dart (double inteiro leva ".0"). */
const dartNum = (v) => {
  if (v === null || v === undefined) return 'null';
  if (typeof v === 'number') {
    if (!Number.isFinite(v)) return 'null';
    return Number.isInteger(v) ? v.toFixed(1) : String(v);
  }
  return String(v);
};

const dartJson = (value) => {
  if (value === null || value === undefined) return 'null';
  if (typeof value === 'number') return dartNum(value);
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  if (typeof value === 'string') return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(dartJson).join(',')}]`;
  if (typeof value === 'object') {
    const parts = Object.entries(value)
      .filter(([, v]) => v !== undefined)
      .map(([k, v]) => `${JSON.stringify(k)}:${dartJson(v)}`);
    return `{${parts.join(',')}}`;
  }
  return 'null';
};

/** SHA-256 hex via WebCrypto (navegador). */
export const sha256Hex = async (text) => {
  const bytes = new TextEncoder().encode(text);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(digest)]
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
};

/** Espelha MrvCalcService.calcularIncerteza (RS-03). */
export function calcularIncerteza(tco2eHaPorIndividuo, mediaTHa) {
  const n = tco2eHaPorIndividuo.length;
  if (n < 2 || mediaTHa <= 0) {
    return {
      n,
      desvio_padrao_tco2e_ha: 0.0,
      erro_padrao_tco2e_ha: 0.0,
      ic95_tco2e_ha: 0.0,
      incerteza_pct: null,
      nivel_confianca: 0.95,
      metodo: 't-student',
      observacao: n < 2 ? 'n < 2: intervalo de confianca nao calculavel' : 'media <= 0',
    };
  }
  const media = tco2eHaPorIndividuo.reduce((a, b) => a + b, 0) / n;
  const variancia =
    tco2eHaPorIndividuo.map((x) => (x - media) ** 2).reduce((a, b) => a + b, 0) /
    (n - 1);
  const dp = Math.sqrt(variancia);
  const ep = dp / Math.sqrt(n);
  const ic95 = tCritico95(n - 1) * ep;
  return {
    n,
    media_tco2e_ha: media,
    desvio_padrao_tco2e_ha: dp,
    erro_padrao_tco2e_ha: ep,
    ic95_tco2e_ha: ic95,
    incerteza_pct: (100 * ic95) / mediaTHa,
    nivel_confianca: 0.95,
    metodo: `t-student (gl=${n - 1})`,
  };
}

/**
 * Espelha calcularParcela. `plantas`: [{uuid, especie, dap_cm, altura_cm,
 * autor_uuid}] — como o app grava em `insumos`.
 */
export function calcularParcela({ plantas, areaM2, densidadesPorEspecie }) {
  const areaHa = areaM2 / 10000;
  let agbTotalKg = 0;
  let nComDap = 0;
  let somaAltura = 0;
  let somaDap = 0;
  const tco2eHaPorIndividuo = [];
  let usouCatalogo = false;

  for (const p of plantas) {
    const dap = p.dap_cm;
    const alturaM = p.altura_cm / 100;
    somaAltura += alturaM;
    if (dap != null && dap > 0 && alturaM > 0) {
      const rhoCatalogo = densidadesPorEspecie?.[String(p.especie).toLowerCase().trim()];
      const rho = rhoCatalogo ?? DENSIDADE_PADRAO;
      if (rhoCatalogo != null) usouCatalogo = true;
      const agb = A_PADRAO * (rho * dap * dap * alturaM) ** B_PADRAO;
      agbTotalKg += agb;
      nComDap++;
      somaDap += dap;
      if (areaHa > 0) tco2eHaPorIndividuo.push((agb * FRACAO_CARBONO * FATOR_CO2 / 1000) / areaHa);
    }
  }

  const agbTHa = areaHa > 0 ? agbTotalKg / 1000 / areaHa : 0;
  const carbonoTotalT = (agbTotalKg * FRACAO_CARBONO) / 1000;
  const co2eTotalT = carbonoTotalT * FATOR_CO2;
  const tco2eHa = areaHa > 0 ? co2eTotalT / areaHa : 0;
  const incerteza = calcularIncerteza(tco2eHaPorIndividuo, tco2eHa);

  const insumos = plantas.map((p) => {
    const rhoCatalogo = densidadesPorEspecie?.[String(p.especie).toLowerCase().trim()];
    return {
      uuid: p.uuid,
      especie: p.especie,
      dap_cm: p.dap_cm,
      altura_cm: p.altura_cm,
      autor_uuid: p.autor_uuid ?? null,
      densidade_g_cm3: rhoCatalogo ?? DENSIDADE_PADRAO,
      densidade_fonte: rhoCatalogo != null
        ? 'catalogo_especies'
        : 'fallback_0.60',
    };
  });

  const base = {
    n_individuos: plantas.length,
    n_com_dap: nComDap,
    altura_media_m: plantas.length === 0 ? 0.0 : somaAltura / plantas.length,
    dap_medio_cm: nComDap === 0 ? 0.0 : somaDap / nComDap,
    agb_total_kg: agbTotalKg,
    agb_t_ha: agbTHa,
    carbono_total_t: carbonoTotalT,
    tco2e_total: co2eTotalT,
    tco2e_ha: tco2eHa,
    area_m2: areaM2,
    area_ha: areaHa,
    fracao_carbono: FRACAO_CARBONO,
    fator_co2: FATOR_CO2,
    equacao: EQUACAO_PADRAO,
    densidade_g_cm3: DENSIDADE_PADRAO,
    densidade_fonte: usouCatalogo ? 'catalogo_especies' : 'fallback_0.60',
    incerteza,
    incerteza_pct: incerteza.incerteza_pct,
    ic95_tco2e_ha: incerteza.ic95_tco2e_ha,
    insumos,
  };

  // O app grava insumos_hash dentro do mapa antes do resultado_hash; aqui o
  // hash é ASSÍNCRONO (WebCrypto) — use hashInsumos(resultado) à parte.
  return base;
}

/** Espelha MrvCalcService.hashInsumos (JSON canônico do Dart + SHA-256). */
export async function hashInsumos(resultado) {
  const canon = dartJson({
    area_m2: resultado.area_m2,
    equacao: resultado.equacao,
    densidade_g_cm3: resultado.densidade_g_cm3,
    fracao_carbono: resultado.fracao_carbono,
    fator_co2: resultado.fator_co2,
    insumos: resultado.insumos,
  });
  return sha256Hex(canon);
}
