# AUDIT-GAPS-P1P2 — Auditoria read-only dos itens P1/P2 do mapa MRV

**Data:** 2026-10-27 · **Escopo:** `D:\projetos\urutau\urutau-app` (lib/, test/) + spec `docs/mapa-mrv.md`
**Modo:** somente leitura de código + este 1 arquivo de relatório. Nenhum arquivo de código do app foi alterado.
**Método:** mapa-mrv.md lido inteiro; busca por ripgrep (ferramenta de busca do ambiente) em `lib/`; leitura de arquivos nos pontos de evidência; `git log` para confirmar commits. Toda afirmação técnica tem `arquivo:linha`.

**Lista exata de P1/P2 segundo o próprio mapa-mrv.md** (§3.1–§3.7, coluna Prio):
- **P1:** RC-05, RC-06, RC-07, RC-08, RC-09, RC-11, RC-13, RC-14, RS-04, RS-05, RQ-04, RQ-05, RG-03, RG-06, RT-02, RT-04
- **P2:** RS-06, RG-05, RT-03

Contexto: o schema local está em **v28** (`lib/data/database.dart:229`) e TODAS as tabelas MRV (v20–v23) estão criadas e registradas (`database.dart:196-207`, DDL em `:434-481`, SQL em `lib/data/migrations/mrv_migration.dart`). Ou seja: **o modelo de dados MRV existe inteiro; o que falta é o código de aplicação (serviços/telas) que povoa e usa essas tabelas.** Os greps abaixo foram feitos em `lib/services`, `lib/screens`, `lib/data/database.dart`, `lib/main.dart` — zero resultados fora de schema/generated significam "só coluna, sem uso".

---

## 1. Tabela item → status → evidência → o que falta

### P1

