// RG-04: collection trilha_auditoria no servidor — append-only.
// create: qualquer usuário autenticado pode append (o app registra).
// update/delete: NINGUÉM (nem admin) — a trilha é imutável; adulteração
// deve ser detectada pela verificação da cadeia de hash, não impedida por regra.
import { fs } from "$hooks/fs.ts";

const collection = {
  name: "trilha_auditoria",
  type: "base",
  fields: [
    { name: "entidade_tipo", type: "text", required: false },
    { name: "entidade_uuid", type: "text", required: false },
    { name: "acao", type: "text", required: true },
    { name: "antes", type: "text", required: false },
    { name: "depois", type: "text", required: false },
    { name: "usuario_uuid", type: "text", required: false },
    { name: "ts_servidor", type: "date", required: false },
    { name: "ts_dispositivo", type: "date", required: false },
    { name: "origem", type: "text", required: true },
    { name: "prev_hash", type: "text", required: false },
    { name: "entry_hash", type: "text", required: false },
    { name: "dispositivo_id", type: "text", required: false },
  ],
  indexes: ["CREATE INDEX idx_trilha_entidade ON trilha_auditoria(entidade_tipo, entidade_uuid)"],
  listRule: "@request.auth.id != ''",
  viewRule: "@request.auth.id != ''",
  createRule: "@request.auth.id != ''",
  updateRule: null, // append-only: sem update
  deleteRule: null, // append-only: sem delete
};

export async function up(db) {
  const dao = new Dao(db);
  dao.saveCollection(collection);
}

export async function down(db) {
  const dao = new Dao(db);
  dao.deleteCollection("trilha_auditoria");
}
