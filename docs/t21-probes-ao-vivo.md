# t21 — Provas ao vivo: hooks PocketBase 0.36.4 vivos e furos B-1/H-2 fechados

Data: 2026-11-10. Servidor de prova limpo: `pocketbase.exe serve --http=127.0.0.1:8093
--dir=D:\urutau-devtools\pb-t21 --migrationsDir=...\pb_migrations
--hooksDir=...\pb_hooks` (37 migrations aplicadas no boot, health 200, log de boot
sem erros). Script: `D:\urutau-devtools\probe-t21.ps1`, saída integral em
`D:\urutau-devtools\probe-t21-out.txt`.

## Causa raiz (por que os hooks estavam mortos — 4 camadas)

1. **Extensão**: no PB ≥ 0.23 só carregam ficheiros `*.pb.js` em `pb_hooks`.
   Prova: hook `.pb.js` com erro de sintaxe → `serve` loga
   `failed to execute parcelas_validation.pb.js: SyntaxError...`. Os ficheiros
   eram `.js` → nunca carregavam, em silêncio.
2. **Nomes de evento**: `onRecordBeforeCreateRequestEvent` /
   `onRecordBeforeUpdateRequestEvent` não existem no binário 0.36.4
   (só `onRecordCreateRequest` / `onRecordUpdateRequest` / etc.).
3. **Arranque sem `--hooksDir`**: provado que o default não apanha
   `servidorbadger/pb_hooks` (boot sem flag → hook de bloqueio total não
   disparou; com `--hooksDir=<abs>` → dispara). `iniciar_servidor.ps1`,
   `serveron.ps1` e `start.sh` não passavam a flag → produção nunca carregou
   hooks. Corrigido nos três scripts.
4. **Sem `e.next()`**: handler de request que faz `return` sem `e.next()`
   pára a chain — resposta 200 com `Content-Length: 0` e o record NÃO é
   criado. E neste build, handler não pode chamar funções declaradas ao
   nível do ficheiro (lança erro silencioso → 400 genérico). Tudo inline +
   `return e.next()`.
5. **`$app.dao()` não existe** neste build — é `$app.findRecordsByFilter(...)`
   / `$app.findRecordById(...)` direto (types.d.ts, `BaseApp`).
6. **`e.error = ...` morto**: rejeição é `throw new BadRequestError(...)`.

## Resultados (saída real do probe)

```
=== TESTE 1 (ACEITACAO t21): A e B criam a MESMA (prop_ut, id_parcela) ===
A cria UT21/21: code=200 id=unp7c8glkwyxdow
B cria UT21/21: code=400 "CONFLITO: esta parcela já existe para outro utilizador. Verifique os dados."
RESULTADO: PASS — segundo utilizador rejeitado (hook VIVO)

=== TESTE 2 (injecao no filtro do hook): prop_ut com aspa ===
A cria prop_ut="UT"X/22: code=200
B cria o MESMO prop_ut malicioso/22: code=400 CONFLITO   (escape seguro)
B cria prop_ut malicioso/99 (id diferente): code=200     (sem falso positivo)

=== TESTE 3 (B-1): create de parcela com dono falso ===
A cria parcela com user=B: code=400 "Failed to create record."  (createRule 1779400000)
B cria parcela com user=B (legitimo): code=200

=== TESTE 4 (H-2): plantas ===
A cria planta so com texto parcela (dono): code=200 parcela_rel=unp7c8glkwyxdow (derivada pelo hook)
B cria planta na parcela de A (so texto): code=400 "Sem permissão para criar/alterar plantas nesta parcela."
B cria planta com parcela_rel de A: code=400 (regra)
B faz PATCH na planta de A: code=404

=== TESTE 5 (users hook) ===
admin A PATCH name de B: code=400 "Administradores só podem alterar o campo isAdmin de outros utilizadores. Campos rejeitados: name."
admin A PATCH isAdmin de B: code=200
nao-admin C PATCH B: code=404
```

## Critério de aceitação do capitão

> DOIS utilizadores a criar a mesma (prop_ut, id_parcela) têm de ter um rejeitado.

**PASS**: A → 200, B → 400 CONFLITO (hook vivo, detetável por comportamento).
Planta sem `parcela_rel` → ou deriva do texto `parcela` (200 com derivation,
dono correto) ou 400 se a parcela não pertencer ao utilizador. O rename
sozinho era cosmética; agora há prova observável.

## Ficheiros alterados

- `servidorbadger/pb_hooks/parcelas_validation.pb.js` (era `.js`): hooks
  `onRecordCreateRequest` (conflito parcelas, filtro escapado como
  `escapePbFilter` do app) + create/update de plantas (deriva `parcela_rel`,
  exige dono/admin). Tudo inline, `return e.next()`, `throw BadRequestError`,
  `$app.findRecordsByFilter` direto.
- `servidorbadger/pb_hooks/users_validation.pb.js` (era `.js`):
  `onRecordUpdateRequest` — self-update livre, admin só `isAdmin` em outros,
  superuser bypassa.
- `servidorbadger/pb_migrations/1779400000_seguranca_b1_parcelas_create_ata_dono.js`:
  `parcelas.createRule = '@request.auth.id != "" && @request.body.user = @request.auth.id'` (fecha B-1).
- `servidorbadger/iniciar_servidor.ps1`, `serveron.ps1`, `start.sh`:
  `serve --hooksDir=<dir>/pb_hooks` explícito (sem ele os hooks não carregam).

## Residual conhecido (documentado, não bloqueante)

- listRule/viewRule de plantas mantêm o escape `parcela_rel.user = ""` para
  órfãs pré-existentes (backfill 1778250001 já as ligou); o hook de
  create/update fecha o furo para dados novos e re-deriva a relation no
  primeiro toque. Alterar a regra de listagem arriscava esconder órfãs do
  próprio dono — decidido manter.
