/// <reference path="../pb_data/types.d.ts" />
// RG-01/RG-02 + campos MRV no sync de parcelas:
//  - geo/area/marcador (RC-10, RS-01/RS-02) passam a sincronizar
//  - status_verificacao: fluxo pendente -> revisado -> aprovado (RG-02)
//    Regra: dono pode editar a parcela, mas só admin muda status_verificacao.
//
// ATENÇÃO — bug de engine medido no PocketBase 0.36.4 deste servidor:
//   collection.fields.push({...})  com objeto JS puro, sobre coleção JÁ
//   carregada (findCollectionByNameOrId), falha com
//   "Go type conversion error: could not convert [object Object] to core.Field
//    at push (native)"
// Criar coleção nova com os MESMOS campos funciona; portanto a causa é o
// push nativo em FieldsList de coleção existente, não o tipo de campo.
// Padrão que aplica limpo neste repo (ver 1776862935_updated_parcelas.js e
// 1778250000_add_isAdmin_users.js): new Field({...}) + collection.fields.add().
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_3294281715")

  const novos = [
    { id: "number_latitude", name: "latitude", type: "number" },
    { id: "number_longitude", name: "longitude", type: "number" },
    { id: "text_geo_json", name: "geo_json", type: "text" },
    { id: "number_area_m2", name: "area_m2", type: "number" },
    { id: "text_unidade_forma", name: "unidade_forma", type: "text" },
    { id: "number_raio_m", name: "raio_m", type: "number" },
    { id: "text_marcador", name: "marcador", type: "text" },
    {
      id: "select_status_verificacao",
      name: "status_verificacao",
      type: "select",
      maxSelect: 1,
      values: ["pendente", "revisado", "aprovado"],
    },
    { id: "text_aprovado_por", name: "aprovado_por", type: "text" },
    { id: "date_aprovado_em", name: "aprovado_em", type: "date" },
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

  // updateRule: dono (ou admin) edita; trocar status_verificacao exige admin
  // (campo inalterado no body passa direto).
  collection.updateRule =
    '@request.auth.id != "" && (user = @request.auth.id || @request.auth.isAdmin = true) && ' +
    '(@request.body.status_verificacao = status_verificacao || @request.auth.isAdmin = true)'

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_3294281715")

  const ids = [
    "number_latitude",
    "number_longitude",
    "text_geo_json",
    "number_area_m2",
    "text_unidade_forma",
    "number_raio_m",
    "text_marcador",
    "select_status_verificacao",
    "text_aprovado_por",
    "date_aprovado_em",
  ]
  for (const id of ids) {
    collection.fields.removeById(id)
  }

  collection.updateRule =
    '@request.auth.id != "" && (user = @request.auth.id || userId = "" || userId = @request.auth.id)'

  return app.save(collection)
})
