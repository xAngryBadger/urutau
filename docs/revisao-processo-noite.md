# Revisão de processo — a noite (t16, revisor)

Escopo: `git log bf9c84b..origin/main` (HEAD `457e622`), só leitura, mais este doc.
Data: 2026-11-10. Revisor: membro `revisor`, attempt `61b0d9c7-ef26-45cc-a55c-cab8529c5fde`.

> Nota de contagem: o brief dizia "31 commits"; o range `bf9c84b..origin/main` tem
> **44 commits** hoje (as rondas 2 e a bateria adversária entraram depois de o
> brief ser escrito). Julguei os 44.

## Veredicto

**PASS** — com findings de higiene de registo (P1-P5 abaixo). Nenhum achado esconde
um defeito de código: todas as alegações substantivas têm prova num commit posterior
e nenhuma asserção falsa sobrevive em `test/`.

## 1. Atomicidade real

Todos os 44 commits têm mensagem em PT-BR com corpo e linha `Gates:` (verificado
per-commit com script). A grande maioria é um assunto por commit (ex.: cada tela da
B5 é um commit próprio: `176050b` home, `b33bc0e` explorer, `a33c4a6` admin,
`0da85e9` login, `e456c7e` settings, `f17a585` telas base, `a0a5b66` widgets,
`6b1ec77`/`4cf34db`/`a4f0779` forms/sync, `f73c151` image_service; cada blocker de
servidor é um commit: `016f41f` H-1, `a0bfe7b` B-3, `0e92d67` B-4, `3bfd5ec` B-1,
`d3cf5c8` B-2, `5803485` H-2, `18ea3c8` H-3).

Três exceções (findings):

- **P2 (low) — `30fee41` junta 3 assuntos não relacionados num commit**:
  spacing dos temas (`theme_provider.dart`, 154 linhas), remap com FK
  (`database.dart`), cor do banner (`home_screen.dart`) + 2 testes + PNGs de
  evidência. Cada um merecia commit próprio (e tinha teste próprio).
- **P3 (low) — `d2196aa` junta banner + versionCode + teste novo + docs**
  (confirma o F1 da t4). Além disso o assunto diz "+ APK de dist", mas `dist/` é
  gitignored — o APK não está no commit; o texto pode induzir a achar que está.
- **P1 (medium) — `bbbddb8` promete no corpo 7 correções de contrato em
  `lib/services/sync_service.dart` ("Corrigido" 7 vezes), mas o diff do commit
  **não toca `sync_service.dart`** (só `lib/main.dart`, 1 teste e 27 PNGs).
  As correções reais aterraram depois em `32a9d33`. Ou seja: a mensagem descreve
  um diff que não existe nesse commit. Não esconde defeito (o fix existe no
  histórico), mas é um registo que mente sobre o próprio diff.
  requiredFix: nas próximas rondas, mensagem = o que o diff muda; se um fix
  planeado não entrou, o commit diz isso. (Histórico não reescrito; esta nota
  no doc é o registo da discrepância.)

## 2. Nada fora do git

`git status --porcelain` no HEAD `457e622` **não está vazio**:

```
?? urutau-app/test/backup_roundtrip_test.dart
```

É trabalho em curso (t15/t17 `in_progress` no team state — o ficheiro cobre o
"buraco 3 da bateria adversária" e referencia `docs/adversario-handshake.md`, que
também não está no repo). Como a ronda ainda não fechou, não é violação da regra
"árvore limpa no fim da ronda", mas é **P4 (low)**: o fecho de ronda tem de
verificar `git status` vazio e commitar ou remover este ficheiro (e o doc que ele
cita). requiredFix: integração (t18/t19) confirma `git status --porcelain` vazio
antes de dar a ronda por fechada.

## 3. Causa vs sintoma (mensagem vs diff)

Pontos fortes: `2075bb3` mede a causa raiz no PB 0.36.4 (erro Go de conversão no
`push` nativo) e converte 4 migrations para `new Field` + `fields.add`;
`30fee41` explica por que `foreign_keys = OFF` é no-op dentro de transação e usa
`defer_foreign_keys`, com teste de regressão reproduzido antes do fix;
`7c97663` remove o `catch` engolido que permitia duplicação silenciosa no
servidor (remap dentro da mesma transação — verificado no código atual,
`sync_service.dart:2151-2175`); `32a9d33` alinhado ao schema vivo medido por API.

P1 acima é o único caso em que a mensagem promete mais do que o diff entrega.
Não encontrei, no range, filtro com campo inexistente ou campo obrigatório
ausente nos caminhos novos (a classe foi fechada em `32a9d33` e a guarda de
injeção em `2ee0315`/`457e622` — `escapePbFilter` público em
`sync_service.dart:51`, usado em `:411`).

## 4. Falsos positivos e a sua gestão

Os três foram retractados **no repo, com evidência**, e não sobrou asserção
falsa (grep em `test/` por FAB/"diferente entre temas"/200-plantas: só o guarda
de injeção, que afirma o comportamento correcto):

- **FAB diferente entre temas**: retractado no corpo de `d2196aa` + B4 em
  `docs/auditoria-ronda-1.md`, com prova de código (`home_screen.dart:304`
  `FloatingActionButton.extended` vs `explorer_screen.dart:1703` botão
  full-width — ecrãs diferentes, não temas diferentes). Re-verificado por mim.
- **Lista de plantas "falhada" por devolver 200**: retractado na NOTA DE
  PROCESSO do corpo de `bb17dac` — o PocketBase devolve 200 com o subconjunto
  visível (`totalItems` 0 para o atacante); a probe media o status, não o
  conteúdo. Regra registada: probe de segurança mede conteúdo, nunca só status.
  Transcript `docs/t13-probes-ao-vivo.txt` está trackado.
