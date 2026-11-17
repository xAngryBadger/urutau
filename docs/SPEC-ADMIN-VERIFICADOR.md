# SPEC-ADMIN-VERIFICADOR — o que `urutau-admin` DEVE ter para um VVB auditar

**Alvo:** `D:\projetos\urutau\urutau-admin` (React 19 + Vite 8 + Tailwind 4, entrada em `src/`)
**Baseline:** auditoria em [`docs/AUDIT-ADMIN-GAPS.md`](./AUDIT-ADMIN-GAPS.md) — 58 itens: **12 EXISTE / 12 PARCIAL / 34 AUSENTE**.
**Nota de revisão (06/11/2026 09:30):** durante a auditoria outro agente criou `urutau-admin/src/theme/tokens.js` e `urutau-admin/src/components/ui/{StatusBadge,ServerOfflineBanner,Loading,EmptyState}.jsx` — naquele momento **nenhuma página os importava** (ver §5 do audit). Onde esta SPEC pedir esses componentes, o trabalho é **ligar/consumir**, não criar. Corrigir antes o defeito `Layout.jsx:45` (`closeMobile` inexistente → `ReferenceError` no menu mobile).

**Nota de revisão 2 (06/11/2026 09:35):** a implementação começou — `src/services/mrv.js` e `src/pages/ParcelaAuditoria.jsx` (rota `/parcels/:id/auditoria`) já existem e **consomem** os componentes de UI. Dois defeitos a corrigir nesse código novo: (1) `mrv.js:75`–`91` não recalcula o SHA-256 do payload da trilha — só compara `prev_hash`, e a mensagem da tela promete "hash divergente" sem verificar hash (referência correta: `urutau-app/lib/services/sync_service.dart:201`–`235`); (2) `ParcelaAuditoria.jsx:187` lê `parcel.status_parcela` enquanto o app grava `status_verificacao` (`sync_service.dart:1822`) — badge cai em "Pendente" para toda parcela. R5 e R6 abaixo continuam pendentes nas partes de recálculo no cliente e verificação real de hash.
**Regra de ouro:** o app Flutter já implementa coleta, hash, trilha, MRV, incidentes e dossiê. O painel **não recalcula nada no servidor e não reinventa regra** — ele **lê, exibe, verifica e permite refazer a conta** com os dados que o app já grava.
**Prioridades:** **P1** = sem isso o VVB não assura nada (bloqueia crédito). **P2** = qualidade/conformidade, não bloqueia.

---

## 0. Mapa de coleções (pré-requisito de tudo)

O painel hoje só conhece `parcelas`, `plantas`, `propriedades`, `uts`, `users` (`urutau-admin/src/services/pocketbase.js:226`, `:247`, `:268`, `:284`, `:297`, `:311`, `:324`, `:340`, `:355`). Os IDs `pbc_3294281715` (parcelas) e `pbc_114875327` (plantas) **não aparecem em nenhum código** — o painel usa nomes.

**R0 (P1) — Mapa nome→ID único e tipado.**
- Criar `urutau-admin/src/services/collections.js` com `export const COLLECTIONS = { parcelas: 'pbc_3294281715', plantas: 'pbc_114875327', fotos: 'fotos_parcela', trilha: 'trilha_auditoria', ativos: 'ativos_brutos', incidentes: 'incidentes', desenho: 'desenho_amostral', projetos: 'projetos_mrv', campanhas: 'campanhas', competencias: 'competencias', verificacoes: 'verificacoes_internas', usuarios: 'usuarios' }` + JSDoc com os campos de cada uma (fonte: `urutau-app/lib/data/migrations/mrv_tables.dart`, `mrv_migration.dart`, `urutau-app/lib/services/sync_service.dart`).
- Nenhum arquivo de página pode usar string de coleção solta — todas passam pelo mapa. Elimina o risco de o painel ler a coleção errada quando o servidor subir com IDs definitivos.

---

## 1. Requisitos funcionais (VVB)

