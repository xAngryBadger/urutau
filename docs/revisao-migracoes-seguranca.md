# Revisão independente das migrations de segurança da t13 (t15)

- **Autor:** auditor (read-only). Nenhum código/migration foi escrito ou modificado.
- **Escopo:** as 6 migrations novas (timestamp > 1779200000) de `servidorbadger/pb_migrations/` + os 2 hooks de `pb_hooks/` que os comentários citam + commits `016f41f..5803485` (e `18ea3c8`/`cfbfc1e` app-side, só contexto).
- **Método:** leitura linha a linha de cada migration + boot limpo do PB 0.36.4 em `D:\urutau-devtools\pb-t15` (porta 8092, `--hooksDir` explícito) com as 36 migrations JS (43 linhas em `_migrations`, health 200, 0 erros) + probes HTTP ao vivo (users A/B/C, superuser `audit15@urutau.local`). Regras finais lidas do `data.db` (`_collections`). Servidor real 8090 não foi tocado; `iniciar_servidor.ps1:41` inicia com cwd=`servidorbadger`, logo lá os hooks são *tentados* — e falham igual (ver achado novo).
- **Data:** 2026-11-10.

## Veredicto por item (responde às 6 perguntas da task)

### 1. B-3 — `1779300000_seguranca_b3_propriedades_uts_admin_only.js` (commit a0bfe7b) — **CORRETA** ✅
- update/delete de `propriedades`/`uts` = `@request.auth.isAdmin = true` (linhas 23-33): fecha o furo público. Provas ao vivo: anónimo PATCH → **404**; não-admin C PATCH → **404**; admin A PATCH → **200**; superuser bypass (painel) intencional.
- createRule não foi tocado e continua `@request.auth.id != ""` → **coletor continua a poder criar** (prova: A criou `codigo='PA'` → 200; anónimo create → 400). É a decisão de produto documentada no comentário (catálogo partilhado, coletor só cria) — consistente com o app, que só cria estas coleções.
- **Anónimo NÃO lê o catálogo**: list/viewRule = `@request.auth.id != ""` → anónimo recebe 200 com **0 itens** (provado), não 403, mas sem dados.
- Nota: o `down()` reverte para `""` = público (linha 36-46) — só para rollback manual; aceitável, mas worth saber.

### 2. B-4 — `1779300001_seguranca_b4_users_delete_admin_only.js` (commit 0e92d67) — **CORRETA** ✅
- `users.deleteRule = '@request.auth.isAdmin = true'` (linha 19). Provas: anónimo DELETE user → **404**; self-DELETE → **404**; admin DELETE → **204**; superuser DELETE → **204** (bypass intencional do painel).
- Outros caminhos de delete de users: só a API de delete e o superuser; o app não apaga utilizadores. Ao apagar um user, nada cascadeia para parcelas/plantas (`user` é texto; `userId` relation tem cascadeDelete=false) — ficam órfãs, semIntegridade quebrada.
- Nota: o próprio utilizador não pode apagar a própria conta por esta regra — decisão documentada no comentário (linha 13-14); app não usa.

### 3. H-1 — `1779300002_seguranca_h1_isadmin_nao_e_do_cliente.js` (commit 016f41f) — **CORRETA** ✅ (com nota sobre hook morto, ver §novos)
- createRule `@request.body.isAdmin != true` (linha 32): signup anónimo com `isAdmin:true` → **400**; com `isAdmin:'true'` (string) → **400** (validação de tipo bool); signup normal → 200 com isAdmin=false.
- updateRule `(id = auth.id && body.isAdmin != true) || auth.isAdmin = true` (linhas 35-37): não-admin self-PATCH `isAdmin=true` → **404** (provado com C); admin PATCH isAdmin de outro → 200 (intencional).
- Outros caminhos de promoção: nenhum. `isAdmin` é o único campo de privilégio referenciado em regras (grep nas 36 migrations). `expand` não se aplica (nenhuma regra usa). Campos `email`/`verified`/`password` de auth collections são protegidos pelo core do PB (admin PATCH email de outro → 400; password sem oldPassword → 400 — provados), então self-update irrestrito não dá privilégio: self-PATCH `verified=true` → 400 (core), self-PATCH name → 200 (inofensivo).
- **Nota:** o comentário (linhas 11-12) cita `pb_hooks/users_validation.js` como camada extra — esse hook está morto no 0.36.4 (ver §novos); a regra de coleção sozinha já fecha o furo medido, então o veredicto não muda.

