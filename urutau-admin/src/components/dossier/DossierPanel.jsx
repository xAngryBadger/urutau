import React, { useState, useEffect, useCallback, startTransition } from 'react';
import { FileArchive, Download, ShieldCheck, ShieldX, Upload, Loader2 } from 'lucide-react';
import { fetchManifesto, verificarArquivoDossie } from '../../services/dossie';
import EmptyState from '../ui/EmptyState';
import { shortHash } from '../../theme/tokens';

/**
 * Dossiê (R10): mostra o manifesto publicado e permite ao verificador
 * CONFERIR o hash de cada arquivo que ele baixou — "auditoria refaz a
 * conta sozinho" também no painel.
 */
const DossierPanel = ({ parcelaId }) => {
  const [estado, setEstado] = useState(null); // { manifesto, arquivoUrl, fonte }
  const [loading, setLoading] = useState(true);
  const [verificados, setVerificados] = useState({}); // arquivo -> {confere, calculado}

  const load = useCallback(async () => {
    setLoading(true);
    const res = await fetchManifesto(parcelaId);
    setEstado(res.ok ? res.data : { manifesto: null, arquivoUrl: null });
    setLoading(false);
  }, [parcelaId]);

  useEffect(() => {
    startTransition(() => {
      load();
    });
  }, [load]);

  const verificar = async (arquivo, nome) => {
    const sha = estado?.manifesto?.arquivos?.[nome]?.sha256;
    if (!sha) return;
    const res = await verificarArquivoDossie(arquivo, sha);
    setVerificados((v) => ({ ...v, [nome]: res }));
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-8 text-sm text-gray-500">
        <Loader2 className="mr-2 h-4 w-4 animate-spin" aria-hidden="true" />
        Carregando dossiê…
      </div>
    );
  }

  const manifesto = estado?.manifesto;
  const arquivos = manifesto?.arquivos ? Object.entries(manifesto.arquivos) : [];

  if (!manifesto) {
    return (
      <EmptyState
        icon={FileArchive}
        title="Dossiê não publicado no servidor"
        description={
          estado?.arquivoUrl
            ? 'Há um ZIP publicado, mas sem manifesto legível no servidor.'
            : 'O dossiê completo (PDF + dados + manifesto + fotos) é gerado pelo app no campo e sobe no sync. Quando o servidor publicar o arquivo/manifesto, a conferência de hashes aparece aqui.'
        }
        compact
      >
        {estado?.arquivoUrl && (
          <a href={estado.arquivoUrl} className="btn-secondary" download>
            <Download className="h-4 w-4" aria-hidden="true" />
            Baixar ZIP
          </a>
        )}
      </EmptyState>
    );
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <p className="text-sm font-medium text-gray-900">
            Manifesto do dossiê {estado.fonte ? `(${estado.fonte})` : ''}
          </p>
          <p className="text-xs text-gray-500">
            gerado em {new Date(manifesto.gerado_em_relogio_confiavel).toLocaleString('pt-BR')} ·
            offset do relógio {manifesto.offset_relogio_ms ?? 0} ms
          </p>
        </div>
        <div className="flex items-center gap-3 text-xs">
          <span className="inline-flex items-center gap-1 rounded-full bg-mrv-green-bg px-2 py-0.5 font-medium text-mrv-green">
            cadeia local: {manifesto.verificacao?.cadeia_local}
          </span>
          <span className="inline-flex items-center gap-1 rounded-full bg-urutau-100 px-2 py-0.5 font-medium text-urutau-800">
            {manifesto.verificacao?.cadeia_servidor}
          </span>
        </div>
      </div>

      <table className="min-w-full divide-y divide-gray-200 text-sm">
        <thead>
          <tr className="table-header">
            <th className="table-cell">Arquivo</th>
            <th className="table-cell">SHA-256 (manifesto)</th>
            <th className="table-cell">Bytes</th>
            <th className="table-cell">Conferir</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-100">
          {arquivos.map(([nome, info]) => {
            const v = verificados[nome];
            return (
              <tr key={nome}>
                <td className="table-cell font-medium text-gray-900">{nome}</td>
                <td className="table-cell">
                  <code className="font-mono text-xs text-gray-600" title={info.sha256}>
                    {shortHash(info.sha256, 14)}
                  </code>
                </td>
                <td className="table-cell">{info.bytes}</td>
                <td className="table-cell">
                  <div className="flex items-center gap-2">
                    <label className="inline-flex cursor-pointer items-center gap-1 rounded-md border border-gray-300 px-2 py-1 text-xs font-medium text-gray-700 hover:bg-gray-50">
                      <Upload className="h-3.5 w-3.5" aria-hidden="true" />
                      arquivo
                      <input
                        type="file"
                        className="hidden"
                        onChange={(e) => {
                          const f = e.target.files?.[0];
                          if (f) verificar(f, nome);
                        }}
                      />
                    </label>
                    {v?.ok && (
                      <span
                        className={`inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-medium ${
                          v.confere
                            ? 'bg-mrv-success/10 text-mrv-green'
                            : 'bg-mrv-danger/10 text-mrv-danger'
                        }`}
                        title={v.sha256Calculado}
                      >
                        {v.confere ? (
                          <ShieldCheck className="h-3 w-3" aria-hidden="true" />
                        ) : (
                          <ShieldX className="h-3 w-3" aria-hidden="true" />
                        )}
                        {v.confere ? 'confere' : 'DIVERGE'}
                      </span>
                    )}
                  </div>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>

      <p className="text-xs text-gray-500">
        Conferência 100% no navegador: o SHA-256 é recalculado do arquivo que você selecionar e
        comparado com o manifesto. Nada é enviado a lugar nenhum.
      </p>
    </div>
  );
};

export default DossierPanel;