### R1 (P1) — Papel `verificador` read-only, de verdade
**Hoje:** só `'admin'` e `'user'` (`pocketbase.js:121`); `hasPermission('edit')`/`('delete')` existem e **nunca são chamados**; `canExport: true` para todos (`pocketbase.js:124`).
**Falta:** papel `verificador`, escopo de leitura e proibição real de exportação em massa.
**Caminho:**
1. `src/services/pocketbase.js` — `buildUserSession` (`:109`–`127`): derivar `role` de um campo do servidor (`users.role` ou `users.papel`), com fallback `isAdmin ? 'admin' : 'verificador'`; `canExport: role === 'admin' || role === 'verificador_senior'`; adicionar `canVerify` (registrar verificação interna) e `canResolveIncident`.
2. `src/context/AuthContext.jsx` — expor `isVerificador`, `isReadOnly` (`:94`–`104`).
3. Criar `src/components/guards.jsx` — `<VerifierRoute>` (bloqueia rota de escrita) e `<ReadOnlyBadge>` (chip "somente leitura" no header, `Layout.jsx:127`–`150`).
4. `src/App.jsx` — adicionar rotas novas sob `ProtectedRoute` e, quando `isReadOnly`, esconder/desabilitar botões de exportação em massa (`Parcels.jsx:604`–`619`, `Reports.jsx:429`–`446`).

### R2 (P1) — Lista de parcelas com **status de verificação** e filtros de auditoria
**Hoje:** coluna "Status" = `prontaParaSync` ("Sync"/"Rascunho") (`Parcels.jsx:701`–`711`); `status_verificacao` **não é lido** (app grava em `sync_service.dart:1822`).
**Falta:** status ativa/pendente/revisado/aprovado + filtros por projeto, período, protocolo e "sem hash".
**Caminho:**
1. `src/services/pocketbase.js` — em `normalizeParcelRecord` (`:56`–`107`) adicionar: `statusVerificacao: parcel.status_verificacao ?? 'pendente'`, `latitude`, `longitude`, `protocoloVersao`, `projetoId`, `periodoId`, `geoJson`. Em `buildFilterString` (`:451`–`487`) adicionar `status`, `projeto`, `periodo`, `protocolo`, `semHash`.
2. `src/pages/Parcels.jsx` — **ligar** o `StatusBadge` já existente (`src/components/ui/StatusBadge.jsx:15`) no lugar do badge inline de `prontaParaSync` (`Parcels.jsx:702`–`710`); adicionar os 4 filtros no bloco `:464`–`576`; adicionar colunas GPS e Protocolo.

### R3 (P1) — Detalhe da parcela completo
**Hoje:** modal tem plantas, propriedade/UT, usuário, observações, data (`Parcels.jsx:35`–`241`). **Faltam** área no modal, GPS, `protocolo_versao`, `projeto_id`/`periodo_id`, status.
**Caminho:** extrair `ParcelDetailModal` para `src/components/parcel/ParcelDetail.jsx` e criar `src/components/parcel/ParcelMetaGrid.jsx` (área ha/m², forma, raio, marcador, lat/long com link para mapa, protocolo, projeto/período, status). Dados já vêm de R2.

### R4 (P1) — Fotos com hash SHA-256, GPS, timestamp e dono (**promessa do pitch**)
**Hoje:** galeria só com nome de arquivo e metadados **da parcela** (`Photos.jsx:19`–`39`, `:33`–`34`). `fotos_meta` não é lido em nenhum lugar.
**Caminho:**
1. `src/services/pocketbase.js` — `fetchFotosMeta(parcelId)` fazendo `getOne` em `parcelas` com `fields: 'fotos_meta'` e `JSON.parse` tolerante (o app monta e sobe esse JSON em `urutau-app/lib/services/sync_service.dart:1825` e `:1624`–`1643`; campos por foto: `arquivo`, `sha256`, `lat`/`long`, `timestamp`, `autor`). A própria coleção de fotos do app carrega GPS e dono desde a v28 (`urutau-app/lib/data/database.dart:175`–`178`) — o painel deve exigir esses campos no schema do servidor.
2. Criar `src/components/photos/PhotoMetaPanel.jsx` — hash em `<code>` monospace com botão copiar, GPS, timestamp ISO + local, dono; selo **"hash não verificado"** quando `sha256` for `null` (o app nasce com hash NULL e calcula no device — `mrv_migration.dart:189`–`190`: nunca afirmar verificação sem hash).
3. `src/pages/Photos.jsx` — ligar o painel ao modal (`:318`–`347`) e adicionar coluna "Hash" no modo lista (`:238`–`248`); filtro "somente com hash" e "somente sem hash".
4. `src/services/pocketbase.js` — `getPhotoUrl` (`:436`–`449`): usar variante `?thumb=400x400` na galeria e arquivo integral no modal.

