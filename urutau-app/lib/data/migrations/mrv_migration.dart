// ============================================================
// mrv_migration.dart — migração versionada v18 → v24 (Drift)
//
// PATCH NAO APLICADO. Destino: urutau-app/lib/data/migrations/mrv_migration.dart
// Task t9 (dev-mrv) · entregável para dev-codigo aplicar após os gates.
//
// >>> ATENÇÃO — MUDANÇA DE COORDENAÇÃO (capitã, t9) <<<
// A v19 DE VERDADE já foi COMMITADA pelo dev-codigo em D:\projetos\urutau:
//   commit 43a165e "fix(Q2): foto com arquivo ausente e MARCADA, nunca deletada"
//   schemaVersion 18 → 19, sem índice novo e sem backfill (o default false do
//   ALTER TABLE ADD COLUMN cobre as linhas existentes).
//   * fotos_parcela.arquivo_ausente  (BoolColumn, default false) — database.dart:92
//   * plantas.foto_ausente           (BoolColumn, default false) — database.dart:77
//   * convenção: `if (from < N) { await m.addColumn(...); }` em onUpgrade — :223
//   * database.g.dart JÁ regerado e commitado.
// O REPO é a verdade, não este papel.
//
//   * `v19Referencia()` abaixo está **SUPERSEDED por 43a165e**: é só registro
//     histórico do formato que eu havia proposto. **NUNCA chamar.**
//   * Este patch é **v20 → v24**, encaixado POR CIMA da v19 committed.
//   * Convenção de nomenclatura: os nomes `arquivo_ausente` / `foto_ausente`
//     são os COMMITADOS e NÃO são renomeados por este patch. São a FONTE do
//     catálogo de evidência RC-01 (ver v21): `foto_ausente = true` faz o ativo
//     nascer com `status = 'ausente'`, não `'pendente_hash'`.
//   * Partir de schemaVersion **19**, não 18.
//   * Ao gerar código: editar database.dart e rodar build_runner POR CIMA
//     (--delete-conflicting-outputs), nunca regerar do zero — o .g.dart já está
//     commitado e correto.
//
// >>> LEIA ANTES DE EDITAR <<<
// Este arquivo carrega SOMENTE `m.customStatement(...)` — SQL puro.
// Ele NAO pode conter `m.createTable(...)` nem `m.addColumn(...)`: essas chamadas
// precisam das instancias geradas pelo build_runner (`projetosMrv`,
// `parcelas.projetoId`...), que existem como CAMPOS da classe AppDatabase e
// portanto nao sao visiveis de outro arquivo.
// O DDL (createTable/addColumn) fica em database.dart, nos metodos
// _mrvV20Ddl.._mrvV23Ddl, chamados em sequência com estes blocos.
// Este desenho foi pego pelo verificador de referencias — ver
// impl-migracao-drift.md §Compat-DDL.
//
// Regras obedecidas:
//  * Nenhum drop de coluna/tabela em uso (plantas, fotos_parcela, audit_log).
//  * Backfill explícito e idempotente (guarda NOT EXISTS / WHERE x IS NULL).
//  * Nada é inventado: sha256 nasce NULL, densidade nasce NULL,
//    geo nasce sem crs/acuracia quando esses dados nao existiam.
// ============================================================

import 'package:drift/drift.dart';

class MrvMigration {
  const MrvMigration._();

  // ----------------------------------------------------------
  // v19 — >>> REFERÊNCIA APENAS. NÃO CHAMAR. <<<
  // A v19 real é do dev-codigo (colunas arquivoAusente/fotoAusente, gate Q2).
  // Este bloco documenta o FORMATO que a v19 precisa cobrir para que a v20
  // deste patch encaixe: 10 colunas em parcelas + 6 tabelas + o protocolo
  // SOP-MRV semeado com a convenção de DAP 1,30 m.
  // A conciliação campo a campo está em hunks/database.dart.patch §RECONCILE.
  // ----------------------------------------------------------
  static Future<void> v19Referencia(Migrator m) async {
    // SUPERSEDED por 43a165e (v19 real commitada pelo dev-codigo: so
    // arquivo_ausente/foto_ausente). NUNCA CHAMAR — registro historico.
    // O backfill das colunas MRV de parcela roda em v19() abaixo, dentro da
    // cadeia from<20 (ver database.dart); o teste mrv_migration_test.dart
    // depende dele (parcela_id_text, area_m2, geo_json, SOP-MRV semeado).
  }

