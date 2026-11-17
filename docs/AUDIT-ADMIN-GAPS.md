# AUDIT-ADMIN-GAPS — painel `urutau-admin` (auditoria read-only)

**Alvo:** `D:\projetos\urutau\urutau-admin` (React 19 + Vite 8 + Tailwind 4 + PocketBase JS SDK 0.27)
**Data:** auditoria estática, sem servidor PocketBase no ar (máquina formatada — sobe só no lançamento).
**Escopo lido:** `src/App.jsx`, `src/main.jsx`, `src/index.css`, `src/context/AuthContext.jsx`, `src/services/pocketbase.js`, `src/services/logger.js`, `src/components/Layout.jsx`, `src/components/ErrorBoundary.jsx`, `src/pages/{Dashboard,Login,Parcels,Photos,Reports,Users}.jsx`, `package.json`, `vite.config.js`, `.env.example`, `README.md`.
**Referência do app (não reinventar):** `urutau-app/lib/services/mrv_calc_service.dart`, `urutau-app/lib/services/dossie_service.dart`, `urutau-app/lib/services/sync_service.dart`, `urutau-app/lib/theme/app_tokens.dart`.

> Legenda: **EXISTE** = implementado e funcional no painel · **PARCIAL** = existe mas incompleto/enganoso · **AUSENTE** = nenhuma referência em `urutau-admin/src`.
> Todos os caminhos são relativos a `D:\projetos\urutau`.

---

## 1. Tabela de gaps

