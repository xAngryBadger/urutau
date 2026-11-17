/// <reference path="../pb_data/types.d.ts" />
// ============================================================
// 1779500000_unique_parcelas_prop_ut_id_parcela.js  (t22)
//
// FRONTEIRA DE VERDADE: UNIQUE(prop_ut, id_parcela) no banco. Um hook e codigo
// de aplicacao — morreu em silencio na t21 e enquanto morto deixou duplicadas
// com 200/200. A constraint torna a duplicata IMPOSSIVEL.
// HIERARQUIA (documentada): 1) esta constraint (banco) bloqueia sempre;
// 2) o hook parcelas_validation.pb.js fica como SEGUNDA LINHA so para dar a
//    mensagem legivel (400 CONFLITO) no create cross-user.
//
// PERIGO: se ja existirem duplicadas (criadas com o hook morto), criar o
// indice por cima delas falha o boot — pior que o problema original. Por isso
// esta migration primeiro DETETA duplicadas (recordQuery + agrupamento em JS,
// porque neste build .all() so aceita arrayOf(model)):
//   - modo strict (env URUTAU_PARCELA_DUP_STRICT=1): lanca erro que lista os
//     grupos e os ids — boot falha COM MENSAGEM CLARA, nada e apagado;
//   - modo default: CONSOLIDA por politica — por grupo (prop_ut, id_parcela),
//     o vencedor e o registo mais antigo (created; desempate: id menor); as
//     plantas dos perdedores sao re-apontadas (texto `parcela` e relation
//     `parcela_rel`) para o vencedor e so depois os perdedores sao apagados
//     (app.delete limpa tambem fotos_parcela; parcela_rel tem cascadeDelete=false).
// Depois cria o indice UNIQUE.
// Os dois caminhos provados ao vivo em docs/t22-constraint-unique.md.
// ============================================================

migrate((app) => {
  const escSql = (v) => String(v).replace(/'/g, "''");

  // 1) todas as parcelas, agrupadas por (prop_ut, id_parcela) em JS
  const todas = arrayOf(new Record);
  app.recordQuery("parcelas").all(todas);

  const grupos = {}; // chave -> Array<Record>
  for (const r of todas) {
    const k = String(r.get("prop_ut")) + "" + String(Number(r.get("id_parcela")));
    if (!grupos[k]) grupos[k] = [];
    grupos[k].push(r);
  }

  const duplicados = [];
  for (const k in grupos) {
    if (grupos[k].length > 1) duplicados.push(grupos[k]);
  }

  if (duplicados.length > 0) {
    const strict = (typeof $os !== "undefined") && $os.getenv("URUTAU_PARCELA_DUP_STRICT") === "1";

    if (strict) {
      const linhas = [];
      for (const g of duplicados) {
        for (const r of g) {
          linhas.push("  - id=" + r.id + " prop_ut=" + JSON.stringify(r.get("prop_ut")) +
            " id_parcela=" + r.get("id_parcela") + " user=" + r.get("user") + " created=" + r.get("created"));
        }
      }
      throw new Error(
        "URUTAU_PARCELA_DUP_STRICT=1: ha " + linhas.length + " parcelas duplicadas (prop_ut, id_parcela) " +
        "que impedem o indice UNIQUE:\n" + linhas.join("\n") +
        "\nNada foi apagado. Consolide manualmente ou re-arranque SEM a env para consolidar " +
        "automaticamente (mantem o mais antigo por grupo e reaponta as plantas)."
      );
    }

    // 2) consolidar por politica: vencedor = created mais antigo (desempate id menor)
    for (const g of duplicados) {
      g.sort((a, b) => {
        const ca = String(a.get("created")), cb = String(b.get("created"));
        if (ca !== cb) return ca < cb ? -1 : 1;
        return a.id < b.id ? -1 : 1;
      });
      const winner = g[0].id;
      const losers = g.slice(1);
      console.log("t22: grupo duplicado prop_ut=" + JSON.stringify(g[0].get("prop_ut")) +
        " id_parcela=" + g[0].get("id_parcela") + " -> mantem id=" + winner +
        " (mais antigo), consolida " + losers.length + " perdedor(es)");

      for (const loserRec of losers) {
        const loser = loserRec.id;
        // re-apontar plantas (texto + relation) ANTES de apagar
        app.db().newQuery(
          "UPDATE plantas SET parcela = '" + winner + "', parcela_rel = '" + winner + "' " +
          "WHERE parcela = '" + loser + "' OR parcela_rel = '" + loser + "'"
        ).execute();
        app.delete(loserRec);
      }
    }
  }

  // 3) a fronteira: unique index
  app.db().newQuery(
    "CREATE UNIQUE INDEX IF NOT EXISTS idx_parcelas_prop_ut_id_parcela ON parcelas (prop_ut, id_parcela)"
  ).execute();

}, (app) => {
  app.db().newQuery(
    "DROP INDEX IF EXISTS idx_parcelas_prop_ut_id_parcela"
  ).execute();
});