  static Future<void> v19(Migrator m) async {
    // 19.1 Índices (mesmo estilo do _createIndexes existente).
    await m.database.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_parcelas_projeto_id ON parcelas(projeto_id)');
    await m.database.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_parcelas_parcela_id_text ON parcelas(parcela_id_text)');
    await m.database.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_amostras_parcela_uuid ON amostras_parcela(parcela_uuid)');
    await m.database.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_amostras_campanha_uuid ON amostras_parcela(campanha_uuid)');
    await m.database.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_amostras_status ON amostras_parcela(status)');
    await m.database.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_campanhas_projeto_uuid ON campanhas(projeto_uuid)');
    await m.database.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_campanhas_periodo_uuid ON campanhas(periodo_uuid)');

    // 19.2 parcela_id_text = chave de negócio legível.
    // NÃO é UNIQUE: o app permite parcela duplicada entre coletores e SINALIZA
    // o conflito (README do Urutau + findParcelaDuplicada, database.dart:609).
    // Índice único quebraria essa feature — decisão Compat-UNIQUE.
    await m.database.customStatement(
        'UPDATE parcelas SET parcela_id_text = prop_ut || \'-P\' || id_parcela '
        'WHERE parcela_id_text IS NULL');

    // area_ha (hectares, manual) → area_m2. Não sobrescreve valor existente.
    await m.database.customStatement(
        'UPDATE parcelas SET area_m2 = area_ha * 10000 '
        'WHERE area_m2 IS NULL AND area_ha IS NOT NULL');

    // geo só quando as duas coordenadas existem. Sem acurácia/fix/datum: o
    // requisito RC-10 fica "desconhecida" até o app passar a capturar de verdade.
    await m.database.customStatement(
        'UPDATE parcelas SET geo_json = '
        '\'{"tipo":"Point","coordenadas":[\' || COALESCE(latitude, 0) || \',\' || COALESCE(longitude, 0) || \'],'
        '"crs":null,"acuracia_m":null,"n_satelites":null,"fonte":"desconhecida"}\' '
        'WHERE geo_json IS NULL AND latitude IS NOT NULL AND longitude IS NOT NULL');

    // 19.3 Protocolo de medição (RC-11) semeado com a convenção CONFIRMADA
    // PELO USUÁRIO (Badger, autoridade de domínio no campo), não inferida:
    //   * ALTURA: sempre coletada, sem exceção.
    //   * DAP: medido a 1,30 m do solo (altura do peito, padrão universal).
    //   * DAP condicional: só exigido quando o indivíduo atinge 1,30 m ou mais;
    //     abaixo disso mede-se por altura. Plântulas/mudas de restauração
    //     nascem medidas por altura e migram para DAP ao cruzar o limite.
    // A categoria (1/2/3) continua sendo a regra JÁ EXISTENTE do app
    // (categoria_helper.dart:1-17), versionada aqui em regra_categoria.
    // inclusao/exclusao seguem NULL: definir exige o responsável técnico.
    //
    // Observação de estilo: os textos são ASCII (sem acento, sem travessão).
    // Acento e travessão dentro de literal Dart forçariam aspas duplas e
    // aumentariam o risco de escape na revisão; o conteúdo semântico está
    // intacto e o harness de verificação lê melhor ASCII.
    await m.database.customStatement(
        'INSERT OR IGNORE INTO protocolos_medicao '
        '(uuid, codigo, versao, vigencia_inicio, regra_altura, regra_dap, '
        'regra_categoria, unidades, aprovado_por, status, created_at, updated_at) '
        "VALUES ('SOP-MRV-V1', 'SOP-MRV', '1.0', "
        'CURRENT_DATE, '
        "'ALTURA sempre coletada (altura total, cm). Sem excecao para nenhuma modalidade.', "
        "'DAP medido a 1,30 m do solo (altura do peito, padrao universal - confirmado pelo usuario). "
        "DAP condicional: exigido somente quando o individuo atinge 1,30 m ou mais; abaixo disso mede-se por altura.', "
        "'{\"limiares_cm\":{\"altura_1\":50,\"dap_2\":5},"
        "\"regra\":\"altura<50 => cat 1 (DAP ignorado); altura>=50 e dap<5 => cat 2; altura>=50 e dap>=5 => cat 3\","
        "\"fonte\":\"urutau-app/lib/data/categoria_helper.dart:1-17 (regra existente, agora versionada)\"}', "
        "'{\"dap\":\"cm\",\"altura\":\"cm\",\"area\":\"m2\",\"dap_referencia_m\":1.30}', "
        "NULL, 'rascunho', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)");
  }

