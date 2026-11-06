import React from 'react';

/** Spinner consistente com o shell (LoadingScreen = tela cheia; Inline = bloco). */
export const LoadingScreen = ({ label = 'Carregando…' }) => (
  <div className="flex min-h-screen items-center justify-center bg-brand-bg">
    <div className="flex flex-col items-center gap-3">
      <div
        className="h-10 w-10 animate-spin rounded-full border-4 border-urutau-200 border-t-urutau-700"
        role="status"
        aria-label={label}
      />
      <p className="text-sm text-gray-500">{label}</p>
    </div>
  </div>
);

export const LoadingBlock = ({ label = 'Carregando…' }) => (
  <div className="flex items-center justify-center py-12" role="status" aria-live="polite">
    <div className="flex flex-col items-center gap-2">
      <div
        className="h-8 w-8 animate-spin rounded-full border-4 border-urutau-200 border-t-urutau-700"
        aria-hidden="true"
      />
      <p className="text-sm text-gray-500">{label}</p>
    </div>
  </div>
);

export default LoadingScreen;
