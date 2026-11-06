import React, { useEffect, useState, useCallback, startTransition } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import {
  ArrowLeft,
  ShieldCheck,
  ShieldAlert,
  Calculator,
  Fingerprint,
  AlertTriangle,
  TreePine,
  MapPin,
  Clock,
  FileJson,
  Link2,
  CheckCircle2,
  XCircle,
} from 'lucide-react';
import { fetchParcelById, fetchPlantsByParcel } from '../services/pocketbase';
import {
  fetchCalculoByParcela,
  fetchTrilhaByEntidade,
  verificarCadeia,
  fetchIncidentesAbertos,
  fetchAtivosByParcela,
} from '../services/mrv';
import { formatTco2e, formatIncerteza, shortHash } from '../theme/tokens';
import StatusBadge from '../components/ui/StatusBadge';
import EmptyState from '../components/ui/EmptyState';
import ServerOfflineBanner from '../components/ui/ServerOfflineBanner';
import { LoadingBlock } from '../components/ui/Loading';
import safeError from '../services/logger';

const Section = ({ icon, title, children, action }) => {
  const Icon = icon;
  return (
    <section className="card">
      <div className="mb-4 flex items-center justify-between gap-3">
        <h2 className="flex items-center gap-2 text-base font-semibold text-gray-900">
          <Icon className="h-5 w-5 text-urutau-700" aria-hidden="true" />
          {title}
        </h2>
        {action}
      </div>
      {children}
    </section>
  );
};

const HashPill = ({ value, label }) => (
  <span
    className="inline-flex items-center gap-1 rounded-md bg-gray-100 px-2 py-0.5 font-mono text-xs text-gray-700"
    title={value ? `${label}: ${value}` : `${label}: —`}
  >
    <Fingerprint className="h-3 w-3" aria-hidden="true" />
    {shortHash(value)}
  </span>
);

const parseJson = (raw, fallback = null) => {
  if (raw == null) return fallback;
  if (typeof raw === 'object') return raw;
  try {
    return JSON.parse(raw);
  } catch {
    return fallback;
  }
};