| Item | Status | Evidência | O que falta exatamente |
|---|---|---|---|
| **RC-05** tempo confiável (offset relógio) | **AUSENTE** (na prática) | Colunas existem: `mrv_tables.dart:132-134` (`medidoEmServidor`, `relogioDispositivo`, `offsetRelogioMs`), backfill legado grava offset 0 (`mrv_migration.dart:144-145`). Mas grep `offsetRelogio\|relogioDispositivo\|medidoEmServidor\|offset\|relogio\|clock` em `lib/services`, `lib/screens`, `sync_service.dart` = **0 matches** de escrita. A trilha usa só relógio do device: `database.dart:1571-1596` (`tsDispositivo = DateTime.now()`). | Capturar hora do servidor no ingresso, gravar `deviceClockOffsetMs` em todo registro, alertar/rejeitar Δ > limiar. Hoje o único tempo é o relógio ajustável do celular. |
| **RC-06** imutabilidade do ingerido (WORM/versionamento) | **PARCIAL** | Upsert versionado = fim do delete+recreate: `sync_service.dart:1781-1787` (comentário explícito) + commit `53a7284`. Trilha append-only local: `database.dart:1552-1601` (`logTrilha`), verificação `verificarCadeiaAuditoria` `:1605-1641`, teste `test/rg04_trilha_hash_test.dart`. **Mas:** grep `trilha\|prev_hash\|entry_hash` em `sync_service.dart` = **0** (trilha NÃO sobe no sync); grep `worm` fora de schema = **0** (`ativos_brutos.worm` nunca setado, `mrv_tables.dart:328`); `purgarDeletados(diasRetencao: 30)` faz **hard delete de arquivos + linhas**: `database.dart:1485-1514`; `_limparDadosParcela` hard-deleta plantas/fotos: `parcela_form_screen.dart:1801-1802`. | Trilha sincronizada ao servidor; WORM/versions no acervo; remover/condicionar o purge de 30 dias (destruição de evidência). |
| **RC-07** política de retenção aplicada | **PARCIAL** | Coluna `retencao_ate` existe (`mrv_tables.dart:327`) nunca preenchida; recheck sob demanda `verificarIntegridadeAtivos` `database.dart:1353-1386`; índice `idx_ativos_retencao` `mrv_migration.dart:179`. | Política escrita (anos), tiering quente→frio→HD, relatório mensal de integridade. **Risco ativo:** `purgarDeletados` default 30 dias (`database.dart:1485`) apaga arquivos de fotos — contra qualquer política MRV. |
| **RC-08** linhagem de pipeline (`pipelineVersion`/`algorithmVersion`/`inputs`) | **PARCIAL** | Cálculo grava linhagem: `mrv_calc_service.dart:119-134` (`pipelineVersao: 'app-2.0.0+2'`, `algorithmVersao`, `equacaoUuid`, `executadoEm`); equacao versionada em `equacoes_alometricas` (`garantirEquacaoPadrao` `mrv_calc_service.dart:81-105`, fonte Chave et al. 2014). | `insumosHash` (JSON de hashes dos inputs, `mrv_tables.dart:423`) **nunca é preenchido** — `persistirCalculo` não o seta. `ativos_brutos.pipelineVersao/insumos` (`mrv_tables.dart:324-325`) também não preenchidos (`registrarHashDoAtivo` `database.dart:1302-1337` não os recebe). |
| **RC-09** acesso verificador read-only + pacote auto-verificável | **PARCIAL** | Papel semeado: `mrv_migration.dart:261` (`PAPEL-VERIF`, "somente leitura — VVB/auditor externo"). | Exports do app não carregam evidência: grep `sha256\|hash\|manifesto` em `export_service.dart` = **0** (só XLSX `:27`, ZIP de fotos `:259`, PDF `:352`). Falta pacote de exportação com **manifesto de hashes**, papel read-only na UI (hoje só `isAdmin`), download em lote por parcela/UTC. |
| **RC-11** protocolo de medição versionado (SOP) | **PARCIAL** | Tabela + seed: `protocolos_medicao` com `SOP-MRV-V1` e regras confirmadas pelo usuário (DAP 1,30 m, altura sempre, categorias) `mrv_migration.dart:71-83`; coluna `parcelas.protocoloVersao` `database.dart:92`. | O formulário **nunca seta** `protocoloVersao` (grep em `lib/screens` = 0) e o sync não envia protocolo (grep `protocolo` em `sync_service.dart` = 0). Registro de medición fica sem vínculo ao SOP. |
| **RC-13** metadados de instrumento (dispositivo/modelo/versão app/operador) | **PARCIAL** | Operador existe: `autorUuid` em plantas/fotos (v28) `database.dart:125,173`, backfill `:363-370`. Tabela `Dispositivos` existe (`mrv_tables.dart:335-347`) **mas nenhum código a povoa** — grep `deviceId\|device_id\|fingerprint` em `database.dart`/`main.dart` = só o registro da tabela `database.dart:203`. | Registrar dispositivo (modelo, SO, versão do app) e vincular operador→dispositivo. Hoje só `userId`/`autorUuid` em texto. |
| **RC-14** foto atrelada à medição com hash + geo | **PARCIAL** (núcleo feito) | Hash na origem: `image_service.dart:26-37` (`sha256De`), `savePhotoLocally` devolve hash `:125-143`; gravado no catálogo: `parcela_form_screen.dart:1744`, `planta_form_screen.dart:785`, `database.dart:1302-1337`. GPS+dono na foto (v28): `fotos_parcela.latitude/longitude/autorUuid` `database.dart:170-173`, captura no form `:1737-1738` + fix best-effort `:1472-1486`; `fotos_meta` (uuid+sha256+lat/long+autor+timestamp) sobe no sync `sync_service.dart:1490-1506` e é enviado no push `:1688`, reaplicado no pull `:1510-1529`. | `n_satelites` sempre **null** (geolocator não expõe — `parcela_form_screen.dart:392`); `exifPreservado` nunca setado (grep fora de schema = 0); foto vinda da galeria fica sem GPS próprio (herda o da parcela). |
| **RS-04** metas de erro declaradas | **AUSENTE** | `desenhoAmostral.incertezaAlvo` é só coluna (`mrv_tables.dart:98`); grep `incerteza` em `lib/services`+`lib/screens` = **0**. | Definir e gravar metas (ex.: 8–15 cm RMSE altura, 6–12% biomassa, conforme mapa §3.4). |
| **RS-05** estratificação documentada | **AUSENTE** | Colunas só no schema: `desenhoAmostral.estratos` `mrv_tables.dart:97`, `coberturas_amostra.estrato` `:292`, `medicoes_restauracao.estrato` `:284`. Grep `estrato` em services/screens = 0. | Semântica de estrato (UT, idade, material genético, manejo) na hierarquia propriedade→UT→parcela. |
| **RQ-04** cálculo reproduzível com hash do resultado | **PARCIAL** | Resultado JSON + `equacaoUuid` + versões persistidos em `calculos_mrv` (`mrv_calc_service.dart:119-134`); teste `test/mrv_calc_test.dart` (esperado ~581 kg AGB, tCO2e ~1,0 para árvore de 30 cm×20 m em 400 m²). | `insumosHash` e hash do resultado **não gravados** (`persistirCalculo` não seta `insumosHash`, coluna `mrv_tables.dart:423`). |
| **RQ-05** pools declarados (inclusive os não medidos) | **FEITO** | `poolsIncluidos: ['agb_aerea']`, `poolsNaoMedidos: ['raizes','serapilheira','solo','madeira_morta']` gravados em `calculos_mrv` (`mrv_calc_service.dart:128-129`). | — (só pool aéreo medido; os demais declarados como não medidos — correto para o estágio atual). |
| **RG-03** re-amostragem/verificação interna | **AUSENTE** | `verificacoesInternas` criada só no schema (`database.dart:480`, `mrv_tables.dart:495-505`); nenhum insert/select fora de migração/generated. | Fluxo de % de parcelas re-medidas por supervisor com resultado (`conclusao`, `divergencias`). |
| **RG-06** gestão de incidentes com bloqueio de crédito | **PARCIAL** | Incidentes já são gravados: hash divergente `database.dart:1316-1325`, recheck de integridade `database.dart:1374-1383`; provado em `test/s3_hash_test.dart:59-92`. | `bloqueiaUsoParaCredito` nunca setado (default false, `mrv_tables.dart:487-488`); sem fluxo de resolução (`resolucao`, `resolvidoEm`) nem UI de incidentes. |
| **RT-02** revisita da parcela em intervalos definidos | **AUSENTE** | `campanhas` existe só com backfill legado (`mrv_migration.dart:118-124`); grep `campanha` em services/screens = 0. | Criar/agendar campanhas de revisita; vincular medições a elas. |
| **RT-04** baseline e adicionalidade documentados | **AUSENTE** | Colunas `projetos_mrv.baselineRef/adicionalidadeRef` (`mrv_tables.dart:47-48`) nunca preenchidas (grep `baseline\|adicionalidade` em services/screens = 0). | Preencher refs no projeto (entra no PD do padrão de crédito). |

