# Análise do acervo de evidências t23 (`docs/evidencias-t23/`)

- **Objeto:** veredicto honesto e citado da verificação independente da ronda 2, consolidando o acervo `docs/evidencias-t23/` (dumps de `bounds` do uiautomator + PNGs).
- **HEAD avaliado:** `83f8a40` (`docs(t22): provas ao vivo da constraint UNIQUE e dos dois caminhos da migration`, 2026-11-10 18:50 -0300).
- **Data desta verificação:** 2026-11-10 21:48 -0300.
- **Execução:** subagente verificador, autónomo. Não correu gate nenhum (`flutter analyze`/`flutter test`/`flutter build`); não tocou no servidor PocketBase, no emulador nem em nenhum processo; git apenas de leitura (`log`/`status`/`diff`); nenhum ficheiro existente alterado; nada commitado.
- **Método de medição:** comparação por SHA-256 do conteúdo integral de cada ficheiro; para os pares, alinhamento posicional dos nós por identidade (`class` + `resource-id` + `content-desc` + `text`) e cálculo da delta de `bounds` nó a nó (`dx1,dy1,dx2,dy2` e deltas de largura/altura). Script usado: análise externa ao repositório, em diretório temporário; nenhum ficheiro do repo foi escrito por esta verificação além deste documento.

## 1. O que este acervo prova e o que não prova

**Parede de honestidade que governa todo o documento:** os ficheiros `.xml` são dumps de `bounds` do uiautomator — cada nó traz `<… bounds="[x1,y1][x2,y2]">`. Isso mede **geometria** (posição, tamanho, área de toque). `bounds` não contém cor, contraste, peso de fonte nem estado de conectividade. Portanto:

| Afirmação | Está provada por este acervo? |
|---|---|
| Paridade de métrica/layout entre tema claro e altoContraste (mesmos nós, mesmas coordenadas) | **Sim — quando o par compara o mesmo ecrã nos dois temas** (medição em §3) |
| Conformidade de contrato geometria↔captura: FAB, cartões, appbar, menu nos lugares esperados | **Sim** (bounds medidos, §3 e §5) |
| Contraste de cor (WCAG) dos temas | **NÃO.** XML de `bounds` não carrega cor. Coberto por código de teste, não por este acervo: `urutau-app/test/theme_legibilidade_test.dart` (pares fundo/texto ≥ 4.5:1 e não-texto ≥ 3:1 em todos os temas) + `urutau-app/test/theme_contrast_test.dart` (tokens do alto contraste + aplicação do tema sem vazar cor clara) + `urutau-app/test/hc_spacing_test.dart` (métrica de texto/peso igual entre temas) — todos travados pelo gate `flutter test` (registo mais recente em `docs/verificacao-t14.md`, HEAD `128e1ab`). |
| Estado de modo avião / perfil convidado como comportamento | **Não integralmente.** O XML do caso é byte-idêntico aos dumps da home (§4); a prova ao vivo do modo avião ficou noutro HEAD, em `docs/verificacao-ronda-2.md` §6. |
| Sequência de 4 estados de sync | **Não.** `ui_sync2/3/4.xml` são o mesmo dump repetido (§5). |

Nenhuma medição neste documento foi inventada: todos os números vêm de leitura directa dos ficheiros de `docs/evidencias-t23/` ou de citação dos docs de `docs/`.

## 2. Gates neste HEAD (`83f8a40`)

**Não executado por este subagente** (nenhum gate corre nesta verificação; ver secção 6 para a lacuna que isso deixa). O que os registos existentes dizem:

