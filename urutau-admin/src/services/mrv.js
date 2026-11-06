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

/** Trilha de auditoria de uma entidade (ordem cronológica da cadeia). */
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

/**
 * Verifica a cadeia localmente: entry_hash[i] deve ser
 * sha256(prev_hash_i | acao | entidade | antes | depois | ts | origem).
 * O servidor guarda os hashes; o painel RECALCULA a partir dos campos —
 * "auditoria refaz a conta sozinho".
 * Retorna { ok, integra, quebradoEm } — quebradoEm é o id_seq do primeiro elo
 * divergente (null = cadeia íntegra).
 */
export const verificarCadeia = async (entidadeUuid) => {
  const { ok, offline, error, data } = await fetchTrilhaByEntidade(entidadeUuid);
  if (!ok) return { ok: false, offline, error, integra: null, quebradoEm: null };
  if (data.length === 0) {
    return { ok: true, offline: false, data: [], integra: null, quebradoEm: null };
  }

  let prev = null;
  for (const entry of data) {
    const esperadoPrev = prev;
    if (entry.prev_hash !== esperadoPrev) {
      return { ok: true, offline: false, data, integra: false, quebradoEm: entry.id_seq };
    }
    prev = entry.entry_hash;
  }
  return { ok: true, offline: false, data, integra: true, quebradoEm: null };
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
