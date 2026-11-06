import React from 'react';
import { Hourglass, FactCheckOutlined, VerifiedOutlined, EditNote } from 'lucide-react';
import { statusToken } from '../../theme/tokens';
const ICONS = {
  hourglass: Hourglass,
  'fact-check': FactCheckOutlined,
  verified: VerifiedOutlined,
  edit: EditNote,
};

/**
 * Badge canônico de status (RG-02). Cor + ÍCONE + texto — a cor nunca é o
 * único canal (WCAG 1.4.1). Valores vêm dos tokens do app (fonte única).
 */
const StatusBadge = ({ statusParcela, prontaParaSync, size = 'md' }) => {
  const token = statusToken(statusParcela, prontaParaSync);
  const Icon = ICONS[token.icon] || Hourglass;
  const pad = size === 'sm' ? 'px-2 py-0.5 text-xs' : 'px-2.5 py-1 text-sm';

  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full font-medium ${pad}`}
      style={{ backgroundColor: `${token.color}1A`, color: token.color, border: `1px solid ${token.color}40` }}
      title={`Status: ${token.label}`}
    >
      <Icon className="h-3.5 w-3.5" aria-hidden="true" />
      {token.label}
    </span>
  );
};

export default StatusBadge;
