/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("_pb_users_auth_")

  // Allow any authenticated user to update any user record.
  // Needed so admin can promote/demote isAdmin from the mobile app.
  // For 3-user beta this is acceptable; tighten before public launch.
  unmarshal({
    "updateRule": "@request.auth.id != \"\""
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("_pb_users_auth_")

  // Revert to self-only updates
  unmarshal({
    "updateRule": "id = @request.auth.id"
  }, collection)

  return app.save(collection)
})
