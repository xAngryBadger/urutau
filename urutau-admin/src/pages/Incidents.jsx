import React, { useEffect, useState, useCallback, startTransition } from 'react';
import { Link } from 'react-router-dom';
import {
  AlertTriangle,
  ShieldCheck,
  ShieldX,
  RotateCcw,
  ExternalLink,
  Loader2,
} from 'lucide-react';
import { fetchIncidentes, resolverIncidente } from '../services/incidentes';
import { useAuth } from '../context/AuthContext';
import { USE_MOCK } from '../services/mock/demoData';
import EmptyState from '../components/ui/EmptyState';
import ServerOfflineBanner from '../components/ui/ServerOfflineBanner';
import DemoBanner from '../components/ui/DemoBanner';
import { LoadingBlock } from '../components/ui/Loading';
import Modal from '../components/ui/Modal';

const SeveridadeBadge = ({ severidade }) => {
  const bloqueadora = String(severidade || '').toLowerCase().includes('bloquead');
  return (
    <span
      className={`inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-medium ${
        bloqueadora
          ? 'bg-mrv-danger/10 text-mrv-danger'
          : 'bg-amber-100 text-amber-700'
      }`}
    >
      <ShieldX className="h-3 w-3" aria-hidden="true" />
      {severidade || 'informativo'}
    </span>
  );
};