### 4. B-1 — `1779300003_seguranca_b1_parcelas_delete_pelo_texto_user.js` (commit 3bfd5ec) — **CORRETA no delete** ✅, **PORÉM furo no create** ⚠️
- deleteRule agora usa o mesmo texto `user` do updateRule (linhas 23-25 vs `1778900000:58-60`): **sem divergência de semântica** — a cláusula extra de `status_verificacao` no updateRule é própria de update e não faz sentido em delete. Provas: B DELETE parcela de A → **404**; B PATCH → **404**; A PATCH própria → **200**; A DELETE própria → **204**; admin → 204.
- **Furo residual (médio): o createRule de parcelas continua `auth` e não ata o dono** — A criou parcela com `user = <id de B>` → **200**, e depois **B fez DELETE dessa parcela → 204** (provado). Ou seja, quem cria escolhe o dono: B pode apagar/editar o que A criou. O app manda o id correto, mas a API permite falso. Fix sugerido: createRule `'@request.auth.id != "" && @request.body.user = @request.auth.id'` (ou hook `onRecordCreateRequest` que força `user = auth.id`).

### 5. B-2 — `1779300004_seguranca_b2_plantas_regras_pelo_texto_user_da_parcela.js` (commit d3cf5c8) — **CORRETA** ✅ (com residual de órfãs)
- list/view/update/delete de plantas passaram ao escopo `parcela_rel.user = "" || = auth.id || isAdmin` (linhas 27-37). **Backfill confirmado**: a migration `1778250001` preencheu `parcela_rel` a partir do texto `parcela`, e o push novo envia `parcela_rel` no create (sync_service.dart:2020-2035) e a parcela traz `user` no push — a regra não fica inerte. Provas ao vivo: B **não vê** a planta W de A na lista (B vê só 2 itens, as órfãs); C PATCH/DELETE planta de A → **404**; A DELETE própria planta → **204**.
- Residual: plantas com `parcela_rel` nulo (órfãs) caem no escape `parcela_rel.user = ""` e qualquer auth vê/edita (B PATCH planta órfã POL → **200**, provado). Agora o escape só casa em relation genuinamente nula — diferente do bug antigo, onde casava sempre porque `userId` estava sempre vazio.

### 6. H-2 — `1779300005_seguranca_h2_plantas_create_escopo_dono.js` (commit 5803485) — **FROUXA** ⚠️ (furo residual médio)
- Com `parcela_rel` enviado: B cria planta na parcela de A → **400** (bloqueado) ✔.
- **Mas omitindo `parcela_rel` (só o texto `parcela`): B criou → 200** (provado). Em PB 0.36.4, `parcela_rel.user` com relation nula resolve como `""` e casa no escape — logo o create sem relation **burla o escopo**. E a planta órfã poluída aparece na listagem por texto do dono real da parcela: A listou `parcela=<P2>` por texto e viu **3 plantas (W, POL, Y)** — POL e Y foram criadas por B. Qualquer auth pode editar essas órfãs (B PATCH POL → 200).
- Fix sugerido: createRule sem escape para relation nula, ex. `'@request.auth.id != "" && @request.body.parcela_rel != "" && (parcela_rel.user = @request.auth.id || @request.auth.isAdmin = true)'`, e/ou hook `onRecordCreateRequest` que deriva `parcela_rel` de `parcela` no create (assim o app antigo continua funcionando e o furo fecha).

## Achados novos transversais (fora das 6 migrations, maslehados por elas)

