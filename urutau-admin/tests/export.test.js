// @vitest-environment node
import { describe, it, expect } from 'vitest';

// pocketbase.js toca window no import — stub ANTES do import dinâmico.
if (!globalThis.window) {
  globalThis.window = { location: { origin: 'http://localhost' } };
}

const { buildRows, toCsv, COLUNAS_AUDITAVEIS } = await import('../src/services/export.js');

describe('export auditável (R9)', () => {
  const parcels = [
    {
      id: 'p1', id_parcela: 1, propertyCode: 'Fazenda Modelo', utCode: 'UT-01',
      statusVerificacao: 'pendente', protocoloVersao: 'SOP-MRV-V1', projetoId: 'LEGADO-PROJ-0000',
      periodoId: 'LEGADO-PER-0000', displayUser: 'Ana', createdAt: '2026-11-06T11:24:53.000Z',
      latitude: -23.5505, longitude: -46.6333, area_m2: 400,
      fotos_parcela: ['f1.jpg', 'f2.jpg'],
    },
  ];
  const calculos = [
    {
      escopo_uuid: 'p1', insumos_hash: 'abc123', resultado_hash: 'def456',
      resultado: JSON.stringify({ tco2e_ha: 59.895 }),
      incerteza: JSON.stringify({ incerteza_pct: 60.21, ic95_tco2e_ha: 36.07 }),
    },
  ];

  it('linhas têm todas as colunas obrigatórias preenchidas', () => {
    const rows = buildRows({ parcels, calculos });
    expect(rows).toHaveLength(1);
    const r = rows[0];
    for (const c of COLUNAS_AUDITAVEIS) {
      expect(Object.keys(r)).toContain(c);
    }
    expect(r.insumos_hash).toBe('abc123');
    expect(r.tco2e_ha).toBe(59.895);
    expect(r.incerteza_pct).toBe(60.21);
    expect(r.area_ha).toBeCloseTo(0.04, 6);
    expect(r.fotos).toBe(2);
    expect(r.status_verificacao).toBe('pendente');
    expect(r.protocolo_versao).toBe('SOP-MRV-V1');
  });

  it('CSV traz o header canônico e escapa vírgula', () => {
    const csv = toCsv(buildRows({
      parcels: [{ ...parcels[0], displayUser: 'Silva, Ana' }],
      calculos,
    }));
    expect(csv.startsWith(`${COLUNAS_AUDITAVEIS[0]},${COLUNAS_AUDITAVEIS[1]}`)).toBe(true);
    expect(csv).toContain('"Silva, Ana"');
  });

  it('parcela sem cálculo não quebra (hash vazio)', () => {
    const rows = buildRows({ parcels });
    expect(rows[0].insumos_hash).toBe('');
    expect(rows[0].tco2e_ha).toBe('');
  });
});
