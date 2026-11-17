# Auditoria do servidor PocketBase — t12 (ronda 1)

- **Autor:** auditor (team urutau-liso), modo READ-ONLY — nenhum ficheiro de código foi alterado.
- **Data:** 2026-11-10 (boot de prova às 2026/11/09 23:38 UTC).
- **Alvo:** `D:\projetos\urutau\servidorbadger\pocketbase.exe` (PocketBase **0.36.4**, MD5 `06D22D8FB79EAF64B570CF91F9C4E743`), migrations em `servidorbadger\pb_migrations\*.js` (**30 ficheiros**), servidor vivo `http://127.0.0.1:8090` (dir `D:\urutau-devtools\pb-sync`), app `urutau-app\lib\services\sync_service.dart`, painel `urutau-admin\src\pages\Parcels.jsx` + `src\services\pocketbase.js`.
- **Prova ao vivo:** boot limpo numa porta separada (`127.0.0.1:8091`, dir novo `D:\urutau-devtools\pb-audit-t12`, logs em `D:\urutau-devtools\logs\pb-audit-t12.log`) para não perturbar o servidor do verificador em 8090/pb-sync. Evidence: `data.db` desse dir + probes HTTP.

---

## 1. Aplicação limpa das migrations num dir NOVO — PASSOU

Comando de prova:

```
pocketbase.exe serve --http=127.0.0.1:8091 --dir=D:\urutau-devtools\pb-audit-t12 --migrationsDir=D:\projetos\urutau\servidorbadger\pb_migrations
```

- `GET /api/health` → **200** `{"message":"API is healthy.","code":200,"data":{}}`.
- Log de boot (`D:\urutau-devtools\logs\pb-audit-t12.log`): **zero erros/fatal/panic**.
- Tabela `_migrations` do data.db novo prova que **todas as 30 migrations JS aplicaram, por ordem de nome**, depois das 7 de sistema. Ordem effective (rowid → file):

```
1640988000_aux_init.go, 1640988000_init.go, 1717233556_v0.23_migrate.go, 1717233557_v0.23_migrate2.go,
1717233558_v0.23_migrate3.go, 1717233559_v0.23_migrate4.go, 1763020353_update_default_auth_alert_templates.go,
1771423363_created_parcelas.js, 1771423363_created_plantas.js, 1771424156_deleted_parcelas.js,
1771424156_deleted_plantas.js, 1771424171_created_parcelas.js, 1771424190_created_plantas.js,
1776859848_updated_users.js, 1776862933_created_propriedades.js, 1776862934_created_uts.js,
1776862935_updated_parcelas.js, 1776863899_updated_uts.js, 1776864000_updated_rules_and_limits.js,
1778173082_updated_parcelas.js, 1778176771_updated_plantas.js, 1778176968_updated_parcelas.js,
1778177173_updated_plantas.js, 1778177774_updated_api_rules_owner.js, 1778180000_updated_users_update_rule.js,
1778190000_updated_parcelas_delete_rule.js, 1778200000_updated_users_self_only.js, 1778250000_add_isAdmin_users.js,
1778250001_plantas_parcela_relation.js, 1778300000_plantas_rules_owner_or_admin.js, 1778500000_updated_plantas_upsert.js,
1778700000_plantas_read_rules_owner_or_admin.js, 1778800000_add_trilha_auditoria.js, 1778900000_parcelas_mrv_verificacao.js,
1779000000_plantas_autor_parcelas_fotos_meta.js, 1779100000_trilha_offset_relogio.js, 1779200000_parcelas_projeto_periodo_protocolo.js
```

- Collections presentes no DB novo: `parcelas`, `plantas`, `propriedades`, `uts`, `trilha_auditoria`, `users` (+ sistema). **Veredicto: PASS** — aplicam limpas num dir vazio, na ordem esperada.
- ⚠️ `servidorbadger-windows-package\pb_migrations` é um bundle **stale** (só 6 migrations antigas, estilo antigo) — não pode ser usado como `--migrationsDir`.

## 2. Estilos mistos `export async function up` vs `migrate((app)=>{})` — PASSOU

- `grep "export async function up" pb_migrations/*.js` → **0 ocorrências**. Os 30/30 usam `migrate((app) => {...}, (app) => {...})` (uniforme). O estilo antigo existia no commit histórico de `1778800000` e foi reescrito (commit do capitão `32a9d33`).
- `grep "fields.push(" pb_migrations/*.js` → só em **comentários** (1778900000:8, 1779000000:7, 1779100000:4, 1779200000:4) documentando o bug medido do motor; o código usa `new Field({...})` + `collection.fields.add()`/`.addAt()`.
- `removeById` de ids inexistentes (ex.: 1776862935:6,9 removem `relation_ut`/`relation_user` que não existem num DB novo) é inócuo no boot limpo (não lança).

