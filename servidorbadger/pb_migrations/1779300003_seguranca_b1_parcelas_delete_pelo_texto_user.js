/// <reference path="../pb_data/types.d.ts" />
// ============================================================
// 1779300003_seguranca_b1_parcelas_delete_pelo_texto_user.js  (t13 — BLOCKER B-1)
//
// ACHADO MEDIDO (docs/servidor-auditoria.md §4, provado ao vivo em 0.36.4):
//   parcelas.deleteRule (1778300000:41-47) usa a RELATION userId:
//     '@request.auth.id != "" && (userId = "" || userId = @request.auth.id || isAdmin)'
//   O app NUNCA preenche userId — escreve o dono no campo TEXTO `user`
//   (sync_service.dart:1913,1924: 'user': parcela.userId). Logo userId fica
//   sempre vazio, o escape userId = "" casa SEMPRE e qualquer autenticado
//   apagava qualquer parcela (probe: B DELETE parcela de A -> 204).
//
// FIX (uma fonte de verdade só, como o updateRule de 1778900000:58-60):
//   deleteRule passa a usar o MESMO campo texto `user` do updateRule:
//     '@request.auth.id != "" && (user = @request.auth.id || @request.auth.isAdmin = true)'
//   - dono apaga a sua; admin apaga qualquer uma; terceiro -> 403.
//   - parcelas "livres"/seed (user = "") passam a só poder ser apagadas por
//     admin — coerente com o updateRule, que já não deixa terceiro editar.
// ============================================================

migrate((app) => {
  const parcelas = app.findCollectionByNameOrId('parcelas');
  parcelas.deleteRule =
    '@request.auth.id != "" && ' +
    '(user = @request.auth.id || @request.auth.isAdmin = true)';
  app.save(parcelas);
}, (app) => {
  const parcelas = app.findCollectionByNameOrId('parcelas');
  // Estado anterior (furado — ver B-1): userId relation, sempre vazio no app.
  parcelas.deleteRule =
    '@request.auth.id != "" && ' +
    '(userId = "" || userId = @request.auth.id || @request.auth.isAdmin = true)';
  app.save(parcelas);
});