- **Injecção de filtro no prop_ut**: `457e622` documenta que a premissa era
  errada (provada ao vivo contra o PB), apaga a asserção que exigia
  vulnerabilidade (o teste antigo nunca foi commitado — o histórico do ficheiro
  começa em `457e622`) e instala uma GUARDA DE REGRESSÃO que usa o
  `escapePbFilter` real e fixa o comportamento correcto (round-trip
  dest-escape == valor original; 0 operadores fora das strings). Verifiquei o
  conteúdo atual: só afirma o comportamento correcto.

P7 (info): `filtro_injecao_test.dart` e o untracked `backup_roundtrip_test.dart`
citam `docs/adversario-handshake.md`, que não existe no repo — commitá-lo junto
quando o t15/t17 fechar.

## 5. O blocker que o capitão introduziu (f73c151 → 128e1ab)

- `f73c151` introduziu `Icon(IconData(0xe09a, ...), color: cs.onSurfaceVariant)`
  não-const (o `color:` tirou o `const` do `Icon`); o tree-shake de ícones exige
  constantes e o `flutter build apk --release` passou a falhar com
  "non-constant invocations de IconData" — `analyze` e `test` continuavam verdes,
  logo só o gate de build apanhava.
- Apanhado pela verificação independente: `a5bb506` (t8 failed, 5/6 PASS + 1
  BLOCKER, com o commit f73c151 apontado e o dist detetado como stale).
- Fechado em `128e1ab` com causa raiz clara no corpo (`const Icon(Icons.broken_image)`
  + import que escondia `Icons`) e re-verificado em `fd3200c` (t14): `flutter clean`
  + build exit 0, dist == HEAD (libapp.so igual), 6/6 PASS.
- **P5 (low)**: a guarda continua procedural, não automatizada — nenhum teste
  apanha IconData não-const; depende de a tarefa de verificação correr
  `flutter clean && flutter build apk --release`. Os dois commits do topo
  (`2ee0315`, `457e622`) têm `Gates:` só com analyze+test (um deles toca
  `sync_service.dart`), ou seja, o build não correu outra vez depois do t14.
  requiredFix: o contrato de toda tarefa de verificação inclui
  `flutter clean + build apk --release + dist==HEAD`; de preferência num script
  repetível, para não depender de alguém se lembrar.

## 6. Rondas: t8 e t11 falhadas, honestamente

team state (`team.json`) + git:

- **t8 failed** — output diz o quê e porquê: build release quebrado no HEAD
  (IconData não-const, f73c151) + dist stale; relatório commitado (`a5bb506`),
  fix commitado (`128e1ab`), re-verificação commitada (`fd3200c`, 6/6 PASS).
  Nada varrido para debaixo do tapete.
- **t11 failed** — output: "FALHOU — e a falha é de ambiente, não de análise"; o
  commit `1c856de` explica que o Dart VM do `flutter test` não sai do sandbox
  para 127.0.0.1:8090 e que o ficheiro de teste foi **apagado de propósito**
  ("um teste que só salta é pior que nenhum"), com o método registado para
  correr fora do sandbox. Honesto.

t1-t7, t12-t14 `completed` com outputs substantivos; t9/t10/t18/t19 `pending`;
t15/t17 `in_progress` (a explicar o untracked de P4).

## 7. Gates re-corridos por este revisor no HEAD 457e622

- `flutter analyze` (re-corrido nesta revisão): **0 erros**, 54 warnings, 204
  issues no total, exit 1 só pelos warnings/infos.
- `flutter test` (re-corrido nesta revisão): **172/172 "All tests passed!",
  exit 0** — 166 dos testes commitados + 6 do untracked
  `backup_roundtrip_test.dart`, que corre e passa **fora do git** (prova viva
  de P4: o ficheiro está na suite mas não está versionado).
- `git status --porcelain`: 1 untracked (P4).
- `HEAD == origin/main == 457e622`.

## Findings

| id | severidade | problema | requiredFix |
|----|-----------|----------|-------------|
| P1 | medium | `bbbddb8` promete 7 fixes em `sync_service.dart` no corpo, mas o diff não toca esse ficheiro (fixes reais em `32a9d33`) | mensagem de commit = o que o diff muda; se algo planeado não entrou, o commit diz isso |
| P2 | low | `30fee41` junta 3 assuntos (temas + FK + banner) num commit | um assunto por commit |
| P3 | low | `d2196aa` junta banner + versionCode + teste + docs (F1 da t4 confirmado); "+ APK de dist" no assunto mas dist/ é gitignored | separar; não mencionar artefactos não commitados como se estivessem no commit |
| P4 | low | HEAD tem untracked `urutau-app/test/backup_roundtrip_test.dart` (t15/t17 em curso) + doc citado (`docs/adversario-handshake.md`) fora do repo | fecho de ronda verifica `git status --porcelain` vazio e commita/remove |
| P5 | low | guarda de build limpo é só processual; commits do topo sem build nos Gates | contrato de verificação inclui sempre `flutter clean + build apk --release + dist==HEAD`, de preferência em script |
| P7 | info | `docs/adversario-handshake.md` citado por 2 testes mas não trackado | commitar com o t15/t17 |
| P6 | info | range tem 44 commits, não os 31 do brief | — |

Nenhum finding bloqueia: o processo da noite foi honesto nos pontos que contam
(falsos positivos retractados com prova, falhas de t8/t11 registadas com causa,
blocker apanhado e fechado com prova de build limpo).