## 3. Regras finais por coleção (lidas do data.db ao vivo — tabela `_collections`)

Semântica medida neste binário 0.36.4 (probes abaixo): **`null` = ninguém (só superuser contorna); `""` (vazia) = público, até anónimo; filtro = corresponde ao filtro.**

| Coleção | Campos (required) | list/view | create | update | delete | Veredicto |
|---|---|---|---|---|---|---|
| **parcelas** | id; `prop_ut` text **req** (1771424171:27-31); `id_parcela` number **req** (:40-43); `observacoes`; `user` text (1771424171:67); `fotos_parcela` file ≤10×10MB (1776864000:12-15); `ut` rel→uts (1776862935:19); `userId` rel→users (1776862935:34); latitude, longitude, geo_json, area_m2, unidade_forma, raio_m, marcador; `status_verificacao` select [pendente,revisado,aprovado] (1778900000:27-33); aprovado_por, aprovado_em; projeto_id, periodo_id, protocolo_versao (1779200000) | `auth` (1776864000:6-7) | `auth` (:8) | `auth && (user = auth.id \|\| isAdmin) && (body.status_verificacao = status_verificacao \|\| isAdmin)` (1778900000:58-60) | `auth && (userId = "" \|\| userId = auth.id \|\| isAdmin)` (1778300000:41-47) | **PARCIAL — deleteRule furada** (ver B-1) |
| **plantas** | id; `parcela` text **req** (1771424190:27-31); `especie` **req** (:41-45); `altura_cm` **req** (:54-57); `dap_cm`; `categoria` **req** (:78-81); `foto_especie` file ≤10MB (1776864000:23-26); `created_at`; `uuid_local`, `updated_at`, `version` (1778500000); `parcela_rel` rel→parcelas + backfill do texto (1778250001:43-70); `autor` (1779000000) | `auth && (parcela_rel.userId = "" \|\| = auth.id \|\| isAdmin)` (1778700000:1372-1380) | `auth` (1776864000:22 — nunca restringido) | igual a list (1778300000:30-36) | igual (1778300000:36) | **PARCIAL — create sem escopo + regra de dono ineficaz** (B-2, H-2) |
| **propriedades** | id; `codigo` text **req** (1776862933:28-32); `nome`; created/updated | `auth` (1776862933:73-78) | `auth` (:5) | `""` (1776864000:41) → **público!** | `""` (1776864000:42) → **público!** | **FALHA — update/delete públicos** (B-3) |
| **uts** | id; `codigo` text **req** (1776862934:28-32); `propriedade` rel→propriedades **req** (:37-47); created/updated | `auth` (1776862934:72-77) | `auth` (:5) | `""` (1776864000:50) → **público!** | `""` (1776864000:51) → **público!** | **FALHA — update/delete públicos** (B-3) |
| **trilha_auditoria** | id; `acao` **req**, `origem` **req** (1778800000:13,19); entidade_tipo, entidade_uuid, antes, depois, usuario_uuid, ts_servidor, ts_dispositivo, prev_hash, `entry_hash`, dispositivo_id, `offset_relogio_ms` (1779100000) | `auth` (1778800000:28-29) | `auth` (:30) | **`null`** (:31) | **`null`** (:32) | **PASS append-only** (contra utilizadores; superuser contorna — M-3) |
| **users** (`_pb_users_auth_`) | sistema + `isAdmin` bool (1778250000:33-42); índice UNIQUE em `email` (sistema) | `auth` (1776859848:8-9) | `""` → **signup público** (aceita `isAdmin` do cliente!) | `id = auth.id \|\| @request.auth.isAdmin = true` (1778300000:56) | `""` (1776859848:7) → **público!** | **FALHA — delete público + auto-promoção** (B-4, H-1) |

## 4. Probes ao vivo (servidor limpo 8091, superuser + users A/B/C/D/E/F)

