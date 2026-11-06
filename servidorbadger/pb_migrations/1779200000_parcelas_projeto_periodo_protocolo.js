// RT-01/RC-11: sync de parcelas passa a levar projeto, período de
// monitoramento e versão do protocolo de medição (SOP).
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_3294281715")

  const newFields = [
    { name: "projeto_id", type: "text", required: false },
    { name: "periodo_id", type: "text", required: false },
    { name: "protocolo_versao", type: "text", required: false },
  ]
  for (const f of newFields) {
    if (!collection.fields.some((x) => x.name === f.name)) {
      collection.fields.push(f)
    }
  }
  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_3294281715")
  const drop = ["projeto_id", "periodo_id", "protocolo_versao"]
  collection.fields = collection.fields.filter((x) => !drop.includes(x.name))
  return app.save(collection)
})