| # | Item | Status | Evidência (arquivo:linha) | Observação |
|---|---|---|---|---|
| 1 | Login (email/usuário + senha) | EXISTE | `urutau-admin/src/pages/Login.jsx:64`–`143`; `urutau-admin/src/services/pocketbase.js:151`–`196` | Formulário completo, validação de campo vazio, toggle de senha, "lembrar-me". |
| 2 | Autenticação contra PocketBase (`users` + `_superusers`) | EXISTE | `urutau-admin/src/services/pocketbase.js:161`–`190` | Tenta as duas coleções em sequência; trata 401/404/rede em `toAuthErrorMessage` (`:129`–`149`). |
| 3 | Sessão, logout, expiração de token | EXISTE | `urutau-admin/src/services/pocketbase.js:198`–`220`; `urutau-admin/src/context/AuthContext.jsx:33`–`42`, `72`–`76`; `urutau-admin/src/components/Layout.jsx:106`–`122` | `onAuthExpired` ligado no `pb.send` (`pocketbase.js:23`–`33`). |
| 4 | Papel **admin** | EXISTE | `urutau-admin/src/services/pocketbase.js:114`–`126`; `urutau-admin/src/context/AuthContext.jsx:103`; `urutau-admin/src/App.jsx:51`–`71` | `AdminRoute` protege `/users`; nav some para não-admin (`Layout.jsx:39`). |
| 5 | Papel **verificador / VVB** dedicado | AUSENTE | `urutau-admin/src/services/pocketbase.js:121` | Só existem `'admin'` e `'user'`. Não há papel read-only de verificador, nem escopo VVB/organização. |
| 6 | Painel **impõe** read-only ao verificador | PARCIAL | `urutau-admin/src/App.jsx:66`–`68`; `urutau-admin/src/components/Layout.jsx:37`; `urutau-admin/src/context/AuthContext.jsx:78`–`92`; `urutau-admin/src/services/pocketbase.js:122`–`125` | `hasPermission('edit')`/`('delete')` existem mas **nunca são chamados em nenhuma página**. `canExport: true` para todos (`pocketbase.js:124`) → qualquer usuário autenticado exporta a base inteira (`Parcels.jsx:607`,`:615`; `Reports.jsx:432`). |
| 7 | Recuperação de senha / 2FA pelo painel | AUSENTE | ausente (nenhuma referência em `urutau-admin/src`) | O app chama `requestPasswordReset` (`urutau-app/lib/services/sync_service.dart:384`); o painel não. |
| 8 | Lista de parcelas paginada | EXISTE | `urutau-admin/src/pages/Parcels.jsx:641`–`773`; `urutau-admin/src/services/pocketbase.js:222`–`241` | 25/página, ordenação `-id_parcela`, contador "Mostrando X – Y de Z". |
| 9 | Filtros de parcela (propriedade, UT, nº, usuário, fotos) | EXISTE | `urutau-admin/src/pages/Parcels.jsx:464`–`576`; `urutau-admin/src/services/pocketbase.js:451`–`487` | 6 filtros, com escaping de filter (`pocketbase.js:35`–`37`). |
| 10 | **Status de verificação** (ativa/pendente/revisado/aprovado) na lista | AUSENTE | `urutau-admin/src/pages/Parcels.jsx:701`–`711` | A coluna "Status" mostra só `prontaParaSync` ("Sync"/"Rascunho"). `status_verificacao` — que o app grava em `sync_service.dart:1822` — **não é lido em nenhum arquivo de `urutau-admin/src`**. |
| 11 | Filtro por status de verificação / projeto / período / protocolo | AUSENTE | `urutau-admin/src/pages/Parcels.jsx:543`–`557`; `urutau-admin/src/services/pocketbase.js:476`–`480` | Só filtro `syncStatus` (`prontaParaSync`). Nenhum filtro por `projeto_id`, `periodo_id` ou `protocolo_versao`. |
| 12 | Detalhe da parcela — plantas (espécie, DAP, altura, categoria) | EXISTE | `urutau-admin/src/pages/Parcels.jsx:174`–`236`; `urutau-admin/src/services/pocketbase.js:295`–`307` | Tabela no modal, com loading (`:178`–`181`) e vazio (`:182`–`185`). |
| 13 | Detalhe da parcela — **área (ha)** | PARCIAL | `urutau-admin/src/pages/Parcels.jsx:686`–`691` | Área aparece só na **lista**; o modal (`Parcels.jsx:86`–`154`) não exibe área, `area_m2`, forma da parcela ou raio. |
| 14 | Detalhe da parcela — **GPS (latitude/longitude)** | AUSENTE | ausente (nenhuma referência a `latitude`/`longitude`/`geo_json` em `urutau-admin/src`) | O app envia `latitude`, `longitude`, `geo_json`, `marcador` (`urutau-app/lib/services/sync_service.dart:1815`–`1821`); o painel ignora. |
| 15 | Detalhe da parcela — **protocolo_versao** (SOP aplicado) | AUSENTE | ausente (nenhuma referência a `protocolo_versao` em `urutau-admin/src`) | App grava `'SOP-MRV-V1'` em `sync_service.dart:1829`. |
| 16 | Detalhe da parcela — **projeto_id / periodo_id** | AUSENTE | ausente em `urutau-admin/src` | App grava ambos em `sync_service.dart:1827`–`1828`. Sem isso o verificador não sabe a qual campanha/período a medição pertence. |
| 17 | Galeria de fotos por parcela (grid/lista, zoom, download) | EXISTE | `urutau-admin/src/pages/Photos.jsx:203`–`234`, `289`–`349`; `urutau-admin/src/services/pocketbase.js:436`–`449` | Dois modos de visualização, modal com navegação prev/next, lazy loading (`Photos.jsx:215`). |
| 18 | Fotos — **hash SHA-256 por foto** | AUSENTE | ausente (nenhuma referência a `sha256`/`hash` em `urutau-admin/src`) | `fotos_meta` (hash por foto, `urutau-app/lib/services/sync_service.dart:1825`) não é lido. Promessa do pitch ("cada foto recebe hash SHA-256…") é **inauditável** no painel. |
| 19 | Fotos — **GPS, timestamp e dono por foto** | AUSENTE | `urutau-admin/src/pages/Photos.jsx:33`–`34`; `urutau-app/lib/data/database.dart:175`–`178` | O app grava GPS (`latitude`/`longitude`) e dono (`autorUuid`) **por foto** desde a v28 (`database.dart:172`–`179`), mas o painel mostra só o dono e a data **da parcela** (`Photos.jsx:33`–`34`). |
| 20 | Trilha de auditoria — exibição da cadeia `prev_hash → entry_hash` | AUSENTE | ausente (nenhuma referência a `trilha`/`entry_hash`/`prev_hash` em `urutau-admin/src`) | Não há rota, página, serviço ou tipo para `trilha_auditoria` (`App.jsx:92`–`97`). |
| 21 | Botão **"verificar cadeia no servidor"** | AUSENTE | ausente em `urutau-admin/src` | O app tem a verificação de integridade (`sync_service.dart:201`–`235`); o painel não expõe nada equivalente. |
| 22 | MRV — exibir **tCO₂e/ha** e totais | AUSENTE | ausente (nenhuma referência a `tco2e` em `urutau-admin/src`) | O cálculo existe no app (`mrv_calc_service.dart:82`–`178`) e no dossiê; o painel não mostra. |
| 23 | MRV — **insumos_hash / resultado_hash** | AUSENTE | ausente em `urutau-admin/src` | `mrv_calc_service.dart:173`–`176`, `:182`–`192`. Sem hash, o verificador não detecta alteração de insumo. |
| 24 | MRV — **equação e versão do cálculo** | AUSENTE | ausente em `urutau-admin/src` | `CHAVE-2014-PANTROPICAL`, FC 0,47, 44/12 (`mrv_calc_service.dart:23`–`28`, `:159`). |
| 25 | MRV — **margem de certeza (IC 95%)** | AUSENTE | ausente (nenhuma referência a `incerteza`/`ic95` em `urutau-admin/src`) | `mrv_calc_service.dart:45`–`79`, `:125`. Promessa "margem de certeza" inauditável no painel. |
| 26 | **Dossiê** — baixar ZIP (manifesto.json + dados.json + dossie.pdf) | AUSENTE | ausente (nenhuma referência a `dossie`/`manifesto`/`zip` em `urutau-admin/src`) | O app gera o ZIP (`urutau-app/lib/services/dossie_service.dart:169`–`198`, `:326`–`390`). |
| 27 | Dossiê em **lote** (várias parcelas) | AUSENTE | ausente em `urutau-admin/src` | — |
| 28 | Exportação Excel/CSV | EXISTE | `urutau-admin/src/services/pocketbase.js:489`–`618`; `urutau-admin/src/pages/Reports.jsx:254`–`354` | 6 tipos de relatório com registros, warning de vazio (`Reports.jsx:422`–`427`) e histórico em `localStorage` (`Reports.jsx:93`–`106`). |
| 29 | Exportação **auditável** (hash, status_verificacao, GPS, protocolo) | AUSENTE | `urutau-admin/src/services/pocketbase.js:499`–`509`, `:568`–`579`; `urutau-admin/src/pages/Reports.jsx:274`–`283` | As colunas exportadas são: propriedade, UT, parcela, área, observações, usuário, status(sync), data, fotos. Nenhum hash, GPS ou protocolo. |
| 30 | **Incidentes** abertos (lista, filtro, severidade) | AUSENTE | ausente em `urutau-admin/src` | App tem `incidentesAbertos()` e tela própria (`urutau-app/lib/screens/mrv_projeto_screen.dart:520`–`523`; `urutau-app/lib/data/database.dart:1475`). |
| 31 | **Resolver incidente** / liberar crédito | AUSENTE | ausente em `urutau-admin/src` | App resolve com trilha (`mrv_projeto_service.dart:190`–`210`); o painel não tem ação equivalente. |
| 32 | Indicador de **bloqueio de crédito** por incidente | AUSENTE | ausente em `urutau-admin/src` | RG-06: `database.dart:1459`–`1471`; dossiê marca "BLOQUEADA — incidente aberto" (`dossie_service.dart:151`). |
| 33 | **Desenho amostral** (estratos, meta de incerteza) | AUSENTE | ausente em `urutau-admin/src` | `mrv_tables.dart:101` (`incerteza_alvo`), `mrv_projeto_service.dart:84`, `:107`. |
| 34 | **Risco de reversão** | AUSENTE | ausente em `urutau-admin/src` | `mrv_projeto_service.dart:230`; `database.dart:467`. |
| 35 | **Competências** (validade, expiração) | AUSENTE | ausente em `urutau-admin/src` | `mrv_projeto_service.dart:250`–`287`; `mrv_projeto_screen.dart:591`. |
| 36 | **Verificação interna** (verificacoes_internas) | AUSENTE | ausente em `urutau-admin/src` | `mrv_projeto_screen.dart:308`. |
| 37 | Coleções MRV acessadas pelo painel | AUSENTE | `urutau-admin/src/services/pocketbase.js:226`, `:247`, `:268`, `:284`, `:297`, `:311`, `:324`, `:340`, `:355` | O painel só conhece `parcelas`, `plantas`, `propriedades`, `uts`, `users`. Nunca `trilha_auditoria`, `incidentes`, `ativos_brutos`, `desenho_amostral`, `projetos_mrv`, `campanhas`, `competencias`, `verificacoes_internas`. |
| 38 | IDs de coleção (`pbc_…`) no painel | AUSENTE | ausente em `urutau-admin/src` (e também em `urutau-app/lib`) | O painel usa **nomes** de coleção; os IDs `pbc_3294281715`/`pbc_114875327` não aparecem em nenhum código do repositório — precisam de um mapa nome→ID único (ver SPEC R0). |
| 39 | Banner **"servidor offline"** / health-check | AUSENTE | componente órfão: `urutau-admin/src/components/ui/ServerOfflineBanner.jsx:9`–`36` — **não é importado por nenhuma página** | Existe o componente (com `role="alert"`, `ServerOfflineBanner.jsx:12`), mas nenhuma tela o renderiza; não há probe de saúde nem `navigator.onLine` em `urutau-admin/src`. Ver §5. |
| 40 | Tratamento de erro por página com "Tentar novamente" | EXISTE | `Dashboard.jsx:122`–`134`; `Parcels.jsx:629`–`630`; `Photos.jsx:191`–`197`; `Reports.jsx:364`–`376`; `Users.jsx:347`–`353` | Timeout de 12 s só no Dashboard (`Dashboard.jsx:40`–`51`). |
| 41 | Diferenciar **"sem dados"** de **"servidor fora"** | PARCIAL | `urutau-admin/src/services/pocketbase.js:366`–`404` | `safeCount` transforma qualquer falha de contagem em `0` (`:372`–`376`) e `pendingParcels` deriva desse zero (`:402`) — um cartão pode mostrar "0 usuários"/"0 parcelas" em vez de acusar falha de rede ou de permissão. Hoje o Dashboard ainda mostra erro porque `getTopSpecies` propaga a falha (`:429`–`433`), mas as demais páginas não têm equivalente. |
| 42 | Fallback / **mock** com servidor ausente | AUSENTE | ausente em `urutau-admin/src` | Nenhum fixture, flag ou modo demo. `.env.example` só tem `VITE_POCKETBASE_URL` (`.env.example:1`–`3`). |
| 43 | Aviso de build/deploy sem `VITE_POCKETBASE_URL` | EXISTE | `urutau-admin/vite.config.js:8`–`14`; `urutau-admin/src/services/pocketbase.js:9`–`15` | Warning no build e `console.error` no cliente quando rodar em `github.io` sem URL. |
| 44 | ErrorBoundary | EXISTE | `urutau-admin/src/components/ErrorBoundary.jsx:1`–`55` | Genérico, sem detalhe do erro nem reporte. |
| 45 | Componentização / reuso | PARCIAL | `urutau-admin/src/index.css:87`–`127` (`.btn-primary`, `.card`, `.input-field`, `.table-header`, `.table-cell`); componentes órfãos `urutau-admin/src/components/ui/{Loading,EmptyState}.jsx` | Boa base CSS, mas: spinner de loading duplicado em 5 pontos (`Dashboard.jsx:116`–`118`, `Parcels.jsx:626`–`628`, `Photos.jsx:168`–`171`, `Reports.jsx:358`–`360`, `Users.jsx:347`–`350`); bloco de erro idêntico em 4 páginas; banner `actionError` + timer de 5 s duplicado em 4 páginas (`Parcels.jsx:411`–`418`, `Photos.jsx:122`–`129`, `Reports.jsx:380`–`387`, `Users.jsx:314`–`329`). `Loading.jsx`/`EmptyState.jsx` já existem, mas **nenhuma página os importa** (ver §5). |
| 46 | Estado vazio (empty state) | PARCIAL | `Parcels.jsx:631`–`638`; `Photos.jsx:179`–`183`; `Users.jsx:374`–`379`; `Dashboard.jsx:297`–`298`; `Reports.jsx:473`–`478` | Existe na maioria das páginas (inline, sem componente comum), mas o modal de detalhe **engole** erro de plantas (`Parcels.jsx:42`–`55`) e fotos não tem estado de "servidor indisponível" específico. |
| 47 | Estado de loading | PARCIAL | `Parcels.jsx:625`; `Photos.jsx:168` | Sem skeleton; `startTransition` usado de forma consistente. A paginação infinita de fotos foi removida na revisão de 06/11 (`Photos.jsx:52`–`71` já não tem `loadMore`/`hasMore`). |
| 48 | Acessibilidade — labels e alt | PARCIAL | `Login.jsx:67`, `:85`, `:124`; `Users.jsx:133`, `:166`, `:179`; `Parcels.jsx:466`, `:486`, `:509`, `:524`, `:544`, `:570`–`571`; `Photos.jsx:194`, `:237`, `:305`; `Parcels.jsx:646` (único `sr-only`); foco visível global `urutau-admin/src/index.css:72`–`75` | Inputs importantes têm `label`/`htmlFor`; imagens têm `alt`; `:focus-visible` padronizado e `prefers-reduced-motion` (`index.css:78`–`84`) foram adicionados na revisão de 06/11. |
| 49 | Acessibilidade — banners de erro anunciados | AUSENTE | ausente (nenhuma referência a `aria-`/`role=` em `urutau-admin/src`) | Nenhum `role="alert"`/`aria-live` nos 5 banners de erro; leitor de tela não é avisado. |
| 50 | Acessibilidade — modais (dialog, ESC, foco) | AUSENTE | `Parcels.jsx:65`–`72`; `Users.jsx:57`–`64`; `Photos.jsx:270`–`277` | Overlay manual: sem `role="dialog"`, `aria-modal`, fechamento por ESC, nem foco preso/restaurado. Botões só com ícone e sem `aria-label` (`Photos.jsx:203`–`211`, `:272`–`297`). |
| 51 | Responsivo | PARCIAL | `Layout.jsx:42`–`47`, `:128`–`133` (sidebar mobile); `Dashboard.jsx:176`; `Photos.jsx:185`; `Reports.jsx:397`; `Parcels.jsx:641` (`overflow-x-auto`) | Em telas pequenas a coluna de filtros fixa `w-64` (`Parcels.jsx:452`) consome a largura e não colapsa. |
| 52 | Dark mode / alto contraste | AUSENTE | `urutau-admin/src/index.css:34`–`40` (tokens HC existem); `urutau-app/lib/theme/app_tokens.dart:16`–`23` | Os **tokens** de alto contraste foram criados na revisão de 06/11 (`index.css:34`–`40`), mas **não são aplicados em lugar nenhum**: zero `prefers-color-scheme`/`dark:`/`[data-theme]` em `urutau-admin/src`. O app tem o tema HC completo. |
| 53 | Paleta/tokens alinhados ao app | PARCIAL | `urutau-admin/src/index.css:5` (`#F9F6F0`), `:12` (`#5A6B5C`), `:16`–`40` (tokens canônicos); `urutau-admin/src/theme/tokens.js:7`–`44` | Os tokens do app agora estão espelhados por completo (marca, status, MRV, HC, spacing, radius, tipografia — `tokens.js:42`–`44`), **mais nenhuma página os consome**: as telas seguem com `forest-*` (`index.css:53`–`63`, verde genérico) e escalas cinza do Tailwind, e títulos de página em `text-3xl` (30 px) contra `fontTitle` 20 do app (`tokens.js:44`). |
| 54 | Tipografia alinhada ao app | PARCIAL | `urutau-admin/src/index.css:40`–`42`; `app_tokens.dart:79`–`82` | Painel usa Inter e `text-3xl` (30 px) nos títulos de página; app usa title 20 / body 16 / small 13 / caption 11. |
| 55 | Testes automatizados | AUSENTE | `urutau-admin/package.json:8`–`13` | Não há script `test`, nem um único arquivo de teste em `urutau-admin/src`. |
| 56 | Documentação do painel | AUSENTE | `urutau-admin/README.md:1`–`16` | README é o template padrão do Vite; não descreve o painel, coleções, papéis ou setup. |
| 57 | Performance de fotos | PARCIAL | `urutau-admin/src/services/pocketbase.js:436`–`449`; `urutau-admin/src/pages/Photos.jsx:211` | `getUrl` sem pedir thumb (`?thumb=`); galeria carrega arquivos integrais. `pb.autoCancellation(false)` (`pocketbase.js:18`) faz toda requisição ir ao servidor. |
| 58 | Superfície de dados do verificador (quem coletou, quando, onde) | PARCIAL | `urutau-admin/src/pages/Parcels.jsx:696`–`700`, `:722`–`728` | Dono e data só no nível da parcela; sem prova por medição/foto. |

