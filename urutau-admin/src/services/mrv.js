/**
 * Serviços MRV/auditoria do painel — o verificador (VVB) precisa enxergar o
 * rastro de cada número. Todas as funções são tolerantes a servidor ausente
 * (retornam { ok:false, offline:true } em vez de estourar): o PocketBase de
 * produção ainda não existe.
 *
 * Coleções esperadas (espelham o app):
 *  - parcelas        (status_parcela, prontaParaSync, protocolo_versao,
 *                     projeto_id, periodo_id, fotos_parcela, fotos_meta)
 *  - plantas         (dap_cm, altura_cm, especie, categoria, foto_especie)
 *  - calculos_mrv    (escopo_uuid=parcela, resultado JSON, incerteza JSON,
 *                     insumos_hash, equacao_uuid, pools_incluidos, status)
 *  - trilha_auditoria(acao, entidade_tipo, entidade_uuid, entry_hash,
 *                     prev_hash, ts_dispositivo, offset_relogio_ms, origem)
 *  - incidentes      (severidade, bloqueia_uso_para_credito, resolvido_em)
 *  - ativos_brutos   (sha256, sha256_verificado, dispositivo_uuid)
 */

import { pb } from './pocketbase';
import safeError from './logger';

const isOfflineError = (err) => {
  const msg = String(err?.message || '');
  return (
    err?.isAbort === true ||
    /failed to fetch|network|connect|timeout/i.test(msg) ||
    err?.status === 0 ||
    err?.status >= 502
  );
};

const fail = (error, label) => {
  if (isOfflineError(error)) {
    return { ok: false, offline: true, error: null, data: [] };
  }
  safeError(`${label}:`, error);
  return { ok: false, offline: false, error: String(error?.message || error), data: [] };
};

/** Cálculo MRV persistido de uma parcela (resultado + incerteza). */
export const fetchCalculoByParcela = async (parcelaId) => {
  try {
    const list = await pb.collection('calculos_mrv').getFullList({
      filter: `escopo_uuid = "${parcelaId}" && escopo_tipo = "parcela"`,
      sort: '-created',
    });
    return { ok: true, offline: false, data: list[0] || null };
  } catch (error) {
    return fail(error, 'fetchCalculoByParcela');
  }
};

/**
 * Trilha de auditoria de uma entidade (ordem cronológica da cadeia).
 * Só para EXIBIÇÃO: a verificação é global (ver verificarCadeiaGlobal).
 */
export const fetchTrilhaByEntidade = async (entidadeUuid, limit = 200) => {
  try {
    const list = await pb.collection('trilha_auditoria').getFullList({
      filter: `entidade_uuid = "${entidadeUuid}"`,
      sort: 'id_seq',
      perPage: limit,
    });
    return { ok: true, offline: false, data: list };
  } catch (error) {
    return fail(error, 'fetchTrilhaByEntidade');
  }
};

/** JSON canônico no formato do Dart (jsonEncode): double inteiro leva ".0". */
const dartJson = (value) => {
  if (value === null || value === undefined) return 'null';
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) return 'null';
    return Number.isInteger(value) ? `${value.toFixed(1)}` : String(value);
  }
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

const sha256Hex = async (text) => {
  const bytes = new TextEncoder().encode(text);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padLeft(2, '0')).join('');
};

/** ts_dispositivo normalizado como o Dart (DateTime.parse().toUtc().toIso8601String()). */
const tsIso = (raw) => {
  if (!raw) return null;
  const d = new Date(raw);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
};

/**
 * Monta o MESMO payload hasheado pelo app (database.dart logTrilha ~1779 e
 * sync_service.dart verificarCadeiaServidor ~217). Ordem das chaves é
 * contratual — mexer aqui quebra a verificação.
 */
const canonicalPayload = (rec, prevHash) => {
  const offset = rec.offset_relogio_ms;
  return dartJson({
    prev: prevHash,
    acao: rec.acao ?? null,
    entidade_tipo: rec.entidade_tipo ?? null,
    entidade_uuid: rec.entidade_uuid ?? null,
    usuario_uuid: rec.usuario_uuid ?? null,
    antes: rec.antes ?? null,
    depois: rec.depois ?? null,
    ts_dispositivo: tsIso(rec.ts_dispositivo),
    ...(offset != null ? { offset_relogio_ms: offset } : {}),
    origem: rec.origem ?? null,
  });
};

