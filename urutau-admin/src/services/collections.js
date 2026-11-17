/**
 * Mapa nome → ID real das coleções PocketBase (R0 da SPEC-ADMIN-VERIFICADOR).
 * Nenhuma página usa string de coleção solta — evita ler a coleção errada
 * quando o servidor subir com os IDs definitivos.
 * Fonte: urutau-app/lib/data/migrations/mrv_tables.dart + sync_service.dart.
 */
export const COLLECTIONS = {
  parcelas: 'pbc_3294281715',
  plantas: 'pbc_114875327',
  fotos: 'fotos_parcela',
  trilha: 'trilha_auditoria',
  ativos: 'ativos_brutos',
  incidentes: 'incidentes',
  desenho: 'desenho_amostral',
  projetos: 'projetos_mrv',
  campanhas: 'campanhas',
  competencias: 'competencias',
  verificacoes: 'verificacoes_internas',
  usuarios: 'users',
};

/** Campos canônicos por coleção (documentação viva pra quem for implementar). */
export const FIELDS = {
  parcelas: [
    'id', 'id_parcela', 'prop_ut', 'propriedade', 'user', 'latitude', 'longitude',
    'area_ha', 'area_m2', 'unidade_forma', 'raio_m', 'marcador', 'status_parcela',
    'status_verificacao', 'prontaParaSync', 'synced', 'protocolo_versao',
    'projeto_id', 'periodo_id', 'substituta_de', 'fotos_parcela', 'fotos_meta',
    'geo_json', 'observacoes', 'created', 'updated',
  ],
  plantas: [
    'id', 'uuid_local', 'parcela', 'especie', 'dap_cm', 'altura_cm', 'categoria',
    'foto_especie', 'autor', 'created',
  ],
  trilha: [
    'id', 'id_seq', 'acao', 'entidade_tipo', 'entidade_uuid', 'usuario_uuid',
    'antes', 'depois', 'ts_servidor', 'ts_dispositivo', 'offset_relogio_ms',
    'origem', 'prev_hash', 'entry_hash',
  ],
  ativos: [
    'id', 'ativo_uuid', 'entidade_tipo', 'entidade_uuid', 'caminho_original',
    'sha256', 'sha256_verificado', 'bytes', 'status', 'dispositivo_uuid',
  ],
  incidentes: [
    'id', 'tipo', 'severidade', 'descricao', 'entidade_tipo', 'entidade_uuid',
    'bloqueia_uso_para_credito', 'detectado_em', 'resolvido_em',
  ],
};

/** Resolve nome lógico → id/collection usável no client. */
export const col = (pb, name) => pb.collection(COLLECTIONS[name]);
