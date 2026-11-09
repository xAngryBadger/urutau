// v29 do app (RC-05): trilha_auditoria ganha offset_relogio_ms.
// O offset do relógio passa a fazer parte da evidência replicada no servidor.
//
// new Field + fields.add (não fields.push com objeto puro) — ver nota em
// 1778900000_parcelas_mrv_verificacao.js sobre o erro de conversão do Go.
migrate((app) => {
  const collection = app.findCollectionByNameOrId("trilha_auditoria")
  if (!collection.fields.some((f) => f.name === "offset_relogio_ms")) {
    collection.fields.add(
      new Field({
        hidden: false,
        id: "number_offset_relogio_ms",
        name: "offset_relogio_ms",
        presentable: false,
        required: false,
        system: false,
        type: "number",
      })
    )
  }
  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("trilha_auditoria")
  collection.fields.removeById("number_offset_relogio_ms")
  return app.save(collection)
})