### R5 (P1) — MRV: tCO₂e/ha, IC 95%, equação, hashes — e **"refazer a conta"**
**Hoje:** zero referência a `tco2e`, `incerteza`, `ic95`, `insumos_hash` em `src/`.
**Falta:** exibir o cálculo do app (`mrv_calc_service.dart:82`–`178`) e permitir que o auditor **recalcule no cliente** e compare o hash.
**Caminho (parcialmente já implementado em `src/services/mrv.js` e `src/pages/ParcelaAuditoria.jsx`):**
1. `src/services/mrv.js` — **já existe** com `fetchCalculoByParcela` (`mrv.js:41`, coleção `calculos_mrv`) e `fetchAtivosByParcela` (`:115`). Falta acrescentar:
   - `recalcular({ plantas, areaM2, equacao })` — **porta fiel** de `mrv_calc_service.dart:82`–`192` (Chave 2014 `a=0.0673`, `b=0.976`, FC 0,47, 44/12, tabela t-95, `hashInsumos` canônico) + `calcularIncerteza` (`:45`–`79`).
   - `hashInsumosCanonico(resultado)` — mesmo JSON canônico do app (`:183`–`191`).
2. `src/components/mrv/MrvRecalc.jsx` (ou seção dentro de `ParcelaAuditoria.jsx`) — botão "Refazer a conta no navegador": recalcula, mostra delta por planta e o resultado de `insumos_hash`/`resultado_hash` — igual ⇒ selo verde "confere"; diferente ⇒ vermelho "insumos alterados". O cartão de resumo já existe (`ParcelaAuditoria.jsx:255`–`301`); falta exibir `equacao`/versão, `resultado_hash` e a **fonte** da densidade (catálogo vs fallback 0,60, `mrv_calc_service.dart:139`–`141`).

### R6 (P1) — Trilha de auditoria: cadeia + "verificar cadeia no servidor"
**Hoje:** serviço e tela **já existem** (`src/services/mrv.js:54` `fetchTrilhaByEntidade`, `:75` `verificarCadeia`; `src/pages/ParcelaAuditoria.jsx:364`–`380` com estados íntegra/quebrada), **mas a verificação não verifica hash** — só compara `prev_hash` (`mrv.js:83`–`89`), e a mensagem da tela (`ParcelaAuditoria.jsx:378`) promete "hash divergente".
**Caminho:**
1. Corrigir `src/services/mrv.js` `verificarCadeia` (`:75`–`91`) para **recalcular** `sha256(payload canônico)` de cada entrada e comparar com `entry_hash` — payload canônico em `urutau-app/lib/services/sync_service.dart:201`–`235` (`prev_hash`, acao, entidade, antes, depois, ts, origem; `dispositivo_id` e `offset_relogio_ms` ficam **fora** do hash, `sync_service.dart:171`–`173`). Devolver `{ ok, integra, quebradoEm, totalVerificados, tipo: 'elo'|'payload' }`. Só então a mensagem "hash divergente" é verdadeira.
2. `verificarCadeiaGlobal()` — mesma verificação sobre a cadeia inteira (paginada), para achar ramificação/elo inserido no meio.
3. `src/components/audit/ChainRow.jsx` — extrair a linha da cadeia de `ParcelaAuditoria.jsx` com botão copiar hash completo (hoje `shortHash` truncada, `tokens.js:73`–`76`).
4. Criar `src/pages/AuditTrail.jsx` (rota `/audit`) com filtro por entidade e aba "Verificação global" — a visualização hoje é só por parcela.

