/// <reference path="../pb_data/types.d.ts" />
// ============================================================
// 1779400000_seguranca_b1_parcelas_create_ata_dono.js  (t21 — furo residual B-1)
//
// ACHADO MEDIDO (docs/revisao-migracoes-seguranca.md §4, provado ao vivo):
//   parcelas.createRule = '@request.auth.id != ""' — qualquer autenticado
//   criava parcela com `user` = id de OUTRO (A criou com user=B -> 200 e
//   depois B apagou essa parcela -> 204). Quem criava escolhia o dono.
//
// FIX: no create, o dono tem de ser o próprio auth:
//   '@request.auth.id != "" && @request.body.user = @request.auth.id'
// O app manda sempre user = auth.id (sync_service.dart:1913,1924); o painel
// admin usa superuser, que bypassa regras. updateRule/deleteRule já usam o
// texto `user` (1779300003) — agora create fecha o circuito.
// ============================================================

migrate((app) => {
  const parcelas = app.findCollectionByNameOrId('parcelas');

  parcelas.createRule =
    '@request.auth.id != "" && @request.body.user = @request.auth.id';

  app.save(parcelas);
}, (app) => {
  const parcelas = app.findCollectionByNameOrId('parcelas');
  // Estado anterior (furado — ver B-1): qualquer auth criava para qualquer dono.
  parcelas.createRule = '@request.auth.id != ""';
  app.save(parcelas);
});
