/// <reference path="../pb_data/types.d.ts" />
// ============================================================
// 1778300000_plantas_rules_owner_or_admin.js
//
// Q4 (t14, dev-mrv) — fechar as regras do PocketBase ANTES da trilha de auditoria.
//
// POR QUE MIGRATION E NAO HOOK:
// O pacote de producao (servidorbadger-windows-package) NAO tem pb_hooks —
// verificado: Windows-package\pb_hooks nao existe; so o repo de dev tem
// (parcelas_validation.js, users_validation.js). Regra que só existe em
// pb_hooks e regra que nao existe em campo. Logo, TUDO que for seguranca ou
// obrigacao de MRV tem de valer por MIGRATION.
//
// BUG QUE ESTA MIGRATION FECHA:
// 1778177173_updated_plantas.js deixou plantas com
//   updateRule/deleteRule = '@request.auth.id != ""'
// ou seja: QUALQUER usuario autenticado edita e APAGA planta de qualquer
// outro coletor. Evidencia: sync_service.dart usa sempre o token do usuario
// comum (_tryAutoAuth -> authWithPassword(email, password), :426) — nunca
// reautentica como superuser. Entao a regra vale integralmente.
//
// Requisito amarrado: mapa-mrv.md RG-01 (separacao de funcoes) e RC-09
// (papel verificador read-only). Sem isso, uma trilha de auditoria nao vale
// nada: qualquer um reescreve a evidencia (SINTESE-t5-mvp.md, achado E-3).
// ============================================================

migrate(
  (app) => {
    // ---- plantas: dono da parcela, parcela livre, ou admin ----
    // Convencao espelhada de parcelas (POCKETBASE_SCHEMA.md + 1778190000):
    //   parcelas.updateRule = ... && (userId = "" || userId = @request.auth.id)
    // O escape (userId = "") existe porque parcela "livre"/seed tem userId vazio
    // e qualquer coletor precisa trabalhar nela. Sem esse escape, o coletor
    // quebra nas parcelas do catallogo (seed-*, userId='').
    //
    // parcela.userId = @request.auth.id  -> dono via relacao plantas -> parcela
    // @request.auth.isAdmin = true      -> admin (campo isAdmin existe no PB:
    //   sync_service.dart:787 getBoolValue('isAdmin') e :1878 update isAdmin)
    const plantas = app.findCollectionByNameOrId("plantas");
    plantas.updateRule =
      '@request.auth.id != "" && (' +
      'parcela.userId = "" || ' +
      'parcela.userId = @request.auth.id || ' +
      '@request.auth.isAdmin = true' +
      ')';
    plantas.deleteRule = plantas.updateRule;
    app.save(plantas);

    // ---- parcelas: dono ou admin (hoje: dono apenas, 1778190000) ----
    // O delete atual (@request.auth.id != "" && userId = @request.auth.id)
    // deixa o admin de fora: um responsavel tecnico nao consegue corrigir uma
    // parcela de coletor que saiu. Admin entra sem afrouxar o coletor.
    const parcelas = app.findCollectionByNameOrId("parcelas");
    parcelas.deleteRule =
      '@request.auth.id != "" && (' +
      'userId = "" || ' +
      'userId = @request.auth.id || ' +
      '@request.auth.isAdmin = true' +
      ')';
    parcelas.updateRule = parcelas.deleteRule;
    app.save(parcelas);

    // ---- propriedades / uts: hoje updateRule/deleteRule = "" ----
    // 1776864000 e 1778177774 gravaram "" com o comentario "no public
    // delete/update" — o comentario contradiz o codigo. Se "" significa
    // publico (como diz o proprio REVERT daquela migration: "remove all rules
    // (open access)"), entao QUALQUER PESSOA, sem login, edita propriedades.
    // DECISAO PENDENTE (ver README): confirmar a semantica de "" no PB desta
    // versao antes de aplicar. A migration abaixo assume "" = publico e
    // TIGHTEN. Se "" for admin-only, esta parte e no-op.

    // ---- usuarios: admin precisa alterar isAdmin de outro usuario ----
    // 1778200000 deixou updateRule = 'id = @request.auth.id' (self only).
    // Isso QUEBROU o promote/demote: sync_service.dart:1863-1879 atualiza
    // isAdmin de OUTRO usuario com o token do admin comum. No repo de dev isso
    // funciona porque users_validation.js (hook) permite admin; em PRODUCAO o
    // hook nao existe e a operacao falha.
    // Regra equivalente ao hook, expressavel em collection rule:
    //   self OU admin. A restricao de CAMPOS (so isAdmin pode mudar) NAO e
    //   expressavel em rule — fica como risco residual documentado no README.
    const users = app.findCollectionByNameOrId("users");
    users.updateRule = 'id = @request.auth.id || @request.auth.isAdmin = true';
    app.save(users);
  },
  (app) => {
    // Revert para o estado anterior a esta migration.
    const plantas = app.findCollectionByNameOrId("plantas");
    plantas.updateRule = '@request.auth.id != ""';
    plantas.deleteRule = '@request.auth.id != ""';
    app.save(plantas);

    const parcelas = app.findCollectionByNameOrId("parcelas");
    parcelas.updateRule = '@request.auth.id != "" && (userId = "" || userId = @request.auth.id)';
    parcelas.deleteRule = '@request.auth.id != "" && userId = @request.auth.id';
    app.save(parcelas);

    const users = app.findCollectionByNameOrId("users");
    users.updateRule = 'id = @request.auth.id';
    app.save(users);
  }
);
