import React, { useEffect, useState, useCallback, startTransition } from 'react';
import {
  ClipboardList,
  Scale,
  Flame,
  GraduationCap,
  ShieldCheck,
  AlertTriangle,
  CheckCircle2,
  XCircle,
  Loader2,
} from 'lucide-react';
import {
  fetchProjetos,
  fetchDesenhos,
  fetchCompetencias,
  fetchVerificacoes,
  registrarVerificacao,
  incertezaRealizada,
} from '../services/mrvProject';
import { useAuth } from '../context/AuthContext';
import EmptyState from '../components/ui/EmptyState';
import ServerOfflineBanner from '../components/ui/ServerOfflineBanner';
import { LoadingBlock } from '../components/ui/Loading';
import { formatIncerteza } from '../theme/tokens';

const TABS = [
  { id: 'desenho', label: 'Desenho amostral', icon: Scale },
  { id: 'risco', label: 'Risco de reversão', icon: Flame },
  { id: 'competencias', label: 'Competências', icon: GraduationCap },
  { id: 'verificacao', label: 'Verificação interna', icon: ShieldCheck },
];

const Field = ({ label, value, mono = false }) => (
  <div>
    <dt className="text-xs font-medium uppercase tracking-wide text-gray-500">{label}</dt>
    <dd className={`mt-0.5 text-sm text-gray-900 ${mono ? 'font-mono text-xs' : ''}`}>
      {value ?? '—'}
    </dd>
  </div>
);

