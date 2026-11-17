/// <reference path="../pb_data/types.d.ts" />
// ============================================================
// 1778300000_plantas_rules_owner_or_admin.js — RELIGADA (2026-10-28)
//
// Esteve desabilitada (.naoaplicar, commit 48a0ffa) porque a regra usava
// parcela.userId sobre plantas.parcela — campo TEXT, não relation
// (medido: type=text sem collectionId; o PB rejeitava a regra e o
// automigrate abortava o boot).
//
// RELIGADA após a conversão: 1778600000 criou plantas.parcela_rel
// (relation → parcelas) com backfill a partir do texto. Agora a
// expressão parcela_rel.userId tem caminho para resolver.
//
// Mudança nesta versão vs a original do patch: parcela.userId ->
// parcela_rel.userId (a relation nova). O campo texto 'parcela' continua
// existindo e preenchido (transição), mas regra só opera sobre relation.
// ============================================================

migrate(
  (app) => {
    // ---- plantas: dono da parcela, parcela livre, ou admin ----
    // Convenção espelhada de parcelas (POCKETBASE_SCHEMA.md + 1778190000):
    //   parcelas.updateRule = ... && (userId = "" || userId = @request.auth.id)
    // O escape (userId = "") existe porque parcela "livre"/seed tem userId vazio
    // e qualquer coletor precisa trabalhar nela.
    //
    // parcela_rel.userId = @request.auth.id -> dono via relacao plantas -> parcela
    // @request.auth.isAdmin = true          -> admin (campo criado em 1778250000)
    const plantas = app.findCollectionByNameOrId("plantas");
    plantas.updateRule =
      '@request.auth.id != "" && (' +
      'parcela_rel.userId = "" || ' +
      'parcela_rel.userId = @request.auth.id || ' +
      '@request.auth.isAdmin = true' +
      ')';
    plantas.deleteRule = plantas.updateRule;
    app.save(plantas);

    // ---- parcelas: dono ou admin (hoje: dono apenas, 1778190000) ----
    const parcelas = app.findCollectionByNameOrId("parcelas");
    parcelas.deleteRule =
      '@request.auth.id != "" && (' +
      'userId = "" || ' +
      'userId = @request.auth.id || ' +
      '@request.auth.isAdmin = true' +
      ')';
    parcelas.updateRule = parcelas.deleteRule;
    app.save(parcelas);

    // ---- usuarios: admin precisa alterar isAdmin de outro usuario ----
    // 1778200000 deixou updateRule = 'id = @request.auth.id' (self only).
    // Regra equivalente ao hook do repo de dev, expressavel em collection rule.
    // Restricao de CAMPOS (so isAdmin pode mudar) NAO e expressavel em rule —
    // risco residual documentado no README do patch-s3-hash.
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
