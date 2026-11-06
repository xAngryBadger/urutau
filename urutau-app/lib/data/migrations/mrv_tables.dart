// ============================================================
// mrv_tables.dart — NOVAS TABELAS DO MODELO MRV (v19 → v24)
//
// PATCH NÃO APLICADO. Destino: urutau-app/lib/data/migrations/mrv_tables.dart
// Task t9 (dev-mrv) · entregável para dev-codigo aplicar após os gates.
//
// Regras obedecidas (ver impl-migracao-drift.md):
//  * NENHUMA coluna nova em tabela existente é NOT NULL sem default.
//  * NENHUM drop de plantas / fotos_parcela / audit_log.
//  * FKs são LÓGICAS (texto sem .references) de propósito — ver §Compat-FK
//    no doc. relações reais só quando os caminhos destrutivos saírem.
//  * TrilhaAuditoria não tem updated_at/deleted_at: é append-only por construção.
// ============================================================

import 'package:drift/drift.dart';

// ------------------------------------------------------------
// v19 — núcleo MRV
// ------------------------------------------------------------

// ------------------------------------------------------------
// v19 — núcleo MRV
// ------------------------------------------------------------

// NOTA sobre status_parcela: nasce NULL-able com DEFAULT de banco, NAO NotaNull.
// Drift so aplica o default do banco quando o campo NAO e mencionado no
// insert; se o app inserir sem setar, SQLite aplica o default. Com NOT NULL,
// qualquer caminho insertParcela() que esquecesse o campo quebraria em campo.
// O default fica garantido pela migracao (ADD COLUMN ... DEFAULT 'ativa').
// Em mrv_tables.dart elas aparecem como text().nullable().

class ProjetosMrv extends Table {
  TextColumn get uuid => text().unique()();
  TextColumn get codigo => text()(); // único por validação de app/servidor
  TextColumn get nome => text()();
  TextColumn get modalidade => text()(); // enum: plantacao | restauracao
  TextColumn get organizacao => text().nullable()();
  TextColumn get padraoCredito => text().nullable()();
  TextColumn get metodologiaRef => text().nullable()();
  RealColumn get areaTotalHa => real().nullable()();
  TextColumn get bioma => text().nullable()();
  TextColumn get regiao => text().nullable()();
  TextColumn get dataInicio => text().nullable()(); // ISO-8601 UTC
  TextColumn get dataFim => text().nullable()();
  IntColumn get periodoCreditacaoAnos => integer().nullable()();
  TextColumn get status => text().withDefault(const Constant('rascunho'))();
  TextColumn get adicionalidadeRef => text().nullable()(); // JSON
  TextColumn get baselineRef => text().nullable()(); // JSON
  TextColumn get notas => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deletedBy => text().nullable()();
  // v32 — RT-03: risco de reversao + fonte historico de fogo
  TextColumn get riscoReversao => text().nullable()(); // baixo|medio|alto
  TextColumn get fonteFogoHistorico => text().nullable()(); // ex: ULTRA/satelite
}

