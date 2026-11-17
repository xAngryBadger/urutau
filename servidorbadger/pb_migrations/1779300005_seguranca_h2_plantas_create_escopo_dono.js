/// <reference path="../pb_data/types.d.ts" />
// ============================================================
// 1779300005_seguranca_h2_plantas_create_escopo_dono.js  (t13 — HIGH H-2)
//
// ACHADO MEDIDO (docs/servidor-auditoria.md §4, provado ao vivo em 0.36.4):
//   plantas.createRule = '@request.auth.id != ""' (1776864000:22, nunca
//   restringido depois): qualquer autenticado criava plantas na parcela de
//   OUTRO (probe: B cria planta na parcela de A -> 200).
//
// FIX: createRule com o mesmo escopo do B-2 (dono da parcela referenciada,
// parcela livre, ou admin), usando a travessia parcela_rel.user:
//   '@request.auth.id != "" && (parcela_rel.user = "" ||
//                                 parcela_rel.user = @request.auth.id ||
//                                 @request.auth.isAdmin = true)'
//   O app envia parcela_rel no create (sync_service.dart:2020-2035), logo a
//   regra resolve contra a parcela referenciada no próprio pedido.
//   Compatibilidade: app antigo que só envia o texto `parcela` (sem
//   parcela_rel) cai no escape parcela_rel.user = "" (relation nula) e
//   continua a funcionar — o endurecimento real vem do backfill de
//   1778250001 + do push novo que preenche os dois.
// ============================================================

migrate((app) => {
  const plantas = app.findCollectionByNameOrId('plantas');

  plantas.createRule =
    '@request.auth.id != "" && (' +
    'parcela_rel.user = "" || ' +
    'parcela_rel.user = @request.auth.id || ' +
    '@request.auth.isAdmin = true' +
    ')';

  app.save(plantas);
}, (app) => {
  const plantas = app.findCollectionByNameOrId('plantas');
  plantas.createRule = '@request.auth.id != ""'; // estado anterior (qualquer auth)
  app.save(plantas);
});