| Probe | Resultado | Esperado | Veredicto |
|---|---|---|---|
| boot limpo → `/api/health` | 200 | 200 | ✅ |
| `_migrations` | 30/30 aplicadas, 0 erros no log | 30/30 | ✅ |
| signup anónimo `users` com `isAdmin=true` | **200** (criado) | 400/403 | ❌ H-1 |
| B (não dono) PATCH parcela de A | 404 (bloqueado — updateRule usa texto `user`) | 403/404 | ✅ |
| A (dono) PATCH `status_verificacao=aprovado` | 404 (só admin muda status) | 403/404 | ✅ |
| superuser PATCH `status_verificacao` | 200 | 200 | ✅ |
| A re-PATCH com `status_verificacao=pendente` (server=aprovado) | **404** — push do dono falha após aprovar | 200 | ⚠️ M-2 |
| **B DELETE parcela de A** (`userId` vazio) | **204 — apagou** | 403/404 | ❌ **B-1** |
| B cria planta na parcela de A (`createRule=auth`) | **200** | 403 | ❌ H-2 |
| C PATCH/DELETE essa planta (`parcela_rel.userId=""`) | **200 / 204** | 403/404 | ❌ **B-2** |
| E PATCH propriedade de D (`updateRule=""`) | **200** | 403 | ❌ B-3 |
| **anónimo** PATCH/DELETE propriedade (`""`) | **200 / 204** | 403 | ❌ **B-3** |
| anónimo lista propriedades (`auth`) | 200 lista vazia (regra de list filtra, não dá 403) | 200 vazia | ✅ (comportamento PB) |
| anónimo cria trilha/parcela | 400 (bloqueado) | 400/403 | ✅ |
| A cria trilha; A PATCH/DELETE trilha | 200; **403; 403** | 403 | ✅ append-only |
| **superuser PATCH/DELETE trilha** | **200 / 204 — contorna o null** | 403 | ⚠️ M-3 |
| C DELETE user A (`deleteRule users=""`) | **204** | 403 | ❌ **B-4** |
| **anónimo DELETE user** | **204** | 403 | ❌ **B-4** |
| C PATCH próprio `isAdmin=true` | **200**, `isAdmin=True` confirmado | 403 | ❌ **H-1** |
| C lista users (`listRule=auth`) | 200 com todos os emails | 200 | ⚠️ M-4 |

## 5. Índices

- `trilha_auditoria`: `idx_trilha_entidade(entidade_tipo, entidade_uuid)` + `idx_trilha_entry_hash(entry_hash)` (1778800000:24-27) — presentes no DB ao vivo. ✅ (o índice de hash é o que torna o push idempotente por `entry_hash` — sync_service.dart `pushTrilhaAuditoria`).
- `users`: UNIQUE em `email` (sistema, `idx_email__pb_users_auth_`). ✅
- **`parcelas`, `plantas`, `propriedades`, `uts`: `indexes: []`** — sem UNIQUE nem índice de pesquisa. Filtros do app (`prop_ut`, `id_parcela`, `user`, `codigo`, `parcela`) fazem full scan; e **o servidor não consegue impor idempotência** (ex.: UNIQUE em (user, prop_ut, id_parcela)) — a idempotência de parcelas fica só no cliente (mapa uuid local→id servidor); crash entre create e remap → duplicado. ⚠️ M-1.

## 6. Schema vs contrato do app (sync_service.dart) e do painel

- Push de parcelas envia: `ut, prop_ut, id_parcela, observacoes, user, latitude, longitude, geo_json, area_m2, unidade_forma, raio_m, marcador, status_verificacao, fotos_meta, projeto_id, periodo_id, protocolo_versao` + ficheiros `fotos_parcela` (sync_service.dart:1906-1933). **Todos existem no schema**; required (`prop_ut`, `id_parcela`) sempre enviados; `status_verificacao` normalizado para os 3 valores do select (:1706-1718). ✅
- Push de plantas envia: `parcela, parcela_rel, especie, altura_cm, dap_cm, categoria, created_at, uuid_local, updated_at, autor` + `foto_especie` (:2020-2035) — todos existem; required OK. ✅
- Propriedades `{codigo, nome}`, uts `{codigo, propriedade}` — todos existem e required cumpridos. ✅
- Rels sem dangling: `parcelas.ut→uts`, `parcelas.userId→users`, `plantas.parcela_rel→parcelas`, `uts.propriedade→propriedades` — todas resolvem para coleções existentes. ✅
- **Painel admin:** `Parcels.jsx:482` usa `prop.codigo` e `:504` usa `ut.codigo` (+ `ut.expand?.propriedade?.codigo`) — ambos os campos existem e são required (1776862933:28-32, 1776862934:28-32); `EXPAND_RELATIONS = 'ut.propriedade,userId'` (pocketbase.js:55) resolve porque `ut` e `userId` são relations em parcelas (1776862935:19,34). ✅ (nota: `status_parcela` referenciado em pocketbase.js:107 não existe no schema — cai no fallback `?? null`, inócuo.)