### R7 (P1) — Incidentes, bloqueio de crédito e resolução
**Hoje:** só a **lista** de incidentes abertos existe (`src/services/mrv.js:94` `fetchIncidentesAbertos`); zero ação de resolver e zero indicador de bloqueio de crédito.
**Caminho:**
1. `src/services/mrv.js` (ou `incidentes.js`) — `resolverIncidente(uuid, { justificativa })` (espelha `mrv_projeto_service.dart:190`–`210`, que registra `incidente_resolvido` na trilha) e `fetchStatusCredito(parcelaUuid)` (regra RG-06: incidente bloqueador aberto ⇒ `bloqueado`, `urutau-app/lib/data/database.dart:1459`–`1471`).
2. `src/pages/Incidents.jsx` (rota `/incidents`) ou seção em `ParcelaAuditoria.jsx`: ações "Resolver" (com justificativa obrigatória) e "Ver trilha".
3. `src/components/parcel/ParcelMetaGrid.jsx` — faixa vermelha "Crédito BLOQUEADO — incidente aberto" quando aplicável (mesma semântica do dossiê, `urutau-app/lib/services/dossie_service.dart:151`).

### R8 (P1) — Estado "sem servidor" explícito (offline / lançamento)
**Hoje:** erros por página com retry; `getStats` engole falhas e devolve `0` (`pocketbase.js:372`–`376`); nenhum banner, health-check ou mock.
**Caminho:**
1. Criar `src/services/health.js` — `checkServer()` com `pb.health.check()` + `pb.collection('users').getList(1,1)`; cache de 15 s; retorna `{ online, latencyMs, detail }`.
2. Criar `src/hooks/useServerHealth.js` — poll a cada 30 s + `navigator.onLine`; expõe `{ status, lastOkAt }`.
3. **Ligar** `src/components/ui/ServerOfflineBanner.jsx` — o componente já existe (`ServerOfflineBanner.jsx:9`–`36`, com `role="alert"` e retry) e não é importado por ninguém. Fixá-lo no topo do `Layout` (`Layout.jsx:126`–`149`) e no lugar dos blocos de erro das 5 páginas; acrescentar a variante "lento > 3 s".
4. Criar `src/components/feedback/ErrorState.jsx` e `OfflineState.jsx` (**`Spinner`/`EmptyState` já existem** em `src/components/ui/` — importar em vez de recriar). Substituir as 5 cópias de spinner inline (`Dashboard.jsx:116`–`118`, `Parcels.jsx:626`–`628`, `Photos.jsx:168`–`171`, `Reports.jsx:358`–`360`, `Users.jsx:347`–`350`), os 4 blocos de erro e os 4 banners `actionError` (`Parcels.jsx:411`–`418`, `Photos.jsx:122`–`129`, `Reports.jsx:380`–`387`, `Users.jsx:314`–`329`).
5. Criar `src/services/mock/` + flag `VITE_USE_MOCK` em `.env.example` — dados de demonstração (3 parcelas, 2 com hash, 1 cadeia íntegra, 1 cadeia quebrada) para treinar verificador e desenvolver sem servidor. **Regra:** com mock ativo, todo banner de dado exibe o selo "DADOS DE DEMONSTRAÇÃO".
6. `src/services/pocketbase.js` — `getStats` (`:366`–`404`) deve **propagar** falha de rede em vez de devolver `0`; zero só é válido quando a consulta deu certo.

### R9 (P1) — Exportação auditável
**Hoje:** colunas sem hash/status/GPS/protocolo (`pocketbase.js:499`–`509`, `:568`–`579`; `Reports.jsx:274`–`283`).
**Caminho:** um único `src/services/export.js` (fonte de colunas) usado por Parcels, Photos, Reports e Dossiê; colunas obrigatórias: `parcela, propriedade, ut, area_ha, latitude, longitude, status_verificacao, protocolo_versao, projeto_id, periodo_id, usuario, created, fotos, fotos_com_hash, insumos_hash, resultado_hash, incerteza_pct, ic95_tco2e_ha, tco2e_ha, credito_bloqueado`. CSV com BOM UTF-8 (hoje não tem, `pocketbase.js:583`).