---

## 2. Totais

| Status | Quantidade | Itens |
|---|---|---|
| **EXISTE** | **12** | 1, 2, 3, 4, 8, 9, 12, 17, 28, 40, 43, 44 |
| **PARCIAL** | **12** | 6, 13, 41, 45, 46, 47, 48, 51, 53, 54, 57, 58 |
| **AUSENTE** | **34** | 5, 7, 10, 11, 14, 15, 16, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 42, 49, 50, 52, 55, 56 |

**Soma verificada:** 12 + 12 + 34 = **58 itens**.

---

## 3. Os 5 gaps mais graves (bloqueiam a auditoria VVB)

1. **Nenhuma prova por foto (hash/GPS/timestamp/dono)** — itens 18, 19, 29. A promessa central do pitch ("cada medição e foto recebe hash SHA-256, GPS, timestamp e dono") é **inauditável** no painel: `fotos_meta` não é lido em nenhum lugar de `urutau-admin/src`.
2. **Trilha de auditoria inexistente no painel** — itens 20, 21, 37. Sem cadeia `prev_hash → entry_hash` e sem "verificar cadeia no servidor", o painel não permite "auditoria refaz a conta" nem detecta adulteração.
3. **MRV e margem de certeza ausentes** — itens 22–25. tCO₂e/ha, IC 95%, `insumos_hash`, `resultado_hash` e equação não são exibidos; o painel é cego ao número que viraria crédito.
4. **Dossiê não é acessível pelo painel** — itens 26, 27. O ZIP com `manifesto.json`/`dados.json`/`dossie.pdf` é gerado pelo app (`dossie_service.dart`), mas o verificador não consegue baixá-lo nem ver os hashes do manifesto.
5. **Status de verificação e fluxo VVB ausentes** — itens 10, 11, 14–16, 30–36. `status_verificacao` (ativa/pendente/revisado/aprovado), `protocolo_versao`, `projeto_id`/`periodo_id`, incidentes, bloqueio de crédito, desenho amostral, risco de reversão e competências não têm nenhuma tela — e um verificador autenticado consegue **exportar a base inteira** (`pocketbase.js:124`), quebrando o read-only.