const MrvProject = () => {
  const { user, isReadOnly } = useAuth();
  const [tab, setTab] = useState('desenho');
  const [projeto, setProjeto] = useState(null);
  const [desenhos, setDesenhos] = useState([]);
  const [competencias, setCompetencias] = useState([]);
  const [verificacoes, setVerificacoes] = useState([]);
  const [realizado, setRealizado] = useState(null);
  const [loading, setLoading] = useState(true);
  const [offline, setOffline] = useState(false);
  const [actionError, setActionError] = useState(null);
  const [actionOk, setActionOk] = useState(null);

  // form verificação interna
  const [escopo, setEscopo] = useState('projeto');
  const [conclusao, setConclusao] = useState('convergente');
  const [obs, setObs] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    const [projRes, desRes, compRes, verRes, realRes] = await Promise.all([
      fetchProjetos(),
      fetchDesenhos('LEGADO-PROJ-0000'),
      fetchCompetencias(),
      fetchVerificacoes('LEGADO-PROJ-0000'),
      incertezaRealizada(),
    ]);
    const anyOffline = [projRes, desRes, compRes, verRes].some((r) => !r.ok);
    setOffline(anyOffline && [projRes, desRes, compRes, verRes].some((r) => r.offline));
    setProjeto(projRes.ok ? projRes.data[0] || null : null);
    setDesenhos(desRes.ok ? desRes.data : []);
    setCompetencias(compRes.ok ? compRes.data : []);
    setVerificacoes(verRes.ok ? verRes.data : []);
    setRealizado(realRes.ok ? realRes.data : null);
    setLoading(false);
  }, []);

  useEffect(() => {
    startTransition(() => {
      load();
    });
  }, [load]);

  const registrar = async () => {
    setActionError(null);
    setActionOk(null);
    const res = await registrarVerificacao(
      { escopo, conclusao, observacoes: obs, usuarioUuid: user?.uuid || user?.email },
      { canWrite: !isReadOnly },
    );
    if (res.ok) {
      setActionOk(
        res.demo
          ? 'Verificação registrada (demo — não persistida; servidor ainda não existe).'
          : 'Verificação registrada.',
      );
      setObs('');
      await load();
    } else {
      setActionError(res.error);
    }
  };

  return (
    <div className="space-y-6">
      {offline && <ServerOfflineBanner onRetry={load} retrying={loading} />}

      <div>
        <h1 className="flex items-center gap-2 text-xl font-bold text-gray-900">
          <ClipboardList className="h-5 w-5 text-urutau-700" aria-hidden="true" />
          Projeto MRV
        </h1>
        <p className="text-sm text-gray-500">
          {projeto ? projeto.nome : 'Nenhum projeto encontrado'} · baseline, adicionalidade,
          amostragem, risco e competências — leitura e registro auditáveis.
        </p>
      </div>

      {/* abas */}
      <div role="tablist" aria-label="Seções do projeto" className="flex flex-wrap gap-2 border-b border-gray-200 pb-2">
        {TABS.map((t) => {
          const Icon = t.icon;
          const ativo = tab === t.id;
          return (
            <button
              key={t.id}
              role="tab"
              aria-selected={ativo}
              onClick={() => setTab(t.id)}
              className={`inline-flex items-center gap-2 rounded-lg px-3 py-2 text-sm font-medium transition-colors ${
                ativo ? 'bg-urutau-100 text-urutau-800' : 'text-gray-600 hover:bg-gray-100'
              }`}
            >
              <Icon className="h-4 w-4" aria-hidden="true" />
              {t.label}
            </button>
          );
        })}
      </div>

      {actionError && (
        <div className="rounded-lg border border-mrv-danger/40 bg-mrv-danger/10 px-4 py-3 text-sm text-mrv-danger" role="alert">
          {actionError}
        </div>
      )}
      {actionOk && (
        <div className="rounded-lg border border-mrv-success/40 bg-mrv-success/10 px-4 py-3 text-sm text-mrv-green" role="status">
          {actionOk}
        </div>
      )}

      {loading ? (
        <LoadingBlock label="Carregando projeto…" />
      ) : (
        <>
          {/* ── RT-04: baseline + adicionalidade (sempre visíveis) ── */}
          <section className="card">
            <h2 className="mb-4 text-base font-semibold text-gray-900">Baseline e adicionalidade (RT-04)</h2>
            <dl className="grid grid-cols-1 gap-4 sm:grid-cols-3">
              <Field label="Referência da baseline" value={projeto?.baseline_ref} mono />
              <Field label="Referência de adicionalidade" value={projeto?.adicionalidade_ref} mono />
              <Field label="Risco de reversão (RT-03)" value={projeto?.risco_reversao} />
            </dl>
          </section>

          {tab === 'desenho' && (
            <section className="card">
              <h2 className="mb-4 text-base font-semibold text-gray-900">
                Desenho amostral (RS-04/05)
              </h2>
              {desenhos.length === 0 ? (
                <EmptyState
                  icon={Scale}
                  title="Nenhum desenho amostral registrado"
                  description="Estratos e meta de incerteza vêm do app (mrv_projeto_service.salvarDesenhoAmostral)."
                  compact
                />
              ) : (
                <div className="space-y-5">
                  {desenhos.map((d) => {
                    const alvo = d.incerteza_alvo ?? null;
                    const feito = realizado?.ic95_pct ?? null;
                    const atingiu = alvo != null && feito != null ? feito <= alvo : null;
                    return (
                      <div key={d.id} className="rounded-lg border border-gray-200 p-4">
                        <dl className="grid grid-cols-1 gap-3 sm:grid-cols-3">
                          <Field label="Escopo" value={d.escopo_tipo} />
                          <Field label="Meta de incerteza (IC 95%)" value={alvo != null ? formatIncerteza(alvo) : '—'} />
                          <Field
                            label="Incerteza realizada"
                            value={feito != null ? formatIncerteza(feito) : '—'}
                          />
                        </dl>
                        <table className="mt-4 min-w-full divide-y divide-gray-200 text-sm">
                          <thead>
                            <tr className="table-header">
                              <th className="table-cell">Estrato</th>
                              <th className="table-cell">Área (ha)</th>
                              <th className="table-cell">Parcelas</th>
                            </tr>
                          </thead>
                          <tbody className="divide-y divide-gray-100">
                            {(d.estratos || []).map((e, i) => (
                              <tr key={`${e.nome}-${i}`}>
                                <td className="table-cell font-medium text-gray-900">{e.nome}</td>
                                <td className="table-cell">{e.area_ha}</td>
                                <td className="table-cell">{e.n_parcelas}</td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                        {atingiu != null && (
                          <p
                            className={`mt-3 inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-medium ${
                              atingiu
                                ? 'bg-mrv-success/10 text-mrv-green'
                                : 'bg-amber-100 text-amber-700'
                            }`}
                          >
                            {atingiu ? (
                              <CheckCircle2 className="h-3.5 w-3.5" aria-hidden="true" />
                            ) : (
                              <AlertTriangle className="h-3.5 w-3.5" aria-hidden="true" />
                            )}
                            {atingiu ? 'Meta de incerteza atingida' : 'Meta NÃO atingida — ampliar amostra'}
                          </p>
                        )}
                      </div>
                    );
                  })}
                </div>
              )}
            </section>
          )}

          {tab === 'risco' && (
            <section className="card">
              <h2 className="mb-4 text-base font-semibold text-gray-900">
                Risco de reversão (RT-03)
              </h2>
              <dl className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <Field label="Classificação" value={projeto?.risco_reversao} />
                <Field label="Fonte do histórico de fogo" value={projeto?.fonte_fogo_historico} />
              </dl>
              <p className="mt-4 text-sm text-gray-600">
                O alerta de fogo/desmatamento em si é gerado na workstation (ULTRA/satélite). O
                painel guarda o registro auditável da classificação e da fonte — como no app.
              </p>
            </section>
          )}

          {tab === 'competencias' && (
            <section className="card">
              <h2 className="mb-4 text-base font-semibold text-gray-900">Competências (RG-05)</h2>
              {competencias.length === 0 ? (
                <EmptyState icon={GraduationCap} title="Nenhuma competência registrada" compact />
              ) : (
                <table className="min-w-full divide-y divide-gray-200 text-sm">
                  <thead>
                    <tr className="table-header">
                      <th className="table-cell">Pessoa</th>
                      <th className="table-cell">Treinamento</th>
                      <th className="table-cell">Válida até</th>
                      <th className="table-cell">Situação</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-100">
                    {competencias.map((c) => {
                      const expirada = c.expirada ?? (c.valido_ate && new Date(c.valido_ate) < new Date());
                      return (
                        <tr key={c.id}>
                          <td className="table-cell font-medium text-gray-900">
                            {c.usuario_nome || c.usuario_uuid}
                          </td>
                          <td className="table-cell">{c.tipo_treinamento}</td>
                          <td className="table-cell">
                            {c.valido_ate ? new Date(c.valido_ate).toLocaleDateString('pt-BR') : '—'}
                          </td>
                          <td className="table-cell">
                            {expirada ? (
                              <span className="inline-flex items-center gap-1 rounded-full bg-mrv-danger/10 px-2 py-0.5 text-xs font-medium text-mrv-danger">
                                <XCircle className="h-3 w-3" aria-hidden="true" />
                                expirada
                              </span>
                            ) : (
                              <span className="inline-flex items-center gap-1 rounded-full bg-mrv-success/10 px-2 py-0.5 text-xs font-medium text-mrv-green">
                                <CheckCircle2 className="h-3 w-3" aria-hidden="true" />
                                válida
                              </span>
                            )}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              )}
            </section>
          )}

          {tab === 'verificacao' && (
            <section className="card">
              <h2 className="mb-4 text-base font-semibold text-gray-900">
                Verificação interna (RG-03)
              </h2>
              <div className="grid grid-cols-1 gap-3 sm:grid-cols-4">
                <div>
                  <label htmlFor="escopo-v" className="text-sm font-medium text-gray-700">
                    Escopo
                  </label>
                  <select
                    id="escopo-v"
                    value={escopo}
                    onChange={(e) => setEscopo(e.target.value)}
                    className="input-field mt-1 py-1.5 text-sm"
                  >
                    <option value="projeto">Projeto</option>
                    <option value="parcela">Parcela</option>
                    <option value="amostra">Amostra</option>
                  </select>
                </div>
                <div>
                  <label htmlFor="conc-v" className="text-sm font-medium text-gray-700">
                    Conclusão
                  </label>
                  <select
                    id="conc-v"
                    value={conclusao}
                    onChange={(e) => setConclusao(e.target.value)}
                    className="input-field mt-1 py-1.5 text-sm"
                  >
                    <option value="convergente">Convergente</option>
                    <option value="divergente">Divergente (abre incidente bloqueador)</option>
                  </select>
                </div>
                <div className="sm:col-span-2">
                  <label htmlFor="obs-v" className="text-sm font-medium text-gray-700">
                    Observações
                  </label>
                  <input
                    id="obs-v"
                    value={obs}
                    onChange={(e) => setObs(e.target.value)}
                    className="input-field mt-1 py-1.5 text-sm"
                    placeholder="O que foi conferido (obrigatório se divergente)"
                  />
                </div>
              </div>
              <button
                type="button"
                onClick={registrar}
                disabled={isReadOnly}
                className="btn-primary mt-3 disabled:opacity-60"
              >
                {conclusao === 'divergente' && <AlertTriangle className="h-4 w-4" aria-hidden="true" />}
                Registrar verificação
              </button>
              {isReadOnly && (
                <p className="mt-2 text-xs text-amber-700">
                  Perfil somente leitura: registrar verificação é privilégio de admin.
                </p>
              )}
              {conclusao === 'divergente' && (
                <p className="mt-2 text-xs text-gray-500">
                  No app, conclusão divergente abre incidente bloqueador (bloqueia crédito) —
                  a ação entra na trilha.
                </p>
              )}

              <h3 className="mb-2 mt-6 text-sm font-semibold text-gray-700">Registros</h3>
              {verificacoes.length === 0 ? (
                <EmptyState icon={ShieldCheck} title="Nenhuma verificação registrada" compact />
              ) : (
                <ul className="divide-y divide-gray-100 text-sm">
                  {verificacoes.map((v) => (
                    <li key={v.id} className="flex items-center justify-between gap-3 py-2">
                      <div>
                        <p className="font-medium text-gray-900">
                          {v.escopo} · {v.conclusao}
                        </p>
                        <p className="text-xs text-gray-500">
                          {v.verificador} ·{' '}
                          {v.created ? new Date(v.created).toLocaleString('pt-BR') : '—'}
                          {v.observacoes ? ` · ${v.observacoes}` : ''}
                        </p>
                      </div>
                      {v.conclusao === 'divergente' ? (
                        <span className="inline-flex items-center gap-1 rounded-full bg-mrv-danger/10 px-2 py-0.5 text-xs font-medium text-mrv-danger">
                          <XCircle className="h-3 w-3" aria-hidden="true" />
                          divergente
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1 rounded-full bg-mrv-success/10 px-2 py-0.5 text-xs font-medium text-mrv-green">
                          <CheckCircle2 className="h-3 w-3" aria-hidden="true" />
                          convergente
                        </span>
                      )}
                    </li>
                  ))}
                </ul>
              )}
            </section>
          )}
        </>
      )}
    </div>
  );
};

export default MrvProject;
