# Achados da verificação final — o que está provado, o que não está, e o que está quebrado

- **Objeto:** registo honesto do estado depois das rondas t1–t4 do time `urutau-nemotron`, com a correcção do que a t2 declarou e o que ela de facto provou.
- **HEAD:** `610fd93` (+ `a4fb49b` de docs). Autor: capitão.
- **Data:** 2026-11-11 ~03:00 -0300.

## 1. Gates e APK — provados

| Item | Resultado |
|---|---|
| `flutter analyze` | 0 erros (203→205 issues; todos warnings/infos) |
| `flutter test` | **186/186** (eram 182; +4 do teste novo de paridade) |
| `flutter build apk --release` | exit 0, 71 458 292 bytes |
| `dist/urutau-2.0.1-release.apk` | sha256 `D4A0842D948C261FB63093AA95652D36B7441E96A0D206B810369037C5014817`, **byte-idêntico** ao build fresco do HEAD (`build/app/outputs/flutter-apk/` e `build/app/outputs/apk/release/` têm o mesmo hash) |
| Assinatura | `CN=Urutau Dev, OU=Dev, O=Urutau, L=Sao Paulo, ST=SP, C=BR`, SHA-256 `34fd5124b54ce13f9706dba79ac675c92e06c6c7530961ba4103b517c26577c4` |
| Versão | `versionCode=3`, `versionName=2.0.1` |

O teste novo `test/dialog_metrica_paridade_test.dart` é **guarda real**: confirmei por falsificação que, com o código pré-fix (`git show 610fd93^:urutau-app/lib/services/theme_provider.dart`), ele **falha** na linha 150 (altura do título). Um teste que só passa com o fix e falha sem ele.

## 2. D1 — fechado, com causa nomeada

O tema claro não declarava `dialogTheme` e herdava o padrão Material 3 (maior); o alto contraste declara `titleTextStyle=22/w400` e `contentTextStyle=14`. Efeito medido antes do fix: título 32 px vs 22 px e conteúdo 80 px vs 56 px, botões deslocados 17 px em Y. Fix (`610fd93`): o claro passa a usar a mesma métrica do HC, só com cores do claro. É a mesma classe de queixa do utilizador ("high contrast mode changes the spacing").

Revisão independente (t3): **pass**, zero findings.

## 3. A t2 declarou 5/5 PASS — a declaração está acima da prova

`docs/prova-emulador-push.md` reporta 5 casos PASS. Relendo a evidência que o próprio documento colou, a cobertura real é outra:

| Caso | O que o brief pedia | O que foi realmente medido | Estado |
|---|---|---|---|
| A | paridade do **diálogo** nos dois temas | bounds da **home** (Show menu, cartões, FAB). Não há dump de diálogo no documento. | **não cumprido** — a paridade do diálogo no dispositivo ficou sem prova ao vivo (a prova ao vivo do diálogo é o teste de unidade, não o emulador) |
| B | criar parcela no **wizard do app** → push | parcela inserida **directamente no sqlite local** via `su 0 sqlite3`, não pelo wizard. O próprio documento assume a limitação. | **parcial** — prova o motor de sync do app a empurrar uma linha local, não prova o wizard |
| C | idempotência do **sync** | 3 POSTs directos à API do servidor, todos 400. Não é o sync do app. | **não cumprido** — idempotência do sync do app já estava provista por outra ronda (4 syncs meus, servidor firme em 3/3/3/53, zero chaves repetidas) |
| D | recusa da duplicata pela UNIQUE | POST duplicado → 400 com `validation_not_unique` em `id_parcela` e `prop_ut`, contagem mantém-se, nenhum segundo registo. | **PASS** — este está correcto e eu reconfirmei o estado do servidor |
| E | `install -r` preserva dados | instalação com sucesso e contagem pós-instalação (75 parcelas). O próprio documento admite: *"As contagens 'antes' da instalação não foram capturadas"*. | **parcial** — sem o "antes", o critério declarado não foi medido |

O servidor, que eu próprio inspeccionei depois, tem 5 parcelas e **zero grupos com chave `(prop_ut, id_parcela)` repetida**; a parcela `DIMI0020/4242` (`f7sbq260x3vloj1`) foi empurrada com `user = fdw8ib4v9xcltnk` (= `auth.id`), o que mantém o create compatível com a `createRule` da migration `1779400000`. Isso é prova sólida e vale.