| Gate | Registo | HEAD do registo | Distância para `83f8a40` |
|---|---|---|---|
| `flutter analyze` | 0 erros, 53 warnings, 149 infos (202 issues) — `docs/verificacao-t14.md` §3 | `128e1ab` | 17 commits antes |
| `flutter test` | 151/151 "All tests passed!" — `docs/verificacao-t14.md` §3 | `128e1ab` | 17 commits antes |
| `flutter build apk --release` | exit 0 após `flutter clean` (68,0 MB); dist com `libapp.so` arm64 igual ao build (`FB9BB8C3…`) — `docs/verificacao-t14.md` §1-§2 | `128e1ab` | 17 commits antes |
| Bateria adversarial de upload (t17) | 8/8 casos PASS, app sempre vivo, zero estado inconsistente — `docs/adversario-ficheiros-hostis.md` | APK de `dist/` (não build do HEAD) | — |

Entre `128e1ab` e `83f8a40` há **6 commits que tocaram `urutau-app`** (`0597177`, `419edde` — backup automático; `40d4062` — remoção do tema Kanagawa; `2ee0315`, `457e622`, `bcbbcc4` — testes/refactor), com `lib/` alterado em 9 ficheiros (+268/−341 linhas, `git diff --stat 128e1ab..83f8a40 -- urutau-app/lib`). **Nenhum dos docs lidos regista `analyze`/`test`/`build` corridos no HEAD `83f8a40`.** O que se pode dizer com honestidade: os gates estavam verdes em `128e1ab` e nenhum commit posterior alega quebrá-los, mas a re-corrida neste HEAD é uma lacuna em aberto (§6), não uma seguranca.

Nota de contexto que favorece a ronda 2: o commit `40d4062` removeu o tema Kanagawa e `lib/services/theme_provider.dart:9` passa a declarar `enum ThemeModeUrutau { claro, altoContraste }` — o conjunto de temas tem exactamente 2 membros, e este acervo captura os dois. As evidências de tema cobrem portanto 100 % dos temas actuais (em `128e1ab` havia 3, e faltaria o terceiro).

## 3. Paridade de métrica entre temas (medição real)

Acervo: 18 ficheiros `.xml` + 7 `.png` em `docs/evidencias-t23/`, capturados em 2026-11-10 (timestamps 18:32–19:57), ecrã **320×640 px** (raio `[0,0][320,640]` em todos os dumps). Por SHA-256, os 18 XML contêm apenas **8 conteúdos distintos** — sete ficheiros são cópias do mesmo dump. Isso por si já reduz o que o acervo consegue provar.

### 3.1 Pares temáticos válidos (mesmo ecrã, dois temas)

**HOME — `ui_home_claro.xml` vs `ui_home_altoContraste.xml`: byte-idênticos** (SHA-256 `533308db…`, 9100 B, 27 nós; capturas a 19:50:00 e 19:50:19). 27/27 nós alinhados por identidade, **0 com bounds diferentes**. Nós representativos (idênticos nos dois dumps):

| Nó | Bounds claro | Bounds altoContraste | Delta | Veredicto |
|---|---|---|---|---|
| raiz FrameLayout | `[0,0][320,640]` | `[0,0][320,640]` | 0 px | iguais |
| cartão "UT01 — Parcela 1" (View) | `[16,96][304,212]` (288×116) | `[16,96][304,212]` (288×116) | 0 px | iguais |
| FAB estendido "Nova Parcela" (Button) | `[152,568][304,624]` (152×56) | `[152,568][304,624]` (152×56) | 0 px | iguais |

Confirmação visual: `ui_home_claro.png` (fundo claro, cartões verdosos, FAB verde) e `ui_home_altoContraste.png` (fundo preto, texto branco/amarelo, cartões com borda amarela, FAB amarelo) mostram a **mesma lista na mesma ordem** (UT01, UT05, UT03, UT06, UT03). Os PNGs sustentam que os dois temas foram de facto renderizados; a paridade métrica vem dos XML.

**MENU — `ui_menu_claro.xml` vs `ui_menu_altoContraste.xml`: byte-idênticos** (SHA-256 `5d314765…`, 4651 B, 14 nós; capturas a 19:02:20 e 19:02:45). 14/14 nós alinhados, **0 diferenças**:

