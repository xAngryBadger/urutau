# Achado F6 — Criar parcela NOVA com planta rebentava com FOREIGN KEY

**Data:** 2026-11-11
**Severidade:** BLOCKER (impossibilitava registar vegetação em parcela nova)
**Estado:** CORRIGIDO e PROVADO no emulador + teste de regressão

---

## 1. Sintoma observado (comportamento, não leitura de código)

Durante a prova do wizard completo (APK release, `emulator-5554`), ao criar
uma parcela nova na UT01 e adicionar uma planta, o ecrã mostrou:

```
Erro ao salvar: SqliteException(787): while executing statement,
FOREIGN KEY constraint failed, constraint failed (code 787)
  Causing statement: INSERT INTO "plantas" ("uuid", "parcela_uuid", "especie",
  "altura_cm", "dap_cm", "categoria", "foto_especie_path", "synced",
  "updated_at", "autor_uuid") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?),
  parameters: 4138f3ac-83ae-4192-a84b-5743a9f5002f,
              508bcd32-3820-4a41-9ebe-cad42b4ac221,
              Lafoensia pacari A. St.-Hil, 350.0, 4.0, 2, null, 0, 1794431371,
              fdw8ib4v9xcltnk
```

A planta **não** era gravada. O wizard ficava na Etapa 3 com "Plantas (0)".

## 2. Causa-raiz

O wizard atribui o uuid da parcela no `_initAsync`
(`parcela_form_screen.dart:191`, `_currentUuid = _uuid.v4()`), mas a **linha**
na tabela `parcelas` só é gravada no passo final, em `_writeParcela`
(`parcela_form_screen.dart:2530`, `insertParcela`).

A Etapa 3 (Plantas) chama `_addPlanta()`
(`parcela_form_screen.dart:2104`), que abre `PlantaFormScreen(parcelaUuid:
_currentUuid!)`. O formulário da planta grava com `insertPlanta`
(`planta_form_screen.dart:723`), e a tabela `plantas` tem FK
`parcela_uuid -> parcelas.uuid`. Com `PRAGMA foreign_keys = ON`, o SQLite
recusa o insert porque o pai ainda não existe.

**Consequência de negócio:** era IMPOSSÍVEL criar uma parcela nova com
qualquer planta. O registo da vegetação — o dado mais valioso que o app
existe para guardar — só entrava na base de dados EDITANDO uma parcela já
existente. Um técnico de campo a criar a primeira parcela de uma UT não
conseguia registar uma única planta.

## 3. Correcção

### 3.1 `lib/data/database.dart` — `ensureParcelaExists(uuid)`

Cria a linha da parcela como **rascunho** (sem dono, `prontaParaSync = false`)
se ainda não existir. É idempotente.

```dart
Future<void> ensureParcelaExists(String uuid) async {
  final existente = await getParcelaByUuid(uuid, includeDeleted: true);
  if (existente != null) return;
  await into(parcelas).insert(ParcelasCompanion(
    uuid: Value(uuid),
    propriedade: const Value(''),
    propUt: const Value(''),
    idParcela: const Value(0),
    userId: const Value(''),
    synced: const Value(false),
    prontaParaSync: const Value(false),
    updatedAt: Value(DateTime.now()),
  ));
}
```

### 3.2 `lib/screens/parcela_form_screen.dart` — `_addPlanta()`

Chama `ensureParcelaExists` antes de abrir o formulário da planta.

### 3.3 `lib/screens/parcela_form_screen.dart` — `_writeParcela()`

Duas correções:

1. Se a linha já existe (o rascunho), faz **UPDATE** da mesma linha em vez de
   `insertParcela` — o uuid é o mesmo, portanto **não nasce uma parcela
   duplicada**.
2. Se existir uma parcela **DISPONÍVEL** com a mesma propriedade/UT/número
   (regra de negócio do app), as plantas já medidas são **MIGRADAS** para essa
   parcela via `migrarDadosParaParcela` — perdê-las seria perda de dados de
   campo. O rascunho fica soft-deleted.

### 3.4 `lib/data/database.dart` — `migrarDadosParaParcela`

Move plantas e fotos do rascunho para a parcela real, numa transacção, com
registo na trilha de auditoria (`parcela_dados_migrados`).

## 4. Prova — comportamento observável (APK release, `emulator-5554`)

### 4.1 A planta agora grava

Antes do fix (APK anterior), o `dump` do ecrã mostrava o erro de FK.
Depois do fix (APK reconstruído e instalado):

```
Button  [16,204][304,407]  desc='Plantas (1) | 1 plantas · 1 espécies |
        Lafoensia pacari A. St.-Hil | Dedaleiro | 1 | Adicionar planta'
```

### 4.2 Rascunho criado, depois actualizado in-place

Após "Adicionar planta", a BD local do dispositivo tinha:

```
uuid      = bc0eedd0-3c49-4ceb-9f98-ad06eff5d60d
propriedade = ''   prop_ut = ''   id_parcela = 0
user_id  = ''   pronta_para_sync = 0   synced = 0
```

Após "Concluir parcela" (mesmo uuid):