- **N-1 (alto para ops, médio para segurança): os 2 hooks de `pb_hooks/` estão MORTOS no PB 0.36.4.** Usam `onRecordBeforeCreateRequestEvent` / `onRecordBeforeUpdateRequestEvent` (`users_validation.js:3`, `parcelas_validation.js:4,29`) — esses nomes **não existem no binário** (strings `onRecordBefore*` ausentes; o d.ts interno lista `onRecordCreateRequest` / `onRecordUpdateRequest`). Consequências provadas ao vivo: (a) duplicata `prop_ut='UT9', id_parcela=9` criada por A e por C → **200/200** (o hook de conflito nunca rodou; resta só M-1, sem UNIQUE no índice); (b) a restrição "admin só muda isAdmin de outros users" não existe — admin PATCH qualquer campo não-protegido de outro user passa pela rule (campos email/password/verified têm guarda do core → 400). Se alguém renomear os hooks para 0.36.4, atenção: `parcelas_validation.js:19` interpola `prop_ut`/`user` **crus** num filtro (`prop_ut = "${propUt}" && ... user != "${user}"`) — injeção de filtro server-side; precisa do mesmo escape que o app ganhou em `2ee0315` (escapePbFilter).
- **N-2 (info):** servidor real 8090 é iniciado com cwd=`servidorbadger` (`iniciar_servidor.ps1:41`), então os hooks são tentados lá também — e falham silenciosamente (sem erro no log). Ou seja, em produção hoje **nenhum hook roda**.

## Tabela final

| # | Migration (arquivo:linhas) | Commit | Veredicto | Prova ao vivo (8092) | Furo residual / fix |
|---|---|---|---|---|---|
| 1 | `1779300000…b3…js:23-33` | a0bfe7b | ✅ correta | anon PATCH 404, C 404, admin 200, anon list 0 itens, coletor create 200 | down() volta a público (só rollback) |
| 2 | `1779300001…b4…js:19` | 0e92d67 | ✅ correta | anon/self DELETE 404, admin/superuser 204 | nenhum; app não apaga users |
| 3 | `1779300002…h1…js:32-37` | 016f41f | ✅ correta | signup isAdmin=true 400; self-PATCH isAdmin 404; admin→outro 200 | hook citado no comentário está morto (N-1); core do PB protege email/password/verified |
| 4 | `1779300003…b1…js:23-25` | 3bfd5ec | ✅ correta no delete | B DELETE/PATCH 404, A DELETE 204 | ⚠️ create não ata `user` ao auth: A cria com user=B → B DELETE 204 (dono falso). Fix: createRule com `@request.body.user = @request.auth.id` |
| 5 | `1779300004…b2…js:27-37` | d3cf5c8 | ✅ correta | B não vê/edita planta de A (404), A DELETE 204; backfill+push preenchem parcela_rel | plantas órfãs (parcela_rel null) ficam "livres" — B PATCH POL 200 |
| 6 | `1779300005…h2…js:26-31` | 5803485 | ⚠️ frouxa | com parcela_rel de terceiro → 400; **sem parcela_rel → 200** e polui lista do dono (A viu POL,Y) | ⚠️ createRule: remover escape para relation nula e/ou hook que deriva parcela_rel de `parcela` no create |
| N-1 | `pb_hooks/*.js` (nomes de hook) | — | ❌ mortos no 0.36.4 | duplicata UT9/9 → 200/200; admin PATCH campo de outro user passa (menos email/password/verified, 400 pelo core) | renomear para `onRecord*Request`; ao renomear, escapar o filtro da linha 19 de `parcelas_validation.js` |
| N-2 | `iniciar_servidor.ps1:41` | — | info | hooks tentam carregar em produção e falham silenciosamente | logar erro de hook no boot |

## Conclusão

As 6 migrations fecham os 4 blockers medidos na t12 (B-1..B-4) e o H-2 principal — **provas ao vivo acima** numa instância limpa com todas as 36 migrations. Restam **2 furos residuais de média**: (1) create de parcelas aceita dono falso (`user` não atado ao auth no createRule — provado com DELETE 204 por B); (2) create de plantas omitindo `parcela_rel` burla o escopo do dono e polui a listagem do dono real (provado). Ambos têm fix simples em createRule/hook. E um achado de ops: **os hooks do servidor não carregam no 0.36.4** (nome de hook antigo), então a proteção de duplicata e a restrição de campos de admin hoje não existem — o que deixa M-1 (sem UNIQUE) sem rede de segurança server-side.