## 7. Login / identidade — risco de colisão (item 8 da t12)

- `_reconcileUserUuid` (sync_service.dart:582-600) → `remapUsuarioUuid(oldUuid, pbRecordId)` em cascata (database.dart:908-918: parcelas.userId/createdBy, usuarios.uuid). Colisão: o servidor garante email UNIQUE (`idx_email__pb_users_auth_`), e `_buildUserIdMap` casa por email tomando `pbMatch.first` (:626-635) — com email único no servidor há no máximo 1 match, logo sem colisão real; **mas** `registrarUsuarioNoServidor` devolve o id existente por email **sem verificar senha** (:400-410), logo dois dispositivos com o mesmo email partilham a mesma identidade no servidor (merge de dados sob um uuid).
- `buscarUsuarioNoServidor` (sync_service.dart:460-501): se `authWithPassword` falha, o fallback (:484-496) devolve `records.first` por email **sem senha** — e `login_screen.dart:86-122` consome isso como login válido e chega a **sobrescrever a senha local** com a senha digitada (login_screen.dart:111 `atualizarSenha`) antes de `autenticarUsuario` local (:121). → **quem souber um email entra na app como esse utilizador com qualquer senha** (a sessão local abre; o sync online falha mas a conta local fica sequestrada). ❌ **H-3**.
- Base local: `usuarios.email` é UNIQUE (database.dart:30) e `getUsuarioByEmail`/`autenticarUsuario` usam `getSingleOrNull()` (database.dart:870-886) → lançam exceção se houver duplicados (só possível via restore raw do DB, porque o insert respeita o UNIQUE). ⚠️ L-1.

## 8. Lista de défices (arquivo:linha)

### BLOCKER
- **B-1** — `parcelas.deleteRule` usa a relation `userId` que o app **nunca preenche** (o app escreve o dono no campo texto `user`, sync_service.dart:1913/1924; grep confirma que nenhum body envia `userId`). Regra final `auth && (userId = "" || userId = auth.id || isAdmin)` (1778300000:41-47) → com `userId=""` **qualquer autenticado apaga qualquer parcela** (provado: B DELETE → 204). Fix: usar `user = @request.auth.id` como no updateRule (1778900000:58-60) ou fazer o app enviar `userId`.
- **B-2** — `plantas` update/delete/list/view usam `parcela_rel.userId` (1778300000:30-36, 1778700000:1372-1377); como a parcela do app tem `userId` vazio, o escape `parcela_rel.userId = ""` deixa **qualquer autenticado editar/apagar plantas de terceiros** (provado: C PATCH 200, C DELETE 204). Mesma causa-raiz de B-1.
- **B-3** — `propriedades` e `uts` têm `updateRule`/`deleteRule = ""` (1776864000:41-42, 50-51) e neste binário **regra vazia = público**: anónimo fez PATCH 200 e DELETE 204. Os comentários das migrations assumiam que `""` = só admin. Fix: `null` (ninguém) ou filtro auth+admin.
- **B-4** — `users.deleteRule = ""` (1776859848:7) → **anónimo apaga qualquer conta** (provado: 204). Fix: `null` ou `id = @request.auth.id || @request.auth.isAdmin = true`.

### HIGH
- **H-1** — auto-promoção a admin: signup público aceita `isAdmin` do cliente (createRule `""`, provado 200) e `users.updateRule = 'id = auth.id || isAdmin'` (1778300000:56) deixa cada um por `isAdmin=true` no próprio registo (provado: C PATCH → 200, isAdmin=True). O próprio comentário 1778300000:53-54 admite que a restrição de campo não é exprimível em rule. Fix: remover `isAdmin` do create/update via hook (`onRecordCreateRequest`/`onRecordUpdateRequest`) ou promovê-lo só via superuser.
- **H-2** — `plantas.createRule = auth` (1776864000:22, nunca restringido): qualquer autenticado cria plantas na parcela de outro (provado: B create → 200). Fix: createRule com `parcela_rel.userId = "" || = auth.id || isAdmin`.
- **H-3** — bypass de login: fallback de `buscarUsuarioNoServidor` devolve utilizador por email sem senha (sync_service.dart:484-496) e `login_screen.dart:86-122` trata como sucesso e sobrescreve a senha local (:111). Fix: remover o fallback ou exigir verificação de senha.

