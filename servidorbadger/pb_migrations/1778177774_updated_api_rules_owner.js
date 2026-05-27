/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const parcelas = app.findCollectionByNameOrId("parcelas");
  parcelas.updateRule = '@request.auth.id != "" && (userId = "" || userId = @request.auth.id)';
  parcelas.deleteRule = '@request.auth.id != "" && (userId = "" || userId = @request.auth.id)';
  app.save(parcelas);

  const plantas = app.findCollectionByNameOrId("plantas");
  plantas.updateRule = '@request.auth.id != ""';
  plantas.deleteRule = '@request.auth.id != ""';
  app.save(plantas);

  const propriedades = app.findCollectionByNameOrId("propriedades");
  propriedades.createRule = '@request.auth.id != ""';
  propriedades.updateRule = "";
  propriedades.deleteRule = "";
  app.save(propriedades);

  const uts = app.findCollectionByNameOrId("uts");
  uts.createRule = '@request.auth.id != ""';
  uts.updateRule = "";
  uts.deleteRule = "";
  app.save(uts);
}, (app) => {
  const parcelas = app.findCollectionByNameOrId("parcelas");
  parcelas.updateRule = '@request.auth.id != ""';
  parcelas.deleteRule = '@request.auth.id != ""';
  app.save(parcelas);

  const plantas = app.findCollectionByNameOrId("plantas");
  plantas.updateRule = '@request.auth.id != ""';
  plantas.deleteRule = '@request.auth.id != ""';
  app.save(plantas);

  const propriedades = app.findCollectionByNameOrId("propriedades");
  propriedades.createRule = '@request.auth.id != ""';
  propriedades.updateRule = "";
  propriedades.deleteRule = "";
  app.save(propriedades);

  const uts = app.findCollectionByNameOrId("uts");
  uts.createRule = '@request.auth.id != ""';
  uts.updateRule = "";
  uts.deleteRule = "";
  app.save(uts);
});