---

## 4. Leitura complementar (para a SPEC)

- App já implementa e **não deve ser reinventado**: status de parcela (`sync_service.dart:1822` usa `parcela.statusParcela`), `protocolo_versao` (`:1829`), `projeto_id`/`periodo_id` (`:1827`–`1828`), `fotos_meta` (`:1825`), trilha encadeada verificável no servidor (`:201`–`235`), incidentes bloqueadores de crédito (`database.dart:1423`–`1432`, `:1459`–`1471`), desenho amostral com meta de incerteza (`mrv_projeto_service.dart:84`, `:107`), risco de reversão (`:230`), competências com validade (`:250`–`287`), verificação interna (`mrv_projeto_screen.dart:308`), MRV com IC 95% (`mrv_calc_service.dart:45`–`79`), dossiê ZIP com manifesto de hashes (`dossie_service.dart:169`–`198`).
- Especificação do que falta: ver `docs/SPEC-ADMIN-VERIFICADOR.md`.

---

## 5. Revisão concorrente (06/11/2026 09:30) — o painel estava sendo editado durante a auditoria

**Aviso importante:** `git status` em `D:\projetos\urutau` mostra trabalho **não commitado e simultâneo** em `urutau-admin` (`src/index.css`, `src/components/Layout.jsx`, `src/pages/Photos.jsx`, `src/pages/Users.jsx` modificados; `src/components/ui/` e `src/theme/` novos). Todos os arquivos tocaram o disco às **09:28–09:29**, ~1 minuto antes da releitura. Onde a linha mudou, a tabela acima foi corrigida nesta revisão; os achados de comportamento foram **revalidados um a um**.