### R10 (P2) — Dossiê no painel
**Hoje:** o app gera ZIP com `manifesto.json` + `dados.json` + `dossie.pdf` (`dossie_service.dart:169`–`198`, `:326`–`390`); o painel não oferece nada.
**Caminho:** `src/services/dossie.js` — `baixarDossie(parcelUuid)` (download do ZIP pelo PocketBase, se o arquivo estiver em `parcelas.dossie_zip`/`ativos_brutos`) e `lerManifesto(zip)` (parse de `manifesto.json` no cliente: lista `arquivo → sha256`); `src/pages/Reports.jsx` — cartão "Dossiê MRV" com "baixar por parcela" e "baixar em lote (N selecionadas)"; `src/components/dossier/ManifestTable.jsx` — tabela arquivo/hash com botão "verificar hash do arquivo baixado".

### R11 (P2) — Desenho amostral, risco de reversão, competências, verificação interna
**Caminho:** uma página `src/pages/MrvProject.jsx` (rota `/mrv`) com quatro abas, todas em `src/services/mrvProject.js` (fonte: `mrv_projeto_service.dart` — `createDesenhoAmostral` `:111`, `updateRiscoReversao` `:230`, `competenciasExpiradas` `:276`; `mrv_projeto_screen.dart:520`–`591`):
- **Desenho amostral:** estratos + meta de incerteza (`incerteza_alvo`, JSON — `mrv_tables.dart:101`) e comparação "atingiu / não atingiu" contra o IC95 realizado (R5).
- **Risco de reversão:** valor + fonte do histórico de fogo (`database.dart:467`).
- **Competências:** lista com validade e destaque para expiradas.
- **Verificação interna:** registrar verificação (convergente/divergente) — divergente abre incidente bloqueador (`mrv_projeto_screen.dart:308`).

### R12 (P2) — Acessibilidade
**Caminho:** criar `src/components/ui/Modal.jsx` (substitui os 3 overlays manuais — `Parcels.jsx:65`–`72`, `Users.jsx:57`–`64`, `Photos.jsx:270`–`277`) com `role="dialog"`, `aria-modal`, fechamento por ESC, foco preso e devolvido ao abrir/fechar; todo banner de erro com `role="alert"`; todo botão só-com-ícone com `aria-label` (`Photos.jsx:203`–`211`, `:272`–`297`); foco visível já existe (`index.css:72`–`75`); contraste mínimo AA nos selos de status.

### R13 (P2) — Dark mode / alto contraste com os tokens do app
**Caminho:** os tokens HC **já existem** (`src/index.css:34`–`40`, `src/theme/tokens.js:15`–`23`) — falta **aplicá-los**: um `@media (prefers-color-scheme: dark)` + `[data-theme="hc"]` em `src/index.css` aplicando `hcBackground/hcSurface/hcOutline/hcText`, e o botão de tema no `Layout.jsx:126`–`149` (persistido em `localStorage`). Ref.: `app_tokens.dart:16`–`23`.

### R14 (P2) — Responsivo
**Caminho:** `Parcels.jsx:452` — filtros em `<details>`/drawer abaixo de `md`, em vez de coluna fixa `w-64`; tabelas com primeira coluna sticky e scroll horizontal já existente (`Parcels.jsx:641`).

### R15 (P2) — Freshness dos dados e prova de quem viu o quê
**Caminho:** cabeçalho com "última consulta" (já existe no Dashboard, `Dashboard.jsx:145`–`153`) extendido a todas as páginas via `src/hooks/useFreshness.js`; log local de exportações já existe (`Reports.jsx:93`–`106`) — mover para `src/services/exportLog.js` e incluir `papel`, `parcelas`, `faixa de hash`.

### R16 (P2) — Testes e build
**Caminho:** `package.json` — script `test` (Vitest + Testing Library) com casos mínimos: `mrv.js` recalcular confere com fixture do app (tCO₂e/ha e IC95 de `mrv_calc_service.dart`), `trilha.js` detecta cadeia quebrada, `health.js` distingue offline de vazio, guards de papel. `README.md` — reescrever: setup, coleções, papéis, flags de ambiente.

---

## 2. Paleta e tokens propostos (extraídos de `urutau-app/lib/theme/app_tokens.dart`)