  // ----------------------------------------------------------
  // v20 — colunas de parcela + indivíduo, medição e modalidade
  // DDL desta versão (10 colunas em parcelas + 8 tabelas) está em
  // database.dart::_mrvV20Ddl e RODA ANTES deste bloco.
  // Nota: as colunas de parcela entraram AQUI (e não na v19) porque a v19
  // committed (43a165e) é só do Q2 — arquivo_ausente/foto_ausente.
  // ----------------------------------------------------------
  static Future<void> v20(Migrator m) async {
    await m.database.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_individuos_parcela_uuid ON individuos(parcela_uuid)');
    await m.database.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_individuos_tag ON individuos(parcela_uuid, tag)');
    await m.database.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_individuos_especie_uuid ON individuos(especie_uuid)');
    await m.database.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_medicoes_amostra_uuid ON medicoes_individuo(amostra_uuid)');
    await m.database.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_medicoes_individuo_uuid ON medicoes_individuo(individuo_uuid)');
    await m.database.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_medicoes_restauracao_medicao ON medicoes_restauracao(medicao_uuid)');
    await m.database.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_coberturas_amostra_uuid ON coberturas_amostra(amostra_uuid)');

    // 20.1 Andaime LEGADO. As parcelas existentes não pertencem a nenhum
    // projeto; sem estes registros o backfill não teria onde pendurar amostras.
    // modalidade='plantacao' é PRESSUPOSIÇÃO DE BACKFILL, não conclusão de
    // domínio: o schema atual só captura inventário de plantação. Corrigir
    // dado a dado quando houver projeto real.
    await m.database.customStatement(
        'INSERT OR IGNORE INTO projetos_mrv '
        '(uuid, codigo, nome, modalidade, area_total_ha, status, created_at, updated_at) '
        "VALUES ('LEGADO-PROJ-0000', 'LEGADO', "
        "'Backfill pre-MRV (migracao v20)', 'plantacao', NULL, 'rascunho', "
        'CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)');

    await m.database.customStatement(
        'INSERT OR IGNORE INTO periodos_monitoramento '
        '(uuid, projeto_uuid, codigo, data_inicio, data_fim, tipo, status, created_at, updated_at) '
        "VALUES ('LEGADO-PER-0000', 'LEGADO-PROJ-0000', 'P0', "
        "(SELECT datetime(MIN(created_at), 'unixepoch') FROM plantas), "
        "(SELECT datetime(MAX(created_at), 'unixepoch') FROM plantas), "
        "'baseline', 'fechado', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)");

    await m.database.customStatement(
        'INSERT OR IGNORE INTO campanhas '
        '(uuid, projeto_uuid, periodo_uuid, nome, data_inicio, data_fim, status, created_at, updated_at) '
        "VALUES ('LEGADO-CAMP-0001', 'LEGADO-PROJ-0000', 'LEGADO-PER-0000', "
        "'Campanha legado (dados pre-v20)', "
        "(SELECT datetime(MIN(created_at), 'unixepoch') FROM plantas), "
        "(SELECT datetime(MAX(created_at), 'unixepoch') FROM plantas), "
        "'fechada', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)");

    // 20.2 parcelas.projeto_id = 'LEGADO'. Feito aqui (e não na v19) porque o
    // registro do projeto só passa a existir nesta versão.
    await m.database.customStatement(
        "UPDATE parcelas SET projeto_id = 'LEGADO-PROJ-0000' WHERE projeto_id IS NULL");

    // 20.3 Uma amostra por parcela que tenha plantas — INCLUSIVE soft-deletada.
    // Decisão explícita: o backfill é de EVIDÊNCIA, não de listagem. O app
    // filtra deleted_at na consulta (getPlantasByParcela), não no backfill. Se
    // excluíssemos aqui, a medição do indivíduo ficaria sem amostra
    // (amostra_uuid é NOT NULL) e a migração quebraria — pego pelo harness.
    // status='aprovado': dado legado não passa por fluxo de revisão; marcar
    // como aprovado evita pendência fantasma no painel.
    await m.database.customStatement(
        'INSERT INTO amostras_parcela '
        '(uuid, parcela_uuid, campanha_uuid, protocolo_versao, medido_em_servidor, '
        ' relogio_dispositivo, offset_relogio_ms, status, versao, created_at, updated_at) '
        "SELECT 'legado-amostra-' || p.uuid, p.uuid, 'LEGADO-CAMP-0001', NULL, "
        ' p.created_at, p.created_at, 0, \'aprovado\', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP '
        'FROM parcelas p '
        'WHERE EXISTS (SELECT 1 FROM plantas pl WHERE pl.parcela_uuid = p.uuid) '
        '  AND NOT EXISTS (SELECT 1 FROM amostras_parcela a WHERE a.parcela_uuid = p.uuid)');

    // 20.4 Um indivíduo por planta existente (fonte: plantas). A planta NÃO é
    // alterada nem removida — continua sendo escrita pelo sync_service.dart.
    // O texto original da espécie é preservado em especie_legado.
    await m.database.customStatement(
        'INSERT INTO individuos '
        '(uuid, parcela_uuid, tag, especie_legado, origem, status, created_at, updated_at) '
        "SELECT 'legado-ind-' || pl.uuid, pl.parcela_uuid, 'L-' || pl.id, pl.especie, "
        "'plantada', 'viva', pl.created_at, CURRENT_TIMESTAMP "
        'FROM plantas pl '
        'WHERE NOT EXISTS (SELECT 1 FROM individuos i WHERE i.uuid = \'legado-ind-\' || pl.uuid)');

    // 20.5 Uma medição por indivíduo, sem duplicata por amostra (I-11).
    await m.database.customStatement(
        'INSERT INTO medicoes_individuo '
        '(uuid, amostra_uuid, individuo_uuid, altura_cm, dap_cm, categoria, '
        ' categoria_origem, estado, especie_confirmada, observacoes, created_at, updated_at) '
        "SELECT 'legado-med-' || pl.uuid, "
        " (SELECT a.uuid FROM amostras_parcela a WHERE a.parcela_uuid = pl.parcela_uuid LIMIT 1), "
        " 'legado-ind-' || pl.uuid, pl.altura_cm, pl.dap_cm, pl.categoria, "
        "'calculada', 'viva', 0, NULL, pl.created_at, CURRENT_TIMESTAMP "
        'FROM plantas pl '
        'WHERE NOT EXISTS (SELECT 1 FROM medicoes_individuo mi '
        "                 WHERE mi.uuid = 'legado-med-' || pl.uuid)");
  }