### 5.1 O que o trabalho concorrente já entregou (e que a SPEC pede)

| Entregue | Evidência | Estado real |
|---|---|---|
| Tokens canônicos do app (marca, status, MRV, alto contraste, spacing, radius, tipografia) | `urutau-admin/src/index.css:16`–`40`; `urutau-admin/src/theme/tokens.js:7`–`44` | **Existem, nenhuma página consome** — grep por `theme/tokens` em `src` só encontra o próprio `StatusBadge.jsx:3`. |
| `StatusBadge` canônico (cor + ícone + texto, WCAG 1.4.1) | `urutau-admin/src/components/ui/StatusBadge.jsx:15`–`29` | **Órfão**: nenhuma página importa. `Parcels.jsx:702`–`710` continua com o badge inline "Sync/Rascunho". |
| `ServerOfflineBanner` ("Servidor indisponível") | `urutau-admin/src/components/ui/ServerOfflineBanner.jsx:9`–`36` | **Órfão**: nenhuma página renderiza; não há health-check (`pb.health`). |
| `LoadingScreen`/`LoadingBlock` e `EmptyState` | `urutau-admin/src/components/ui/Loading.jsx:4`–`27`; `EmptyState.jsx:7`–`21` | **Órfãos**: as 5 páginas mantêm spinner inline (`Dashboard.jsx:116`, `Parcels.jsx:626`, `Photos.jsx:168`, `Reports.jsx:358`, `Users.jsx:347`). |
| Foco visível + `prefers-reduced-motion` | `urutau-admin/src/index.css:72`–`84` | **Aplicado** (CSS global). |

