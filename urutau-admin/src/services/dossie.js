/**
 * R10 — Dossiê no painel. O ZIP completo (manifesto.json + dados.json +
 * dossie.pdf + fotos) é gerado pelo app (`dossie_service.dart`). O painel:
 *  - se o arquivo está publicado na parcela (`dossie_zip`) ou nos ativos,
 *    baixa e oferece verificar cada hash do manifesto contra o arquivo;
 *  - senão, mostra os metadados conferíveis (insumos_hash, ativos, cadeia)
 *    e diz onde o ZIP é gerado (app de campo).
 */
import { pb } from './pocketbase';
import safeError from './logger';
import { USE_MOCK } from './mock/demoData';
import { sha256Hex } from './mrvCalc';

const MANIFESTO_MOCK = {
  gerado_em_relogio_confiavel: '2026-11-06T11:59:43.299378Z',
  parcela_uuid: 'demo-parcela-01',
  arquivos: {
    'dados.json': {
      sha256: '195c0301891e8862f3479e46281bd990c512ca731bd2a18ebe19d1360e622b9e',
      bytes: 1453,
    },
    'dossie.pdf': {
      sha256: '4e5adb800b358572940c566ea182c27531a1f6c551599dc00cd0baef7716927a',
      bytes: 6035,
    },
  },
  verificacao: { cadeia_local: 'INTEGRA', cadeia_servidor: 'INTEGRA (ultimo sync)', creditacao: 'liberada' },
};

/** Metadados/hash do manifesto publicados no servidor para a parcela. */
export const fetchManifesto = async (parcelaId) => {
  if (USE_MOCK) {
    return {
      ok: true,
      offline: false,
      data: { fonte: 'manifesto publicado (demo)', manifesto: MANIFESTO_MOCK, arquivoUrl: null },
    };
  }
  try {
    const rec = await pb.collection('parcelas').getOne(parcelaId, {
      fields: 'id,dossie_zip,dossie_manifesto',
    });
    const manifestoRaw = rec?.dossie_manifesto;
    let manifesto = null;
    if (manifestoRaw) {
      manifesto = typeof manifestoRaw === 'string' ? JSON.parse(manifestoRaw) : manifestoRaw;
    }
    const arquivoUrl = rec?.dossie_zip
      ? pb.files.getUrl(rec, rec.dossie_zip, { download: true })
      : null;
    return { ok: true, offline: false, data: { manifesto, arquivoUrl } };
  } catch (error) {
    safeError('fetchManifesto', error);
    return {
      ok: false,
      offline: true,
      data: { manifesto: null, arquivoUrl: null },
      error: String(error?.message || error),
    };
  }
};

/**
 * Verifica o hash de UM arquivo do dossiê baixado contra o manifesto.
 * O usuário seleciona o arquivo (ou baixamos do servidor quando há URL);
 * devolvemos { confere, sha256Calculado, sha256Manifesto }.
 */
export const verificarArquivoDossie = async (arquivo /* File */, sha256Manifesto) => {
  try {
    const bytes = new Uint8Array(await arquivo.arrayBuffer());
    const digest = await crypto.subtle.digest('SHA-256', bytes);
    const sha256Calculado = [...new Uint8Array(digest)]
      .map((b) => b.toString(16).padStart(2, '0'))
      .join('');
    return {
      ok: true,
      confere: sha256Calculado === sha256Manifesto,
      sha256Calculado,
      sha256Manifesto,
    };
  } catch (error) {
    safeError('verificarArquivoDossie', error);
    return { ok: false, error: String(error?.message || error) };
  }
};

export const hashDeTexto = sha256Hex;
