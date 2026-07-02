/// <reference path="../pb_data/types.d.ts" />
migrate(
  (app) => {
    const collection = new Collection({
      "createRule": '@request.auth.id != ""',
      "deleteRule": "",
      "fields": [
        {
          "autogeneratePattern": "[a-z0-9]{15}",
          "hidden": false,
          "id": "text_id",
          "max": 0,
          "min": 0,
          "name": "id",
          "pattern": "^[a-z0-9]+$",
          "presentable": false,
          "primaryKey": true,
          "required": true,
          "system": true,
          "type": "text"
        },
        {
          "autogeneratePattern": "",
          "hidden": false,
          "id": "text_codigo",
          "max": 0,
          "min": 0,
          "name": "codigo",
          "pattern": "",
          "presentable": true,
          "primaryKey": false,
          "required": true,
          "system": false,
          "type": "text"
        },
        {
          "autogeneratePattern": "",
          "hidden": false,
          "id": "text_nome",
          "max": 0,
          "min": 0,
          "name": "nome",
          "pattern": "",
          "presentable": false,
          "primaryKey": false,
          "required": false,
          "system": false,
          "type": "text"
        },
        {
          "hidden": false,
          "id": "autodate_created",
          "name": "created",
          "onCreate": true,
          "onUpdate": false,
          "presentable": false,
          "system": false,
          "type": "autodate"
        },
        {
          "hidden": false,
          "id": "autodate_updated",
          "name": "updated",
          "onCreate": true,
          "onUpdate": true,
          "presentable": false,
          "system": false,
          "type": "autodate"
        }
      ],
      "id": "prop_col_9z2zfyiugd",
      "indexes": [],
      "listRule": '@request.auth.id != ""',
      "name": "propriedades",
      "system": false,
      "type": "base",
      "updateRule": "",
      "viewRule": '@request.auth.id != ""'
    });

    return app.save(collection);
  },
  (app) => {
    const collection = app.findCollectionByNameOrId("prop_col_9z2zfyiugd");

    return app.delete(collection);
  }
);
