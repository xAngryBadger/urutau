/// <reference path="../pb_data/types.d.ts" />
// Q3 motor Fase 1 (dev-codigo) — upsert versionado de plantas.
//
// Contexto: o app sincronizava plantas com delete+recreate (apaga todas as do
// servidor e recria) — janela de destruição se o create falhasse depois, e
// zero identidade/versão no servidor. Fases seguintes substituem o push por
// upsert por (parcela, uuid_local) com last-writer-wins por updated_at.
//
// Esta migration só prepara o SCHEMA do servidor (nenhum comportamento muda):
//   - uuid_local: texto, não required (linhas antigas nascem NULL)
//   - updated_at: texto ISO-8601, não required
//   - version: número inteiro, não required (app preenche; default via app)
// Índice único deliberadamente NÃO criado aqui: com coluna nullable, o índice
// único teria de tratar NULL como distinto; a identidade é garantida pelo
// upsert do app (busca por parcela+uuid_local, atualiza o único match).
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_114875327")

  // add field
  collection.fields.addAt(8, new Field({
    "autogeneratePattern": "",
    "hidden": false,
    "id": "text8845000001",
    "max": 0,
    "min": 0,
    "name": "uuid_local",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": false,
    "system": false,
    "type": "text"
  }))

  // add field
  collection.fields.addAt(9, new Field({
    "autogeneratePattern": "",
    "hidden": false,
    "id": "text8845000002",
    "max": 0,
    "min": 0,
    "name": "updated_at",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": false,
    "system": false,
    "type": "text"
  }))

  // add field
  collection.fields.addAt(10, new Field({
    "hidden": false,
    "id": "number8845000003",
    "max": null,
    "min": null,
    "name": "version",
    "onlyInt": true,
    "presentable": false,
    "primaryKey": false,
    "required": false,
    "system": false,
    "type": "number"
  }))

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_114875327")

  // remove field
  collection.fields.removeById("text8845000001")

  // remove field
  collection.fields.removeById("text8845000002")

  // remove field
  collection.fields.removeById("number8845000003")

  return app.save(collection)
})
