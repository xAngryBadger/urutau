# Verificação independente dos fixes de segurança (capitão)

O `implementador` fechou a `t13` com 8 commits atómicos e reportou **53/53 probes PASS**.
Alegações de segurança verificam-se, por isso repeti as probes eu mesmo, num servidor
limpo e à parte: **`127.0.0.1:8093`, dir novo `D:\urutau-devtools\pb-cap`**, arrancado
com as migrations do repo (HEAD `d77e284`). O servidor do time (8090, `pb-sync`)
e o do implementador (8092, `pb-ronda2`) não foram tocados.

Premissas criadas: utilizador dono `dono@urutau.local`, propriedade `CAP-VERIF`,
UT `CAP-UT`, parcela 90 daquele dono, e uma planta lá dentro. Segundo utilizador
legítimo `vitimaB@urutau.local` para testes cross-tenant.

## Resultado, probe a probe

| Blocker | Probe | Esperado | Obtido | Veredicto |
|---|---|---|---|---|
| **B-3** | anónimo `PATCH propriedades/<id>` | 403/404 | **404** | ✅ fechado |
| **B-3** | anónimo `DELETE uts/<id>` | 403/404 | **404** | ✅ fechado |
| **B-3** | não-admin `PATCH propriedades/<id>` | 403/404 | **404** | ✅ fechado |
| **B-4** | anónimo `DELETE users/<id>` | 403/404 | **404** | ✅ fechado |
| **H-1** | signup anónimo com `isAdmin=true` | 400 | **400** | ✅ fechado |
| **B-1** | não-admin `DELETE parcelas/<id>` de outro | 403/404 | **404** | ✅ fechado |
| **B-1** | não-admin `PATCH parcelas/<id>` de outro | 403/404 | **404** | ✅ fechado |
| **B-2** | não-admin lista `plantas` | vazio | **200 com `totalItems: 0`** | ✅ fechado (ver nota) |
| **H-2** | não-admin `POST plantas` na parcela de outro | 400/403 | **400** | ✅ fechado |
| **B-2** | não-admin `PATCH plantas/<id>` de outro | 403/404 | **404** | ✅ fechado |
| **B-2** | não-admin `DELETE plantas/<id>` de outro | 403/404 | **404** | ✅ fechado |
| **Sanidade** | dono lê a **sua** parcela | 200 | **200** | ✅ caminho legítimo intacto |

## Nota sobre a probe B-2 da lista — correcção a um erro meu

Inicialmente marquei a lista de plantas como **falhada** porque obteve HTTP 200.
Estava errado: o PocketBase devolve **200 com o subconjunto que o utilizador pode ver**,
não 403, quando uma `listRule` filtra por dono. Inspeccionando o corpo:
`totalItems: 0` para o atacante e `totalItems: 1` para o superuser — a mesma planta logo
a seguir. A protecção funciona; a minha probe media o status e não o conteúdo.

É a **segunda vez esta noite** que quase reporto um falso positivo por não ler o
corpo da resposta (a primeira foi o "FAB diferente entre temas"). A regra que fica:
probe de segurança mede o **conteúdo**, nunca só o status code.

## H-3 (login bypass) — verificado por leitura e por teste, não por probe de rede

É do lado da app, não do servidor. Confirmado em `sync_service.dart`: o fallback que
devolvia utilizador só por email (linhas 484-499) foi **removido** — `buscarUsuarioNoServidor`
passa a exigir senha e a aceitar apenas `authWithPassword` verificado pelo servidor.
`registrarUsuarioNoServidor` já não envia `isAdmin`. Coberto por `flutter test 150/150`
e pelo código lido.

## Conclusão

**Os 4 blockers e os 3 high estão fechados**, com o caminho legítimo intacto (o dono
lê e escreve o que é seu; o superuser promove a admin). Sem regressão funcional.
Servidor de verificação parado; dir `pb-cap` é descartável.
