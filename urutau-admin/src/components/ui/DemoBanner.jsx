import React from 'react';
import { FlaskConical } from 'lucide-react';

/**
 * Selo obrigatório quando VITE_USE_MOCK=true: dado de demonstração NUNCA
 * pode se passar por dado real num painel de auditoria.
 */
const DemoBanner = () => (
  <div
    className="mb-6 flex items-center gap-3 rounded-lg border border-status-revisado/40 bg-status-revisado/10 px-4 py-3"
    role="status"
  >
    <FlaskConical className="h-5 w-5 flex-shrink-0 text-status-revisado" aria-hidden="true" />
    <p className="text-sm text-status-revisado">
      <strong>DADOS DE DEMONSTRAÇÃO</strong> — servidor PocketBase ainda não foi publicado.
      Os hashes e a cadeia abaixo são calculados de verdade (mesmo código do app), mas os
      registros são fictícios.
    </p>
  </div>
);

export default DemoBanner;
