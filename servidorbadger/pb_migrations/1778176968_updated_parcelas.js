/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_3294281715")

  // update collection data
  unmarshal({
    "deleteRule": "@request.auth.id != \"\" && (userId = \"\" || userId = @request.auth.id)",
    "updateRule": "@request.auth.id != \"\" && (userId = \"\" || userId = @request.auth.id)"
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_3294281715")

  // update collection data
  unmarshal({
    "deleteRule": "@request.auth.id != \"\" && userId = @request.auth.id",
    "updateRule": "@request.auth.id != \"\" && userId = @request.auth.id"
  }, collection)

  return app.save(collection)
})
