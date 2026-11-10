/// <reference path="../pb_data/types.d.ts" />
// ============================================================
// 1779300001_seguranca_b4_users_delete_admin_only.js  (t13 — BLOCKER B-4)
//
// ACHADO MEDIDO (docs/servidor-auditoria.md §4, provado ao vivo em 0.36.4):
//   users.deleteRule = "" (1776859848:7). Regra VAZIA = PÚBLICA neste binário:
//   anónimo fez DELETE /api/collections/users/records/<id> -> 204 (conta
//   apagada), e qualquer autenticado apagava qualquer conta (C DELETE user A
//   -> 204).
//
// FIX: deleteRule = '@request.auth.isAdmin = true' — só admin apaga contas
// (superuser do painel também apaga, contorna regras). Anónimo NUNCA.
// O próprio utilizador também não se apaga por aqui (use o fluxo de app se
// for preciso); hoje o app não apaga utilizadores, só o painel.
// ============================================================

migrate((app) => {
  const users = app.findCollectionByNameOrId('users');
  users.deleteRule = '@request.auth.isAdmin = true';
  app.save(users);
}, (app) => {
  const users = app.findCollectionByNameOrId('users');
  users.deleteRule = ''; // estado anterior (público — ver B-4)
  app.save(users);
});
