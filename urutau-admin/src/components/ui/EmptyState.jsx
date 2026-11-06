import React from 'react';

/**
 * Estado vazio explicativo — sempre com a ação seguinte (não é tela morta).
 * `icon` é um componente lucide; `action` é um nó (botão/link).
 */
const EmptyState = ({ icon: Icon, title, description, action, compact = false }) => (
  <div
    className={`flex flex-col items-center justify-center rounded-xl border border-dashed border-gray-300 bg-white text-center ${compact ? 'px-4 py-8' : 'px-6 py-14'}`}
    role="status"
  >
    {Icon && (
      <div className="mb-3 flex h-11 w-11 items-center justify-center rounded-full bg-urutau-100 text-urutau-700">
        <Icon className="h-5 w-5" aria-hidden="true" />
      </div>
    )}
    <h3 className="text-base font-semibold text-gray-900">{title}</h3>
    {description && <p className="mt-1 max-w-md text-sm text-gray-500">{description}</p>}
    {action && <div className="mt-4">{action}</div>}
  </div>
);

export default EmptyState;
