import { pb } from './pocketbase';

/**
 * Health check do PocketBase. Distingue OFFLINE (rede/servidor) de VAZIO
 * (consulta ok, zero registros) —Zero só é válido quando a consulta deu certo.
 */
let cache = { at: 0, result: null };
const CACHE_MS = 15000;

export const checkServerHealth = async ({ force = false } = {}) => {
  const now = Date.now();
  if (!force && cache.result && now - cache.at < CACHE_MS) {
    return cache.result;
  }
  const started = now;
  try {
    await pb.health.check();
    // health sozinho pode responder 200 mesmo em coleção inexistente; uma
    // consulta real confirma que o schema está acessível.
    await pb.collection('users').getList(1, 1);
    const result = { ok: true, offline: false, latencyMs: Date.now() - started };
    cache = { at: now, result };
    return result;
  } catch (error) {
    const result = {
      ok: false,
      offline: true,
      latencyMs: Date.now() - started,
      error: String(error?.message || error),
    };
    cache = { at: now, result };
    return result;
  }
};

export default checkServerHealth;
