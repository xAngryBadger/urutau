/// <reference path="../pb_data/types.d.ts" />
// ============================================================
// 1778250000_add_isAdmin_users.js
//
// Q4 (investigação D-4 do dev-codigo) — PRÉ-REQUISITO BLOQUEANTE.
//
// ACHADO MEDIDO (data.db ao vivo, via inspecionar_pb.py): a collection
// 'users' — a que o app usa (`_pb!.collection('users')` em
// sync_service.dart:2007) — NÃO tem campo isAdmin. Campos atuais:
// id, password, tokenKey, email, emailVisibility, verified, name,
// avatar, created, updated. Consequências hoje:
//   - sync_service.dart:801/837/854 (rec.getBoolValue('isAdmin')) lê
//     campo inexistente → flag admin do servidor é sempre falsa;
//   - sync_service.dart:2007 (promote/demote) escreve campo inexistente;
//   - qualquer regra `@request.auth.isAdmin = true` (patch Q4 do
//     dev-mrv, 1778300000) NUNCA resolveria → lockout total.
//
// Esta migration é ADITIVA e não muda nenhuma regra: cria o campo
// (bool, não required, default false, visível na API). Com ela:
//   - o pull passa a refletir o admin do servidor;
//   - o patch de regras 1778300000 fica DESBLOQUEADO (a aplicar após
//     aval do capitão — ver impl-sync-implementado.md).
// A promoção continua self-only até o patch de regras entrar.
//
// Timestamp 1778250000: > 1778200000 (última existente) e < 1778300000
// (a primeira do patch Q4), preservando a ordem de aplicação.
// ============================================================

migrate((app) => {
  const collection = app.findCollectionByNameOrId("users")

  // add field
  collection.fields.add(new Field({
    "hidden": false,
    "id": "bool_isAdmin_users",
    "name": "isAdmin",
    "presentable": false,
    "primaryKey": false,
    "required": false,
    "system": false,
    "type": "bool"
  }))

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("users")

  // remove field
  collection.fields.removeById("bool_isAdmin_users")

  return app.save(collection)
})