```
uuid      = bc0eedd0-3c49-4ceb-9f98-ad06eff5d60d
propriedade = DIMI0020   prop_ut = UT01   id_parcela = 7777
user_id  = fdw8ib4v9xcltnk   pronta_para_sync = 1   synced = 0
latitude = 37.4219983   longitude = -122.084
area_m2  = 1963.49540849362   unidade_forma = circular   raio_m = 25.0
```

**Actualização in-place.** Totais: 78 parcelas / 54 plantas (+1 cada) — **zero
duplicados**.

Planta ligada:

```
uuid = 3720414c-1fa4-46b6-82a3-b39fdc43dc92
parcela_uuid = bc0eedd0-3c49-4ceb-9f98-ad06eff5d60d
especie = Lafoensia pacari A. St.-Hil   altura_cm = 350.0
dap_cm = 4.0   categoria = 2   synced = 0
```

### 4.3 Push ao servidor — autenticado

`POST /api/collections/parcelas/records` + `POST
/api/collections/plantas/records`. O SQL do servidor mostra:

```
INSERT INTO `parcelas` (..., `id_parcela`, `latitude`, `longitude`, `prop_ut`,
`raio_m`, `status_verificacao`, `unidade_forma`, `user`, `ut`) VALUES
(..., 7777, 37.4219983, -122.084, ..., 'UT01', 25, 'pendente', 'circular',
'fdw8ib4v9xcltnk', '3juq54zjf9sjky8')
```

`geo_json` transportou o fix GPS completo:

```json
{"tipo":"Point","coordenadas":[-122.084,37.4219983],"crs":"WGS84",
 "acuracia_m":5.0,"n_satelites":null,
 "n_satelites_fonte":"indisponivel_geolocator",
 "fix_em":"2026-11-11T21:49:17.201Z","fonte":"geolocator"}
```

Resultado no servidor:

```
parcelas=6  plantas=53 -> 54
8gledj4lszo1wij | prop= | prop_ut=UT01 | id_parcela=7777 | user=fdw8ib4v9xcltnk
x32y78lwwpgo0c1 | uuid_local=3720414c-1fa4-46b6-82a3-b39fdc43dc92
                | parcela=8gledj4lszo1wij | especie=Lafoensia pacari A. St.-Hil
                | altura=350 | dap=4 | cat=2
```

**Autenticação:** 15 linhas SQL autenticadas, **0 anónimas** (regex ancorada
`'fdw8ib4v9xcltnk' IS NOT ''` vs `('' IS NOT '')`).

### 4.4 Pull → 0 órfãos, 0 duplicados

Após "Puxar do servidor" (acessível graças ao fix F2):

```
locais: 78 parcelas | 54 plantas | 54 uuid distintos
duplicados (prop_ut, id_parcela): VAZIO
órfãos (plantas sem parcela): 0
```

O pull remapeou o uuid local da parcela (`bc0eedd0` -> `pb-8gledj4lszo1wij`) e
a cascata `remapParcelaUuid` moveu a planta consigo — `parcela_uuid =
pb-8gledj4lszo1wij`, `synced = 1`.

### 4.5 Idempotência — 2º push faz PATCH, não INSERT

Com `synced = 0` forçado na parcela 7777 e na planta, o 2º push produziu:

```
INFO PATCH /api/collections/parcelas/records/8gledj4lszo1wij
INFO GET   /api/collections/plantas/records?...filter=parcela+="8gledj4lszo1wij"
INFO PATCH /api/collections/plantas/records/x32y78lwwpgo0c1
```

Resultado: **parcelas=6, plantas=54** (inalterado), duplicados
`(prop_ut, id_parcela)`: **VAZIO**, mesma planta `x32y78lwwpgo0c1`.

Autenticação da janela: **32 autenticadas, 0 anónimas**.

## 5. Teste de regressão

`urutau-app/test/wizard_fk_parcela_nova_test.dart` — 4 testes:

1. `ensureParcelaExists` cria a linha e satisfaz a FK de plantas
2. `ensureParcelaExists` é idempotente — não duplica a parcela
3. `migrarDadosParaParcela` move plantas do rascunho para a real
4. `migrarDadosParaParcela` não mexe quando não há dados a migrar

**Falsificação:** com `ensureParcelaExists` neutralizado, **3 dos 4 testes
falham** com o mesmo `SqliteException(787) FOREIGN KEY constraint failed`
observado no emulador. Com o fix, todos passam.

## 6. Gates

```
flutter analyze  -> 0 errors (213 issues preexistentes, warnings/infos)
flutter test     -> 00:14 +190: All tests passed!   (186 anteriores + 4 novos)
flutter build apk --release -> Built app-release.apk (68.2MB)
```

## 7. Nota sobre a prova de GPS

O GPS é obrigatório ao concluir (RC-10: parcela sem geo não é auditável para
MRV). A captura exigiu:

```
adb emu geo fix -46.6333 -23.5505
adb shell pm grant com.urutau.app android.permission.ACCESS_FINE_LOCATION
adb shell pm grant com.urutau.app android.permission.ACCESS_COARSE_LOCATION
```

As permissões vêm `granted=false` numa instalação limpa do APK release — o
emulador tem de as conceder (ou a app tem de as pedir em runtime) antes de a
captura GPS funcionar. **Isto não é um bug do wizard**; é comportamento
correcto da permissão Android. Registo-o aqui para que a prova seja
reproduzível.
