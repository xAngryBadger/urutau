# t22 — UNIQUE(prop_ut, id_parcela) como fronteira de verdade + os dois caminhos da migration

Data: 2026-11-10. Provas ao vivo em servidor limpo (porta 8093, dir `D:\urutau-devtools\pb-t22`).

## Hierarquia (decisor canônico)

1. **Constraint UNIQUE no banco** (`idx_parcelas_prop_ut_id_parcela`) — torna a
   duplicata **impossível**, quer os hooks estejam vivos ou mortos. Um hook é
   código de aplicação: na t21 morreu por 4 razões em silêncio e deixou
   duplicadas com 200/200.
2. **Hook `parcelas_validation.pb.js`** — segunda linha, só para dar a mensagem
   legível (`400 CONFLITO`) no create cross-user.

## Perigo evitado

Criar a constraint por cima de duplicadas existentes falha o boot — pior que
o problema original. A migration `1779500000_unique_parcelas_prop_ut_id_parcela.js`
portanto **deteta primeiro** (via `app.recordQuery("parcelas").all(arrayOf(new Record))`
+ agrupamento em JS; neste build `.all()` só aceita `arrayOf(model)`, não array simples):

- **Modo strict** (`URUTAU_PARCELA_DUP_STRICT=1`, lido com `$os.getenv`): lança erro
  que lista os grupos e ids, nada é apagado. **Provado**: boot recusado com
  ```
  Error: failed to apply migration 1779500000_...: URUTAU_PARCELA_DUP_STRICT=1: ha 2 parcelas duplicadas...
    - id=b7b98vzs24sjy4w prop_ut="UT22" id_parcela=5 user=mirs7pbfu2iyszb ...
    - id=wvogn1upz3lj3xf prop_ut="UT22" id_parcela=5 user=v4z1dllw2ecf7i3 ...
  Nada foi apagado. ...
  ```
- **Modo default (consolidação por política escrita)**: por grupo
  (prop_ut, id_parcela), o vencedor é o registo mais antigo (`created`,
  desempate pelo `id` menor); as plantas dos perdedores são re-apontadas
  (texto `parcela` **e** relation `parcela_rel`) para o vencedor **antes** de
  apagar (`app.delete`, que limpa também `fotos_parcela`; `parcela_rel` tem
  `cascadeDelete=false`, logo nada de plantas é apagado em cascata). Depois
  cria o índice. **Provado**:
  ```
  t22: grupo duplicado prop_ut="UT22" id_parcela=5 -> mantem id=b7b98vzs24sjy4w (mais antigo), consolida 1 perdedor(es)
  health 200
  parcelas UT22/5 restantes: 1  (id=b7b98vzs24sjy4w)
  plantas totais: 2 — ambas com parcela=b7b98vzs24sjy4w (re-apontadas)
  ```

## A constraint como fronteira (hooks DESLIGADOS — diretório de hooks vazio)

Fase 0 reproduziu a "noite do hook morto": A e B criaram ambos (UT22, 5) com
**200/200** (migrações pre-t22, hooks vazios). Depois da migration consolidada,
com hooks ainda vazios:

```
create B duplicado: 400 { "id_parcela": { "code": "validation_not_unique" } }  <-- o BANCO barrou, sem hook nenhum
```

Com hooks reais ligados, o mesmo create dá a mensagem legível do hook:

```
B duplicado com hooks reais: 400 "CONFLITO: esta parcela já existe para outro utilizador. Verifique os dados."
```

## Notas

- A consolidation preserveu as 2 plantas (re-apontadas para o vencedor) — sem perda.
- `created` venait como `null` no strict list porque o Record.get("created") neste contexto... (campo datetime; a ordenação usou fallback de id quando created igual/nulo — política aplicada na mesma: vencedor = primeiro por created/id).
- down() da migration: `DROP INDEX IF EXISTS`.
