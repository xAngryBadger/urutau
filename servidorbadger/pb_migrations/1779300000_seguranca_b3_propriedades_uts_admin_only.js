/// <reference path="../pb_data/types.d.ts" />
// ============================================================
// 1779300000_seguranca_b3_propriedades_uts_admin_only.js  (t13 — BLOCKER B-3)
//
// ACHADO MEDIDO (docs/servidor-auditoria.md §4, provado ao vivo em 0.36.4):
//   propriedades.updateRule/deleteRule = ""  e  uts.updateRule/deleteRule = ""
//   (1776864000:41-42,50-51). Neste binário, regra VAZIA = PÚBLICA: anónimo fez
//   PATCH 200 e DELETE 204 numa propriedade (probe E PATCH propriedade de D ->
//   200; anónimo PATCH/DELETE -> 200/204).
//
// FIX (decisão de produto confirmada pelo capitão): propriedades e uts são
// CATÁLOGO PARTILHADO — o coletor só CRIA (createRule continua '@request.auth.id != ""'),
// nunca edita/apaga no campo. Quem edita/apaga catálogo é admin:
//   updateRule = deleteRule = '@request.auth.isAdmin = true'
// (superuser do painel contorna regras, logo o painel admin segue a funcionar).
//
// Trade-off documentado: o criador NÃO pode editar o próprio catálogo — se um
// dia precisar, gravamos o criador num campo e filtramos por ele. Hoje não há
// esse campo e o app nunca faz update/delete destas coleções.
// ============================================================

migrate((app) => {
  const regraAdmin = '@request.auth.isAdmin = true';

  const propriedades = app.findCollectionByNameOrId('propriedades');
  propriedades.updateRule = regraAdmin;
  propriedades.deleteRule = regraAdmin;
  app.save(propriedades);

  const uts = app.findCollectionByNameOrId('uts');
  uts.updateRule = regraAdmin;
  uts.deleteRule = regraAdmin;
  app.save(uts);
}, (app) => {
  // Revert para o estado anterior (vazio = público neste binário — ver B-3).
  const vazio = '';

  const propriedades = app.findCollectionByNameOrId('propriedades');
  propriedades.updateRule = vazio;
  propriedades.deleteRule = vazio;
  app.save(propriedades);

  const uts = app.findCollectionByNameOrId('uts');
  uts.updateRule = vazio;
  uts.deleteRule = vazio;
  app.save(uts);
});