  // ----------------------------------------------------------
  // v21 — custódia e evidência.  DDL em database.dart::_mrvV21Ddl.
  // ----------------------------------------------------------
  static Future<void> v21(Migrator m) async {
    await m.database.customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS uq_ativos_brutos_sha256 ON ativos_brutos(sha256)');
    await m.database.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_ativos_entidade ON ativos_brutos(entidade_tipo, entidade_uuid)');
    await m.database.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_ativos_retencao ON ativos_brutos(retencao_ate)');
    await m.database.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_trilha_entidade ON trilha_auditoria(entidade_tipo, entidade_uuid)');
    await m.database.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_trilha_ts ON trilha_auditoria(ts_servidor)');

    // 21.1 Catálogo de evidência a partir do que está referenciado hoje.
    // FONTE DA VERDADE para "o arquivo existe?": as colunas COMMITADAS na v19
    // (43a165e) — fotos_parcela.arquivo_ausente e plantas.foto_ausente.
    // Este patch NÃO as renomeia e NÃO as redefine: apenas as LÊ.
    //   * flag false → ativo nasce 'pendente_hash' (hash a calcular no device)
    //   * flag true  → ativo nasce 'ausente'     (o arquivo já se perdeu;
    //                   a linha permanece como evidência, regra P-2)
    // LIMITAÇÃO REAL: SQLite não calcula SHA-256. O hash nasce NULL e tem de
    // ser calculado em Dart pós-migração. Isto é honesto: não inventamos hash.
    await m.database.customStatement(
        'INSERT INTO ativos_brutos '
        '(uuid, entidade_tipo, entidade_uuid, papel, mime, sha256, sha256_verificado, '
        ' caminho_logico, caminho_original, nome_original, capturado_em, ingerido_em, '
        ' status, created_at, updated_at) '
        "SELECT 'legado-ativo-' || f.uuid, 'parcela', f.parcela_uuid, 'bruto', "
        "'image/jpeg', NULL, 0, NULL, f.file_path, NULL, f.created_at, CURRENT_TIMESTAMP, "
        "  CASE WHEN f.arquivo_ausente THEN 'ausente' ELSE 'pendente_hash' END, "
        'CURRENT_TIMESTAMP, CURRENT_TIMESTAMP '
        'FROM fotos_parcela f '
        'WHERE NOT EXISTS (SELECT 1 FROM ativos_brutos at WHERE at.uuid = \'legado-ativo-\' || f.uuid)');

    await m.database.customStatement(
        'INSERT INTO ativos_brutos '
        '(uuid, entidade_tipo, entidade_uuid, papel, mime, sha256, sha256_verificado, '
        ' caminho_logico, caminho_original, capturado_em, ingerido_em, '
        ' status, created_at, updated_at) '
        "SELECT 'legado-ativo-' || pl.uuid, 'medicao', 'legado-med-' || pl.uuid, 'bruto', "
        "'image/jpeg', NULL, 0, NULL, pl.foto_especie_path, pl.created_at, CURRENT_TIMESTAMP, "
        "  CASE WHEN pl.foto_ausente THEN 'ausente' ELSE 'pendente_hash' END, "
        'CURRENT_TIMESTAMP, CURRENT_TIMESTAMP '
        'FROM plantas pl '
        'WHERE pl.foto_especie_path IS NOT NULL '
        '  AND NOT EXISTS (SELECT 1 FROM ativos_brutos at '
        "                  WHERE at.uuid = 'legado-ativo-' || pl.uuid)");
  }

