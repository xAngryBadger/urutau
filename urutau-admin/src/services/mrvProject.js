/**
 * R11 — Projeto MRV no painel: desenho amostral (RS-04/05), risco de
 * reversão (RT-03), competências (RG-05) e verificação interna (RG-03).
 * Espelha `mrv_projeto_service.dart`; a verificação divergente abre
 * incidente bloqueador (regra do app). Nada é recalculado aqui — o painel
 * lê, exibe e registra.
 */
import { pb } from './pocketbase';
import safeError from './logger';
import { USE_MOCK } from './mock/demoData';

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

const MOCK = {
  projetos: [
    {
      id: 'LEGADO-PROJ-0000',
      nome: 'Projeto P0 (baseline)',
      baseline_ref: 'inventario-florestal-2024-v1.json',
      adicionalidade_ref: 'cenario-continua-uso-do-solo.pdf',
      risco_reversao: 'medio',
      fonte_fogo_historico: 'Mapa histórico de queimadas INPE 2015-2025 (demo)',
    },
  ],
  desenhos: [
    {
      id: 'demo-desenho-1',
      projeto_uuid: 'LEGADO-PROJ-0000',
      escopo_tipo: 'projeto',
      estratos: [
        { nome: 'floresta madura', area_ha: 12.4, n_parcelas: 4 },
        { nome: 'regeneração', area_ha: 6.1, n_parcelas: 2 },
      ],
      incerteza_alvo: 15.0,
      created: '2026-10-01T12:00:00.000Z',
    },
  ],
  competencias: [
    { id: 'demo-comp-1', usuario_uuid: 'demo-ana', usuario_nome: 'Ana Ribeiro', tipo_treinamento: 'SOP-MRV-V1 (medição de campo)', valido_ate: '2027-06-01', evidencia_uuid: null },
    { id: 'demo-comp-2', usuario_uuid: 'demo-carlos', usuario_nome: 'Carlos Lima', tipo_treinamento: 'SOP-MRV-V1 (medição de campo)', valido_ate: '2026-05-01', evidencia_uuid: null },
  ],
  verificacoes: [
    { id: 'demo-ver-1', projeto_uuid: 'LEGADO-PROJ-0000', escopo: 'projeto', conclusao: 'convergente', verificador: 'VVB Externa', observacoes: 'Amostra conferida', created: '2026-10-20T09:00:00.000Z' },
  ],
};

export const fetchProjetos = async () => {
  if (USE_MOCK) return { ok: true, offline: false, data: MOCK.projetos };
  try {
    const data = await pb.collection('projetos_mrv').getFullList({ sort: 'nome' });
    return { ok: true, offline: false, data };
  } catch (error) {
    return fail(error, 'fetchProjetos');
  }
};

export const fetchDesenhos = async (projetoUuid) => {
  if (USE_MOCK) {
    return { ok: true, offline: false, data: MOCK.desenhos.filter((d) => d.projeto_uuid === projetoUuid) };
  }
  try {
    const data = await pb.collection('desenho_amostral').getFullList({
      filter: `escopo_uuid = "${projetoUuid}"`,
      sort: '-created',
    });
    return { ok: true, offline: false, data };
  } catch (error) {
    return fail(error, 'fetchDesenhos');
  }
};

export const fetchCompetencias = async () => {
  if (USE_MOCK) {
    const hoje = new Date();
    return {
      ok: true,
      offline: false,
      data: MOCK.competencias.map((c) => ({
        ...c,
        expirada: new Date(c.valido_ate) < hoje,
      })),
    };
  }
  try {
    const data = await pb.collection('competencias').getFullList({ sort: 'valido_ate' });
    return { ok: true, offline: false, data };
  } catch (error) {
    return fail(error, 'fetchCompetencias');
  }
};

export const fetchVerificacoes = async (projetoUuid) => {
  if (USE_MOCK) {
    return { ok: true, offline: false, data: MOCK.verificacoes.filter((v) => v.projeto_uuid === projetoUuid) };
  }
  try {
    const data = await pb.collection('verificacoes_internas').getFullList({
      filter: `projeto_uuid = "${projetoUuid}"`,
      sort: '-created',
    });
    return { ok: true, offline: false, data };
  } catch (error) {
    return fail(error, 'fetchVerificacoes');
  }
};

/** RG-03: registra verificação interna. Divergente → o painel avisa que o app abre incidente bloqueador. */
export const registrarVerificacao = async (
  { escopo, conclusao, observacoes, usuarioUuid },
  { canWrite },
) => {
  if (!canWrite) {
    return { ok: false, error: 'Perfil somente leitura: registrar verificação é privilégio de admin.' };
  }
  if (conclusao === 'divergente' && (!observacoes || observacoes.trim().length < 10)) {
    return { ok: false, error: 'Conclusão divergente exige observações (mínimo 10 caracteres).' };
  }
  if (USE_MOCK) {
    MOCK.verificacoes.unshift({
      id: `demo-ver-${Date.now()}`,
      projeto_uuid: 'LEGADO-PROJ-0000',
      escopo,
      conclusao,
      verificador: usuarioUuid || 'painel',
      observacoes,
      created: new Date().toISOString(),
    });
    return { ok: true, offline: false, demo: true };
  }
  try {
    await pb.collection('verificacoes_internas').create({
      projeto_uuid: 'LEGADO-PROJ-0000',
      escopo,
      conclusao,
      observacoes: observacoes || '',
      verificador: usuarioUuid || 'painel',
    });
    return { ok: true, offline: false };
  } catch (error) {
    safeError('registrarVerificacao', error);
    return { ok: false, offline: isOfflineError(error), error: String(error?.message || error) };
  }
};

/** Extrai o IC95 realizado dos cálculos de um conjunto de parcelas (mock: dos cálculos demo). */
export const incertezaRealizada = async () => {
  if (USE_MOCK) return { ok: true, offline: false, data: { ic95_pct: 60.21, n_total: 3 } };
  try {
    const calculos = await pb.collection('calculos_mrv').getFullList({ sort: '-created', perPage: 500 });
    if (calculos.length === 0) return { ok: true, offline: false, data: null };
    // pior margem do conjunto (conservador)
    let pior = null;
    let nTotal = 0;
    for (const c of calculos) {
      const inc = JSON.parse(c.incerteza || '{}');
      if (inc.incerteza_pct != null && (pior == null || inc.incerteza_pct > pior)) pior = inc.incerteza_pct;
      nTotal += inc.n || 0;
    }
    return { ok: true, offline: false, data: { ic95_pct: pior, n_total: nTotal, n_calculos: calculos.length } };
  } catch (error) {
    return fail(error, 'incertezaRealizada');
  }
};
