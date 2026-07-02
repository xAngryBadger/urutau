/// <reference path="../pb_data/types.d.ts" />
migrate(
  (app) => {
    const collection = app.findCollectionByNameOrId("users");
    collection.updateRule = 'id = @request.auth.id';
    app.save(collection);
  },
  (app) => {
    const collection = app.findCollectionByNameOrId("users");
    collection.updateRule = '@request.auth.id != ""';
    app.save(collection);
  }
);
