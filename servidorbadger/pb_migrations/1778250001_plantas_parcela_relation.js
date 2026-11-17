/// <reference path="../pb_data/types.d.ts" />
// ============================================================
// 1778600000_plantas_parcela_relation.js
//
// t14 (dev-mrv) — plantas.parcela: TEXT puro + RELATION nova (parcela_rel).
//
// DIAGNOSTICO (medido nos dois data.db, dev e pacote de producao):
//   plantas.parcela -> type=text, SEM collectionId. Nao ha relacao a percorrer,
//   entao a expressao `parcela.userId` de uma regra NAO resolve. Era o bloqueio
//   que impedia a regra 1778300000 (owner-or-admin) de operar — vazamento
//   cross-tenant ativo (provado ao vivo pelo pb-rules-gate do capitao).
//
//   O texto guarda o SERVER ID da parcela: sync_service.dart:1690 escreve
//   'parcela': record.id, e o mesmo record.id e usado nos filtros (:1674, :1837,
//   :1921, :2062). Nao e uuid local, nao e chave prop_ut-P-n.
//
// ESTRATEGIA: campo relation NOVO (parcela_rel) + backfill a partir do texto.
// NAO converter in-place: PB nao converte text em relation preservando valor, e
// dropar campo com dados e perda de evidencia.
//
// CONVIVENCIA: o campo texto 'parcela' FICA. Ele ja contem exatamente o valor
// que a relation precisa — os dois concordam por construcao, sem janela de
// divergencia. O push do app novo preenche OS DOIS (Fase 2 do motor). Corte
// definitivo em v27 futura, apos 2 releases sem app antigo.
//
// ORDEM DENTRO DA LEVA: conversao PRIMEIRO, regra DEPOIS. Regra sem campo e
// lockout total — licao da investigacao D-4.
//
// ADAPTACAO DE APLICACAO (dev-codigo, provada por E2E): o patch original usava
// $app.dao() no bloco migrate — ReferenceError MEDIDO: "$app is not defined"
// ($app so existe em hooks, nao em migrations). Caminho suportado: criar o
// campo pelo migrate (API de collections) e o backfill por SQL puro via
// customStatement — idempotente (WHERE parcela_rel IS NULL), e log do que
// ficou sem casa fica para o job de reconciliação (nunca inventar vinculo).
// ============================================================

migrate((app) => {
  const plantas = app.findCollectionByNameOrId("plantas");

  // ---- campo relation novo ----
  // maxSelect 1: uma planta pertence a exatamente uma parcela (N:1).
  // Padrao copiado de 1776862935_updated_parcelas.js (relation ut/user).
  plantas.fields.add(new Field({
    "cascadeDelete": false,
    "collectionId": "pbc_3294281715", // parcelas
    "hidden": false,
    "id": "relation_parcela_novo1",
    "maxSelect": 1,
    "minSelect": 0,
    "name": "parcela_rel",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "relation"
  }));

  app.save(plantas);

  // ---- backfill a partir do texto ----
  // O texto JA e o server id da parcela (sync_service.dart:1690). A relation
  // recebe o MESMO valor; linha cujo texto nao corresponda a nenhuma
  // parcelas.id fica NULL — nunca inventamos vinculo.
  // API medida por probe no runtime (APP_KEYS): app.db() é o raw DB; newQuery
  // executa SQL puro. Idempotente:WHERE parcela_rel IS NULL.
  app.db().newQuery(
    "UPDATE plantas SET parcela_rel = parcela " +
    "WHERE (parcela_rel IS NULL OR parcela_rel = '') " +
    "AND parcela IS NOT NULL AND parcela != '' " +
    "AND EXISTS (SELECT 1 FROM parcelas WHERE parcelas.id = plantas.parcela)"
  ).execute();
}, (app) => {
  // Revert: remove a relation. O campo texto 'parcela' permanece (nunca foi
  // tocado), entao o revert e seguro — nao ha perda de dado.
  const plantas = app.findCollectionByNameOrId("plantas");
  plantas.fields.removeById("relation_parcela_novo1");
  return app.save(plantas);
});