### MEDIUM
- **M-1** — sem índices/UNIQUE em `parcelas`/`plantas`/`propriedades`/`uts` (`indexes: []`); idempotência do push de parcelas é só do cliente → duplicados possíveis em crash entre create e remap; queries por `prop_ut`/`user`/`codigo` fazem scan.
- **M-2** — edge do updateRule de parcelas (1778900000:58-60): depois de admin por `status_verificacao=aprovado`, o dono reenvia `pendente` (app normaliza legado) → `@request.body.status_verificacao != status_verificacao` → 404 no push inteiro (provado). Fix: o app não deve reenviar o campo quando inalterado, ou a regra deve comparar só quando o campo vem no body.
- **M-3** — trilha é append-only só contra utilizadores: `updateRule/deleteRule = null` (1778800000:31-32) bloqueou PATCH/DELETE 403, **mas o superuser contorna** (PATCH 200, DELETE 204 provados). A imutabilidade real depende da verificação da cadeia de hash (`verificarCadeiaServidor`), que o app já faz.
- **M-4** — `users.listRule/viewRule = auth` (1776859848:8-9): qualquer autenticado lista todos os emails/nomes/isAdmin (provado 200). O app precisa disto para `pullUsuariosDoServidor`, mas é fuga de dados entre utilizadores.

### LOW
- **L-1** — `getSingleOrNull` em `usuarios.email` (database.dart:870-886) lança exceção se houver email duplicado no DB local (só via restore raw; o insert respeita UNIQUE database.dart:30).
- **L-2** — bundle `servidorbadger-windows-package\pb_migrations` stale (6 migrations antigas); risco de alguém usar como `--migrationsDir` e regredir o schema.
- **L-3** — `pocketbase.js:107` referencia `status_parcela` inexistente no schema (fallback `?? null`, inócuo).
- **L-4** — `removeById` de ids inexistentes em DB novo (1776862935:6,9) é inócuo mas confuso; documentar.

## 9. O que PASSOU (para o registo)

1. Boot limpo num dir novo: 30/30 migrations aplicadas por ordem, `/api/health` 200, zero erros no log (evidence: `D:\urutau-devtools\pb-audit-t12\data.db`, `D:\urutau-devtools\logs\pb-audit-t12.log`).
2. Estilo uniforme `migrate((app)=>{})` nos 30 ficheiros; `fields.push` só em comentários; `new Field()` + `fields.add()` no código.
3. `trilha_auditoria` append-only contra utilizadores (update/delete `null` → 403 provado) + índices `idx_trilha_entidade`, `idx_trilha_entry_hash` presentes.
4. `parcelas.updateRule` final usa o campo texto `user` (1778900000:58-60): dono edita a sua (B/C → 404), só admin muda `status_verificacao` (A → 404, superuser → 200) — conforme spec RG-01/RG-02.
5. Schema cobre 100% dos campos que o app envia (parcelas/plantas/propriedades/uts/trilha) e os required são sempre enviados; selects batem certo; relations sem dangling; painel admin (`Parcels.jsx:482,504`) usa `codigo` que existe e é required.
6. Email UNIQUE no servidor (`users`).

## 10. Recomendações (sem código alterado — para a ronda de implementação)

1. Unificar dono em UM campo: ou o app passa a enviar `userId` (relation) nas parcelas, ou `deleteRule` de parcelas e as regras de plantas passam a usar `user` (texto) / `parcela` (texto). Hoje updateRule usa `user` mas deleteRule e plantas usam `userId`/`parcela_rel.userId` — inconsistente (B-1, B-2).
2. Trocar `""` por `null` (ou filtro admin) em `propriedades`/`uts` update/delete e `users` delete (B-3, B-4) — regra vazia é pública no 0.36.4.
3. Proteger `isAdmin` com hook de create/update (H-1) e remover o fallback sem senha do login (H-3).
4. `plantas.createRule` com escopo de dono (H-2).
5. Índices/UNIQUE em parcelas (ex.: UNIQUE(user, prop_ut, id_parcela)) para idempotência server-side (M-1); índice em `parcelas.user`, `plantas.parcela_rel`.
6. App não reenviar `status_verificacao` quando inalterado (M-2).
7. Congelar/remover o bundle stale `servidorbadger-windows-package/pb_migrations` (L-2).
