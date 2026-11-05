/// <reference path="../pb_data/types.d.ts" />
// RG-01/RG-02 + campos MRV no sync de parcelas:
//  - geo/area/marcador (RC-10, RS-01/RS-02) passam a sincronizar
//  - status_verificacao: fluxo pendente -> revisado -> aprovado (RG-02)
//    Regra: dono pode editar a parcela, mas só admin muda status_verificacao.
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_3294281715")

  const newFields = [
    { name: "latitude", type: "number", required: false },
    { name: "longitude", type: "number", required: false },
    { name: "geo_json", type: "text", required: false },
    { name: "area_m2", type: "number", required: false },
    { name: "unidade_forma", type: "text", required: false },
    { name: "raio_m", type: "number", required: false },
    { name: "marcador", type: "text", required: false },
    {
      name: "status_verificacao",
      type: "select",
      required: false,
      maxSelect: 1,
      values: ["pendente", "revisado", "aprovado"],
    },
    { name: "aprovado_por", type: "text", required: false },
    { name: "aprovado_em", type: "date", required: false },
  ]
  for (const f of newFields) {
    if (!collection.fields.some((x) => x.name === f.name)) {
      collection.fields.push(f)
    }
  }

  // updateRule: dono (ou admin) edita; trocar status_verificacao exige admin
  // (campo inalterado no body passa direto).
  collection.updateRule =
    '@request.auth.id != "" && (user = @request.auth.id || @request.auth.isAdmin = true) && ' +
    '(@request.body.status_verificacao = status_verificacao || @request.auth.isAdmin = true)'

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_3294281715")
  const drop = ["latitude", "longitude", "geo_json", "area_m2", "unidade_forma",
    "raio_m", "marcador", "status_verificacao", "aprovado_por", "aprovado_em"]
  collection.fields = collection.fields.filter((x) => !drop.includes(x.name))
  collection.updateRule =
    '@request.auth.id != "" && (user = @request.auth.id || userId = "" || userId = @request.auth.id)'
  return app.save(collection)
})
