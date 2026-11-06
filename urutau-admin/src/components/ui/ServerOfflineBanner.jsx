import React from 'react';
import { CloudOff, RefreshCw } from 'lucide-react';

/**
 * Banner de servidor indisponível. O PocketBase de produção ainda não existe
 * (sobe no lançamento) — o painel precisa DIZER isso em vez de mostrar dados
 * vazios sem explicação.
 */
const ServerOfflineBanner = ({ onRetry, retrying = false }) => (
  <div
    className="mb-6 flex flex-col gap-3 rounded-lg border border-amber-300 bg-amber-50 px-4 py-3 sm:flex-row sm:items-center sm:justify-between"
    role="alert"
  >
    <div className="flex items-start gap-3">
      <CloudOff className="mt-0.5 h-5 w-5 flex-shrink-0 text-amber-600" aria-hidden="true" />
      <div>
        <p className="text-sm font-semibold text-amber-900">Servidor indisponível</p>
        <p className="text-sm text-amber-800">
          Não foi possível conectar ao PocketBase. Os dados abaixo podem estar
          incompletos ou desatualizados. Tente novamente quando o servidor estiver no ar.
        </p>
      </div>
    </div>
    {onRetry && (
      <button
        type="button"
        onClick={onRetry}
        disabled={retrying}
        className="inline-flex items-center gap-2 self-start rounded-lg border border-amber-400 bg-white px-3 py-1.5 text-sm font-medium text-amber-800 transition-colors hover:bg-amber-100 disabled:opacity-60 sm:self-auto"
      >
        <RefreshCw className={`h-4 w-4 ${retrying ? 'animate-spin' : ''}`} aria-hidden="true" />
        {retrying ? 'Tentando…' : 'Tentar novamente'}
      </button>
    )}
  </div>
);

export default ServerOfflineBanner;