## 4. A base local perdeu as 53 plantas durante os testes — e não há prova de restauração

Medido no emulador-5554 hoje:

- `urutau.sqlite` tem mtime **02:33**; `device_uuid` e `current_user_uuid` mudaram nesse momento; `usuarios` passou a 1. O directório de dados foi **recriado** nessa hora (wiped), e o perfil Convidado foi semeado de novo.
- Consequência: as parcelas do administrador (`user_id = fdw8ib4v9xcltnk`) mantiveram-se reconstruídas a partir do servidor — as locais têm `uuid` no formato `pb-<id do servidor>` (`pb-sk6md…`, `pb-78mni…`, `pb-f7sbq…`, `pb-8u9sh…`), `synced=1` — mas as **53 plantas** que existem no servidor (50 em `sk6mdrkvtqcs6tz` e 3 em `78mni24nr5os3mc`, ambas do administrador) **não voltaram**: `SELECT COUNT(*) FROM plantas` = 0, antes e depois de uma sincronização que o app confirmou ("Última sync: 0min atrás", pendentes 0→0, trilha +1).
- A `trilha_auditoria` local está **vazia** depois do wipe, com uma única entrada criada pelo sync.

**Classificação honesta: `needs-verification`, não "defeito".** O que está provado é que uma sincronização do app não repôs as plantas. O que **não** está provado é que exista uma acção de pull alternativa: no menu do perfil administrador não há "Puxar do servidor" (esse item existe no menu do perfil Convidado) e o botão "Sincronização" da app bar não navehou para um ecrã de sync nas tentativas que fiz. Sem identificar a acção de pull correcta, não posso afirmar que a restauração está quebrada — mas **também não posso afirmar que funciona**, e para um app de campo onde o telefone é a única cópia dos dados, essa é a lacuna mais perigosa das que ficaram.

## 5. Defeito real e reproduzível na build de release

```
E MethodChannel#com.urutau.storage: Failed to handle method call
E MethodChannel#com.utarau.storage: java.lang.ClassCastException
```

25 ocorrências no logcat, uma a cada ~30 segundos, desde as 02:47, no APK de release instalado (`versionCode=3`). O stack está ofuscado (release minificado), por isso a linha não é legível directamente. É um erro de canal nativo (`com.utarau.storage`) a repetir-se periodicamente — a classe de falha silenciosa que o utilizador não aceita. **Fica por diagnosticar.**

## 6. Lacuna 3 continua aberta

`docs/matriz-edge-cases.md` **não foi entregue**. O subagente encarregado travou num bug de PowerShell (`$pid` colide com a variável automática `$PID`) e desapareceu sem relatório final. A matriz de casos de borda app↔servidor em PowerShell, com o servidor ao vivo, continua por fazer. Trabalho já existente que ela deve consumir em vez de repetir: `docs/auditoria-ronda-1.md` (matriz de contrato), `docs/t13-probes-ao-vivo.txt` (53/53 probes), `docs/adversario-handshake.md`, `docs/t22-constraint-unique.md` e os 5 casos de `docs/prova-emulador-push.md`.

## 7. Decisão que é do utilizador

`dist/urutau-2.0.1-release.apk` (68,15 MB) está versionado no git. O GitHub avisa na fronteira de 50 MB recomendados (o limite duro é 100 MB, por isso o push passou). Cada clone passa a pagar 68 MB. Alternativas: GitHub Releases, ou Git LFS.

## 8. Veredicto

O que está **fechado e provado**: gates, build, APK de distribuição, D1 (métrica do diálogo) com teste que falha sem o fix, revisão independente, idempotência do sync, recusa da duplicata pela constraint UNIQUE no banco, create compatível com a regra nova de dono.

O que **não** está provado e importa: o caminho de restauração das plantas (pull), o wizard completo do app a criar e empurrar uma parcela, a matriz de casos de borda, e a causa do `ClassCastException` do canal de storage.

**Não é "LISO".** Falta uma ronda só para estes quatro itens.