### P2

| Item | Status | Evidência | O que falta |
|---|---|---|---|
| **RS-06** amostragem híbrida campo+drone | **AUSENTE** | `parcelas.substitutaDe` só coluna (`database.dart:93`); grep `drone\|NDVI\|CHM\|ortomosaico\|satelite` em `lib/` = 0 (fora de comentários). | Integração drone (ortomosaico/CHM/NDVI por parcela), 1 parcela/10–20 ha, rastreio de substituição. |
| **RG-05** registro de treinamento/competência | **AUSENTE** | `Competencias` só schema (`database.dart:481`, `mrv_tables.dart:507-516`); grep `competencia\|treinamento` em services/screens = 0. | Cadastro de treinamento + evidência (link `ativos_brutos`) + validade. |
| **RT-03** permanence/anti-reversão por sensoriamento | **AUSENTE** | `risco_reversao`/`fogoHistorico` só colunas (`mrv_tables.dart:243,256`); grep `fogo\|queimada\|desmatamento\|reversao` fora de schema = 0. | Alertas de fogo/desmatamento/corte sobre a área do projeto. |

---

## 2. Priorizado pelo maior impacto no MRV (primeiro o que mais derruba auditoria)

1. **RS-03 (P0, Anexo)** — incerteza amostral propagada a tCO₂e (±%, IC, n): **ausente**. Sem isso o número de carbono não é defensável; o pitch promete "margem de certeza" (página 3). Colunas existem (`mrv_tables.dart:429,451`) mas `MrvCalcService` não calcula nada disso.
2. **RC-05** — tempo confiável: hoje **todo** timestamp (trilha, createdAt, fotos_meta) vem do relógio ajustável do celular (`database.dart:1571-1596`). Sem offset device↔servidor, a "hora da evidência" não prova nada.
3. **RC-06 + RC-07 (custódia)** — **risco de destruir evidência já no código**: `purgarDeletados(diasRetencao: 30)` apaga arquivos de fotos + linhas (`database.dart:1485-1514`) e `_limparDadosParcela` faz hard delete (`parcela_form_screen.dart:1801-1802`, `:1787`). Falta trilha no sync, WORM, política de retenção escrita. Desligar o purge de 30 dias é a ação mais urgente.
4. **RC-09** — dossiê do verificador auto-verificável (manifesto de hashes): o pitch promete "dossiê gerado com rastro de cada número" (página 5); hoje o export (XLSX/PDF/ZIP) não leva hash nenhum.
5. **RQ-04** — `insumosHash`/hash do resultado no `calculos_mrv`: sem isso o auditor não consegue "refazer a conta" (pitch página 6, diferencial nº 2).
6. **RG-06** — incidentes existem mas `bloqueiaUsoParaCredito` nunca é ligado; dado suspeito segue contando.
7. **RT-01 (P0, Anexo)** — vínculo parcela→período/projeto no sync (`projeto_id` não vai no push; grep = 0 em `sync_service.dart`) e criação de novos períodos/campanhas no app.
8. **RC-11 / RC-13 / RC-14 (restos)** — gravar `protocoloVersao` na parcela; povoar `Dispositivos`; `exifPreservado` + `n_satelites` na foto.
9. **RT-02 / RT-04** — revisitas (campanhas) e baseline/adicionalidade no projeto (entra no PD).
10. **P2** — RS-06 (drone), RG-05 (treinamento), RT-03 (permanence): todos ausentes, nenhum código fora do schema.