/**
 * Verifica a cadeia GLOBAL no servidor — espelha verificarCadeiaServidor do
 * app: baixa tudo em ordem, fecha os elos por prev_hash E RECALCULA
 * sha256(payload) comparando com entry_hash. Detecta elo removido E payload
 * adulterado. Retorna { ok, offline, integra, quebradoEm, motivo, total }.
 */
export const verificarCadeiaGlobal = async () => {
  let data;
  try {
    data = await pb.collection('trilha_auditoria').getFullList({ sort: 'id', batch: 500 });
  } catch (error) {
    return fail(error, 'verificarCadeiaGlobal');
  }
  if (!data || data.length === 0) {
    return { ok: true, offline: false, integra: null, quebradoEm: null, motivo: 'cadeia vazia', total: 0, data: [] };
  }

  let prev = 'GENESIS';
  for (const rec of data) {
    if ((rec.prev_hash ?? '') !== prev) {
      return {
        ok: true, offline: false, integra: false, quebradoEm: rec.id,
        motivo: `elo rompido: prev_hash deveria ser ${prev.slice(0, 12)}…, veio ${String(rec.prev_hash).slice(0, 12)}…`,
        total: data.length, data,
      };
    }
    if (rec.entry_hash == null) {
      return { ok: true, offline: false, integra: false, quebradoEm: rec.id, motivo: 'entry_hash ausente', total: data.length, data };
    }
    const esperado = await sha256Hex(canonicalPayload(rec, prev));
    if (rec.entry_hash !== esperado) {
      return {
        ok: true, offline: false, integra: false, quebradoEm: rec.id,
        motivo: `payload adulterado: sha256 recalculado ${esperado.slice(0, 12)}… ≠ entry_hash ${String(rec.entry_hash).slice(0, 12)}…`,
        total: data.length, data,
      };
    }
    prev = rec.entry_hash;
  }
  return { ok: true, offline: false, integra: true, quebradoEm: null, total: data.length, data };
};

/** Incidentes abertos (bloqueiam crédito enquanto resolvido_em for nulo). */
export const fetchIncidentesAbertos = async (parcelaUuid) => {
  try {
    const conditions = ['resolvido_em = null || resolvido_em = ""'];
    if (parcelaUuid) {
      conditions.push(`entidade_uuid = "${parcelaUuid}" || entidade_uuid = ""`);
    }
    const list = await pb.collection('incidentes').getFullList({
      filter: conditions.join(' && '),
      sort: '-created',
    });
    return { ok: true, offline: false, data: list };
  } catch (error) {
    return fail(error, 'fetchIncidentesAbertos');
  }
};

/**
 * Metadados do dossiê (ativos com hash) de uma parcela — o ZIP completo é
 * gerado pelo app; o painel mostra o manifesto e permite conferir o SHA-256
 * dos arquivos contra o que o app registrou.
 */
export const fetchAtivosByParcela = async (parcelaUuid) => {
  try {
    const list = await pb.collection('ativos_brutos').getFullList({
      filter: `entidade_uuid = "${parcelaUuid}"`,
      sort: 'created',
    });
    return { ok: true, offline: false, data: list };
  } catch (error) {
    return fail(error, 'fetchAtivosByParcela');
  }
};

/** Projetos MRV (baseline/adicionalidade/risco de reversão). */
export const fetchProjetosMrv = async () => {
  try {
    const list = await pb.collection('projetos_mrv').getFullList({ sort: 'nome' });
    return { ok: true, offline: false, data: list };
  } catch (error) {
    return fail(error, 'fetchProjetosMrv');
  }
};

/** Health check curtinho — usado pelo ServerOfflineBanner. */
export const checkServerHealth = async () => {
  try {
    await pb.health.check();
    return { ok: true, offline: false };
  } catch (error) {
    return { ok: false, offline: true, error: String(error?.message || error) };
  }
};