Fonte única: `app_tokens.dart:11`–`83`. **Estado atual (06/11 09:30):** o painel já tem todos esses valores declarados em `src/index.css:16`–`40` e espelhados em `src/theme/tokens.js:7`–`44` — **mas nenhuma página os consome**. A tabela abaixo fica como o contrato a cumprir (as colunas "token proposto" viram "token existente").

| Token app | Valor | Token no painel (`src/index.css` / `src/theme/tokens.js`) | Estado |
|---|---|---|---|
| `brandPrimary` | `#5A6B5C` | `--color-brand-primary` (`index.css:18`; `tokens.js:8`) | existe; ainda duplicado em `--color-urutau-700` (`index.css:12`) |
| `brandSecondary` | `#C4A47C` | `--color-brand-secondary` (`index.css:19`; `tokens.js:9`) | existe; **nenhum uso** nas telas |
| `brandBackground` | `#F9F6F0` | `--color-brand-bg` (`index.css:17`; `tokens.js:10`) | existe; aplicado no `body` (`index.css:68`) |
| `brandSurface` | `#FFFFFF` | `--color-brand-surface` (`tokens.js:11`) | existe; **nenhum uso** |
| `hcPrimary` | `#FFD600` | `--color-hc-primary` (`index.css:35`; `tokens.js:16`) | existe; **não aplicado** (sem dark mode) |
| `hcOnPrimary` | `#000000` | `--color-hc-on-primary` (`tokens.js:17`) | idem |
| `hcBackground` | `#000000` | `--color-hc-bg` (`index.css:36`; `tokens.js:18`) | idem |
| `hcSurface` / `hcSurface2` | `#141200` / `#1A1500` | `--color-hc-surface`, `--color-hc-surface-2` (`index.css:37`–`38`) | idem |
| `hcOutline` | `#332B00` | `--color-hc-outline` (`index.css:39`) | idem |
| `hcText` | `#FFFFFF` | `--color-hc-text` (`index.css:40`) | idem |
| `statusPendente` | `#E8A13A` | `--color-status-pendente` (`index.css:22`; `tokens.js:27`) | um lugar só para cor+ícone+label (RG-02); só o `StatusBadge` órfão usa |
| `statusRevisado` | `#3A7BD5` | `--color-status-revisado` (`index.css:23`; `tokens.js:28`) | idem |
| `statusAprovado` | `#3E8E4F` | `--color-status-aprovado` (`index.css:24`; `tokens.js:29`) | idem |
| `statusRascunho` (painel) | `#6B7280` | `--color-status-rascunho` (`index.css:25`; `tokens.js:30`) | acréscimo do painel para `prontaParaSync=false` (não existe no app) |
| `mrvGreen` | `#2E7D32` | `--color-mrv-green` (`index.css:28`; `tokens.js:35`) | nenhum uso ainda (não existe tela MRV) |
| `mrvGreenBg` | `#E8F5E9` | `--color-mrv-green-bg` (`index.css:29`; `tokens.js:36`) | idem |
| `danger` | `#C62828` | `--color-mrv-danger` (`index.css:30`; `tokens.js:37`) | idem (usar em incidente/bloqueio de crédito) |
| `radiusS/M/L` | 8 / 12 / 16 | `radius` (`tokens.js:43`) | só JS; o CSS ainda usa `0.5rem`/`0.75rem` fixos |
| `spaceXs…Xxl` | 4/8/12/16/24/32 | `spacing` (`tokens.js:42`) | só JS |
| `buttonHeight` | 52 | `buttonHeight` (`tokens.js` — **não exportado**, falta) | botões e inputs do mesmo tamanho |
| `cardPadding` | 12 | `cardPadding` (`tokens.js` — **não exportado**, falta) | hoje `1.5rem` fixo (`index.css:126`) |
| `fontTitle/Body/Small/Caption` | 20/16/13/11 | `font` (`tokens.js:44`) | só JS; telas usam `text-3xl` = 30 px (`Parcels.jsx:422`) — **divergente** |

**Regras de uso:** selo de status sempre com a cor do token + ícone + texto (nunca cor sozinha); hash sempre em monoespaçada; amarelo `#FFD600` **nunca** como fundo de texto corrido no tema claro — só no tema HC com texto preto.

---