---

## 3. Promessas do pitch ainda não cobertas pelo app

Fonte: `C:\Users\Badger\urutau-pitch\Urutau_MRV_MachineLearning_v3_final.txt`

| Promessa do pitch | Estado no app |
|---|---|
| p3: "o sistema não dá só o número: diz o quanto confia nele" (margem de certeza) | **Não coberto** — RS-03 ausente (sem ±%/IC). |
| p5: "dossiê de auditoria gerado com rastro de cada número" | **Parcial** — hash/trilha existem, mas export não gera pacote com manifesto de hashes (RC-09). |
| p6–7: "cada medição e foto tem GPS, timestamp e autor" | **Feito em v28** (hash+GPS+dono por foto/planta, `fotos_meta` no sync `sync_service.dart:1490-1506,1688`) **com ressalvas**: timestamp = relógio do device sem offset (RC-05 ausente) e `n_satelites` null (`parcela_form_screen.dart:392`). |
| p7: "sincronização sem perdas, sem duplicatas" | **Feito** — upsert versionado por `updated_at`, fim do delete+recreate (`sync_service.dart:1781-1787`). |
| p3/p8: "1% → 100% da área medida via drone e satélite"; Fase 2 (ortomosaico/CHM/NDVI); Fase 3 (ML) | **Não coberto** — zero menção a drone/NDVI/CHM/satélite em `lib/` (RS-06, RT-03 ausentes). ML fora de escopo ano 1 está **consistente** com RQ-06 e com o próprio pitch ("ML é a última fase"). |
| p9: "entregamos o dossiê completo; aprovação final é da verificadora" | **Parcial** — dossiê sem manifesto de hashes e sem papel de verificador no app. |

---

## 4. Nota sobre o OFFLINE_REWORK.md

`D:\projetos\urutau\OFFLINE_REWORK.md` (na raiz, não em docs/) refere-se a **outro projeto** (`/home/badger/ProjetosBadger/urutau-ultra/`, caminho Linux — ver §"Auditoria Final" do próprio doc): um plano "100% offline" que **removeria** GPS, audit log, sync e automações de carbono. No `urutau-app` atual (este monorepo), sync/auth/GPS foram **mantidos e reativados** (ex.: `geolocator` de volta no `pubspec.yaml:35`), então os "fica de fora" desse doc **não se aplicam** ao app MRV. Pendências registradas lá: apenas `flutter analyze` (T25 ⏳) e build APK real (T26 ⏳), ambos daquele outro diretório. **Nenhum item de MRV pendente nesse arquivo.**

---

## 5. Anexo — verificação rápida dos P0 citados no exemplo do pedido (RC-03, RS-03, RT-01) e dos demais P0

