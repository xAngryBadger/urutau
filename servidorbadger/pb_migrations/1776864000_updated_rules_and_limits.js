/// <reference path="../pb_data/types.d.ts" />
migrate(
  (app) => {
    // Update parcelas collection: auth rules + file limits
    let collection = app.findCollectionByNameOrId("pbc_3294281715");
    collection.listRule = '@request.auth.id != ""';
    collection.viewRule = '@request.auth.id != ""';
    collection.createRule = '@request.auth.id != ""';
    collection.updateRule = '@request.auth.id != ""';
    collection.deleteRule = '@request.auth.id != ""';
    for (const field of collection.fields) {
      if (field.name === "fotos_parcela") {
        field.maxSize = 10485760;
        field.mimeTypes = ["image/jpeg", "image/png", "image/webp"];
        field.maxSelect = 10;
      }
    }
    app.save(collection);

    // Update plantas collection: auth rules + file limits
    collection = app.findCollectionByNameOrId("pbc_114875327");
    collection.listRule = '@request.auth.id != ""';
    collection.viewRule = '@request.auth.id != ""';
    collection.createRule = '@request.auth.id != ""';
    collection.updateRule = '@request.auth.id != ""';
    collection.deleteRule = '@request.auth.id != ""';
    for (const field of collection.fields) {
      if (field.name === "foto_especie") {
        field.maxSize = 10485760;
        field.mimeTypes = ["image/jpeg", "image/png", "image/webp"];
        field.maxSelect = 1;
      }
    }
    app.save(collection);

    // Update propriedades: auth read/create, no public delete/update
    collection = app.findCollectionByNameOrId("prop_col_9z2zfyiugd");
    collection.listRule = '@request.auth.id != ""';
    collection.viewRule = '@request.auth.id != ""';
    collection.createRule = '@request.auth.id != ""';
    collection.updateRule = "";
    collection.deleteRule = "";
    app.save(collection);

    // Update uts: auth read/create, no public delete/update
    collection = app.findCollectionByNameOrId("uts_col_e0lf97og6s");
    collection.listRule = '@request.auth.id != ""';
    collection.viewRule = '@request.auth.id != ""';
    collection.createRule = '@request.auth.id != ""';
    collection.updateRule = "";
    collection.deleteRule = "";
    app.save(collection);
  },
  (app) => {
    // Revert: remove all rules (open access)
    for (const id of ["pbc_3294281715", "pbc_114875327", "prop_col_9z2zfyiugd", "uts_col_e0lf97og6s"]) {
      const collection = app.findCollectionByNameOrId(id);
      collection.listRule = "";
      collection.viewRule = "";
      collection.createRule = "";
      collection.updateRule = "";
      collection.deleteRule = "";
      for (const field of collection.fields) {
        if (field.type === "file") {
          field.maxSize = 0;
          field.mimeTypes = null;
          field.maxSelect = 0;
        }
      }
      app.save(collection);
    }
  }
);