const Incidents = () => {
  const { user, isReadOnly } = useAuth();
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [offline, setOffline] = useState(false);
  const [actionError, setActionError] = useState(null);
  const [resolvendo, setResolvendo] = useState(null); // id do incidente em edição
  const [justificativa, setJustificativa] = useState('');
  const [filtro, setFiltro] = useState('abertos');

  const load = useCallback(async () => {
    setLoading(true);
    const res = await fetchIncidentes({ abertos: filtro === 'abertos' });
    if (res.ok) {
      setItems(res.data);
      setOffline(false);
    } else {
      setOffline(res.offline === true);
      if (!res.offline) setActionError(res.error);
    }
    setLoading(false);
  }, [filtro]);

  useEffect(() => {
    startTransition(() => {
      load();
    });
  }, [load]);

  const resolver = async (id) => {
    setActionError(null);
    const res = await resolverIncidente(
      id,
      { justificativa, usuarioUuid: user?.uuid || user?.id || 'painel' },
      { canWrite: !isReadOnly },
    );
    if (res.ok) {
      setResolvendo(null);
      setJustificativa('');
      await load();
    } else {
      setActionError(res.error);
    }
  };

  return (
    <div className="space-y-6">
      {USE_MOCK && <DemoBanner />}
      {offline && <ServerOfflineBanner onRetry={load} retrying={loading} />}

      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-xl font-bold text-gray-900">Incidentes</h1>
          <p className="text-sm text-gray-500">
            RG-06: incidente bloqueador aberto impede o uso do resultado para crédito.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <label htmlFor="filtro-inc" className="text-sm text-gray-500">
            Exibir
          </label>
          <select
            id="filtro-inc"
            value={filtro}
            onChange={(e) => setFiltro(e.target.value)}
            className="input-field w-auto py-1.5 text-sm"
          >
            <option value="abertos">Abertos</option>
            <option value="todos">Todos</option>
          </select>
        </div>
      </div>

      {actionError && (
        <div className="rounded-lg border border-mrv-danger/40 bg-mrv-danger/10 px-4 py-3 text-sm text-mrv-danger" role="alert">
          {actionError}
        </div>
      )}

      {loading ? (
        <LoadingBlock label="Carregando incidentes…" />
      ) : items.length === 0 ? (
        <EmptyState
          icon={ShieldCheck}
          title={filtro === 'abertos' ? 'Nenhum incidente aberto' : 'Nenhum incidente registrado'}
          description="Incidentes são abertos automaticamente por hash divergente (RC-04) ou verificação interna divergente (RG-03)."
        />
      ) : (
        <div className="card overflow-x-auto p-0">
          <table className="min-w-full divide-y divide-gray-200 text-sm">
            <thead>
              <tr className="table-header">
                <th className="table-cell">Tipo</th>
                <th className="table-cell">Severidade</th>
                <th className="table-cell">Entidade</th>
                <th className="table-cell">Detectado</th>
                <th className="table-cell">Situação</th>
                <th className="table-cell">Ações</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {items.map((inc) => {
                const resolvido = !!inc.resolvido_em;
                return (
                  <tr key={inc.id}>
                    <td className="table-cell font-medium text-gray-900">
                      <div className="flex items-center gap-2">
                        <AlertTriangle className="h-4 w-4 text-amber-500" aria-hidden="true" />
                        {inc.tipo || '—'}
                      </div>
                      {inc.descricao && (
                        <p className="mt-0.5 max-w-md text-xs text-gray-500">{inc.descricao}</p>
                      )}
                    </td>
                    <td className="table-cell">
                      <SeveridadeBadge severidade={inc.severidade} />
                    </td>
                    <td className="table-cell">
                      {inc.entidade_tipo} ·{' '}
                      <span className="font-mono text-xs text-gray-500">
                        {inc.entidade_uuid || 'global'}
                      </span>
                    </td>
                    <td className="table-cell text-gray-500">
                      {inc.detectado_em || inc.created
                        ? new Date(inc.detectado_em || inc.created).toLocaleString('pt-BR')
                        : '—'}
                    </td>
                    <td className="table-cell">
                      {resolvido ? (
                        <span className="inline-flex items-center gap-1 rounded-full bg-mrv-success/10 px-2 py-0.5 text-xs font-medium text-mrv-green">
                          <ShieldCheck className="h-3 w-3" aria-hidden="true" />
                          resolvido
                        </span>
                      ) : inc.bloqueia_uso_para_credito ? (
                        <span className="inline-flex items-center gap-1 rounded-full bg-mrv-danger/10 px-2 py-0.5 text-xs font-medium text-mrv-danger">
                          bloqueia crédito
                        </span>
                      ) : (
                        <span className="text-gray-400">informativo</span>
                      )}
                    </td>
                    <td className="table-cell">
                      <div className="flex items-center gap-2">
                        {!resolvido && (
                          <button
                            type="button"
                            onClick={() => {
                              setResolvendo(inc.id);
                              setJustificativa('');
                            }}
                            className="btn-secondary px-2 py-1 text-xs"
                          >
                            <RotateCcw className="h-3.5 w-3.5" aria-hidden="true" />
                            Resolver
                          </button>
                        )}
                        {inc.entidade_uuid && inc.entidade_tipo === 'parcela' && (
                          <Link
                            to={`/parcels/${inc.entidade_uuid}/auditoria`}
                            className="inline-flex items-center gap-1 text-xs font-medium text-urutau-700 hover:underline"
                          >
                            <ExternalLink className="h-3.5 w-3.5" aria-hidden="true" />
                            Auditoria
                          </Link>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      {resolvendo && (
        <Modal open onClose={() => setResolvendo(null)} title="Resolver incidente" labelledBy="resolver-titulo">
          <p className="text-sm text-gray-600">
            A justificativa entra na trilha de auditoria ({' '}
            <code className="rounded bg-gray-100 px-1 text-xs">incidente_resolvido</code> ). Sem
            justificativa o bloqueio NÃO é liberado.
          </p>
          <label htmlFor="just" className="mt-4 block text-sm font-medium text-gray-700">
            Justificativa
          </label>
          <textarea
            id="just"
            data-autofocus
            value={justificativa}
            onChange={(e) => setJustificativa(e.target.value)}
            rows={4}
            className="input-field mt-1"
            placeholder="Ex.: foto reenviada confere com o catálogo; hash recalculado no dispositivo."
          />
          {isReadOnly && (
            <p className="mt-2 text-xs text-amber-700">
              Seu perfil é somente leitura — resolver incidente é privilégio de admin.
            </p>
          )}
          <div className="mt-4 flex justify-end gap-2">
            <button type="button" className="btn-secondary" onClick={() => setResolvendo(null)}>
              Cancelar
            </button>
            <button
              type="button"
              className="btn-primary"
              disabled={isReadOnly}
              onClick={() => resolver(resolvendo)}
            >
              Resolver e liberar
            </button>
          </div>
        </Modal>
      )}
    </div>
  );
};

export default Incidents;
