import React from 'react';
import { Eye } from 'lucide-react';

/** Chip "somente leitura" — deixa claro o papel de quem está logado. */
const ReadOnlyBadge = ({ role = 'verificador' }) => (
  <span
    className="inline-flex items-center gap-1.5 rounded-full border border-status-revisado/40 bg-status-revisado/10 px-2.5 py-1 text-xs font-medium text-status-revisado"
    title={`Perfil ${role}: consulta e verificação, sem alteração de dados`}
  >
    <Eye className="h-3.5 w-3.5" aria-hidden="true" />
    Somente leitura
  </span>
);

export default ReadOnlyBadge;
