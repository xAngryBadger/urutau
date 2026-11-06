import React, { useState } from 'react';
import { Copy, Check, Fingerprint, MapPin, Clock, User, ShieldQuestion } from 'lucide-react';

const CopyButton = ({ value }) => {
  const [copied, setCopied] = useState(false);
  if (!value) return null;
  return (
    <button
      type="button"
      onClick={async () => {
        try {
          await navigator.clipboard.writeText(value);
          setCopied(true);
          setTimeout(() => setCopied(false), 1500);
        } catch { /* clipboard indisponível */ }
      }}
      className="rounded p-1 text-gray-400 transition-colors hover:bg-gray-100 hover:text-gray-600"
      title="Copiar hash"
      aria-label="Copiar hash"
    >
      {copied ? <Check className="h-3.5 w-3.5 text-mrv-green" /> : <Copy className="h-3.5 w-3.5" />}
    </button>
  );
};

/**
 * Provas por foto (promessa do pitch): SHA-256, GPS, timestamp e dono.
 * Sem hash => selo "hash não verificado" — nunca afirmar verificação sem hash.
 */
const PhotoMetaPanel = ({ meta }) => {
  if (!meta) return null;
  const semHash = !meta.sha256;

  return (
    <div className="space-y-2 text-sm">
      <div className="flex items-center gap-2">
        <Fingerprint className="h-4 w-4 flex-shrink-0 text-gray-400" aria-hidden="true" />
        {semHash ? (
          <span className="inline-flex items-center gap-1 rounded-md bg-amber-100 px-2 py-0.5 text-xs font-medium text-amber-700">
            <ShieldQuestion className="h-3.5 w-3.5" aria-hidden="true" />
            hash não verificado
          </span>
        ) : (
          <>
            <code className="break-all font-mono text-xs text-gray-700">{meta.sha256}</code>
            <CopyButton value={meta.sha256} />
          </>
        )}
      </div>
      <div className="flex flex-wrap gap-4 text-xs text-gray-500">
        {(meta.lat != null || meta.long != null) && (
          <span className="inline-flex items-center gap-1">
            <MapPin className="h-3.5 w-3.5" aria-hidden="true" />
            {meta.lat}, {meta.long}
          </span>
        )}
        {meta.timestamp && (
          <span className="inline-flex items-center gap-1">
            <Clock className="h-3.5 w-3.5" aria-hidden="true" />
            {new Date(meta.timestamp).toLocaleString('pt-BR')}
          </span>
        )}
        {meta.autor && (
          <span className="inline-flex items-center gap-1">
            <User className="h-3.5 w-3.5" aria-hidden="true" />
            {meta.autor}
          </span>
        )}
      </div>
    </div>
  );
};

export default PhotoMetaPanel;
