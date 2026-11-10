/// <reference path="../pb_data/types.d.ts" />
// ============================================================
// 1779300004_seguranca_b2_plantas_regras_pelo_texto_user_da_parcela.js  (t13 — BLOCKER B-2)
//
// ACHADO MEDIDO (docs/servidor-auditoria.md §4, provado ao vivo em 0.36.4):
//   plantas list/view/update/delete usam parcela_rel.userId
//   (1778300000:30-36, 1778700000:41-46). Como a parcela do app tem userId
//   SEMPRE vazio (o app escreve o dono no texto `user`), o escape
//   'parcela_rel.userId = ""' casa em TODAS as plantas e qualquer autenticado
//   editava/apagava plantas de terceiros (probe: C PATCH 200, C DELETE 204).
//
// FIX (mesma fonte de verdade do B-1 — o texto `user` da parcela, via
// travessia da relation parcela_rel):
//   '@request.auth.id != "" && (parcela_rel.user = "" ||
//                                 parcela_rel.user = @request.auth.id ||
//                                 @request.auth.isAdmin = true)'
//   - dono da parcela vê/edita/apaga as suas plantas; admin vê tudo;
//   - parcela livre/seed (user = "") continua acessível a qualquer coletor
//     (o escape agora só casa em parcelas genuinamente livres, porque o app
//     preenche `user` nas parcelas que cria);
//   - terceiro -> 403 em list/view/update/delete.
// ============================================================

migrate((app) => {
  const plantas = app.findCollectionByNameOrId('plantas');

  const escopo =
    '@request.auth.id != "" && (' +
    'parcela_rel.user = "" || ' +
    'parcela_rel.user = @request.auth.id || ' +
    '@request.auth.isAdmin = true' +
    ')';

  plantas.listRule = escopo;
  plantas.viewRule = escopo;
  plantas.updateRule = escopo;
  plantas.deleteRule = escopo;
  app.save(plantas);
}, (app) => {
  const plantas = app.findCollectionByNameOrId('plantas');
  // Estado anterior (furado — ver B-2): userId da relation, sempre vazio.
  const antigo =
    '@request.auth.id != "" && (' +
    'parcela_rel.userId = "" || ' +
    'parcela_rel.userId = @request.auth.id || ' +
    '@request.auth.isAdmin = true' +
    ')';
  plantas.listRule = antigo;
  plantas.viewRule = antigo;
  plantas.updateRule = antigo;
  plantas.deleteRule = antigo;
  app.save(plantas);
});
