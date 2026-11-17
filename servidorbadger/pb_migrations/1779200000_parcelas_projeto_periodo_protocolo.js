// RT-01/RC-11: sync de parcelas passa a levar projeto, período de
// monitoramento e versão do protocolo de medição (SOP).
//
// new Field + fields.add (não fields.push com objeto puro) — ver nota em
// 1778900000_parcelas_mrv_verificacao.js sobre o erro de conversão do Go.
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_3294281715")

  const novos = [
    { id: "text_projeto_id", name: "projeto_id", type: "text" },
    { id: "text_periodo_id", name: "periodo_id", type: "text" },
    { id: "text_protocolo_versao", name: "protocolo_versao", type: "text" },
  ]

  for (const def of novos) {
    if (!collection.fields.some((x) => x.name === def.name)) {
      collection.fields.add(
        new Field(
          Object.assign(
            {
              hidden: false,
              presentable: false,
              system: false,
              required: false,
            },
            def
          )
        )
      )
    }
  }
  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_3294281715")
  for (const id of ["text_projeto_id", "text_periodo_id", "text_protocolo_versao"]) {
    collection.fields.removeById(id)
  }
  return app.save(collection)
})
