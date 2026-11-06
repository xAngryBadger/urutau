// @vitest-environment node
import { describe, it, expect, beforeAll } from 'vitest';
import { webcrypto } from 'node:crypto';
import { buildMockChain } from '../src/services/mock/chain.js';

// pocketbase.js toca window no import — stubs antes do import dinâmico.
beforeAll(() => {
  if (!globalThis.window) {
    globalThis.window = { location: { origin: 'http://localhost' } };
  }
  if (!globalThis.crypto?.subtle) {
    globalThis.crypto = webcrypto;
  }
});

describe('mock chain (cadeia hasheada de verdade)', () => {
  it('constrói 4 elos com hash encadeado', async () => {
    const rows = await buildMockChain();
    expect(rows).toHaveLength(4);
    expect(rows[0].prev_hash).toBe('GENESIS');
    for (let i = 1; i < rows.length; i++) {
      expect(rows[i].prev_hash).toBe(rows[i - 1].entry_hash);
    }
  });

  it('verificarCadeiaGlobal acusa QUEBRADA no elo adulterado (demo)', async () => {
    const { verificarCadeiaGlobal } = await import('../src/services/mrv.js');
    const res = await verificarCadeiaGlobal();
    expect(res.ok).toBe(true);
    expect(res.integra).toBe(false);
    expect(res.quebradoEm).toBe('mock-trilha-3');
    expect(res.motivo).toContain('payload adulterado');
  });

  it('se o elo adulterado for corrigido, a cadeia fica ÍNTEGRA', async () => {
    const rows = await buildMockChain();
    // desfaz a adulteração: grava o depois que foi hasheado
    rows[2].depois = rows[2].entidade_uuid;
    const { canonicalPayloadForTest } = await import('./helpers/canonical.js');
    const recalc = await canonicalPayloadForTest(rows[2], rows[2].prev_hash);
    expect(recalc).toBe(rows[2].entry_hash);
  });
});
