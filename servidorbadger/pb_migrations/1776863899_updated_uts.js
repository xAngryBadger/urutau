/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("uts_col_e0lf97og6s")

  // remove field
  collection.fields.removeById("relation_prop")

  // add field
  collection.fields.addAt(2, new Field({
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
  }))

  // update field
  collection.fields.addAt(0, new Field({
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
  }))

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("uts_col_e0lf97og6s")

  // add field
  collection.fields.addAt(2, new Field({
    "cascadeDelete": false,
    "collectionId": "",
    "hidden": false,
    "id": "relation_prop",
    "maxSelect": 0,
    "minSelect": 0,
    "name": "propriedade",
    "presentable": false,
    "required": true,
    "system": false,
    "type": "relation"
  }))

  // remove field
  collection.fields.removeById("relation_prop_new1")

  // update field
  collection.fields.addAt(0, new Field({
    "autogeneratePattern": "[a-z0-9]{15}",
    "hidden": false,
    "id": "text_id",
    "max": 0,
    "min": 0,
    "name": "id",
    "pattern": "",
    "presentable": false,
    "primaryKey": true,
    "required": true,
    "system": false,
    "type": "text"
  }))

  return app.save(collection)
})
