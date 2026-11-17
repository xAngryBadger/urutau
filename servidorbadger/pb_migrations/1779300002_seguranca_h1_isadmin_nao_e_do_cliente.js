/// <reference path="../pb_data/types.d.ts" />
// ============================================================
// 1779300002_seguranca_h1_isadmin_nao_e_do_cliente.js  (t13 — HIGH H-1)
//
// ACHADO MEDIDO (docs/servidor-auditoria.md §4, provado ao vivo em 0.36.4):
//   - signup público (users.createRule = "") aceitava isAdmin=true do corpo
//     -> conta ADMINISTRADORA criada por anónimo (probe: 200).
//   - users.updateRule = 'id = @request.auth.id || @request.auth.isAdmin = true'
//     (1778300000:56) deixava cada um promover-se a si próprio:
//     C PATCH próprio isAdmin=true -> 200, isAdmin=True confirmado.
//   (o hook pb_hooks/users_validation.js também permite self-update irrestrito;
//    a regra de coleção é a camada duradoura que agora fecha o furo)
//
// FIX em regras (camada que persiste no data.db):
//   createRule = '@request.body.isAdmin != true'
//     -> signup continua público, mas isAdmin=true no corpo é rejeitado (403).
//        Sem o campo no corpo, @request.body.isAdmin é null (null != true = true)
//        e o default do campo bool é false: a conta nasce NÃO-admin.
//   updateRule = '(id = @request.auth.id && @request.body.isAdmin != true)
//                  || @request.auth.isAdmin = true'
//     -> self-update permitido desde que não ponha isAdmin=true;
//        admin pode tudo (incl. promover/rebaixar).
//
// Verificado ao vivo na t13: signup com isAdmin=true -> 403; signup normal ->
// 200 com isAdmin=false; self-PATCH isAdmin=true -> 403.
// ============================================================

migrate((app) => {
  const users = app.findCollectionByNameOrId('users');

  // Signup público, mas o cliente nunca decide o isAdmin.
  users.createRule = '@request.body.isAdmin != true';

  // Self-update não pode promote-se; admin pode tudo.
  users.updateRule =
    '(id = @request.auth.id && @request.body.isAdmin != true) || ' +
    '@request.auth.isAdmin = true';

  app.save(users);
}, (app) => {
  const users = app.findCollectionByNameOrId('users');
  users.createRule = ''; // estado anterior: signup público aceitava isAdmin
  users.updateRule = 'id = @request.auth.id || @request.auth.isAdmin = true';
  app.save(users);
});
