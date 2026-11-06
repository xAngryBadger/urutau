import { useEffect, useState, useCallback, useRef, startTransition } from 'react';
import { checkServerHealth } from '../services/health';

/**
 * Monitora o servidor a cada 30s (+ navigator.onLine). Expõe
 * { status: 'online'|'offline'|'checking', lastOkAt }.
 * Servidor só existe no lançamento — o painel precisa DIZER que está offline
 * em vez de mostrar dados vazios sem explicação.
 */
export function useServerHealth({ intervalMs = 30000 } = {}) {
  const [status, setStatus] = useState('checking');
  const [lastOkAt, setLastOkAt] = useState(null);
  const [latencyMs, setLatencyMs] = useState(null);
  const mounted = useRef(true);

  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
    };
  }, []);

  const check = useCallback(async () => {
    const res = await checkServerHealth();
    if (!mounted.current) return;
    if (res.ok) {
      setStatus('online');
      setLastOkAt(new Date());
      setLatencyMs(res.latencyMs ?? null);
    } else {
      setStatus('offline');
    }
  }, []);

  useEffect(() => {
    // startTransition: o check inicial mexe em estados; dentro de transição o
    // React 19 não trata como render em cascata (regra react-hooks).
    startTransition(() => { check(); });
    const timer = setInterval(() => {
      startTransition(() => { check(); });
    }, intervalMs);
    const onOnline = () => startTransition(() => { check(); });
    window.addEventListener('online', onOnline);
    return () => {
      clearInterval(timer);
      window.removeEventListener('online', onOnline);
    };
  }, [check, intervalMs]);

  return { status, lastOkAt, latencyMs, recheck: check };
}

export default useServerHealth;
