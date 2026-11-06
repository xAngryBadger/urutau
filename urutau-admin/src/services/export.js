/**
 * R9 — exportação auditável, fonte ÚNICA de colunas.
 * Usado por Parcels, Photos, Reports e Dossiê (antes cada um montava seu
 * próprio CSV/Excel com colunas diferentes). Colunas obrigatórias incluem
 * status/GPS/protocolo/hashes — o que um VVB precisa no arquivo exportado.
 * CSV sai com BOM UTF-8 (Excel pt-BR abrir sem estragar acento).
 */
import { pb } from './pocketbase';

export const COLUNAS_AUDITAVEIS = [
  'parcela',
  'propriedade',
  'ut',
  'area_ha',
  'latitude',
  'longitude',
  'status_verificacao',
  'protocolo_versao',
  'projeto_id',
  'periodo_id',
  'usuario',
  'created',
  'fotos',
  'fotos_com_hash',
  'insumos_hash',
  'resultado_hash',
  'incerteza_pct',
  'ic95_tco2e_ha',
  'tco2e_ha',
  'credito_bloqueado',
];

const parseJson = (raw, fallback = null) => {
  if (raw == null || raw === '') return fallback;
  if (typeof raw === 'object') return raw;
  try {
    return JSON.parse(raw);
  } catch {
    return fallback;
  }
};

/** Monta as linhas canônicas a partir das parcelas + plantas + cálculos. */
export const buildRows = ({ parcels, plantas = [], calculos = [], calculosPorParcela }) => {
  const plantasPorParcela = new Map();
  for (const p of plantas) {
    const k = p.parcela || p.parcela_uuid || p.parcelaUuid;
    if (!k) continue;
    if (!plantasPorParcela.has(k)) plantasPorParcela.set(k, 0);
    plantasPorParcela.set(k, plantasPorParcela.get(k) + 1);
  }
  const calcPorParcela = new Map();
  for (const c of calculos) {
    calcPorParcela.set(c.escopo_uuid || c.parcela, c);
  }

  return parcels.map((p) => {
    const calc = (calculosPorParcela && calculosPorParcela.get(p.uuid || p.id)) ||
      calcPorParcela.get(p.uuid || p.parcela_uuid) ||
      calcPorParcela.get(p.id) ||
      null;
    const resultado = parseJson(calc?.resultado, {});
    const incerteza = parseJson(calc?.incerteza, {});
    const fotos = p.fotos_parcela || [];
    const areaM2 = p.areaM2 ?? p.area_m2;
    const areaHa = p.area_ha != null
      ? p.area_ha
      : (areaM2 != null ? Number(areaM2) / 10000 : '');
    return {
      parcela: p.id_parcela ?? '',
      propriedade: p.propertyCode || p.propriedade || '',
      ut: p.utCode || p.prop_ut || '',
      area_ha: areaHa,
      latitude: p.latitude ?? p.lat ?? '',
      longitude: p.longitude ?? p.long ?? '',
      status_verificacao: p.statusVerificacao ?? p.status_verificacao ?? p.status_parcela ?? '',
      protocolo_versao: p.protocoloVersao ?? p.protocolo_versao ?? '',
      projeto_id: p.projetoId ?? p.projeto_id ?? '',
      periodo_id: p.periodoId ?? p.periodo_id ?? '',
      usuario: p.displayUser ?? p.user ?? '',
      created: p.createdAt || p.created || '',
      fotos: fotos.length || 0,
      fotos_com_hash: '',
      insumos_hash: calc?.insumos_hash ?? '',
      resultado_hash: calc?.resultado_hash ?? resultado.resultado_hash ?? '',
      incerteza_pct: incerteza.incerteza_pct ?? '',
      ic95_tco2e_ha: incerteza.ic95_tco2e_ha ?? '',
      tco2e_ha: resultado.tco2e_ha ?? '',
      credito_bloqueado: p.credito_bloqueado ?? '',
    };
  });
};

const csvEscape = (val) => {
  const str = String(val ?? '');
  return /[",\n]/.test(str) ? `"${str.replace(/"/g, '""')}"` : str;
};

export const toCsv = (rows) => {
  const header = COLUNAS_AUDITAVEIS.join(',');
  const body = rows.map((r) => COLUNAS_AUDITAVEIS.map((c) => csvEscape(r[c])).join(',')).join('\r\n');
  return `${header}\r\n${body}`;
};

export const downloadCsv = (rows, filename = 'urutau_parcelas_auditavel.csv') => {
  // BOM UTF-8: Excel em pt-BR lê acentuação corretamente
  const blob = new Blob([`\uFEFF${toCsv(rows)}`], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
};

export const downloadExcel = async (rows, plantsRows = [], filename = 'urutau_parcelas_auditavel.xlsx') => {
  const XLSX = await import('xlsx');
  const wsParcelas = XLSX.utils.json_to_sheet(
    rows.map((r) => {
      const o = {};
      for (const c of COLUNAS_AUDITAVEIS) o[c] = r[c];
      return o;
    }),
  );
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, wsParcelas, 'Parcelas');
  if (plantsRows.length > 0) {
    XLSX.utils.book_append_sheet(wb, XLSX.utils.json_to_sheet(plantsRows), 'Plantas');
  }
  XLSX.writeFile(wb, filename);
};

/**
 * Exportação completa usada pelas páginas: busca plantas e cálculos do
 * servidor (ou mock) e baixa nas colunas canônicas.
 */
export const exportarParcelasAuditavel = async (parcels, { formato = 'csv' } = {}) => {
  const ids = parcels.map((p) => p.uuid || p.id);
  let plantas = [];
  let calculos = [];
  try {
    plantas = await pb.collection('plantas').getFullList({
      filter: ids.length ? ids.map((id) => `parcela = "${id}"`).join(' || ') : '',
      perPage: 500,
    });
  } catch { /* servidor ausente: exporta sem planta */ }
  try {
    calculos = await pb.collection('calculos_mrv').getFullList({ perPage: 500 });
  } catch { /* sem cálculo persistido */ }

  const rows = buildRows({ parcels, plantas, calculos });
  if (formato === 'xlsx') {
    await downloadExcel(rows);
  } else {
    downloadCsv(rows);
  }
  return { ok: true, total: rows.length };
};
