/**
 * Dados de demonstração (VITE_USE_MOCK=true) — o PocketBase de produção só
 * existe no lançamento. Os hashes NÃO são fingidos: são calculados com o mesmo
 * port do app (mrvCalc.js / payload canônico da trilha), então "refazer a
 * conta" e "verificar cadeia" realmente conferem. Tela com dado mock exibe o
 * selo "DADOS DE DEMONSTRAÇÃO" (DemoBanner).
 */
import { calcularParcela, hashInsumos } from '../mrvCalc';

export const USE_MOCK = import.meta.env.VITE_USE_MOCK === 'true';

const MOCK_AREAS = [
  { uuid: 'demo-parcela-01', id_parcela: 1, propertyCode: 'Fazenda Modelo', utCode: 'UT-01', latitude: -23.5505, longitude: -46.6333, area_m2: 400, status_verificacao: 'pendente', prontaParaSync: true, protocolo_versao: 'SOP-MRV-V1', projeto_id: 'LEGADO-PROJ-0000', createdAt: '2026-11-06T11:24:53.000Z', user: 'Ana Ribeiro' },
  { uuid: 'demo-parcela-02', id_parcela: 2, propertyCode: 'Fazenda Modelo', utCode: 'UT-01', latitude: -23.5511, longitude: -46.6341, area_m2: 400, status_verificacao: 'revisado', prontaParaSync: true, protocolo_versao: 'SOP-MRV-V1', projeto_id: 'LEGADO-PROJ-0000', createdAt: '2026-11-05T10:02:11.000Z', user: 'Ana Ribeiro' },
  { uuid: 'demo-parcela-03', id_parcela: 3, propertyCode: 'Sítio Boa Vista', utCode: 'UT-02', latitude: -22.9112, longitude: -43.1904, area_m2: 900, status_verificacao: 'aprovado', prontaParaSync: false, protocolo_versao: 'SOP-MRV-V1', projeto_id: null, createdAt: '2026-11-04T15:44:00.000Z', user: 'Carlos Lima' },
];

const PLANTAS = {
  'demo-parcela-01': [
    { uuid: 'demo-p1', especie: 'Eucalyptus grandis', dap_cm: 32.5, altura_cm: 1250.0, autor_uuid: 'demo-ana' },
    { uuid: 'demo-p2', especie: 'Eucalyptus grandis', dap_cm: 21.0, altura_cm: 980.0, autor_uuid: 'demo-ana' },
    { uuid: 'demo-p3', especie: 'Pinus taeda', dap_cm: 41.2, altura_cm: 1500.0, autor_uuid: 'demo-ana' },
  ],
  'demo-parcela-02': [
    { uuid: 'demo-p4', especie: 'Eucalyptus grandis', dap_cm: 28.9, altura_cm: 1100.0, autor_uuid: 'demo-ana' },
    { uuid: 'demo-p5', especie: 'Eucalyptus grandis', dap_cm: 30.1, altura_cm: 1180.0, autor_uuid: 'demo-ana' },
  ],
  'demo-parcela-03': [
    { uuid: 'demo-p6', especie: 'Handroanthus chrysotrichus', dap_cm: 18.4, altura_cm: 760.0, autor_uuid: 'demo-carlos' },
  ],
};

const FOTOS_META = {
  'demo-parcela-01': [
    { arquivo: 'foto_01.jpg', sha256: 'aa11bb22cc33dd44ee55ff6677889900aa11bb22cc33dd44ee55ff6677889900', lat: -23.5505, long: -46.6333, timestamp: '2026-11-06T11:24:53.000Z', autor: 'Ana Ribeiro' },
    { arquivo: 'foto_02.jpg', sha256: null, lat: -23.5506, long: -46.6334, timestamp: '2026-11-06T11:25:10.000Z', autor: 'Ana Ribeiro' },
  ],
  'demo-parcela-02': [
    { arquivo: 'foto_11.jpg', sha256: '11223344556677889900aabbccddeeff11223344556677889900aabbccddeeff', lat: -23.5511, long: -46.6341, timestamp: '2026-11-05T10:02:11.000Z', autor: 'Ana Ribeiro' },
  ],
  'demo-parcela-03': [],
};

