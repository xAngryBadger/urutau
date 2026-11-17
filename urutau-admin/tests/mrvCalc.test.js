/**
 * Aceitação do port fiel: recalcular no Node e comparar com o hash que o APP
 * (Dart) gravou no emulador para a parcela semeada (docs/EVIDENCIAS-EMULADOR.md):
 *   insumos_hash = 6b41ee497d67f55b8374c9c6ab26257f9bd8e10f86a4b9777639cd7b68935a92
 *   tco2e_ha    = 59.8949587106818 · ic95 = 36.06515237683653 (±60.214%)
 * Se este teste passar, "a auditoria refaz a conta sozinha" é verdade.
 */
import { describe, it, expect } from 'vitest';
import { webcrypto } from 'node:crypto';
import { calcularParcela, hashInsumos } from '../src/services/mrvCalc.js';

if (!globalThis.crypto?.subtle) {
  globalThis.crypto = webcrypto;
}

const plantas = [
  { uuid: 'emu-up1', especie: 'Eucalyptus grandis', dap_cm: 32.5, altura_cm: 1250.0, autor_uuid: 'emu-admin-0001' },
  { uuid: 'emu-up2', especie: 'Eucalyptus grandis', dap_cm: 21.0, altura_cm: 980.0, autor_uuid: 'emu-admin-0001' },
  { uuid: 'emu-up3', especie: 'Pinus taeda', dap_cm: 41.2, altura_cm: 1500.0, autor_uuid: 'emu-admin-0001' },
];

const AREA_M2 = 400.0;

describe('mrvCalc — port fiel do Dart', () => {
  it('reproduz tco2e_ha e IC95 do app', () => {
    const r = calcularParcela({ plantas, areaM2: AREA_M2 });
    expect(r.tco2e_ha).toBeCloseTo(59.8949587106818, 8);
    expect(r.ic95_tco2e_ha).toBeCloseTo(36.06515237683653, 8);
    expect(r.incerteza_pct).toBeCloseTo(60.21400323697793, 8);
    expect(r.n_individuos).toBe(3);
    expect(r.n_com_dap).toBe(3);
    expect(r.densidade_fonte).toBe('fallback_0.60');
  });

  it('reproduz o insumos_hash gravado pelo app', async () => {
    const r = calcularParcela({ plantas, areaM2: AREA_M2 });
    const hash = await hashInsumos(r);
    expect(hash).toBe(
      '6b41ee497d67f55b8374c9c6ab26257f9bd8e10f86a4b9777639cd7b68935a92',
    );
  });

  it('densidade do catálogo muda o resultado e o hash', async () => {
    const sem = calcularParcela({ plantas, areaM2: AREA_M2 });
    const com = calcularParcela({
      plantas,
      areaM2: AREA_M2,
      densidadesPorEspecie: { 'eucalyptus grandis': 0.55, 'pinus taeda': 0.50 },
    });
    expect(com.densidade_fonte).toBe('catalogo_especies');
    expect(com.tco2e_ha).not.toBe(sem.tco2e_ha);
    expect(await hashInsumos(com)).not.toBe(await hashInsumos(sem));
  });

  it('n<2 nao calcula IC (honestidade)', () => {
    const r = calcularParcela({ plantas: [plantas[0]], areaM2: AREA_M2 });
    expect(r.incerteza.incerteza_pct).toBeNull();
    expect(r.incerteza.observacao).toContain('n < 2');
  });
});