| Nó | Bounds claro | Bounds altoContraste | Delta | Veredicto |
|---|---|---|---|---|
| painel do menu (Spinner) | `[32,32][312,292]` (280×260) | idem | 0 px | iguais |
| item "Puxar do servidor" | `[32,40][312,116]` (280×76) | idem | 0 px | iguais |
| item "Baixar minhas fotos" | `[32,116][312,172]` (280×56) | idem | 0 px | iguais |
| item "Configurações" | `[32,172][312,228]` (280×56) | idem | 0 px | iguais |
| item "Sair" | `[32,228][312,284]` (280×56) | idem | 0 px | iguais |

**UI_PH — `ui_ph_claro.xml` vs `ui_ph_altoContraste.xml`: par INVÁLIDO como prova de altoContraste.** Os dois são byte-idênticos entre si **e ao `ph1_claro.xml`** (SHA-256 `128cacf3…`, 5691 B, 17 nós): o dump rotulado "altoContraste" é uma cópia do dump claro. A paridade existe no papel (0 deltas) mas não é evidência independente — é o mesmo ficheiro com dois nomes (defeito D4, §6). Agrava-o que `ui_ph_altoContraste.png` mostre o wizard "Editar Parcela" em tema escuro, ecrã diferente do diálogo que o XML do mesmo nome descreve (defeito D5).

### 3.2 PH1 — o único par diálogo claro/escuro genuíno, e ele **não** tem paridade

`ph1_claro.xml` (17 nós) vs `ph1_altoContraste.xml` (17 nós), ambos com o diálogo "Parcela já sincronizada" (textos idênticos nos dois). 17/17 nós alinhados por identidade, raiz `[0,0][320,640]` igual — mas **6 dos 17 nós (35 %) têm bounds diferentes**:

| Nó | Bounds claro | Bounds altoContraste | Delta | Veredicto |
|---|---|---|---|---|
| contentor do diálogo (View) | `[40,102][280,562]` (240×460) | `[40,132][280,532]` (240×400) | `dy1 +30`, altura **−60** | **diferente** |
| título "Parcela já sincronizada" | `[64,174][256,238]` (192×64) | `[64,204][256,256]` (192×52) | `dy1 +30`, `dy2 +18`, altura −12 | **diferente** |
| corpo do diálogo (View) | `[64,254][256,414]` (192×160) | `[64,272][256,384]` (192×112) | `dy1 +18`, `dy2 −30`, altura −48 | **diferente** |
| texto do corpo | `[64,254][256,414]` (192×160) | `[64,272][256,384]` (192×112) | idem | **diferente** |
| botão "Cancelar" | `[176,438][256,486]` (80×48) | `[177,408][256,456]` (79×48) | `dx1 +1`, `dy −30`, largura −1 | **diferente** |
| botão "Sim, editar" | `[133,486][256,538]` (123×52) | `[131,456][256,508]` (125×52) | `dx1 −2`, `dy −30`, largura +2 | **diferente** |

Resumo numérico do par: deslocamento vertical máximo **30 px**; delta de altura do contentor **60 px**; largura de botão a variar **1–2 px**; 11 nós iguais. Os `bounds` por si não dizem **porquê** — as causas possíveis incluem exactamente a classe de regressão que `urutau-app/test/hc_spacing_test.dart` existe para travar (tema a fixar `textTheme` com tamanhos/pesos diferentes → texto embrulha mais cedo → layout "respira" diferente) ou dois estados de captura distintos. Não invento a causa: o que está medido é que o par PH1 **não tem paridade de métrica**, e isso contradiz qualquer alegação de "zero diferenças de layout" para este ecrã (defeito D1, §6).

### 3.3 PH2 e PH3 — pares temáticos INVÁLIDOS (ecrãs diferentes)

