/**
 * RG-06/RG-03: incidentes bloqueadores de crédito.
 * Resolver espelha `mrv_projeto_service.dart:191` (resolucao + resolvido_em +
 * trilha 'incidente_resolvido') — a justificativa é OBRIGATÓRIA: sem ela o
 * bloqueio não pode ser liberado.
 */
import { pb } from './pocketbase';
import safeError from './logger';
import { USE_MOCK, mock } from './mock/demoData';
import { statusToken } from '../theme/tokens';

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
  if (isOfflineError(error)) return { ok: false, offline: true, data: [] };
  safeError(`${label}:`, error);
  return { ok: false, offline: false, error: String(error?.message || error), data: [] };
};

/** Lista incidentes (abertos por padrão) com a entidade afetada. */
export const fetchIncidentes = async ({ abertos = true, page = 1, perPage = 50 } = {}) => {
  if (USE_MOCK) {
    const todos = Object.values(mock.incidentes).flat();
    return {
      ok: true,
      offline: false,
      data: abertos ? todos.filter((i) => !i.resolvido_em) : todos,
      totalItems: todos.length,
    };
  }
  try {
    const result = await pb.collection('incidentes').getList(page, perPage, {
      filter: abertos ? 'resolvido_em = null || resolvido_em = ""' : '',
      sort: '-created',
      expand: 'parcela',
    });
    return { ok: true, offline: false, data: result.items, totalItems: result.totalItems };
  } catch (error) {
    return fail(error, 'fetchIncidentes');
  }
};

/**
 * Resolve um incidente. Regra RG-06: só admin (ou verificador sênior, quando
 * o servidor expuser o papel) pode liberar crédito; justificativa obrigatória.
 */
export const resolverIncidente = async (incidenteId, { justificativa, usuarioUuid: _u }, { canWrite }) => {
  if (!canWrite) {
    return { ok: false, error: 'Perfil somente leitura: resolver incidente é privilégio de admin.' };
  }
  if (!justificativa || justificativa.trim().length < 10) {
    return { ok: false, error: 'Justificativa obrigatória (mínimo 10 caracteres) — a liberação do crédito entra na trilha.' };
  }
  if (USE_MOCK) {
    // demo: marca localmente pra UX de sucesso
    const alvo = Object.values(mock.incidentes)
      .flat()
      .find((i) => i.id === incidenteId);
    if (alvo) alvo.resolvido_em = new Date().toISOString();
    return { ok: true, offline: false, demo: true };
  }
  try {
    await pb.collection('incidentes').update(incidenteId, {
      resolucao: justificativa.trim(),
      resolvido_em: new Date().toISOString(),
      resolvido_por: _u || 'painel',
    });
    return { ok: true, offline: false };
  } catch (error) {
    safeError('resolverIncidente', error);
    return { ok: false, offline: isOfflineError(error), error: String(error?.message || error) };
  }
};

/** Crédito de uma parcela: bloqueado se houver incidente bloqueador aberto. */
export const fetchStatusCredito = async (parcelaUuid) => {
  const res = await fetchIncidentes({ abertos: true });
  if (!res.ok) return { ok: false, offline: res.offline, bloqueado: null };
  // incidente GLOBAL (entidade vazia) bloqueia todas as parcelas
  const bloqueadores = res.data.filter(
    (i) => i.bloqueia_uso_para_credito === true &&
      (i.entidade_uuid === parcelaUuid || !i.entidade_uuid),
  );
  return { ok: true, offline: false, bloqueado: bloqueadores.length > 0, incidentes: bloqueadores };
};

export const severidadeToken = (severidade) => {
  const s = String(severidade || '').toLowerCase();
  if (s.includes('bloquead')) return { color: '#C62828', label: 'Bloqueadora' };
  if (s.includes('alta')) return { color: '#E8A13A', label: severidade };
  return statusToken(null, true);
};