### 5.2 Defeito introduzido pela edição concorrente (corrigir antes de qualquer deploy)

- **`Layout.jsx:45` — `onClick={closeMobile}` referencia uma constante que não existe mais.** A função foi renomeada para `closeMobileNav` na linha 25; o overlay do drawer mobile (`Layout.jsx:42`–`47`) ainda chama `closeMobile`. Clicar no fundo escuro do menu **em viewport mobile dispara `ReferenceError`** e o menu não fecha. (Correção: `onClick={closeMobileNav}`.)

### 5.3 Consequência para os totais

Os **34 AUSENTE / 12 PARCIAL / 12 EXISTE** continuam válidos no nível de **comportamento do painel** (é isso que o VVB usa). O que mudou é que **parte do caminho da SPEC já tem peças prontas e desconectadas** — o trabalho restante é majoritariamente **fiação** (importar/consumir os componentes em `src/pages/*`), não criação do zero. Nenhum item AUSENTE da tabela passou a EXISTE por causa disso: nenhuma tela de trilha, incidentes, MRV, dossiê ou papel verificador foi criada.

### 5.4 Recomendação operacional

1. Corrigir `Layout.jsx:45` agora (quebra em mobile).
2. Fazer commit do trabalho concorrente antes de continuar — a auditoria acima perde validade de linha a linha edição.
3. Depois do commit, reauditar apenas os itens 39, 45, 46, 47, 48, 52, 53 (os que a revisão tocou).
4. A SPEC permanece válida; atualizar o §0 (R0) se o outro agente criar o mesmo `collections.js`.