- **PH2:** `ph2_claro.xml` (27 nós) mostra a **home** do perfil Convidado (cartões UT01/UT05/UT03/UT06, "Tudo sincronizado", FAB); `ph2_altoContraste.xml` (48 nós) mostra o **wizard "Editar Parcela"** (Etapa 1 de 4, GPS, DIMI0020/UT01, Voltar/Continuar). Alinhamento por identidade: 9/27 nós, 18 só no claro, 39 só no altoContraste; os 9 alinhados têm bounds iguais. Comparar estes dois ficheiros é comparar dois ecrãs — não é prova de tema (defeito D2).
- **PH3:** `ph3_claro.xml` (17 nós, cópia do diálogo de PH1) vs `ph3_altoContraste.xml` (49 nós: o wizard mais o erro de validação "Raio: Informe o raio em metros"). 9/17 nós alinhados, 8 só no claro, 40 só no altoContraste; o único nó alinhado com delta é um View `[0,0][320,640]` no claro vs `[0,0][320,80]` no altoContraste (altura −560 px) — assinatura de ecrãs diferentes, não de tema (defeito D3).

**Saldo da secção:** paridade de métrica provada em HOME (27/27, Δ0) e MENU (14/14, Δ0); paridade **refutada pela medição** no par PH1 (6/17 nós, até 30 px/60 px); PH2 e PH3 não são pares temáticos.

## 4. Modo avião / perfil convidado (`ui_aviao_convidado.*`)

O que a evidência mostra:

- `ui_aviao_convidado.xml` (9100 B, 27 nós) é **byte-idêntico** a `ui_home_claro.xml` e a `ui_home_altoContraste.xml` (SHA-256 `533308db…`). Conteúdo: perfil "Urutau – Convidado" com "Nunca sincronizado", campo "Filtrar por data ou talhão", chip "Tudo sincronizado", 5 cartões (UT01, UT05, UT03, UT06, UT03 — "0 plantas / 0 fotos / 10/11/2026 22:32"), FAB "Nova Parcela" `[152,568][304,624]`.
- `ui_aviao_convidado.png` (46 678 B; bytes distintos dos dois PNGs de home, 46 897 e 42 057 B) renderiza a lista em **tema claro**, com os cartões de convidado e sem nenhum banner de "offline"/"modo avião" visível.

O que **não** está provado por este acervo:

- Que o modo avião estava activo no momento da captura: a árvore do XML não tem nenhum nó de estado de conectividade, e sendo byte-idêntica à da home normal, não carrega qualquer diferença atribuível ao modo avião (defeito D8, §6).
- Qualquer comportamento de primeira abertura sem login: isso foi provado ao vivo noutro HEAD — `docs/verificacao-ronda-2.md` §6 (airplane on + `pm clear` + `am start` → "/home como Convidado, sem tela de login", perfil "Nunca sincronizado", parcelas guest) no HEAD `c8f239d`.

Veredicto da secção: o acervo confirma o **perfil convidado e o estado "Nunca sincronizado" coerente com uso offline**, e é coerente com o registo anterior de modo avião; não constitui, por si, prova ao vivo do modo avião.

## 5. Ecrãs de sync (`ui_sync1..4`) e pós-instalação (`ui_pos_install`)

