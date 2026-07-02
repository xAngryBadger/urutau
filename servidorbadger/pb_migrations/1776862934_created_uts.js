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
          "cascadeDelete": false,
          "collectionId": "prop_col_9z2zfyiugd",
          "hidden": false,
          "id": "relation_prop_new1",
          "maxSelect": 1,
          "minSelect": 1,
          "name": "propriedade",
          "presentable": false,
          "required": true,
          "system": false,
          "type": "relation"
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
      "id": "uts_col_e0lf97og6s",
      "indexes": [],
      "listRule": '@request.auth.id != ""',
      "name": "uts",
      "system": false,
      "type": "base",
      "updateRule": "",
      "viewRule": '@request.auth.id != ""'
    });

    return app.save(collection);
  },
  (app) => {
    const collection = app.findCollectionByNameOrId("uts_col_e0lf97og6s");

    return app.delete(collection);
  }
);
