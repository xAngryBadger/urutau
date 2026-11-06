/** Espelha canonicalPayload de services/mrv.js para os testes. */
const dartJson = (value) => {
  if (value === null || value === undefined) return 'null';
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) return 'null';
    return Number.isInteger(value) ? value.toFixed(1) : String(value);
  }
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  if (typeof value === 'string') return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(dartJson).join(',')}]`;
  if (typeof value === 'object') {
    return `{${Object.entries(value)
      .filter(([, v]) => v !== undefined)
      .map(([k, v]) => `${JSON.stringify(k)}:${dartJson(v)}`)
      .join(',')}}`;
  }
  return 'null';
};

const sha256Hex = async (text) => {
  const bytes = new TextEncoder().encode(text);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('');
};

export const canonicalPayloadForTest = async (rec, prevHash) => {
  const tsIso = (raw) => {
    if (!raw) return null;
    const d = new Date(raw);
    return Number.isNaN(d.getTime()) ? null : d.toISOString();
  };
  const canon = dartJson({
    prev: prevHash,
    acao: rec.acao ?? null,
    entidade_tipo: rec.entidade_tipo ?? null,
    entidade_uuid: rec.entidade_uuid ?? null,
    usuario_uuid: rec.usuario_uuid ?? null,
    antes: rec.antes ?? null,
    depois: rec.depois ?? null,
    ts_dispositivo: tsIso(rec.ts_dispositivo),
    ...(rec.offset_relogio_ms != null ? { offset_relogio_ms: rec.offset_relogio_ms } : {}),
    origem: rec.origem ?? null,
  });
  return sha256Hex(canon);
};