- `ui_pos_install.xml` e `ui_sync1.xml` são **byte-idênticos** (SHA-256 `c018c315…`, 9121 B, 27 nós). Conteúdo: home do perfil "Urutau – Admin Emulador" (seed), appbar `[0,80][320,640]`, cartões "UT-77 — Parcela 7 (3 plantas)" `[16,96][304,212]`, "UT-90 — Parcela 90 (50 plantas)" `[16,212][304,328]`, "UT01/UT05/UT03 — Parcela 1 (0 plantas)" e FAB `[152,568][304,624]`, chip "Tudo sincronizado". Este dump mostra um estado de **home sincronizada pós-sync** — coerente com os registos de sync idempotente (`docs/verificacao-t14.md` §6 e `docs/verificacao-ronda-2.md` §4: servidor 2 parcelas/53 plantas, 0 ids duplicados em todas as rondas).
- **Defeito:** `ui_pos_install.png` (9509 B) mostra o **splash do Flutter** (logo azul), não a home que o XML do mesmo nome descreve. O PNG e o XML do "pós-instalação" são de estados diferentes do arranque (defeito D6, §6).
- `ui_sync2.xml`, `ui_sync3.xml`, `ui_sync4.xml` são os **três byte-idênticos ao diálogo "Parcela já sincronizada"** (SHA-256 `128cacf3…`; capturas a 18:56:01, 18:56:33 e 18:57:05, ~32 s de intervalo). Quatro capturas de sync produziram **2 conteúdos distintos**: a home "Tudo sincronizado" e o diálogo de parcela já sincronizada. O acervo **não mostra uma sequência de 4 estados de sync** — não prova progresso de sync, contagens, nem erros a caminho (defeito D7, §6).

## 6. Lacunas remanescentes (com nome honesto)

| # | Lacuna / defeito | Evidência | Nome honesto |
|---|---|---|---|
| D1 | Par PH1 sem paridade de métrica: 6/17 nós diferem (até 30 px; contentor −60 px; botões ±1–2 px) | `docs/evidencias-t23/ph1_claro.xml`, `ph1_altoContraste.xml` | regressão de métrica entre temas não refutada por este par; a guarda `hc_spacing_test.dart` cobre a classe de bug em teste unitário, mas o par ao vivo falhou |
| D2 | PH2 compara home (claro) com wizard (altoContraste) | `ph2_claro.xml` (27 nós) vs `ph2_altoContraste.xml` (48 nós) | par não comparável |
| D3 | PH3 compara diálogo (claro, cópia do PH1) com wizard + erro (altoContraste) | `ph3_claro.xml` vs `ph3_altoContraste.xml` | par não comparável |
| D4 | `ui_ph_altoContraste.xml` é cópia byte-a-byte de `ui_ph_claro.xml` (= `ph1_claro.xml`) | SHA-256 `128cacf3…` em 7 ficheiros | evidência de altoContraste ausente para esse ecrã |
| D5 | `ui_ph_altoContraste.png` (wizard escuro) não corresponde ao XML do mesmo nome (diálogo claro copiado) | `ui_ph_altoContraste.png` vs `.xml` | incompatibilidade PNG/XML |
| D6 | `ui_pos_install.png` mostra o splash; o XML do mesmo nome mostra a home (= `ui_sync1.xml`) | `ui_pos_install.png` vs `.xml` | incompatibilidade PNG/XML |
| D7 | `ui_sync2/3/4.xml` são o mesmo dump repetido; não há sequência de 4 estados | SHA-256 `128cacf3…` ×3, timestamps 32 s | evidência de sequência de sync ausente |
| D8 | Modo avião não demonstrável por este acervo (XML byte-idêntico ao da home, sem nó de conectividade) | `ui_aviao_convidado.xml` vs `ui_home_*.xml` | prova herdada de `docs/verificacao-ronda-2.md` §6 (HEAD `c8f239d`), não revalidada em `83f8a40` |
| D9 | Gates não re-corridos nem registados no HEAD `83f8a40`; último verde em `128e1ab` (17 commits antes; 6 tocaram a app) | `docs/verificacao-t14.md` + `git log 128e1ab..83f8a40` | lacuna de verificação de gate neste HEAD |
| D10 | Cor/contraste: fora do alcance destes XML (bounds não têm cor) | — | coberto só por código de teste (`theme_legibilidade_test.dart`, `theme_contrast_test.dart`, `hc_spacing_test.dart`) e pelo gate `flutter test` (ver D9) |

Este subagente **reporta** os defeitos; não corrigiu nenhum, não voltou a capturar nada e não alterou nenhum ficheiro de evidência.

## 7. Veredicto final

**O que ficou provado (com números):**