## 3. Arquivos a criar/modificar (resumo do caminho)

```
urutau-admin/src/
├── services/
│   ├── collections.js      (NOVO — R0)
│   ├── mrv.js              (JÁ EXISTE — acrescentar recalcular()/hashInsumosCanonico() e corrigir verificarCadeia; R5/R6)
│   ├── trilha.js           (NOVO — R6 verificação global; ou funções em mrv.js)
│   ├── incidentes.js       (NOVO — R7 resolver + status de crédito)
│   ├── dossie.js           (NOVO — R10)
│   ├── mrvProject.js       (NOVO — R11)
│   ├── health.js           (NOVO — R8; checkServerHealth já existe em mrv.js:138)
│   ├── export.js           (NOVO — R9, substitui exportToExcel/CSV)
│   ├── exportLog.js        (NOVO — R15)
│   ├── mock/               (NOVO — R8, atrás de VITE_USE_MOCK)
│   └── pocketbase.js       (ALTERAR — papéis R1, normalize R2/R4, getStats R8, getPhotoUrl R4)
├── hooks/
│   ├── useServerHealth.js  (NOVO — R8)
│   └── useFreshness.js     (NOVO — R15)
├── components/
│   ├── ui/Modal.jsx        (NOVO — R12; StatusBadge, ServerOfflineBanner, Loading e EmptyState JÁ EXISTEM em src/components/ui/ — agora consumidos por ParcelaAuditoria.jsx:27–30; ainda órfãos nas 5 páginas antigas)
│   ├── feedback/ErrorState.jsx (NOVO — R8)
│   ├── guards.jsx          (NOVO — R1)
│   ├── audit/ChainRow.jsx  (NOVO — R6, extrair de ParcelaAuditoria.jsx)
│   ├── mrv/MrvRecalc.jsx   (NOVO — R5, "refazer a conta" no cliente)
│   ├── photos/PhotoMetaPanel.jsx                  (NOVO — R4)
│   ├── parcel/{ParcelDetail,ParcelMetaGrid}.jsx   (NOVO — R3, extraído de Parcels.jsx)
│   └── dossier/ManifestTable.jsx                  (NOVO — R10)
├── theme/tokens.js        (JÁ EXISTE — espelho de app_tokens.dart; consumir nas telas)
├── pages/
│   ├── AuditTrail.jsx      (NOVO — R6, rota /audit)
│   ├── Incidents.jsx       (NOVO — R7, rota /incidents)
│   ├── MrvProject.jsx      (NOVO — R11, rota /mrv)
│   ├── ParcelaAuditoria.jsx (JÁ EXISTE — rota /parcels/:id/auditoria; acrescentar fotos_meta, equacao, resultado_hash, resolver incidente)
│   ├── Parcels.jsx         (ALTERAR — R2, R3, R5)
│   ├── Photos.jsx          (ALTERAR — R4)
│   ├── Reports.jsx         (ALTERAR — R10)
│   └── Users.jsx           (ALTERAR — R1)
├── context/AuthContext.jsx (ALTERAR — R1)
├── App.jsx                 (ALTERAR — rotas /audit, /incidents, /mrv)
├── index.css               (ALTERAR — dark mode HC; tokens canônicos já estão em :16–:40)
├── .env.example            (ALTERAR — VITE_USE_MOCK, VITE_BASE_PATH)
├── package.json            (ALTERAR — script test)
└── README.md               (REESCREVER — coleções, papéis, ambiente)
```

---

## 4. Ordem de execução sugerida

1. **R0 + R8** (mapa de coleções, saúde do servidor, feedback components) — sem isso nada é confiável e o painel parece "vazio" em vez de "offline".
2. **R1 + R2 + R3** (papel verificador, status, detalhe) — o VVB consegue **ver** a parcela e saber em que pé está.
3. **R4 + R5** (hash por foto, MRV com IC95 e refazer a conta) — as duas promessas centrais do pitch.
4. **R6 + R7** (trilha e incidentes) — auditoria e bloqueio de crédito.
5. **R9 + R10** (export auditável, dossiê).
6. **R11…R16** (amostral/reversão/competências, acessibilidade, dark mode, responsivo, testes, docs).
