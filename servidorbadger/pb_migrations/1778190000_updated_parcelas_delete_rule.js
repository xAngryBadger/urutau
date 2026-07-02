/// <reference path="../pb_data/types.d.ts" />
migrate(
  (app) => {
    const collection = app.findCollectionByNameOrId("parcelas");
    collection.updateRule = '@request.auth.id != "" && (userId = "" || userId = @request.auth.id)';
    collection.deleteRule = '@request.auth.id != "" && userId = @request.auth.id';
    app.save(collection);
  },
  (app) => {
    const collection = app.findCollectionByNameOrId("parcelas");
    collection.updateRule = '@request.auth.id != "" && (userId = "" || userId = @request.auth.id)';
    collection.deleteRule = '@request.auth.id != "" && (userId = "" || userId = @request.auth.id)';
    app.save(collection);
  }
);
