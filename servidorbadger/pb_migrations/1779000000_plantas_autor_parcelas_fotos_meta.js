/// <reference path="../pb_data/types.d.ts" />
// v28 MRV — promessa do pitch: "cada medição e foto recebe hash SHA-256,
// GPS, timestamp e dono".
//  - plantas ganha `autor` (dono da medição)
//  - parcelas ganha `fotos_meta` (JSON: por foto uuid/sha256/lat/long/autor/ts)
migrate((app) => {
  const plantas = app.findCollectionByNameOrId("pbc_114875327")
  if (!plantas.fields.some((x) => x.name === "autor")) {
    plantas.fields.push({ name: "autor", type: "text", required: false })
  }
  app.save(plantas)

  const parcelas = app.findCollectionByNameOrId("pbc_3294281715")
  if (!parcelas.fields.some((x) => x.name === "fotos_meta")) {
    parcelas.fields.push({ name: "fotos_meta", type: "text", required: false })
  }
  return app.save(parcelas)
}, (app) => {
  const plantas = app.findCollectionByNameOrId("pbc_114875327")
  plantas.fields = plantas.fields.filter((x) => x.name !== "autor")
  app.save(plantas)
  const parcelas = app.findCollectionByNameOrId("pbc_3294281715")
  parcelas.fields = parcelas.fields.filter((x) => x.name !== "fotos_meta")
  return app.save(parcelas)
})
