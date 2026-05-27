/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_3294281715")

  // remove field
  collection.fields.removeById("relation_ut")

  // remove field
  collection.fields.removeById("relation_user")

  // add field
  collection.fields.addAt(6, new Field({
    "cascadeDelete": false,
    "collectionId": "uts_col_e0lf97og6s",
    "hidden": false,
    "id": "relation_ut_new1",
    "maxSelect": 1,
    "minSelect": 0,
    "name": "ut",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "relation"
  }))

  // add field
  collection.fields.addAt(9, new Field({
    "cascadeDelete": false,
    "collectionId": "_pb_users_auth_",
    "hidden": false,
    "id": "relation_user_new1",
    "maxSelect": 1,
    "minSelect": 0,
    "name": "userId",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "relation"
  }))

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_3294281715")

  // add field
  collection.fields.addAt(6, new Field({
    "cascadeDelete": false,
    "collectionId": "",
    "hidden": false,
    "id": "relation_ut",
    "maxSelect": 0,
    "minSelect": 0,
    "name": "ut",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "relation"
  }))

  // add field
  collection.fields.addAt(9, new Field({
    "cascadeDelete": false,
    "collectionId": "",
    "hidden": false,
    "id": "relation_user",
    "maxSelect": 0,
    "minSelect": 0,
    "name": "userId",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "relation"
  }))

  // remove field
  collection.fields.removeById("relation_ut_new1")

  // remove field
  collection.fields.removeById("relation_user_new1")

  return app.save(collection)
})