### 5.5 Implementação em curso (09:35) — a SPEC já está sendo executada por outro agente

**Ao contrário do que a tabela diz, parte do trabalho já começou durante a auditoria.** Não é mais só peça órfã:

| Novo | Evidência |
|---|---|
| Serviço MRV/auditoria tolerante a offline | `urutau-admin/src/services/mrv.js:1`–`145` (`fetchCalculoByParcela` `:41`, `fetchTrilhaByEntidade` `:54`, `fetchIncidentesAbertos` `:94`, `fetchAtivosByParcela` `:115`, `checkServerHealth` `:138`) |
| Página de auditoria da parcela (520 linhas) | `urutau-admin/src/pages/ParcelaAuditoria.jsx:69`–`520` |
| Rota + botão de entrada | `urutau-admin/src/App.jsx` (`<Route path="parcels/:id/auditoria"`); `urutau-admin/src/pages/Parcels.jsx:729`–`745` (link "Auditar") |
| Os 4 componentes órfãos passaram a ser **usados** | `ParcelaAuditoria.jsx:27`–`30` (imports), `:186` (StatusBadge), `:204` (ServerOfflineBanner), `:136`/`:474` (LoadingBlock), `:144`/`:303` (EmptyState) |

**Itens que a implementação em curso já endereça** (continuam AUSENTE/PARCIAL na tabela porque a tabela descreve o estado auditado): 20 (cadeia exibida + botão verificar), 22 (tCO₂e/ha `ParcelaAuditoria.jsx:259`), 23 (`insumos_hash` `:298`), 25 (margem IC 95% `:271`–`275`), 14/15 (GPS `:211`–`215`, protocolo `:181`/`:235`), 12 (plantas `:313`–`324`), 30 (lista de incidentes `:94` do serviço).

**Dois defeitos na implementação nova — corrigir antes de confiar nela:**

1. **A verificação de cadeia não verifica hash nenhum.** `mrv.js:75`–`91` (`verificarCadeia`) apenas compara `entry.prev_hash` com o hash do elo anterior; **não recalcula `sha256(payload)`**, apesar de o docstring `mrv.js:68`–`71` afirmar "O painel RECALCULA a partir dos campos". O app faz o recálculo real (`urutau-app/lib/services/sync_service.dart:201`–`235`). Consequência: detecta elo removido/reordenado, mas **não detecta payload adulterado com `prev_hash` consistente** — a promessa "auditoria refaz a conta sozinho" segue não cumprida. (A mensagem da tela `ParcelaAuditoria.jsx:378` — "hash divergente" — promete mais do que o código entrega.)
2. **Nome de campo de status errado.** `ParcelaAuditoria.jsx:187` lê `parcel.status_parcela`, mas o app grava **`status_verificacao`** (`urutau-app/lib/services/sync_service.dart:1822`) e `normalizeParcelRecord` (`urutau-admin/src/services/pocketbase.js:56`–`107`) não mapeia nenhum dos dois nomes. Resultado: `statusParcela` chega `undefined` e o badge cai no fallback "Pendente" (`urutau-admin/src/theme/tokens.js:47`–`51`) para **toda** parcela — status exibido errado em silêncio.

**Ainda ausente na página nova:** `fotos_meta` (hash/GPS/timestamp/dono por foto — itens 18/19), `resultado_hash`, `equacao`/versão do cálculo, recálculo no cliente comparado ao hash do servidor, ação de **resolver** incidente, dossiê ZIP, papel verificador.

**Recomendação:** commitar o trabalho em curso antes de continuar (a auditoria perde validade de linha a cada edição), corrigir os 2 defeitos acima e alinhar o nome do campo de status com o schema real do servidor.

---

## ✅ FECHAMENTO (2026-11-06 12:2x) — commits `3bde04d`, `b2801ec`

Os 2 defeitos apontados foram **corrigidos** e vários AUSENTE virou EXISTE:

| Item do audit | Estado agora | Evidência |
|---|---|---|
| Cadeia só comparava `prev_hash` | **CORRIGIDO** — recalcula `sha256(payload canônico)` e compara com `entry_hash`; cadeia é GLOBAL (GENESIS), espelhando `sync_service.dart:200`–`248` | `urutau-admin/src/services/mrv.js` `verificarCadeiaGlobal` |
| `status_parcela` vs `status_verificacao` | **CORRIGIDO** — `normalizeParcelRecord` mapeia `statusVerificacao` (+ legado como fallback); página e badge usam o canônico | `services/pocketbase.js` `normalizeParcelRecord`, `ParcelaAuditoria.jsx` |
| MRV (tCO₂e/ha, IC95, insumos_hash) | **EXISTE** na página de Auditoria + **"Refazer a conta"** no navegador | `services/mrvCalc.js` (port fiel), `ParcelaAuditoria.jsx` |
| "Refazer a conta" / hash | **EXISTE** — `mrvCalc.js` porta `mrv_calc_service.dart` (Chave 2014, FC 0,47, 44/12, t-student) com JSON canônico no formato `jsonEncode` do Dart; **teste `tests/mrvCalc.test.js` reproduz o hash real gerado pelo app no emulador** (`6b41ee49…`) — 4/4 passando | `vitest run` |
| `fotos_meta` (hash/GPS/ts/dono por foto) | **EXISTE** — `fetchFotosMeta` + `PhotoMetaPanel` no modal; sem hash ⇒ selo "hash não verificado" | `services/mrv.js`, `components/photos/PhotoMetaPanel.jsx`, `Photos.jsx` |
| Papel verificador / `canExport: true` para todos | **CORRIGIDO** — não-admin é `verificador` read-only; `canEdit/canDelete/canExport` só admin; `isVerificador`/`isReadOnly` no AuthContext; `ReadOnlyBadge` no header | `services/pocketbase.js` `buildUserSession`, `AuthContext.jsx`, `components/ui/ReadOnlyBadge.jsx` |
| Estado "sem servidor" | **EXISTE** — `health.js` + `useServerHealth` (distingue OFFLINE de VAZIO, cache 15 s) + `ServerOfflineBanner` fixado no `Layout` | `services/health.js`, `hooks/useServerHealth.js`, `Layout.jsx` |
| Mapa de coleções (R0) | **EXISTE** — `collections.js` nome→ID (`pbc_3294281715` etc) + campos documentados | `services/collections.js` |
| StatusBadge na lista | **LIGADO** (antes componente órfão) | `Parcels.jsx` |
| `Layout.jsx:45` `closeMobile` | **CORRIGIDO** (ReferenceError no menu mobile) | `Layout.jsx` |

**Ainda AUSENTE (P2, próximos passos):** resolver incidente pelo painel (R7 — ação de escrita), dossiê ZIP no painel (R10), página MRV do projeto (R11: desenho amostral/risco/competências), dark mode HC (R13), mock `VITE_USE_MOCK` (R8.5), exportação auditável unificada (R9), modais acessíveis (R12).

**Gates atuais:** `eslint` 0 erros · `vitest` 4/4 · `vite build` OK.

---

## ✅✅ FECHAMENTO TOTAL (2026-11-06 11:1x) — commits `b2801ec`, `334fa39`, `a870a33`, `33588eb`

**Todos os P1 E os P2 da spec fechados.** O que era "AUSENTE" agora:

| Requisito | Estado | Evidência |
|---|---|---|
| **R7** Incidentes + resolver (bloqueio de crédito) | **EXISTE** | `pages/Incidents.jsx`, `services/incidentes.js` — justificativa obrigatória (min 10), read-only bloqueado, espelha `resolverIncidente` do app |
| **R10** Dossiê no painel | **EXISTE** | `services/dossie.js` + `components/dossier/DossierPanel.jsx` — manifesto publicado, download do ZIP e **conferência de hash no navegador** (confere/DIVERGE) |
| **R11** Projeto MRV (4 abas) | **EXISTE** | `pages/MrvProject.jsx` + `services/mrvProject.js` — desenho amostral (meta vs realizada: "atingida/NÃO atingida"), risco RT-03, competências RG-05 (expirada em destaque), verificação interna RG-03 (divergente abre incidente) |
| **R12** Modal acessível | **EXISTE** | `components/ui/Modal.jsx` — role=dialog, ESC, foco preso/devolvido; aplicado no resolver incidente |
| **R13** Dark mode / alto contraste | **EXISTE** | `index.css` `[data-theme="hc"]` com os tokens HC do app (preto/amarelo) + botão persistido no header |
| **R9** Exportação auditável | **EXISTE** | `services/export.js` — fonte única de colunas (status/GPS/protocolo/projeto/período/hashes/IC95/tCO₂e/crédito), CSV com BOM UTF-8, `exportarParcelasAuditavel` |
| **R8.5** Mock `VITE_USE_MOCK` | **EXISTE** | `services/mock/*` — 3 parcelas, hashes reais (port do app), cadeia com elo adulterado de propósito, `DemoBanner` obrigatório |

**Gates finais:** `eslint` 0 erros · `vitest` **10/10** · `vite build` OK.
**Restando de verdade:** só o que depende de infraestrutura externa — aplicar migrações no PocketBase quando o servidor existir, publicar o dossiê/manifesto no servidor (a UI já lê), e teste em dispositivo real do painel.
