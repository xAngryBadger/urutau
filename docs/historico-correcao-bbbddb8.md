# Correção de registo — commit `bbbddb8`

Data: 2026-11-10. Achado **P1** de [revisao-processo-noite.md](revisao-processo-noite.md) (secção 1, linha 35), confirmado pelo capitão.

## O que aconteceu

O commit `bbbddb8` ("feat(app): perfil convidado offline + corrige contrato de sync com PocketBase") tem no **corpo da mensagem** a descrição de 7 correções do contrato de sync em `lib/services/sync_service.dart` ("Corrigido" 7 vezes), mas o **diff não toca `sync_service.dart`** — contém apenas `lib/main.dart`, 1 teste e 27 PNGs de evidência do convidado offline:

```
$ git show --stat bbbddb8        # sync_service.dart ausente do diff
$ git show --stat 32a9d33        # aqui estão os fixes reais:
                                  #   urutau-app/lib/services/sync_service.dart | 128 +++...
                                  #   servidorbadger/pb_migrations/1778800000_add_trilha_auditoria.js
```

As 7 correções reais aterraram no commit **seguinte**, `32a9d33` ("fix(servidorbadger+app): campos do sync alinhados ao schema real do PocketBase"). A mensagem de `bbbddb8` foi escrita como se já os contivesse.

## Consequência

Quem lê o histórico e confia nas mensagens concluye que `bbbddb8` contém as correções de sync — e não contém. A mensagem descreve um diff que não existe nesse commit. Nenhum defeito fica escondido (o fix existe no histórico em `32a9d33`), mas o registo mente sobre o próprio diff.

## Correção (por adição, não por reescrita)

O histórico **não é reescrito**: nada de `--amend`, nada de rebase, nada de force push em `bbbddb8` (já empurrado). Este ficheiro é o registo correcto: `bbbddb8` = apenas o convidado offline (main.dart + teste + PNGs); os 7 fixes do contrato de sync estão em `32a9d33`.

Regra вперёд (já seguida a noite toda): mensagem de commit = o que o diff muda; se um fix planeado não entrou num commit, o commit diz isso.