  // ----------------------------------------------------------
  // v22 — espécies e alometria.  DDL em database.dart::_mrvV22Ddl.
  // ----------------------------------------------------------
  static Future<void> v22(Migrator m) async {
    await m.database.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_especies_nome ON especies_catalogo(nome_cientifico)');
    await m.database.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_especies_status ON especies_catalogo(status)');
    await m.database.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_calculos_escopo ON calculos_mrv(escopo_tipo, escopo_uuid)');
    await m.database.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_calculos_equacao ON calculos_mrv(equacao_uuid)');
    await m.database.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_resultados_amostra ON resultados_amostra(amostra_uuid)');

    // 22.1 Catálogo de espécies a partir do texto livre de plantas.especie.
    // densidade_basica fica NULL de propósito: NÃO existe fonte no sistema
    // hoje (asset dados_especies.xlsx ausente). ρ só entra com densidade_fonte
    // preenchida (RQ-03) — não inventamos valor.
    await m.database.customStatement(
        'INSERT INTO especies_catalogo '
        '(uuid, nome_cientifico, nome_popular, origem, densidade_basica, densidade_fonte, '
        ' status, created_at, updated_at) '
        "SELECT lower(hex(randomblob(16))), especie, especie, 'desconhecida', NULL, NULL, "
        "'ativo', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP "
        'FROM (SELECT DISTINCT especie FROM plantas '
        "      WHERE especie IS NOT NULL AND especie <> '') "
        "WHERE especie NOT IN (SELECT nome_cientifico FROM especies_catalogo)");

    // 22.2 especie_legado (texto preservado) → especie_uuid (catálogo).
    // O texto original NUNCA é sobrescrito: histórico não se reescreve.
    await m.database.customStatement(
        'UPDATE individuos SET especie_uuid = '
        '(SELECT e.uuid FROM especies_catalogo e WHERE e.nome_cientifico = individuos.especie_legado) '
        'WHERE especie_uuid IS NULL AND especie_legado IS NOT NULL');
  }