| Item | Status | Evidência |
|---|---|---|
| RC-02 upload do bruto | **FEITO** (app) | Original sobe: `sync_service.dart:1747-1767` ("D-1: o ORIGINAL sobe", `fileToSend = file`); picker sem re-encode (commit `4024076`); `cleanCompressedPhotos` sem chamador no sync (grep = só definição `image_service.dart:218`). |
| RC-03 soft-delete | **PARCIAL** | Soft-delete de entidades OK: `softDeleteParcela`/`restaurar` `database.dart:1421-1461`, `deletedAt` em parcelas/plantas/fotos + filtros (`:58,110,151`). **Mas** purge de 30 dias hard-deleta arquivos+linhas (`database.dart:1485-1514`), `_limparDadosParcela` hard-deleta (`:1801-1802` no form), `deletePhoto` ainda chamado em edição (`parcela_form_screen.dart:1533,1787`; `image_service.dart:178-188`). |
| RC-04 hash na origem + verificação | **FEITO** (com ressalva) | Hash no device `image_service.dart:26-37`; recheck antes do upload `sync_service.dart:1747-1759`; divergência abre incidente `database.dart:1316-1325`; teste `test/s3_hash_test.dart`. **Ressalva:** flags `sha256_verificado`/`arquivo_estado='enviado_verificado'` não são gravadas pelo sync após upload (grep em `sync_service.dart` = 0; só a migração marca dados antigos `database.dart:347-352`) — máquina de estados D-1 trava em `capturado` para fotos novas. |
| RC-10 GPS obrigatório | **FEITO** | Obrigatório ao concluir `parcela_form_screen.dart:1589-1594`; geoJson com acurácia/datum/fix_em `:408-418`; `geolocator` `pubspec.yaml:35`; sync leva `geo_json` `sync_service.dart:1680`. `n_satelites` null (`:392`). |
| RC-12 catálogo de espécies | **FEITO** | `assets/dados_especies.xlsx` existe e está no pubspec (`:96`); entrada fechada via `species_service.dart` (carrega XLSX `:46-80`); commit `253e9b9`. |
| RS-01/RS-02 área+marcador | **FEITO** | `areaM2/unidadeForma/raioM/marcador/parcelaIdText` no form e no sync (push `sync_service.dart:1681-1684`, pull `:1002-1024,1110-1136`). |
| RS-03 incerteza (P0) | **AUSENTE** | Colunas existem (`mrv_tables.dart:429,451`); `MrvCalcService.calcularParcela` não calcula ±%/IC (`mrv_calc_service.dart:30-77`); grep `incerteza` em services/screens = 0. |
| RQ-01/RQ-02 cálculo + fatores | **FEITO** | Chave 2014 pantropical versionada (`mrv_calc_service.dart:11-26`, `garantirEquacaoPadrao :81-105`); 0,47 e 44/12 explícitos e persistidos (`:25-26,56-57,126-127`); teste `test/mrv_calc_test.dart`. |
| RQ-03 densidade por espécie (P0) | **PARCIAL** | Catálogo fechado existe, mas `EspecieItem` não tem densidade (`especie_item.dart:1-27`); `especies_catalogo.densidade_basica` nasce NULL de propósito (`mrv_migration.dart:226-237`); `calcularParcela` é chamado **sem** densidade (`parcela_form_screen.dart:110,1758-1761`) → usa fallback 0,60 (`mrv_calc_service.dart:27,46`). |
| RG-01/RG-02 papéis + fluxo aprovação | **FEITO** (app) | Fluxo pendente→revisado→aprovado no form (`parcela_form_screen.dart:93-94,909-915,1711-1713`); `status_verificacao` no sync push `:1685` e pull `:1026,1138`; commit `93ba7bc`. |
| RG-04 trilha encadeada | **FEITO local / PENDENTE sync** | `logTrilha` encadeada `database.dart:1552-1601`, `verificarCadeiaAuditoria :1605-1641`, dual-write no `logAudit :1538-1546`; teste `test/rg04_trilha_hash_test.dart`. **Mas** a trilha não sincroniza ao servidor (grep `trilha` em `sync_service.dart` = 0). |
| RT-01 período de monitoramento (P0) | **PARCIAL** | `periodos_monitoramento` + backfill `LEGADO-PER-0000` baseline (`mrv_migration.dart:111-116`); `projeto_id` backfill `:133-134`. Falta: app não cria períodos/campanhas novas e o sync não envia `projeto_id` (grep em `sync_service.dart` = 0). |
| v28 foto/planta GPS+dono | **FEITO** | `fotos_parcela` e `plantas` ganham `lat/long/autorUuid` (`database.dart:170-173,125`); migração `:356-371`; sync `fotos_meta` `sync_service.dart:1490-1506,1688`. |

**Commits de hoje confirmados via `git log`:** `64e258c` RC-10 · `253e9b9` RC-12 · `0fecef1` RS-01/02 · `7c85210` RQ-01..03 · `3559822` RG-04 · `93ba7bc` RG-01/02 · `2b1a855` v28 · `c8504f9` S3/RC-04 · `6c2dd75` D-1/RC-03 · `53a7284` upsert versionado · `1123a32`/`efd2b1d` S1/S2 catálogo (RC-01).

---

*Relatório gerado por auditoria read-only; nenhum arquivo de código foi modificado.*