const ParcelaAuditoria = () => {
  const { id } = useParams();
  const navigate = useNavigate();

  const [parcel, setParcel] = useState(null);
  const [plants, setPlants] = useState([]);
  const [calculo, setCalculo] = useState(null);
  const [ativos, setAtivos] = useState([]);
  const [incidentes, setIncidentes] = useState([]);
  const [cadeia, setCadeia] = useState(null);
  const [loading, setLoading] = useState(true);
  const [offline, setOffline] = useState(false);
  const [error, setError] = useState(null);
  const [verificando, setVerificando] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const p = await fetchParcelById(id);
      setParcel(p);
      const [plantsData, calc, ativosRes, incRes] = await Promise.all([
        fetchPlantsByParcel(id),
        fetchCalculoByParcela(p.uuid || p.id),
        fetchAtivosByParcela(p.uuid || p.id),
        fetchIncidentesAbertos(p.uuid || p.id),
      ]);
      setPlants(plantsData);
      setCalculo(calc.ok ? calc.data : null);
      setAtivos(ativosRes.ok ? ativosRes.data : []);
      setIncidentes(incRes.ok ? incRes.data : []);
      setOffline(!calc.ok && calc.offline);
    } catch (err) {
      if (!err?.isAbort) {
        safeError('ParcelaAuditoria.load', err);
        setError('Não foi possível carregar a parcela. Tente novamente.');
      }
    } finally {
      setLoading(false);
    }
  }, [id]);

  useEffect(() => {
    // startTransition: o load começa com setState — dentro de transição o
    // React 19 não trata como render em cascata (regra react-hooks).
    startTransition(() => {
      load();
    });
  }, [load]);

  const verificar = async () => {
    if (!parcel) return;
    setVerificando(true);
    try {
      const res = await verificarCadeia(parcel.uuid || parcel.id);
      setCadeia(res);
    } catch (err) {
      safeError('verificarCadeia', err);
      setCadeia({ ok: false, offline: true, integra: null });
    } finally {
      setVerificando(false);
    }
  };

  if (loading) {
    return (
      <div className="space-y-6">
        <LoadingBlock label="Carregando trilha de auditoria…" />
      </div>
    );
  }

  if (error || !parcel) {
    return (
      <div className="space-y-6">
        <EmptyState
          icon={AlertTriangle}
          title="Parcela não encontrada"
          description={error || 'O registro pode ter sido removido do servidor.'}
          action={
            <Link to="/parcels" className="btn-primary">
              Voltar para parcelas
            </Link>
          }
        />
      </div>
    );
  }

  const resultado = parseJson(calculo?.resultado, {});
  const incerteza = parseJson(calculo?.incerteza, {});
  const bloqueada = incidentes.some((i) => i.bloqueia_uso_para_credito === true);

  return (
    <div className="space-y-6">
      {/* Cabeçalho */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex items-center gap-3">
          <button
            type="button"
            onClick={() => navigate('/parcels')}
            className="rounded-lg p-2 text-gray-500 transition-colors hover:bg-gray-100 hover:text-gray-700"
            aria-label="Voltar"
          >
            <ArrowLeft className="h-5 w-5" />
          </button>
          <div>
            <h1 className="text-xl font-bold text-gray-900">
              Auditoria — Parcela {String(parcel.id_parcela).padStart(3, '0')}
            </h1>
            <p className="text-sm text-gray-500">
              {parcel.propertyCode || '—'} · UT {parcel.utCode || '—'} ·{' '}
              {parcel.protocolo_versao || 'SOP-MRV-V1'}
            </p>
          </div>
        </div>
        <div className="flex items-center gap-3">
          <StatusBadge
            statusParcela={parcel.status_parcela}
            prontaParaSync={parcel.prontaParaSync}
          />
          {bloqueada ? (
            <span className="inline-flex items-center gap-1.5 rounded-full border border-mrv-danger/40 bg-mrv-danger/10 px-2.5 py-1 text-sm font-medium text-mrv-danger">
              <ShieldAlert className="h-3.5 w-3.5" aria-hidden="true" />
              Crédito bloqueado
            </span>
          ) : (
            <span className="inline-flex items-center gap-1.5 rounded-full border border-mrv-success/40 bg-mrv-success/10 px-2.5 py-1 text-sm font-medium text-mrv-green">
              <ShieldCheck className="h-3.5 w-3.5" aria-hidden="true" />
              Crédito liberado
            </span>
          )}
        </div>
      </div>

      {offline && <ServerOfflineBanner onRetry={load} retrying={loading} />}

      {/* Identificação */}
      <Section icon={MapPin} title="Identificação e geo">
        <dl className="grid grid-cols-2 gap-4 text-sm sm:grid-cols-4">
          <div>
            <dt className="text-gray-500">Latitude</dt>
            <dd className="font-medium text-gray-900">{parcel.latitude ?? '—'}</dd>
          </div>
          <div>
            <dt className="text-gray-500">Longitude</dt>
            <dd className="font-medium text-gray-900">{parcel.longitude ?? '—'}</dd>
          </div>
          <div>
            <dt className="text-gray-500">Área (m²)</dt>
            <dd className="font-medium text-gray-900">
              {parcel.area_m2 != null ? Number(parcel.area_m2).toLocaleString('pt-BR') : '—'}
            </dd>
          </div>
          <div>
            <dt className="text-gray-500">Responsável</dt>
            <dd className="font-medium text-gray-900">{parcel.displayUser || '—'}</dd>
          </div>
          <div>
            <dt className="text-gray-500">Coletado em</dt>
            <dd className="font-medium text-gray-900">
              {parcel.createdAt ? new Date(parcel.createdAt).toLocaleString('pt-BR') : '—'}
            </dd>
          </div>
          <div>
            <dt className="text-gray-500">Protocolo</dt>
            <dd className="font-medium text-gray-900">{parcel.protocolo_versao || '—'}</dd>
          </div>
          {parcel.projeto_id && (
            <div>
              <dt className="text-gray-500">Projeto</dt>
              <dd className="font-mono text-xs font-medium text-gray-900">{parcel.projeto_id}</dd>
            </div>
          )}
          {parcel.substituta_de && (
            <div>
              <dt className="text-gray-500">Substituída por</dt>
              <dd className="font-medium text-gray-900">{parcel.substituta_de}</dd>
            </div>
          )}
        </dl>
      </Section>

      {/* Cálculo MRV */}
      <Section icon={Calculator} title="Cálculo MRV">
        {calculo ? (
          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
              <div className="rounded-lg bg-mrv-green-bg p-3">
                <p className="text-xs font-medium uppercase tracking-wide text-mrv-green">Carbono</p>
                <p className="text-lg font-bold text-gray-900">{formatTco2e(resultado.tco2e_ha)}</p>
              </div>
              <div className="rounded-lg bg-urutau-100 p-3">
                <p className="text-xs font-medium uppercase tracking-wide text-urutau-700">Na parcela</p>
                <p className="text-lg font-bold text-gray-900">
                  {resultado.tco2e_total != null
                    ? `${Number(resultado.tco2e_total).toLocaleString('pt-BR', { maximumFractionDigits: 3 })} tCO₂e`
                    : '—'}
                </p>
              </div>
              <div className="rounded-lg bg-amber-50 p-3">
                <p className="text-xs font-medium uppercase tracking-wide text-amber-700">
                  Margem (IC 95%)
                </p>
                <p className="text-lg font-bold text-gray-900">
                  {incerteza.n ? formatIncerteza(incerteza.incerteza_pct) : '—'}
                </p>
              </div>
              <div className="rounded-lg bg-gray-100 p-3">
                <p className="text-xs font-medium uppercase tracking-wide text-gray-600">Amostra</p>
                <p className="text-lg font-bold text-gray-900">
                  n={resultado.n_individuos ?? '—'} · com DAP {resultado.n_com_dap ?? '—'}
                </p>
              </div>
            </div>
            <div className="flex flex-wrap items-center gap-3 text-xs text-gray-600">
              <span>
                Pools medidos:{' '}
                <strong className="text-gray-900">
                  {(calculo.pools_incluidos || []).join(', ') || '—'}
                </strong>
              </span>
              <span>
                FC <strong className="text-gray-900">{calculo.fracao_carbono ?? '—'}</strong>
              </span>
              <span>
                Status <strong className="text-gray-900">{calculo.status || '—'}</strong>
              </span>
              <span className="flex items-center gap-1">
                Hash dos insumos <HashPill value={calculo.insumos_hash} label="insumos_hash" />
              </span>
            </div>
          </div>
        ) : (
          <EmptyState
            icon={Calculator}
            title="Sem cálculo persistido"
            description="Esta parcela ainda não foi concluída no app — o cálculo MRV é gravado ao marcar como concluída e aparece aqui com hash dos insumos."
            compact
          />
        )}
      </Section>

      {/* Plantas */}
      <Section
        icon={TreePine}
        title={`Plantas (${plants.length})`}
      >
        {plants.length > 0 ? (
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200 text-sm">
              <thead>
                <tr className="table-header">
                  <th className="table-cell">Espécie</th>
                  <th className="table-cell">DAP (cm)</th>
                  <th className="table-cell">Altura (cm)</th>
                  <th className="table-cell">Foto</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {plants.map((pl) => (
                  <tr key={pl.id}>
                    <td className="table-cell font-medium text-gray-900">{pl.especie || '—'}</td>
                    <td className="table-cell">{pl.dap_cm ?? '—'}</td>
                    <td className="table-cell">{pl.altura_cm ?? '—'}</td>
                    <td className="table-cell">
                      {pl.foto_especie ? 'Sim' : <span className="text-gray-400">não</span>}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <EmptyState icon={TreePine} title="Nenhuma planta" description="" compact />
        )}
      </Section>

      {/* Trilha de auditoria */}
      <Section
        icon={Link2}
        title="Trilha de auditoria"
        action={
          <button
            type="button"
            onClick={verificar}
            disabled={verificando}
            className="btn-secondary disabled:opacity-60"
          >
            {verificando ? 'Verificando…' : 'Verificar cadeia'}
          </button>
        }
      >
        {cadeia && (
          <div
            className={`mb-4 flex items-center gap-2 rounded-lg border px-3 py-2 text-sm ${
              cadeia.integra === true
                ? 'border-mrv-success/40 bg-mrv-success/10 text-mrv-green'
                : cadeia.integra === false
                  ? 'border-mrv-danger/40 bg-mrv-danger/10 text-mrv-danger'
                  : 'border-gray-300 bg-gray-100 text-gray-600'
            }`}
            role="status"
          >
            {cadeia.integra === true && <CheckCircle2 className="h-4 w-4" aria-hidden="true" />}
            {cadeia.integra === false && <XCircle className="h-4 w-4" aria-hidden="true" />}
            {cadeia.integra === true
              ? `Cadeia ÍNTEGRA — ${cadeia.data.length} elos conferidos (prev_hash → entry_hash).`
              : cadeia.integra === false
                ? `Cadeia QUEBRADA no elo #${cadeia.quebradoEm} — hash divergente.`
                : cadeia.offline
                  ? 'Servidor indisponível — não foi possível verificar a cadeia.'
                  : 'Nenhuma entrada na trilha para esta parcela.'}
          </div>
        )}
        <TrilhaTable parcelaUuid={parcel.uuid || parcel.id} />
      </Section>

      {/* Ativos com hash (fotos) */}
      <Section icon={Fingerprint} title={`Ativos com hash (${ativos.length})`}>
        {ativos.length > 0 ? (
          <ul className="divide-y divide-gray-100 text-sm">
            {ativos.map((a) => (
              <li key={a.id} className="flex items-center justify-between gap-3 py-2">
                <div className="min-w-0">
                  <p className="truncate font-medium text-gray-900">
                    {a.caminho_original || a.entidade_tipo}
                  </p>
                  <p className="font-mono text-xs text-gray-500">{shortHash(a.sha256, 16)}</p>
                </div>
                <span
                  className={`flex-shrink-0 rounded-full px-2 py-0.5 text-xs font-medium ${
                    a.sha256_verificado
                      ? 'bg-mrv-success/10 text-mrv-green'
                      : 'bg-amber-100 text-amber-700'
                  }`}
                >
                  {a.sha256_verificado ? 'verificado' : 'pendente'}
                </span>
              </li>
            ))}
          </ul>
        ) : (
          <EmptyState
            icon={Fingerprint}
            title="Nenhum ativo catalogado"
            description="Fotos recebem hash SHA-256 ao serem capturadas no app; o catálogo sobe no sync."
            compact
          />
        )}
      </Section>

      {/* Incidentes */}
      <Section icon={AlertTriangle} title={`Incidentes abertos (${incidentes.length})`}>
        {incidentes.length > 0 ? (
          <ul className="divide-y divide-gray-100 text-sm">
            {incidentes.map((i) => (
              <li key={i.id} className="py-2">
                <p className="font-medium text-gray-900">{i.descricao || i.titulo || 'Incidente'}</p>
                <p className="text-xs text-gray-500">
                  {i.severidade ? `severidade: ${i.severidade} · ` : ''}
                  {i.bloqueia_uso_para_credito ? 'bloqueia crédito' : 'informativo'}
                </p>
              </li>
            ))}
          </ul>
        ) : (
          <EmptyState
            icon={ShieldCheck}
            title="Nenhum incidente aberto"
            description="Incidentes bloqueadores são abertos por verificação interna divergente ou hash divergente."
            compact
          />
        )}
      </Section>

      {/* Dossiê */}
      <Section icon={FileJson} title="Dossiê de auditoria">
        <p className="text-sm text-gray-600">
          O dossiê completo (PDF + dados + manifesto de hashes + fotos) é gerado pelo app no
          campo. O painel mostra aqui os metadados conferíveis: hash dos insumos, hashes dos
          ativos e o estado da cadeia acima.
        </p>
      </Section>
    </div>
  );
};

const TrilhaTable = ({ parcelaUuid }) => {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const res = await fetchTrilhaByEntidade(parcelaUuid);
      if (!cancelled) {
        setRows(res.ok ? res.data : []);
        setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [parcelaUuid]);
  if (loading) return <LoadingBlock label="Carregando trilha…" />;
  if (rows.length === 0) {
    return (
      <EmptyState
        icon={Clock}
        title="Trilha vazia"
        description="Nenhuma ação registrada no servidor para esta parcela ainda."
        compact
      />
    );
  }

  return (
    <div className="overflow-x-auto">
      <table className="min-w-full divide-y divide-gray-200 text-sm">
        <thead>
          <tr className="table-header">
            <th className="table-cell">#</th>
            <th className="table-cell">Ação</th>
            <th className="table-cell">Entidade</th>
            <th className="table-cell">Quando</th>
            <th className="table-cell">Origem</th>
            <th className="table-cell">entry_hash</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-100">
          {rows.map((r) => (
            <tr key={r.id}>
              <td className="table-cell text-gray-500">{r.id_seq}</td>
              <td className="table-cell font-medium text-gray-900">{r.acao}</td>
              <td className="table-cell">{r.entidade_tipo}</td>
              <td className="table-cell">
                {r.ts_dispositivo ? new Date(r.ts_dispositivo).toLocaleString('pt-BR') : '—'}
              </td>
              <td className="table-cell">{r.origem || '—'}</td>
              <td className="table-cell">
                <HashPill value={r.entry_hash} label="entry_hash" />
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};

export default ParcelaAuditoria;