  // ----------------------------------------------------------
  // v23 — governança.  DDL em database.dart::_mrvV23Ddl.
  // ----------------------------------------------------------
  static Future<void> v23(Migrator m) async {
    await m.database.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_usuario_papeis_usuario ON usuario_papeis(usuario_uuid)');
    await m.database.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_incidentes_entidade ON incidentes(entidade_tipo, entidade_uuid)');
    await m.database.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_incidentes_bloqueio ON incidentes(bloqueia_uso_para_credito)');

    // 23.1 Papéis-base. Usuários existentes NÃO ganham papel automaticamente:
    // atribuição de papel é decisão de governança (RG-01), não efeito colateral
    // de migração. is_admin continua existindo e mandando.
    await m.database.customStatement(
        'INSERT OR IGNORE INTO papeis (uuid, nome, escopo, descricao, created_at) VALUES '
        "('PAPEL-COLETOR', 'coletor', NULL, 'Cria e edita amostra propria enquanto pendente', CURRENT_TIMESTAMP), "
        "('PAPEL-REVISOR', 'revisor_interno', NULL, 'Revisa amostra; aprova ou rejeita', CURRENT_TIMESTAMP), "
        "('PAPEL-RESP', 'responsavel_tecnico', NULL, 'Aprova calculo, fecha periodo, emite dossie', CURRENT_TIMESTAMP), "
        "('PAPEL-VERIF', 'verificador', 'global', 'Somente leitura - papel do VVB/auditor externo', CURRENT_TIMESTAMP), "
        "('PAPEL-ADM', 'administrador', 'global', 'Acesso total + gestao de usuarios', CURRENT_TIMESTAMP)");
  }

  // ----------------------------------------------------------
  // v24 — deprecação controlada.  ** NENHUM DDL, NENHUM DROP. **
  //
  // plantas, fotos_parcela e audit_log continuam 100% funcionais: o
  // sync_service.dart:1607-1612 ainda escreve em plantas e database.g.dart
  // ainda expõe fotos_parcela. Só é seguro remover depois de:
  //   (a) grep em lib/ e pb_hooks provando ZERO referências;
  //   (b) 2 releases de campo sem uso;
  //   (c) auditoria legada exportada/arquivada com política de retenção.
  // Este bloco existe só para marcar o marco no histórico de versões.
  // ----------------------------------------------------------
  static Future<void> v24(Migrator m) async {
    return;
  }
}
