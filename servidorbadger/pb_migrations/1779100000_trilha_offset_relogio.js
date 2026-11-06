// v29 do app (RC-05): trilha_auditoria ganha offset_relogio_ms.
// O offset do relogio passa a fazer parte da evidencia replicada no servidor.
export async function up(db) {
  const dao = new Dao(db);
  const c = dao.findCollectionByNameOrId("trilha_auditoria");
  c.fields.push({ name: "offset_relogio_ms", type: "number", required: false });
  dao.saveCollection(c);
}

export async function down(db) {
  const dao = new Dao(db);
  const c = dao.findCollectionByNameOrId("trilha_auditoria");
  c.fields = c.fields.filter((f) => f.name !== "offset_relogio_ms");
  dao.saveCollection(c);
}
