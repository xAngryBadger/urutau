/**
 * Tokens de design do Urutau para o painel web.
 * ESPELHO de urutau-app/lib/theme/app_tokens.dart — fonte única no app.
 * Se um valor mudar lá, muda aqui (e vice-versa). O painel não inventa cor.
 */

export const brand = {
  primary: '#5A6B5C',      // verde-sálvia
  secondary: '#C4A47C',    // bege-dourado
  background: '#F9F6F0',   // off-white quente
  surface: '#FFFFFF',
};

/** Alto contraste (campo sob sol) — mesmo par do app. */
export const hc = {
  primary: '#FFD600',
  onPrimary: '#000000',
  background: '#000000',
  surface: '#141200',
  surface2: '#1A1500',
  outline: '#332B00',
  text: '#FFFFFF',
};

/** Status de verificação (RG-02) — um lugar só pra cor+label. */
export const status = {
  pendente: { color: '#E8A13A', label: 'Pendente', icon: 'hourglass' },
  revisado: { color: '#3A7BD5', label: 'Revisado', icon: 'fact-check' },
  aprovado: { color: '#3E8E4F', label: 'Aprovado', icon: 'verified' },
  rascunho: { color: '#6B7280', label: 'Rascunho', icon: 'edit' },
};

/** MRV / carbono. */
export const mrv = {
  green: '#2E7D32',
  greenBg: '#E8F5E9',
  danger: '#C62828',
  warning: '#FF9800',
  success: '#4CAF50',
};

export const spacing = { xs: 4, s: 8, m: 12, l: 16, xl: 24, xxl: 32 };
export const radius = { s: 8, m: 12, l: 16 };
export const font = { title: 20, body: 16, small: 13, caption: 11 };

/** Mapeia status_parcela do servidor para o token canônico. */
export function statusToken(statusParcela, prontaParaSync) {
  if (!prontaParaSync) return status.rascunho;
  if (statusParcela === 'aprovado') return status.aprovado;
  if (statusParcela === 'revisado') return status.revisado;
  return status.pendente;
}

/** Formata tCO2e/ha com 1 decimal e separador pt-BR. */
export function formatTco2e(value) {
  if (value == null || Number.isNaN(value)) return '—';
  return `${Number(value).toLocaleString('pt-BR', {
    minimumFractionDigits: 1,
    maximumFractionDigits: 1,
  })} tCO₂e/ha`;
}

/** Formata porcentagem de incerteza (IC95). */
export function formatIncerteza(pct) {
  if (pct == null || Number.isNaN(pct)) return '—';
  return `± ${Number(pct).toLocaleString('pt-BR', {
    minimumFractionDigits: 1,
    maximumFractionDigits: 1,
  })}%`;
}

/** Encurta hash pra exibição auditável (nunca esconde o valor completo). */
export function shortHash(hash, size = 12) {
  if (!hash) return '—';
  return hash.length <= size * 2 ? hash : `${hash.slice(0, size)}…${hash.slice(-8)}`;
}