1. **Paridade de métrica entre temas, nos pares válidos:** HOME 27/27 nós e MENU 14/14 nós com delta 0 px, com ficheiros byte-idênticos (SHA-256 `533308db…` e `5d314765…`) e capturas em dois temas distintos (timestamps 19 s e 25 s apart). Nós âncora idênticos: raiz `[0,0][320,640]`, cartão `[16,96][304,212]`, FAB `[152,568][304,624]`, itens de menu de 280×56 px (`ui_home_*.xml`, `ui_menu_*.xml`).
2. **Geometria geral do app** no ecrã 320×640: appbar de 80 px, cartões de 116 px de altura, FAB estendido no canto inferior direito (`ui_pos_install.xml`, `ui_aviao_convidado.xml`).
3. **Conformidade dos temas actuais:** o conjunto de temas tem 2 membros (`claro`, `altoContraste`; `lib/services/theme_provider.dart:9`), e ambos estão capturados — 100 % de cobertura do conjunto.
4. **Coerência de estado:** perfis "Convidado" ("Nunca sincronizado") e "Admin Emulador" ("Tudo sincronizado"), diálogo de parcela já sincronizada, todos presentes nas capturas.

**O que NÃO ficou provado:**

1. **Contraste de cor** por este acervo — `bounds` não contém cor. Fica dependente dos testes de tema e do gate (D10).
2. **Paridade do diálogo PH1** — a medição refuta-a: 6/17 nós diferem, até 30 px de deslocamento e 60 px de altura (D1).
3. **Paridade em ph2/ph3** — os pares comparam ecrãs diferentes (D2, D3); a evidência de altoContraste do ecrã ph é uma cópia do claro (D4, D5).
4. **Modo avião ao vivo** neste HEAD (D8) e **sequência de 4 estados de sync** (D7).
5. **Gates verdes no HEAD `83f8a40`** — não executados por este subagente e sem registo nos docs lidos; o último verde mede outro HEAD, 17 commits atrás, com a app alterada nesse intervalo (D9).

**Conclusão:** o acervo `docs/evidencias-t23/` sustenta a paridade de métrica claro/altoContraste para a home e o menu (prova forte, byte-a-byte) e a geometria geral das telas; **não** sustenta paridade para o diálogo PH1 (medição mostra diferença real), nem para ph2/ph3 (pares inválidos), nem prova cor/contraste, modo avião ou sequência de sync. Antes de qualquer afirmação de "LISO" em métrica de UI, faltam: recapturar o diálogo nos dois temas no mesmo estado, refazer os pares ph2/ph3 como pares de ecrã único, corrigir as incompatibilidades PNG/XML e re-correr os gates no HEAD `83f8a40`.

---

*Evidências citadas neste documento, todas em `D:\projetos\urutau\docs\evidencias-t23\`: `ph1_claro.xml`, `ph1_altoContraste.xml`, `ph2_claro.xml`, `ph2_altoContraste.xml`, `ph3_claro.xml`, `ph3_altoContraste.xml`, `ui_home_claro.xml`, `ui_home_altoContraste.xml`, `ui_menu_claro.xml`, `ui_menu_altoContraste.xml`, `ui_ph_claro.xml`, `ui_ph_altoContraste.xml`, `ui_aviao_convidado.xml`, `ui_aviao_convidado.png`, `ui_pos_install.xml`, `ui_pos_install.png`, `ui_sync1.xml`, `ui_sync2.xml`, `ui_sync3.xml`, `ui_sync4.xml`. Documentos de apoio: `docs/ronda-2.md`, `docs/auditoria-ronda-1.md`, `docs/verificacao-ronda-2.md`, `docs/verificacao-t14.md`, `docs/adversario-ficheiros-hostis.md`, `urutau-app/test/theme_legibilidade_test.dart`, `urutau-app/test/theme_contrast_test.dart`, `urutau-app/test/hc_spacing_test.dart`.*