class PeriodosMonitoramento extends Table {
  TextColumn get uuid => text().unique()();
  TextColumn get projetoUuid => text()(); // FK lógica → projetos_mrv
  TextColumn get codigo => text()();
  TextColumn get dataInicio => text().nullable()();
  TextColumn get dataFim => text().nullable()();
  TextColumn get tipo => text()(); // baseline | monitoramento | verificacao | encerramento
  DateTimeColumn get planoAprovadoEm => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('planejado'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class Campanhas extends Table {
  TextColumn get uuid => text().unique()();
  TextColumn get projetoUuid => text()(); // FK lógica
  TextColumn get periodoUuid => text()(); // FK lógica
  TextColumn get nome => text()();
  TextColumn get dataInicio => text().nullable()();
  TextColumn get dataFim => text().nullable()();
  TextColumn get responsavelUuid => text().nullable()(); // FK lógica → usuarios
  TextColumn get protocoloUuid => text().nullable()(); // FK lógica
  TextColumn get status => text().withDefault(const Constant('planejada'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class DesenhoAmostral extends Table {
  TextColumn get uuid => text().unique()();
  TextColumn get escopoTipo => text()(); // projeto | ut
  TextColumn get escopoUuid => text()(); // FK lógica
  RealColumn get areaParcelaM2 => real().nullable()();
  TextColumn get forma => text().nullable()(); // retangular | circular | quadrada
  RealColumn get raioM => real().nullable()();
  TextColumn get dimensoesM => text().nullable()(); // JSON {largura,comprimento}
  RealColumn get densidadeParcelasHa => real().nullable()();
  RealColumn get percentualAmostrado => real().nullable()();
  TextColumn get criterioPosicionamento => text().nullable()();
  IntColumn get nParcelasPrevistas => integer().nullable()();
  TextColumn get estratos => text().nullable()(); // JSON
  TextColumn get incertezaAlvo => text().nullable()(); // JSON
  TextColumn get observacoes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class ProtocolosMedicao extends Table {
  TextColumn get uuid => text().unique()();
  TextColumn get codigo => text()();
  TextColumn get versao => text()();
  TextColumn get vigenciaInicio => text().nullable()();
  TextColumn get vigenciaFim => text().nullable()();
  TextColumn get regraDap => text().nullable()();
  TextColumn get regraAltura => text().nullable()();
  TextColumn get regraCategoria => text().nullable()(); // JSON — limiares versionados
  TextColumn get inclusao => text().nullable()(); // JSON
  TextColumn get exclusao => text().nullable()(); // JSON
  TextColumn get unidades => text().nullable()(); // JSON
  TextColumn get equacaoPadraoUuid => text().nullable()(); // FK lógica (v22)
  TextColumn get aprovadoPor => text().nullable()(); // FK lógica → usuarios
  TextColumn get status => text().withDefault(const Constant('rascunho'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class AmostrasParcela extends Table {
  TextColumn get uuid => text().unique()();
  TextColumn get parcelaUuid => text()(); // FK lógica → parcelas
  TextColumn get campanhaUuid => text()(); // FK lógica → campanhas
  TextColumn get operadorUuid => text().nullable()();
  TextColumn get dispositivoUuid => text().nullable()(); // FK lógica (v21)
  TextColumn get protocoloVersao => text().nullable()();
  DateTimeColumn get medidoEmServidor => dateTime().nullable()(); // RC-05
  DateTimeColumn get relogioDispositivo => dateTime().nullable()();
  IntColumn get offsetRelogioMs => integer().nullable()();
  TextColumn get geo => text().nullable()(); // JSON
  TextColumn get status => text().withDefault(const Constant('pendente'))();
  TextColumn get revisorUuid => text().nullable()();
  DateTimeColumn get revisadoEm => dateTime().nullable()();
  TextColumn get justificativa => text().nullable()();
  IntColumn get versao => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

// ------------------------------------------------------------
// v20 — indivíduo, medição e modalidade
// ------------------------------------------------------------

class Individuos extends Table {
  TextColumn get uuid => text().unique()();
  TextColumn get parcelaUuid => text()(); // FK lógica → parcelas
  TextColumn get tag => text()(); // único por parcela (validação de app)
  TextColumn get especieUuid => text().nullable()(); // FK lógica → especies_catalogo (v22)
  TextColumn get especieLegado => text().nullable()(); // texto original de plantas.especie
  RealColumn get xM => real().nullable()();
  RealColumn get yM => real().nullable()();
  DateTimeColumn get nascimentoEm => dateTime().nullable()();
  TextColumn get origem => text().withDefault(const Constant('plantada'))();
  // plantada | regeneracao | regrowth | desconhecida
  TextColumn get status => text().withDefault(const Constant('viva'))();
  // viva | morta | ausente | substituida
  TextColumn get observacoes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class MedicoesIndividuo extends Table {
  TextColumn get uuid => text().unique()();
  TextColumn get amostraUuid => text()(); // FK lógica → amostras_parcela
  TextColumn get individuoUuid => text()(); // FK lógica → individuos
  // ALTURA: sempre coletada (cm). Convenção CONFIRMADA pelo usuário.
  RealColumn get alturaCm => real().nullable()();
  // DAP: medido a 1,30 m do solo (altura do peito). Convenção CONFIRMADA pelo
  // usuário (Badger). Condicional — só exigido quando o indivíduo atinge
  // >= 1,30 m; abaixo disso (plântulas/mudas de restauração) mede-se por altura
  // e o DAP fica NULL até cruzar o limite. Validação de APP, não NOT NULL.
  RealColumn get dapCm => real().nullable()();
  IntColumn get categoria => integer().nullable()(); // 1, 2 ou 3
  TextColumn get categoriaOrigem => text().withDefault(const Constant('calculada'))();
  TextColumn get estado => text().withDefault(const Constant('viva'))();
  // viva | morta | danificada | quebrada | ausente
  TextColumn get copa => text().nullable()(); // JSON
  TextColumn get dano => text().nullable()(); // JSON
  RealColumn get alturaDominanteM => real().nullable()();
  BoolColumn get especieConfirmada => boolean().withDefault(const Constant(false))();
  TextColumn get fotoAtivoUuid => text().nullable()(); // FK lógica → ativos_brutos (v21)
  TextColumn get observacoes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class PlantacaoUts extends Table {
  TextColumn get uuid => text().unique()();
  TextColumn get propUt => text()(); // FK lógica → uts do servidor (não existe local)
  TextColumn get especiePrincipalUuid => text().nullable()();
  TextColumn get materialGenetico => text().nullable()();
  TextColumn get procedencia => text().nullable()();
  TextColumn get espacamento => text().nullable()(); // JSON
  IntColumn get anoPlantio => integer().nullable()();
  IntColumn get rotacaoAnos => integer().nullable()();
  TextColumn get sistema => text().nullable()(); // maco | puro | taloes
  TextColumn get produto => text().nullable()();
  TextColumn get manejo => text().nullable()(); // JSON
  IntColumn get idadeAtualAnos => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class MedicoesPlantacao extends Table {
  TextColumn get uuid => text().unique()();
  TextColumn get medicaoUuid => text()(); // FK lógica 1:1 → medicoes_individuo
  TextColumn get qualidadeFuste => text().nullable()();
  RealColumn get insercaoCopa => real().nullable()();
  RealColumn get desramaNaturalM => real().nullable()();
  TextColumn get posicaoSocial => text().nullable()();
  BoolColumn get aptidaoSerraria => boolean().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class RestauracaoProjetos extends Table {
  TextColumn get uuid => text().unique()();
  TextColumn get projetoUuid => text()(); // FK lógica 1:1 → projetos_mrv
  TextColumn get modalidadeRestauracao => text()();
  // plantio_mudas | semeadura_direta | regeneracao_natural_assistida |
  // nucleacao | conversao | hibrido
  RealColumn get areaRestauradaHa => real().nullable()();
  TextColumn get ecossistemaAlvo => text().nullable()();
  TextColumn get ecossistemaReferencia => text().nullable()();
  IntColumn get nEspeciesPrevistas => integer().nullable()();
  IntColumn get nEspeciesPlantadas => integer().nullable()();
  RealColumn get densidadeInicialHa => real().nullable()();
  IntColumn get anoExecucao => integer().nullable()();
  TextColumn get metodoPlantio => text().nullable()(); // JSON
  TextColumn get manutencoes => text().nullable()(); // JSON
  TextColumn get corredores => text().nullable()(); // JSON
  TextColumn get adicionalidadeRef => text().nullable()();
  TextColumn get baselineRef => text().nullable()();
  TextColumn get riscoReversao => text().nullable()(); // baixo | medio | alto
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class RestauracaoUts extends Table {
  TextColumn get uuid => text().unique()();
  TextColumn get propUt => text()(); // FK lógica → uts do servidor
  TextColumn get tipoArea => text().nullable()();
  TextColumn get usoAnterior => text().nullable()();
  TextColumn get nivelDegradacao => text().nullable()();
  TextColumn get faseSucedional => text().nullable()();
  BoolColumn get fogoHistorico => boolean().withDefault(const Constant(false))();
  BoolColumn get pressaoGado => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class MedicoesRestauracao extends Table {
  TextColumn get uuid => text().unique()();
  TextColumn get medicaoUuid => text()(); // FK lógica 1:1 → medicoes_individuo
  BoolColumn get sobreviveu => boolean().nullable()(); // métrica #1 de restauração
  TextColumn get causaMorte => text().nullable()();
  RealColumn get alturaNoPlantioCm => real().nullable()();
  RealColumn get crescimentoPeriodoCm => real().nullable()();
  TextColumn get danoHerbivoria => text().nullable()(); // nenhum|leve|moderado|severo
  BoolColumn get danoFormiga => boolean().nullable()();
  BoolColumn get atacadaPraga => boolean().nullable()();
  // DAN: boolean GENÉRICO — semântica NÃO confirmada. O capitão perguntou ao
  // Badger (usuário/autoridade de domínio) e a pergunta segue SEM RESPOSTA.
  // NÃO calcular nada em cima desta coluna enquanto não houver confirmação.
  BoolColumn get dan => boolean().nullable()();
  TextColumn get danDescricao => text().nullable()();
  BoolColumn get rebrota => boolean().nullable()();
  BoolColumn get florescimento => boolean().nullable()();
  BoolColumn get frutificacao => boolean().nullable()();
  RealColumn get invasoraCobrindo => real().nullable()(); // % sobre o indivíduo
  TextColumn get competicao => text().nullable()(); // nenhuma|baixa|media|alta
  RealColumn get alturaDominanteM => real().nullable()();
  TextColumn get estrato => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class CoberturasAmostra extends Table {
  TextColumn get uuid => text().unique()();
  TextColumn get amostraUuid => text()(); // FK lógica → amostras_parcela
  TextColumn get estrato => text()();
  // arvoreo | arbustivo | herbaceo | serapilheira | solo_exposto | liana
  RealColumn get coberturaPct => real().nullable()();
  RealColumn get alturaMediaM => real().nullable()();
  TextColumn get especieDominanteUuid => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

// ------------------------------------------------------------
// v21 — custódia e evidência
// ------------------------------------------------------------

class AtivosBrutos extends Table {
  TextColumn get uuid => text().unique()();
  TextColumn get entidadeTipo => text()();
  TextColumn get entidadeUuid => text()();
  TextColumn get papel => text().withDefault(const Constant('bruto'))();
  // bruto | derivado | miniatura | laudo | manifesto
  TextColumn get mime => text().nullable()();
  IntColumn get bytes => integer().nullable()();
  TextColumn get sha256 => text().nullable()(); // hash na origem (RC-04)
  BoolColumn get sha256Verificado =>
      boolean().withDefault(const Constant(false))();
  TextColumn get caminhoLogico => text().nullable()(); // RC-01
  TextColumn get caminhoOriginal => text().nullable()();
  TextColumn get nomeOriginal => text().nullable()();
  DateTimeColumn get capturadoEm => dateTime().nullable()();
  DateTimeColumn get ingeridoEm => dateTime().nullable()();
  TextColumn get dispositivoUuid => text().nullable()();
  TextColumn get operadorUuid => text().nullable()();
  TextColumn get pipelineVersao => text().nullable()(); // RC-08
  TextColumn get insumos => text().nullable()(); // JSON de hashes
  BoolColumn get exifPreservado => boolean().nullable()();
  TextColumn get retencaoAte => text().nullable()(); // ISO date (RC-07)
  BoolColumn get worm => boolean().withDefault(const Constant(false))();
  TextColumn get status => text().withDefault(const Constant('presente'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class Dispositivos extends Table {
  TextColumn get uuid => text().unique()();
  TextColumn get identificador => text()(); // fingerprint estável
  TextColumn get modelo => text().nullable()();
  TextColumn get so => text().nullable()();
  TextColumn get versaoApp => text().nullable()();
  IntColumn get offsetRelogioMedianoMs => integer().nullable()();
  BoolColumn get confiavel => boolean().withDefault(const Constant(true))();
  TextColumn get observacoes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Trilha encadeada por hash. **Append-only**: não tem updated_at nem
/// deleted_at, e não pode ser alterada depois de inserida (RG-04/RC-06).
class TrilhaAuditoria extends Table {
  IntColumn get idSeq => integer().autoIncrement()();
  TextColumn get entidadeTipo => text().nullable()();
  TextColumn get entidadeUuid => text().nullable()();
  TextColumn get acao => text()();
  TextColumn get antes => text().nullable()(); // JSON
  TextColumn get depois => text().nullable()(); // JSON
  TextColumn get usuarioUuid => text().nullable()();
  DateTimeColumn get tsServidor => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get tsDispositivo => dateTime().nullable()();
  IntColumn get offsetRelogioMs => integer().nullable()(); // RC-05 (v29)
  TextColumn get origem => text()(); // app | painel | servidor | pipeline | importacao
  TextColumn get prevHash => text().nullable()();
  TextColumn get entryHash => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// ------------------------------------------------------------
// v22 — espécies e alometria
// ------------------------------------------------------------

class EspeciesCatalogo extends Table {
  TextColumn get uuid => text().unique()();
  TextColumn get nomeCientifico => text()();
  TextColumn get nomePopular => text().nullable()();
  TextColumn get sinonimos => text().nullable()(); // JSON
  TextColumn get familia => text().nullable()();
  TextColumn get origem => text().withDefault(const Constant('desconhecida'))();
  RealColumn get densidadeBasica => real().nullable()(); // g/cm³ (RQ-03)
  TextColumn get densidadeFonte => text().nullable()();
  TextColumn get faixaBioma => text().nullable()(); // JSON
  TextColumn get status => text().withDefault(const Constant('ativo'))();
  TextColumn get validoDe => text().nullable()();
  TextColumn get validoAte => text().nullable()();
  TextColumn get hashFonte => text().nullable()(); // FK lógica → ativos_brutos
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class EquacoesAlometricas extends Table {
  TextColumn get uuid => text().unique()();
  TextColumn get codigo => text()();
  TextColumn get versao => text()();
  TextColumn get alvo => text()();
  // altura_total | volume_sem_casca | volume_com_casca | agb | biomassa_total
  TextColumn get escopo => text()(); // especie | genero | familia | grupo | geral
  TextColumn get escopoValor => text().nullable()();
  TextColumn get bioma => text().nullable()();
  TextColumn get regiao => text().nullable()();
  TextColumn get forma => text()(); // potencia | linear | logaritmica | nao_linear
  TextColumn get parametros => text().nullable()(); // JSON {a,b}
  TextColumn get variaveisEntrada => text().nullable()(); // JSON
  RealColumn get densidadeAssumida => real().nullable()();
  TextColumn get fonte => text().nullable()();
  TextColumn get uso => text().withDefault(const Constant('nao_aprovada'))();
  TextColumn get validoDe => text().nullable()();
  TextColumn get validoAte => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('rascunho'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class CalculosMrv extends Table {
  TextColumn get uuid => text().unique()();
  TextColumn get escopoTipo => text()(); // amostra | parcela | ut | projeto | periodo
  TextColumn get escopoUuid => text()();
  TextColumn get amostraUuid => text().nullable()(); // FK lógica
  TextColumn get periodoUuid => text().nullable()(); // FK lógica
  TextColumn get equacaoUuid => text().nullable()(); // FK lógica
  TextColumn get pipelineVersao => text().nullable()();
  TextColumn get algorithmVersao => text().nullable()();
  TextColumn get insumosHash => text().nullable()(); // JSON (RQ-04)
  RealColumn get fracaoCarbono => real().withDefault(const Constant(0.47))();
  RealColumn get fatorCo2 => real().withDefault(const Constant(3.6666666666666665))();
  TextColumn get poolsIncluidos => text().nullable()(); // JSON (RQ-05)
  TextColumn get poolsNaoMedidos => text().nullable()(); // JSON (RQ-05)
  TextColumn get resultado => text().nullable()(); // JSON
  TextColumn get incerteza => text().nullable()(); // JSON (RS-03)
  RealColumn get unidadeArea => real().nullable()();
  TextColumn get status => text().withDefault(const Constant('valido'))();
  DateTimeColumn get executadoEm => dateTime().nullable()();
  TextColumn get executadoPor => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class ResultadosAmostra extends Table {
  TextColumn get uuid => text().unique()();
  TextColumn get amostraUuid => text()(); // FK lógica
  RealColumn get alturaMediaM => real().nullable()();
  RealColumn get dapMedioCm => real().nullable()();
  RealColumn get areaBasalM2Ha => real().nullable()();
  RealColumn get volumeM3Ha => real().nullable()();
  RealColumn get agbTHa => real().nullable()();
  RealColumn get tco2eHa => real().nullable()();
  IntColumn get nIndividuos => integer().nullable()();
  IntColumn get nVivos => integer().nullable()();
  IntColumn get nMortos => integer().nullable()();
  TextColumn get incerteza => text().nullable()(); // JSON
  TextColumn get calculosRef => text().nullable()(); // JSON de uuids
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// ------------------------------------------------------------
// v23 — governança
// ------------------------------------------------------------

class Papeis extends Table {
  TextColumn get uuid => text().unique()();
  TextColumn get nome => text()(); // coletor | revisor_interno | ...
  TextColumn get escopo => text().nullable()(); // projeto | global
  TextColumn get descricao => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class UsuarioPapeis extends Table {
  TextColumn get uuid => text().unique()();
  TextColumn get usuarioUuid => text()(); // FK lógica → usuarios
  TextColumn get papelUuid => text()(); // FK lógica → papeis
  TextColumn get projetoUuid => text().nullable()(); // null = global
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class Incidentes extends Table {
  TextColumn get uuid => text().unique()();
  TextColumn get tipo => text()();
  TextColumn get entidadeTipo => text().nullable()();
  TextColumn get entidadeUuid => text().nullable()();
  TextColumn get severidade => text()(); // baixa | media | alta | bloqueadora
  TextColumn get descricao => text().nullable()();
  DateTimeColumn get detectadoEm => dateTime().nullable()();
  TextColumn get detectadoPor => text().nullable()();
  BoolColumn get bloqueiaUsoParaCredito =>
      boolean().withDefault(const Constant(false))();
  TextColumn get resolucao => text().nullable()();
  DateTimeColumn get resolvidoEm => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class VerificacoesInternas extends Table {
  TextColumn get uuid => text().unique()();
  TextColumn get amostraOriginalUuid => text()(); // FK lógica
  TextColumn get amostraVerificacaoUuid => text()(); // FK lógica
  TextColumn get verificadorUuid => text().nullable()(); // FK lógica
  TextColumn get conclusao => text().nullable()(); // conforme | divergente | inconclusiva
  TextColumn get divergencias => text().nullable()(); // JSON
  TextColumn get observacoes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Competencias extends Table {
  TextColumn get uuid => text().unique()();
  TextColumn get usuarioUuid => text()(); // FK lógica
  TextColumn get tipoTreinamento => text()();
  DateTimeColumn get concluidoEm => dateTime().nullable()();
  TextColumn get validoAte => text().nullable()();
  TextColumn get evidenciaUuid => text().nullable()(); // FK lógica → ativos_brutos
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