const INCIDENTES = {
  'demo-parcela-01': [
    {
      id: 'demo-inc-1', tipo: 'hash_divergente', severidade: 'bloqueadora',
      descricao: 'Hash do ativo no catálogo difere do arquivo re-enviado (demo)',
      entidade_tipo: 'parcela', entidade_uuid: '',
      bloqueia_uso_para_credito: true, detectado_em: '2026-11-06T11:26:00.000Z', resolvido_em: null,
    },
  ],
  'demo-parcela-02': [],
  'demo-parcela-03': [],
};

const ATIVOS = {
  'demo-parcela-01': [
    { id: 'demo-a1', entidade_tipo: 'foto', entidade_uuid: 'demo-parcela-01', caminho_original: 'foto_01.jpg', sha256: 'aa11bb22cc33dd44ee55ff6677889900aa11bb22cc33dd44ee55ff6677889900', sha256_verificado: true, status: 'presente', dispositivo_uuid: 'demo-device' },
    { id: 'demo-a2', entidade_tipo: 'foto', entidade_uuid: 'demo-parcela-01', caminho_original: 'foto_02.jpg', sha256: null, sha256_verificado: false, status: 'pendente_hash', dispositivo_uuid: 'demo-device' },
  ],
  'demo-parcela-02': [
    { id: 'demo-a3', entidade_tipo: 'foto', entidade_uuid: 'demo-parcela-02', caminho_original: 'foto_11.jpg', sha256: '11223344556677889900aabbccddeeff11223344556677889900aabbccddeeff', sha256_verificado: true, status: 'presente', dispositivo_uuid: 'demo-device' },
  ],
  'demo-parcela-03': [],
};

/** Cálculos com hash REAL (port do app) — "refazer a conta" confere. */
export async function mockCalculo(parcelaUuid) {
  const plantas = PLANTAS[parcelaUuid] || [];
  const area = MOCK_AREAS.find((p) => p.uuid === parcelaUuid)?.area_m2 ?? 400;
  const r = calcularParcela({ plantas, areaM2: area });
  const hash = await hashInsumos(r);
  return {
    id: `mock-calc-${parcelaUuid}`,
    escopo_tipo: 'parcela',
    escopo_uuid: parcelaUuid,
    insumos_hash: hash,
    fracao_carbono: r.fracao_carbono,
    pools_incluidos: ['agb_aerea'],
    status: INCIDENTES[parcelaUuid]?.length ? 'bloqueado_incidente' : 'valido',
    resultado: {
      n_individuos: r.n_individuos, n_com_dap: r.n_com_dap,
      tco2e_ha: r.tco2e_ha, tco2e_total: r.tco2e_total,
      incerteza_pct: r.incerteza_pct, ic95_tco2e_ha: r.ic95_tco2e_ha,
      area_m2: r.area_m2,
    },
    incerteza: r.incerteza,
    created: '2026-11-06T11:26:30.000Z',
  };
}

/**
 * Trilha mock com cadeia REAL: cada elo é hasheado com o mesmo payload
 * canônico do app (services/mrv.js canonicalPayload). A parcela 02 tem um elo
 * com payload adulterado para demonstrar o estado "QUEBRADA".
 */
export async function mockTrilha() {
  const { buildMockChain } = await import('./chain.js');
  return buildMockChain();
}

export const mockParcels = MOCK_AREAS.map((p) => ({
  ...p,
  fotos_parcela: [],
  photoCount: (FOTOS_META[p.uuid] || []).length,
  displayUser: p.user,
  synced: false,
  statusVerificacao: p.status_verificacao,
  protocoloVersao: p.protocolo_versao,
  projetoId: p.projeto_id,
  areaM2: p.area_m2,
  latitude: p.latitude,
  longitude: p.longitude,
}));

export const mock = {
  parcels: mockParcels,
  plants: PLANTAS,
  fotosMeta: FOTOS_META,
  incidentes: INCIDENTES,
  ativos: ATIVOS,
};
