/// <reference path="../pb_data/types.d.ts" />
// v28 MRV — promessa do pitch: "cada medição e foto recebe hash SHA-256,
// GPS, timestamp e dono".
//  - plantas ganha `autor` (dono da medição)
//  - parcelas ganha `fotos_meta` (JSON: por foto uuid/sha256/lat/long/autor/ts)
//
// new Field + fields.add (não fields.push com objeto puro) — ver nota em
// 1778900000_parcelas_mrv_verificacao.js sobre o erro de conversão do Go.
migrate((app) => {
  const plantas = app.findCollectionByNameOrId("pbc_114875327")
  if (!plantas.fields.some((x) => x.name === "autor")) {
    plantas.fields.add(
      new Field({
        hidden: false,
        id: "text_autor_plantas",
        name: "autor",
        presentable: false,
        required: false,
        system: false,
        type: "text",
      })
    )
  }
  app.save(plantas)

  const parcelas = app.findCollectionByNameOrId("pbc_3294281715")
  if (!parcelas.fields.some((x) => x.name === "fotos_meta")) {
    parcelas.fields.add(
      new Field({
        hidden: false,
        id: "text_fotos_meta",
        name: "fotos_meta",
        presentable: false,
        required: false,
        system: false,
        type: "text",
      })
    )
  }
  return app.save(parcelas)
}, (app) => {
  const plantas = app.findCollectionByNameOrId("pbc_114875327")
  plantas.fields.removeById("text_autor_plantas")
  app.save(plantas)

  const parcelas = app.findCollectionByNameOrId("pbc_3294281715")
  parcelas.fields.removeById("text_fotos_meta")
  return app.save(parcelas)
})
