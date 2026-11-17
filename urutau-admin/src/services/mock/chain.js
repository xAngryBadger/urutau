/**
 * Constrói a trilha mock hasheando com o MESMO payload canônico do app
 * (espelho de services/mrv.js canonicalPayload). Assim a verificação de cadeia
 * no modo demo é real: íntegra até alguém adulterar um elo de propósito.
 */

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

let _chain = null;

/**
 * Elo 3 é deliberadamente ADULTERADO: o `depois` gravado difere do que foi
 * hasheado — demonstra o estado "Cadeia QUEBRADA" (payload adulterado).
 */
export async function buildMockChain() {
  if (_chain) return _chain;

  const entries = [
    { acao: 'create', entidade: 'demo-parcela-01', ts: '2026-11-06T11:24:53.000Z' },
    { acao: 'foto_registrada', entidade: 'demo-parcela-01', ts: '2026-11-06T11:25:10.000Z' },
    { acao: 'parcela_concluida', entidade: 'demo-parcela-01', ts: '2026-11-06T11:26:00.000Z' },
    { acao: 'update', entidade: 'demo-parcela-02', ts: '2026-11-05T10:02:11.000Z' },
  ];

  const rows = [];
  let prev = 'GENESIS';
  let seq = 1;
  for (const e of entries) {
    const honesto = seq !== 3;
    const depoisHasheado = e.entidade;
    const depoisGravado = honesto ? e.entidade : 'entidade-injetada';
    const canon = dartJson({
      prev,
      acao: e.acao,
      entidade_tipo: 'parcela',
      entidade_uuid: e.entidade,
      usuario_uuid: 'demo-ana',
      antes: null,
      depois: depoisHasheado,
      ts_dispositivo: e.ts,
      offset_relogio_ms: 0,
      origem: 'app',
    });
    const entryHash = await sha256Hex(canon);
    rows.push({
      id: `mock-trilha-${seq}`,
      id_seq: seq,
      acao: e.acao,
      entidade_tipo: 'parcela',
      entidade_uuid: e.entidade,
      usuario_uuid: 'demo-ana',
      antes: null,
      depois: depoisGravado,
      ts_dispositivo: e.ts,
      offset_relogio_ms: 0,
      origem: 'app',
      prev_hash: prev,
      entry_hash: entryHash,
    });
    prev = entryHash;
    seq++;
  }
  _chain = rows;
  return rows;
}

export default buildMockChain;
