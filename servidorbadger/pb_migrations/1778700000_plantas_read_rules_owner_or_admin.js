/// <reference path="../pb_data/types.d.ts" />
// ============================================================
// 1778700000_plantas_read_rules_owner_or_admin.js
//
// t16 (dev-mrv) — fecha a LEITURA de plantas (F-02 residual).
//
// BUG: 1776864000_updated_rules_and_limits.js deixou plantas com
//   listRule/viewRule/createRule = '@request.auth.id != ""'
// A ESCRITA foi fechada pelo Q4 (1778300000: dono||livre||admin), a LEITURA não.
// Qualquer autenticado ainda lê planta de terceiro — coletor vê plantio do vizinho.
//
// ESCOPO LEVANTADO ANTES DE ESCREVER (por que esta regra não quebra o app):
// os 4 pontos de leitura de plantas em sync_service.dart são:
//   :1682 push upsert    -> filter parcela = record.id (parcela sendo enviada)
//   :1851 delete no server-> filter parcela = serverId (parcela do dono logado)
//   :1935 export fotos   -> filter parcela = <id> (parcela já filtrada antes)
//   :2076 limpeza orfaos -> filter parcela = <id>
// e as parcelas que os alimentam vêm de :1897-1901, cujo filtro é montado em
// :1885-1895 como: user = <userId> | prop_ut = <ut> | id = <parcelaServerId>.
// Ou seja: o app lê planta apenas de parcela do usuario logado, parcela
// livre/seed (user=""), ou parcela por id especifico — sempre partir de um
// desses dois escopos. Admin (isAdmin) cobre verificador/painel.
//
// PRÉ-REQUISITOS (ordem importa):
//   1. 1778250000 (users.isAdmin) aplicado — inclusive em PRODUCAO. Sem o campo,
//      @request.auth.isAdmin nunca resolve (licao do D-4: lockout total).
//   2. 1778600000 (parcela_rel relation) aplicado. Sem a relation, parcela_rel.userId
//      nao resolve.
//   3. 1778300000 (regras de escrita) aplicado ANTES desta: escrever corretamente
//      e depois restringir a leitura evita janela em que o app nao rele o que escreveu.
// ============================================================

migrate(
  (app) => {
    const plantas = app.findCollectionByNameOrId("plantas");

    // DONO (via parcela_rel -> parcelas.userId) || LIVRE (userId = "") || ADMIN.
    // Mesmo padrao da regra de escrita do Q4: quem pode escrever pode ler, e
    // mais ninguem. viewRule igual a listRule de proposito — ver uma planta por
    // id e o mesmo direito de lista-la; diferente seria furo.
    const escopoLeitura =
      '@request.auth.id != "" && (' +
      'parcela_rel.userId = "" || ' +
      'parcela_rel.userId = @request.auth.id || ' +
      '@request.auth.isAdmin = true' +
      ')';

    plantas.listRule = escopoLeitura;
    plantas.viewRule = escopoLeitura;
    // createRule NAO e tocada aqui: ja e do Q4 de escrita (1778300000).
    app.save(plantas);
  },
  (app) => {
    // Revert para o estado anterior (qualquer autenticado lia tudo).
    const plantas = app.findCollectionByNameOrId("plantas");
    plantas.listRule = '@request.auth.id != ""';
    plantas.viewRule = '@request.auth.id != ""';
    app.save(plantas);
  }
);
